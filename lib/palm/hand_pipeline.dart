import 'dart:math' as math;
import 'dart:typed_data';

import 'frame.dart';
import 'mediapipe_hand.dart';
import 'palm_types.dart';
import 'tensor_model.dart';

/// The two MediaPipe networks and the glue between them: find a palm, cut it
/// out upright, place 21 points on it, and follow it from frame to frame so the
/// detector only has to run when the hand is lost.
///
/// Pure Dart over [TensorModel], so the same code runs on a phone, in a worker
/// isolate, and in a test with real models and real photographs.
class HandPipeline {
  HandPipeline({
    required this.detector,
    required this.landmarker,
    this.minPresence = 0.5,
    this.minPalmScore = 0.5,
  }) : _outputs = _LandmarkOutputs.resolve(landmarker);

  final TensorModel detector;
  final TensorModel landmarker;

  /// Below this the landmark model is saying there is no hand in its window.
  final double minPresence;
  final double minPalmScore;

  final PalmAnchors _anchors = PalmAnchors();
  final _LandmarkOutputs _outputs;

  // Input buffers, kept between frames so a phone is not asked for another
  // megabyte of floats eight times a second.
  final Float32List _detectorInput = Float32List(detectorSize * detectorSize * 3);
  final Float32List _landmarkInput = Float32List(landmarkSize * landmarkSize * 3);
  RoiRect? _track;

  /// Forget the hand being followed, so the next frame starts from detection.
  void reset() => _track = null;

  /// Looks for a hand in [frame]. Returns null when there is none.
  HandObservation? process(PalmFrame frame, {int timeMs = 0}) {
    final double frameBrightness = _coarseBrightness(frame);

    _Landmarks? found;
    RoiRect? roi = _track;
    if (roi != null) {
      found = _landmarks(frame, roi);
      if (found == null || found.presence < minPresence) {
        _track = null;
        roi = null;
        found = null;
      }
    }
    if (found == null) {
      final PalmDetection? palm = _detect(frame);
      if (palm == null) return null;
      roi = roiFromPalm(palm, Letterbox(frame.width, frame.height));
      found = _landmarks(frame, roi);
      if (found == null || found.presence < minPresence) {
        _track = null;
        return null;
      }
    }
    _track = roiFromLandmarks(found.points);
    return HandObservation(
      points: found.points,
      depth: found.depth,
      world: found.world,
      presence: found.presence,
      rightProbability: found.rightProbability,
      frameWidth: frame.width,
      frameHeight: frame.height,
      look: _look(frame, found, frameBrightness),
      timeMs: timeMs,
    );
  }

  /// Looks again, with a second pass on the box the first found. The first
  /// pass cuts the hand out from a palm detector's rough box; the second cuts
  /// it out around the hand itself and is the more exact. Used on the picture
  /// that is actually read.
  HandObservation? refine(PalmFrame frame, {int timeMs = 0}) {
    reset();
    final HandObservation? first = process(frame, timeMs: timeMs);
    if (first == null) return null;
    return process(frame, timeMs: timeMs) ?? first;
  }

  PalmDetection? _detect(PalmFrame frame) {
    final Letterbox lb = Letterbox(frame.width, frame.height);
    final Float32List input = _detectorInput..fillRange(0, _detectorInput.length, 0);
    final Float32List px = Float32List(3);
    for (int j = 0; j < detectorSize; j++) {
      final double fy = (j + 0.5 - lb.padY) / lb.scale - 0.5;
      for (int i = 0; i < detectorSize; i++) {
        final double fx = (i + 0.5 - lb.padX) / lb.scale - 0.5;
        if (fx < 0 || fy < 0 || fx > frame.width - 1 || fy > frame.height - 1) {
          continue;
        }
        frame.rgbAt(fx, fy, px, 0);
        final int o = (j * detectorSize + i) * 3;
        input[o] = px[0];
        input[o + 1] = px[1];
        input[o + 2] = px[2];
      }
    }
    final List<Float32List> out = detector.run(input);
    // Two outputs: 2016 by 18 box numbers, and 2016 scores.
    Float32List regressors = out[0];
    Float32List scores = out[1];
    if (regressors.length < scores.length) {
      final Float32List t = regressors;
      regressors = scores;
      scores = t;
    }
    return decodePalm(
      regressors: regressors,
      scores: scores,
      anchors: _anchors,
      threshold: minPalmScore,
    );
  }

