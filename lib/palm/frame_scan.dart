import 'dart:typed_data';

import 'crease_finder.dart';
import 'frame.dart';
import 'hand_pipeline.dart';
import 'hand_tracker.dart';
import 'palm_geometry.dart';
import 'palm_types.dart';

// What a tracker does with one frame, kept out of the platform files so the
// phone (in a worker isolate) and the browser (on the page) do exactly the same
// thing with the same numbers: a quick look while aiming, and one careful scan
// of the frame that is read.

/// Mean brightness of the whole frame, 0 to 1, from a coarse grid.
double frameBrightness(PalmFrame frame) {
  double sum = 0;
  const int n = 12;
  for (int j = 0; j < n; j++) {
    for (int i = 0; i < n; i++) {
      sum += frame.lumaAt(
        (i + 0.5) / n * frame.width,
        (j + 0.5) / n * frame.height,
      );
    }
  }
  return sum / (n * n);
}

/// The quick look made while the person is still aiming.
TrackResult trackFrame(HandPipeline pipeline, PalmFrame frame, int timeMs) {
  final HandObservation? hand = pipeline.process(frame, timeMs: timeMs);
  return TrackResult(
    hand: hand,
    frameBrightness: frameBrightness(frame),
    timeMs: timeMs,
  );
}

/// The lines of the palm, searched for only when a hand was found and it is
/// not the back of the hand.
CreaseResult? findPalmCreases(PalmFrame frame, HandObservation? hand) {
  if (hand == null) return null;
  final HandGeometry g = HandGeometry.of(hand);
  if (g.facing == Facing.back) return null;
  return findCreases(frame, hand.points, thumbOnLeft: g.thumbOnLeft);
}

/// A shrunken copy of the frame to show the lines on. 640 on the long side is
/// plenty.
StillScan stillFrom(
  PalmFrame frame,
  HandObservation? hand,
  CreaseResult? creases,
) {
  final double scale =
      640 / (frame.width > frame.height ? frame.width : frame.height);
  final int pw = (frame.width * scale).round();
  final int ph = (frame.height * scale).round();
  final Uint8List rgba = Uint8List(pw * ph * 4);
  final Float32List px = Float32List(3);
  for (int y = 0; y < ph; y++) {
    for (int x = 0; x < pw; x++) {
      frame.rgbAt((x + 0.5) / scale - 0.5, (y + 0.5) / scale - 0.5, px, 0);
      final int o = (y * pw + x) * 4;
      rgba[o] = (px[0] * 255).round();
      rgba[o + 1] = (px[1] * 255).round();
      rgba[o + 2] = (px[2] * 255).round();
      rgba[o + 3] = 255;
    }
  }
  return StillScan(
    hand: hand,
    creases: creases,
    previewRgba: rgba,
    previewWidth: pw,
    previewHeight: ph,
    previewScale: scale,
  );
}

/// The careful look at the frame chosen as the photograph.
StillScan scanFrame(HandPipeline pipeline, PalmFrame frame, int timeMs) {
  final HandObservation? hand = pipeline.refine(frame, timeMs: timeMs);
  return stillFrom(frame, hand, findPalmCreases(frame, hand));
}
