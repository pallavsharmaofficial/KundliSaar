// Shared by the tests that hold the web build's hand models to the phone's.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/palm/tensor_model.dart';

import 'synthetic_palm.dart';

/// A model that remembers what it was given and what it said.
class RecordingModel implements TensorModel {
  RecordingModel(this.inner);

  final TensorModel inner;
  final List<Float32List> inputs = <Float32List>[];
  final List<List<Float32List>> outputs = <List<Float32List>>[];

  @override
  List<int> get inputShape => inner.inputShape;
  @override
  List<String> get outputNames => inner.outputNames;
  @override
  List<List<int>> get outputShapes => inner.outputShapes;

  @override
  List<Float32List> run(Float32List input) {
    inputs.add(Float32List.fromList(input));
    final List<Float32List> out = inner.run(input);
    outputs.add(<Float32List>[
      for (final Float32List o in out) Float32List.fromList(o),
    ]);
    return out;
  }

  @override
  void close() {}
}

/// Drawn hands that the real models find, as a phone would hold one up
/// (portrait) and as a laptop's webcam would see one (landscape), left and
/// right, in three skin tones against three walls.
Map<String, RgbaFrame> parityFrames() => <String, RgbaFrame>{
  'portrait, left palm, turned a little': renderPalm(
    tone: const <int>[170, 120, 92],
    wall: const <int>[215, 210, 200],
    scale: 0.75,
    tilt: 8,
    seed: 4,
  ),
  'portrait, right palm': renderPalm(
    thumbLeft: false,
    seed: 5,
    tone: const <int>[224, 172, 140],
    wall: const <int>[200, 200, 200],
    scale: 0.8,
  ),
  'webcam, left palm': renderPalm(
    width: 1280,
    height: 720,
    scale: 0.8,
    seed: 6,
  ),
  'webcam, right palm, turned a little': renderPalm(
    width: 1280,
    height: 720,
    scale: 0.8,
    thumbLeft: false,
    seed: 7,
    tone: const <int>[170, 120, 92],
    wall: const <int>[215, 210, 200],
    tilt: 6,
  ),
};

/// The largest difference between two lists of the same length.
double maxDifference(List<double> a, List<double> b) {
  expectSameLength(a, b);
  double worst = 0;
  for (int i = 0; i < a.length; i++) {
    worst = math.max(worst, (a[i] - b[i]).abs());
  }
  return worst;
}

void expectSameLength(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) {
    throw StateError('lengths differ: ${a.length} and ${b.length}');
  }
}

/// How far apart two hands' 21 points are, at the worst, in pixels.
double worstPointGap(HandObservation a, HandObservation b) {
  double worst = 0;
  for (int i = 0; i < Joint.count; i++) {
    worst = math.max(worst, a.points[i].distanceTo(b.points[i]));
  }
  return worst;
}

/// A picture as Android's camera hands it over: full-size luma and quarter-size
/// chroma, the way BT.601 full-range writes colour. Used to show that the same
/// picture, delivered in the browser's format or the phone's, is read as the
/// same hand.
Yuv420Frame toYuv420(RgbaFrame f) {
  final int w = f.width, h = f.height;
  final Uint8List y = Uint8List(w * h);
  final int cw = (w + 1) ~/ 2, ch = (h + 1) ~/ 2;
  final Uint8List u = Uint8List(cw * ch), v = Uint8List(cw * ch);
  for (int j = 0; j < h; j++) {
    for (int i = 0; i < w; i++) {
      final int o = (j * w + i) * 4;
      final double r = f.bytes[o].toDouble(),
          g = f.bytes[o + 1].toDouble(),
          b = f.bytes[o + 2].toDouble();
      y[j * w + i] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    }
  }
  for (int j = 0; j < ch; j++) {
    for (int i = 0; i < cw; i++) {
      double r = 0, g = 0, b = 0;
      int n = 0;
      for (int dj = 0; dj < 2; dj++) {
        for (int di = 0; di < 2; di++) {
          final int x = math.min(i * 2 + di, w - 1),
              yy = math.min(j * 2 + dj, h - 1);
          final int o = (yy * w + x) * 4;
          r += f.bytes[o];
          g += f.bytes[o + 1];
          b += f.bytes[o + 2];
          n++;
        }
      }
      r /= n;
      g /= n;
      b /= n;
      u[j * cw + i] = (128 - 0.168736 * r - 0.331264 * g + 0.5 * b)
          .round()
          .clamp(0, 255);
      v[j * cw + i] = (128 + 0.5 * r - 0.418688 * g - 0.081312 * b)
          .round()
          .clamp(0, 255);
    }
  }
  return Yuv420Frame(
    y: y,
    u: u,
    v: v,
    rawWidth: w,
    rawHeight: h,
    yRowStride: w,
    uvRowStride: cw,
    uvPixelStride: 1,
  );
}