  _Landmarks? _landmarks(PalmFrame frame, RoiRect roi) {
    final Float32List input = _landmarkInput..fillRange(0, _landmarkInput.length, 0);
    final Float32List px = Float32List(3);
    for (int j = 0; j < landmarkSize; j++) {
      for (int i = 0; i < landmarkSize; i++) {
        final Pt p = roi.toFrame(
          (i + 0.5) / landmarkSize,
          (j + 0.5) / landmarkSize,
        );
        final double fx = p.x - 0.5;
        final double fy = p.y - 0.5;
        if (fx < 0 || fy < 0 || fx > frame.width - 1 || fy > frame.height - 1) {
          continue;
        }
        frame.rgbAt(fx, fy, px, 0);
        final int o = (j * landmarkSize + i) * 3;
        input[o] = px[0];
        input[o + 1] = px[1];
        input[o + 2] = px[2];
      }
    }
    final List<Float32List> out = landmarker.run(input);
    final Float32List raw = out[_outputs.landmarks];
    final double presence = out[_outputs.presence][0];
    final double handed = out[_outputs.handedness][0];
    final Float32List? worldRaw = _outputs.world == null
        ? null
        : out[_outputs.world!];
    if (raw.length < Joint.count * 3) return null;
    final List<Pt> points = projectLandmarks(raw, roi);
    return _Landmarks(
      points: points,
      depth: projectDepth(raw, roi),
      world: worldRaw == null
          ? null
          : <List<double>>[
              for (int i = 0; i < Joint.count; i++)
                <double>[
                  worldRaw[i * 3],
                  worldRaw[i * 3 + 1],
                  worldRaw[i * 3 + 2],
                ],
            ],
      presence: presence,
      // Read straight off the network. Checked on labelled photographs, left
      // and right, palm and back of the hand: it is the probability of a
      // right hand as the camera sees it, and it separates a right hand's
      // back from a left hand's palm, which look alike in outline.
      rightProbability: handed,
      crop: input,
      roi: roi,
    );
  }

  double _coarseBrightness(PalmFrame frame) {
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

  /// Brightness, blown-out and black shares, and fine detail over the palm,
  /// read from the very crop that was fed to the landmark model.
  FrameLook _look(PalmFrame frame, _Landmarks lm, double frameBrightness) {
    final List<Pt> polygon = <Pt>[
      for (final int j in const <int>[
        Joint.wrist,
        Joint.indexMcp,
        Joint.middleMcp,
        Joint.ringMcp,
        Joint.pinkyMcp,
      ])
        lm.roi.fromFrame(lm.points[j]).scaled(landmarkSize.toDouble()),
    ];
    final Float32List crop = lm.crop;
    double lumaAt(int i, int j) {
      final int o = (j * landmarkSize + i) * 3;
      return 0.299 * crop[o] + 0.587 * crop[o + 1] + 0.114 * crop[o + 2];
    }

    double sum = 0;
    int count = 0, blown = 0, black = 0;
    double detail = 0;
    int detailCount = 0;
    const int step = 3;
    for (int j = 2; j < landmarkSize - 2; j += step) {
      for (int i = 2; i < landmarkSize - 2; i += step) {
        if (!_inside(polygon, i + 0.5, j + 0.5)) continue;
        final double l = lumaAt(i, j);
        sum += l;
        count++;
        if (l > 0.96) blown++;
        if (l < 0.06) black++;
        final double lap =
            (4 * l -
                    lumaAt(i - 1, j) -
                    lumaAt(i + 1, j) -
                    lumaAt(i, j - 1) -
                    lumaAt(i, j + 1))
                .abs();
        detail += lap;
        detailCount++;
      }
    }
    if (count == 0) return FrameLook(frameBrightness: frameBrightness);
    final double mean = sum / count;
    final double fine = detail / detailCount;
    return FrameLook(
      palmBrightness: mean,
      clipped: blown / count,
      crushed: black / count,
      // Fine detail relative to the brightness, so a dim palm is not
      // mistaken for a blurred one.
      sharpness: mean < 0.02 ? 0 : fine / mean,
      frameBrightness: frameBrightness,
    );
  }

  void close() {
    detector.close();
    landmarker.close();
  }
}

bool _inside(List<Pt> polygon, double x, double y) {
  bool inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final Pt a = polygon[i];
    final Pt b = polygon[j];
    if ((a.y > y) != (b.y > y) &&
        x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

class _Landmarks {
  _Landmarks({
    required this.points,
    required this.depth,
    required this.world,
    required this.presence,
    required this.rightProbability,
    required this.crop,
    required this.roi,
  });

  final List<Pt> points;
  final List<double> depth;
  final List<List<double>>? world;
  final double presence;
  final double rightProbability;
  final Float32List crop;
  final RoiRect roi;
}

/// Which of the landmark model's four outputs is which. The bundle's own
/// metadata names them, but shapes are the safer thing to read: two carry 63
/// numbers (the picture-space points and the metric ones), two carry one.
class _LandmarkOutputs {
  _LandmarkOutputs(this.landmarks, this.presence, this.handedness, this.world);

  final int landmarks;
  final int presence;
  final int handedness;
  final int? world;

  static _LandmarkOutputs resolve(TensorModel model) {
    final List<List<int>> shapes = model.outputShapes;
    int size(List<int> s) => s.fold<int>(1, (int a, int b) => a * b);
    final List<int> big = <int>[
      for (int i = 0; i < shapes.length; i++)
        if (size(shapes[i]) == Joint.count * 3) i,
    ];
    final List<int> small = <int>[
      for (int i = 0; i < shapes.length; i++)
        if (size(shapes[i]) == 1) i,
    ];
    if (big.isEmpty || small.length < 2) {
      throw StateError(
        'The hand model has outputs $shapes, not the ones expected.',
      );
    }
    // MediaPipe's order: landmarks, hand presence, handedness, world points.
    return _LandmarkOutputs(
      big.first,
      small[0],
      small[1],
      big.length > 1 ? big[1] : null,
    );
  }
}

/// Used by tests and the isolate to read a hand's size without a model.
double handExtent(List<Pt> points) {
  double minX = double.infinity, maxX = -double.infinity;
  double minY = double.infinity, maxY = -double.infinity;
  for (final Pt p in points) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  return math.max(maxX - minX, maxY - minY);
}
