import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'frame.dart';
import 'frame_scan.dart';
import 'hand_pipeline.dart';
import 'hand_tracker.dart';
import 'web_litert.dart';
import 'web_model.dart';

/// Whether this browser can run the hand models and use a camera: it has
/// WebAssembly and `getUserMedia`, which means a secure page.
final bool handDetectionSupported = browserCanDetectHands();

/// One tracker for the page. Compiling the two networks takes memory the
/// browser does not hand back until the page closes, so it is done once and
/// kept for the next visit to the camera.
HandTracker createHandTracker() => WebHandTracker.shared;

const String _detectorAsset = 'assets/models/hand_detector.tflite';
const String _landmarkAsset = 'assets/models/hand_landmarks_detector.tflite';

/// The same [HandPipeline] as on the phone, over the same two model files,
/// run by LiteRT.js's WebAssembly build of TensorFlow Lite on the page's own
/// thread.
///
/// Nothing leaves the browser. The runtime and the models are downloaded from
/// this site, once, when the person opens the camera; the frames are looked at
/// in memory and dropped.
///
/// A browser page has no worker isolate to give this, so a look blocks the page
/// for as long as it takes (tens of milliseconds on a laptop, more on a phone).
/// The tracker therefore rests after each look for at least as long as the look
/// took, and for at least as long as the phone's gap between looks, so the
/// screen keeps drawing and the countdown keeps moving; frames that arrive in
/// the meantime are dropped, as the phone's tracker drops them.
class WebHandTracker implements HandTracker {
  WebHandTracker._();

  static final WebHandTracker shared = WebHandTracker._();

  Future<void>? _starting;
  HandPipeline? _pipeline;
  bool _busy = false;
  int _notBeforeMs = 0;
  final Stopwatch _clock = Stopwatch()..start();

  /// The least time from the start of one live look to the start of the next,
  /// as on the phone: about eight a second.
  static const int minGapMs = 120;

  @override
  Future<void> start() {
    final Future<void>? existing = _starting;
    if (existing != null) return existing;
    final Future<void> attempt = _start();
    _starting = attempt;
    // A failed start must not stick: "try again" has to try again.
    unawaited(
      attempt.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_starting, attempt)) _starting = null;
        },
      ),
    );
    return attempt;
  }

  Future<void> _start() async {
    // The runtime and the two models are fetched side by side; they are about
    // 17 MB between them and nothing waits on any one of them.
    final (LiteRtRuntime runtime, ByteData det, ByteData lm) = await (
      LiteRtRuntime.load(),
      rootBundle.load(_detectorAsset),
      rootBundle.load(_landmarkAsset),
    ).wait;
    final ModelRunner detector = await runtime.loadModel(
      det.buffer.asUint8List(det.offsetInBytes, det.lengthInBytes),
    );
    final ModelRunner landmarker = await runtime.loadModel(
      lm.buffer.asUint8List(lm.offsetInBytes, lm.lengthInBytes),
    );
    _pipeline = HandPipeline(
      detector: RunnerTensorModel(detector),
      landmarker: RunnerTensorModel(landmarker),
    );
  }

  HandPipeline get _ready {
    final HandPipeline? p = _pipeline;
    if (p == null) throw StateError('The hand detector has not been started.');
    return p;
  }

  @override
  Future<TrackResult?> track(CameraFrame frame, int timeMs) async {
    if (_pipeline == null || _busy || _clock.elapsedMilliseconds < _notBeforeMs) {
      return null;
    }
    _busy = true;
    try {
      // Let the page draw what it has before it is held up.
      await Future<void>.delayed(Duration.zero);
      final int started = _clock.elapsedMilliseconds;
      try {
        return trackFrame(_ready, frame.toPalmFrame(), timeMs);
      } finally {
        final int end = _clock.elapsedMilliseconds;
        final int took = end - started;
        // Rest as long as the work took, and at least to the phone's pace, so
        // the page is never busy more than half the time.
        _notBeforeMs = end + math.max(took, minGapMs - took);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Future<StillScan> scan(CameraFrame frame, int timeMs) async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    _busy = true;
    try {
      // The careful look is the long one: placing the hand twice, then
      // searching the palm for lines. The page is given a moment between the
      // steps so the "reading your palm" spinner keeps turning.
      final PalmFrame picture = frame.toPalmFrame();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final hand = _ready.refine(picture, timeMs: timeMs);
      await Future<void>.delayed(Duration.zero);
      final creases = findPalmCreases(picture, hand);
      await Future<void>.delayed(Duration.zero);
      return stillFrom(picture, hand, creases);
    } finally {
      _busy = false;
    }
  }

  /// Leaves the models loaded for the next visit; only abandons what was in
  /// flight.
  @override
  Future<void> dispose() async {
    _busy = false;
  }
}
