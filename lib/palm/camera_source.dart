import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'hand_tracker.dart';

/// Why the camera could not be used.
enum CameraProblem {
  /// The person said no, or the system did.
  denied,

  /// There is no usable camera, or it is in use elsewhere.
  unavailable,
}

class CameraUnavailable implements Exception {
  const CameraUnavailable(this.problem, [this.detail]);

  final CameraProblem problem;
  final String? detail;

  @override
  String toString() => 'CameraUnavailable($problem, $detail)';
}

/// The camera, as the capture screen needs it: a preview to show, and frames
/// to look at. Behind an interface so the screen can be tested with a script
/// in place of a lens.
abstract class CameraSource {
  /// Opens the back camera. Asks the person for permission if it has not been
  /// given, which is the system's own prompt. Throws [CameraUnavailable].
  Future<void> open();

  /// Frames arrive here, upright-able through [CameraFrame.rotationDegrees].
  /// Nothing is recorded; each frame is looked at and dropped.
  Stream<CameraFrame> get frames;

  /// Width over height of the preview as the person sees it, portrait.
  double get previewAspectRatio;

  Widget buildPreview(BuildContext context);

  /// Stops sending frames (the picture on screen freezes or the screen moves
  /// on) without closing the camera.
  Future<void> pause();

  Future<void> close();
}

/// The `camera` plugin's implementation.
class PluginCameraSource implements CameraSource {
  CameraController? _controller;
  final StreamController<CameraFrame> _frames =
      StreamController<CameraFrame>.broadcast();
  bool _streaming = false;

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  double get previewAspectRatio {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return 3 / 4;
    // The plugin reports the sensor's landscape size; the screen is portrait.
    final double a = c.value.aspectRatio;
    return a > 1 ? 1 / a : a;
  }

  @override
  Future<void> open() async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraUnavailable(_problemOf(e), e.code);
    }
    if (cameras.isEmpty) {
      throw const CameraUnavailable(CameraProblem.unavailable, 'none');
    }
    final CameraDescription chosen = cameras.firstWhere(
      (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    // 720p: enough pixels for the creases of a palm held at arm's length,
    // few enough for a cheap phone to keep up with.
    final CameraController controller = CameraController(
      chosen,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: !kIsWeb && Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } on CameraException catch (e) {
      await controller.dispose();
      throw CameraUnavailable(_problemOf(e), e.code);
    }
    _controller = controller;
    final int rotation = chosen.sensorOrientation;
    await controller.startImageStream((CameraImage image) {
      if (_frames.isClosed || !_streaming) return;
      _frames.add(_convert(image, rotation));
    });
    _streaming = true;
  }

  CameraProblem _problemOf(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return CameraProblem.denied;
      default:
        return CameraProblem.unavailable;
    }
  }

  CameraFrame _convert(CameraImage image, int rotation) => CameraFrame(
    format: image.format.group == ImageFormatGroup.bgra8888
        ? FrameFormat.bgra8888
        : FrameFormat.yuv420,
    width: image.width,
    height: image.height,
    rotationDegrees: rotation,
    planes: <FramePlane>[
      for (final Plane p in image.planes)
        FramePlane(p.bytes, p.bytesPerRow, p.bytesPerPixel),
    ],
  );

  @override
  Widget buildPreview(BuildContext context) {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return CameraPreview(c);
  }

  @override
  Future<void> pause() async {
    _streaming = false;
    final CameraController? c = _controller;
    if (c != null && c.value.isStreamingImages) {
      try {
        await c.stopImageStream();
      } on CameraException {
        // Already stopped.
      }
    }
  }

  @override
  Future<void> close() async {
    _streaming = false;
    final CameraController? c = _controller;
    _controller = null;
    await _frames.close();
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } on CameraException {
        // Closing anyway.
      }
      await c.dispose();
    }
  }
}
