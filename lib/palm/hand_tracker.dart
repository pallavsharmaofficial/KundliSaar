import 'dart:typed_data';

import 'crease_finder.dart';
import 'frame.dart';
import 'palm_types.dart';

import 'hand_tracker_stub.dart'
    if (dart.library.ffi) 'hand_tracker_native.dart'
    if (dart.library.js_interop) 'hand_tracker_web.dart'
    as platform;

/// One plane of a camera frame.
class FramePlane {
  const FramePlane(this.bytes, this.bytesPerRow, [this.bytesPerPixel]);

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

enum FrameFormat {
  /// Android's camera.
  yuv420,

  /// iOS's camera.
  bgra8888,

  /// Plain RGBA bytes, which is what a browser's canvas gives.
  rgba8888,
}

/// A frame as the camera plugin hands it over, kept free of the plugin's own
/// types so tests can make one and the worker can be sent one.
class CameraFrame {
  const CameraFrame({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
    required this.rotationDegrees,
  });

  final FrameFormat format;

  /// Size of the sensor's picture, before turning it upright.
  final int width;
  final int height;
  final List<FramePlane> planes;

  /// Clockwise degrees that take the sensor's picture to upright.
  final int rotationDegrees;

  PalmFrame toPalmFrame() {
    final Turn turn = turnFromDegrees(rotationDegrees);
    switch (format) {
      case FrameFormat.yuv420:
        return Yuv420Frame(
          y: planes[0].bytes,
          u: planes[1].bytes,
          v: planes[2].bytes,
          rawWidth: width,
          rawHeight: height,
          yRowStride: planes[0].bytesPerRow,
          uvRowStride: planes[1].bytesPerRow,
          uvPixelStride: planes[1].bytesPerPixel ?? 1,
          turn: turn,
        );
      case FrameFormat.bgra8888:
        return Bgra8888Frame(
          bytes: planes[0].bytes,
          rawWidth: width,
          rawHeight: height,
          rowStride: planes[0].bytesPerRow,
          turn: turn,
        );
      case FrameFormat.rgba8888:
        // A browser hands over frames already upright, tightly packed.
        return RgbaFrame(planes[0].bytes, width, height);
    }
  }
}

/// What one live look found.
class TrackResult {
  const TrackResult({
    required this.hand,
    required this.frameBrightness,
    required this.timeMs,
  });

  final HandObservation? hand;
  final double frameBrightness;
  final int timeMs;
}

/// The photograph the reading was made from, held in memory only, with what
/// was found on it. Never written anywhere.
class StillScan {
  const StillScan({
    required this.hand,
    required this.creases,
    required this.previewRgba,
    required this.previewWidth,
    required this.previewHeight,
    required this.previewScale,
  });

  /// The hand as found on the chosen frame, or null if it was not there.
  final HandObservation? hand;
  final CreaseResult? creases;

  /// The picture, upright and shrunk, as RGBA bytes, for showing the lines
  /// where they were found.
  final Uint8List previewRgba;
  final int previewWidth;
  final int previewHeight;

  /// Preview pixels per frame pixel.
  final double previewScale;
}

/// Finds a hand in camera frames, on this device, and nowhere else.
///
/// The work runs off the UI thread. [track] answers null, at once, when it is
/// still busy with the last frame or was asked again too soon: dropping a frame
/// is the right thing on a slow phone, queueing it is not.
abstract class HandTracker {
  /// Loads the models. Call once.
  Future<void> start();

  Future<TrackResult?> track(CameraFrame frame, int timeMs);

  /// The careful look at the frame chosen as the photograph: the hand placed
  /// precisely, and the lines of the palm searched for.
  Future<StillScan> scan(CameraFrame frame, int timeMs);

  Future<void> dispose();
}

/// Whether this build can run the hand models at all: the phone apps always
/// can; the web build can where the browser has WebAssembly and a camera it is
/// allowed to ask for, and otherwise keeps the hand tracer.
bool get handDetectionSupported => platform.handDetectionSupported;

/// The tracker for this platform.
HandTracker createHandTracker() => platform.createHandTracker();
