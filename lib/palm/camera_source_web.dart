import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'camera_source.dart';
import 'hand_tracker.dart';
import 'web_litert.dart' show browserCanDetectHands;

CameraSource createWebCameraSource() => WebCameraSource();

/// The browser's own camera, through `getUserMedia`: the `camera` plugin
/// cannot stream frames on the web.
///
/// The picture goes from the camera to a `<video>` element the person sees,
/// and from there, a few times a second, onto a canvas the page reads. It stays
/// in this page: nothing is recorded, uploaded or stored.
class WebCameraSource implements CameraSource, MirroredPreview {
  static int _count = 0;

  /// How often a frame is grabbed. The tracker takes about eight looks a
  /// second at most and drops what it has no time for, so more than this would
  /// only be copied for nothing.
  static const Duration _every = Duration(milliseconds: 100);

  final StreamController<CameraFrame> _frames =
      StreamController<CameraFrame>.broadcast();
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _context;
  Timer? _timer;
  String? _viewType;
  bool _mirrored = true;
  bool _streaming = false;

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  bool get previewMirrored => _mirrored;

  @override
  double get previewAspectRatio {
    final web.HTMLVideoElement? v = _video;
    if (v == null || v.videoWidth == 0 || v.videoHeight == 0) return 3 / 4;
    return v.videoWidth / v.videoHeight;
  }

  @override
  Future<void> open() async {
    if (!browserCanDetectHands()) {
      throw const CameraUnavailable(CameraProblem.unavailable, 'no camera API');
    }
    final web.MediaStream stream = await _ask();
    _stream = stream;

    final web.HTMLVideoElement video =
        web.document.createElement('video') as web.HTMLVideoElement;
    video
      ..autoplay = true
      ..muted = true
      ..playsInline = true
      ..srcObject = stream;
    // Safari wants the attribute as well as the property.
    video.setAttribute('playsinline', '');
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..backgroundColor = 'black'
      ..pointerEvents = 'none';

    final web.MediaStreamTrack track = stream.getVideoTracks().toDart.first;
    final JSAny? facing = track.getSettings().getProperty<JSAny?>(
      'facingMode'.toJS,
    );
    _mirrored = previewMirroredFor(
      facing.isA<JSString>() ? (facing as JSString).toDart : null,
    );
    if (_mirrored) video.style.transform = 'scaleX(-1)';
    _video = video;

    try {
      await video.play().toDart;
    } catch (_) {
      // A muted video may start by itself; ignore a refused play() and let the
      // wait below decide whether frames are coming.
    }
    // Frames are not there until the video has its size.
    for (int i = 0; i < 100 && video.videoWidth == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (video.videoWidth == 0) {
      await close();
      throw const CameraUnavailable(CameraProblem.unavailable, 'no picture');
    }

    final String viewType = 'kundlisaar-hand-camera-${_count++}';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => video,
    );
    _viewType = viewType;

    final web.HTMLCanvasElement canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    _canvas = canvas;
    // The page reads this canvas often; ask for one that is kept in main
    // memory so reading it is quick.
    _context =
        canvas.getContext(
              '2d',
              <String, Object>{'willReadFrequently': true}.jsify(),
            )
            as web.CanvasRenderingContext2D?;
    _streaming = true;
    _timer = Timer.periodic(_every, (_) => _grab());
  }

  /// Asks for the camera: the one facing away from the person if there is one
  /// (a phone's back camera), at about 720p; any camera, if that cannot be had.
  Future<web.MediaStream> _ask() async {
    final web.MediaDevices devices = web.window.navigator.mediaDevices;
    Future<web.MediaStream> get(JSAny video) => devices
        .getUserMedia(web.MediaStreamConstraints(video: video, audio: false.toJS))
        .toDart;
    try {
      try {
        return await get(
          <String, Object>{
            'facingMode': <String, Object>{'ideal': 'environment'},
            'width': <String, Object>{'ideal': 1280},
            'height': <String, Object>{'ideal': 720},
          }.jsify()!,
        );
      } catch (e) {
        final String? name = _errorName(e);
        if (name != 'OverconstrainedError' &&
            name != 'ConstraintNotSatisfiedError') {
          rethrow;
        }
        return await get(true.toJS);
      }
    } catch (e) {
      final String? name = _errorName(e);
      throw CameraUnavailable(
        cameraProblemFromBrowserError(name),
        name ?? '$e',
      );
    }
  }

  /// The name of a browser error such as NotAllowedError, or null for anything
  /// that is not one.
  static String? _errorName(Object error) {
    if (!error.isA<web.DOMException>()) return null;
    return (error as web.DOMException).name;
  }

  void _grab() {
    final web.HTMLVideoElement? video = _video;
    final web.HTMLCanvasElement? canvas = _canvas;
    final web.CanvasRenderingContext2D? context = _context;
    if (!_streaming ||
        _frames.isClosed ||
        !_frames.hasListener ||
        video == null ||
        canvas == null ||
        context == null ||
        video.readyState < 2 ||
        video.videoWidth == 0 ||
        video.videoHeight == 0 ||
        web.document.hidden) {
      return;
    }
    // A video that is moved into the page's layout can be paused by the
    // browser on the way; set it going again.
    if (video.paused && !video.ended) {
      unawaited(video.play().toDart.then<void>((_) {}, onError: (Object _) {}));
    }
    final (int w, int h) = captureSize(video.videoWidth, video.videoHeight);
    if (canvas.width != w || canvas.height != h) {
      canvas
        ..width = w
        ..height = h;
    }
    context.drawImage(video, 0, 0, w, h);
    final Uint8ClampedList pixels = context.getImageData(0, 0, w, h).data.toDart;
    _frames.add(
      CameraFrame(
        format: FrameFormat.rgba8888,
        width: w,
        height: h,
        // The browser hands over the picture the way up it is shown.
        rotationDegrees: 0,
        planes: <FramePlane>[
          FramePlane(
            pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
            w * 4,
            4,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildPreview(BuildContext context) {
    final String? viewType = _viewType;
    if (viewType == null) return const SizedBox.shrink();
    return HtmlElementView(viewType: viewType);
  }

  @override
  Future<void> pause() async {
    _streaming = false;
  }

  @override
  Future<void> close() async {
    _streaming = false;
    _timer?.cancel();
    _timer = null;
    final web.MediaStream? stream = _stream;
    _stream = null;
    if (stream != null) {
      for (final web.MediaStreamTrack t in stream.getTracks().toDart) {
        t.stop();
      }
    }
    final web.HTMLVideoElement? video = _video;
    _video = null;
    if (video != null) {
      video.pause();
      video.srcObject = null;
    }
    _canvas = null;
    _context = null;
    if (!_frames.isClosed) await _frames.close();
  }
}
