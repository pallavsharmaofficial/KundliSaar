// Stand-ins for the two MediaPipe networks that answer, for one known hand,
// exactly what the real ones would: a palm detection where the hand is, and the
// 21 landmarks of that hand in the numbers the landmark network speaks (pixels
// of its 224 square crop, which depends on where the pipeline cut the crop).
//
// They are built from a [HandObservation] whose landmarks are known, so a test
// can run the real HandPipeline over them and check the points come back where
// they were put, whatever path the numbers took on the way.
import 'dart:typed_data';

import 'package:kundlisaar/palm/mediapipe_hand.dart';
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/palm/tensor_model.dart';
import 'package:kundlisaar/palm/web_model.dart';

/// A network defined by a function, with the shapes and names the real one has.
class FixtureRunner implements ModelRunner {
  FixtureRunner({
    required this.inputShape,
    required this.outputNames,
    required this.outputShapes,
    required this.answer,
  });

  @override
  final List<int> inputShape;
  @override
  final List<String> outputNames;
  @override
  final List<List<int>> outputShapes;

  final List<Float32List> Function(Float32List input) answer;
  int runs = 0;
  bool closed = false;

  @override
  List<Float32List> run(Float32List input) {
    runs++;
    return answer(input);
  }

  @override
  void close() => closed = true;
}

/// The phone's way of holding a model: the runtime's own tensors copied out as
/// fresh floats (see TfliteModel). Same numbers, no web adapter in between.
class DirectModel implements TensorModel {
  DirectModel(this._runner);

  final ModelRunner _runner;

  @override
  List<int> get inputShape => _runner.inputShape;
  @override
  List<String> get outputNames => _runner.outputNames;
  @override
  List<List<int>> get outputShapes => _runner.outputShapes;
  @override
  List<Float32List> run(Float32List input) => _runner.run(input);
  @override
  void close() => _runner.close();
}

class FixtureNetworks {
  /// [truth] is where the hand really is. [rightProbability] and the
  /// presence the landmark network reports are taken from it, and from
  /// [presence].
  FixtureNetworks(this.truth, {this.presence = 0.97})
    : _lb = Letterbox(truth.frameWidth, truth.frameHeight) {
    final Pt wrist = truth.points[Joint.wrist];
    final Pt middle = truth.points[Joint.middleMcp];
    // A box around the palm, as the detector would draw it, and the seven
    // palm keypoints: wrist, the four knuckles, and the two thumb joints.
    final double palm = wrist.distanceTo(middle);
    final Pt centre = Pt((wrist.x + middle.x) / 2, (wrist.y + middle.y) / 2);
    final List<int> kp = <int>[
      Joint.wrist,
      Joint.indexMcp,
      Joint.middleMcp,
      Joint.ringMcp,
      Joint.pinkyMcp,
      Joint.thumbCmc,
      Joint.thumbMcp,
    ];
    const int anchor = 300;
    final PalmAnchors anchors = PalmAnchors();
    final double ax = anchors.x[anchor], ay = anchors.y[anchor];
    Pt inDetector(Pt p) => _lb.fromFrame(p.x, p.y);
    final Pt c = inDetector(centre);
    final double sizePx = palm * 1.15;
    final double size = sizePx * _lb.scale / detectorSize;
    _regressors = Float32List(2016 * 18);
    _scores = Float32List(2016)..fillRange(0, 2016, -20.0);
    final int o = anchor * 18;
    _regressors[o] = (c.x - ax) * detectorSize;
    _regressors[o + 1] = (c.y - ay) * detectorSize;
    _regressors[o + 2] = size * detectorSize;
    _regressors[o + 3] = size * detectorSize;
    for (int k = 0; k < 7; k++) {
      final Pt p = inDetector(truth.points[kp[k]]);
      _regressors[o + 4 + k * 2] = (p.x - ax) * detectorSize;
      _regressors[o + 5 + k * 2] = (p.y - ay) * detectorSize;
    }
    _scores[anchor] = 10;

    final PalmDetection? found = decodePalm(
      regressors: _regressors,
      scores: _scores,
      anchors: anchors,
    );
    if (found == null) throw StateError('the fixture detection did not decode');
    // The very box the pipeline will cut the landmark crop from.
    roi = roiFromPalm(found, _lb);
  }

  final HandObservation truth;
  final double presence;
  final Letterbox _lb;
  late final Float32List _regressors;
  late final Float32List _scores;

  /// Where the pipeline will cut the crop, for the first look at a frame.
  late final RoiRect roi;

  FixtureRunner get detector => FixtureRunner(
    inputShape: const <int>[1, detectorSize, detectorSize, 3],
    outputNames: const <String>['Identity', 'Identity_1'],
    outputShapes: const <List<int>>[
      <int>[1, 2016, 18],
      <int>[1, 2016, 1],
    ],
    answer: (Float32List _) => <Float32List>[
      Float32List.fromList(_regressors),
      Float32List.fromList(_scores),
    ],
  );

  /// Answers for the first look only: the numbers are the hand's points in the
  /// crop of [roi], and a later look, which cuts a different crop, would need
  /// different ones.
  FixtureRunner get landmarker => FixtureRunner(
    inputShape: const <int>[1, landmarkSize, landmarkSize, 3],
    outputNames: const <String>[
      'Identity',
      'Identity_1',
      'Identity_2',
      'Identity_3',
    ],
    outputShapes: const <List<int>>[
      <int>[1, 63],
      <int>[1, 1],
      <int>[1, 1],
      <int>[1, 63],
    ],
    answer: (Float32List _) {
      final Float32List raw = Float32List(63);
      final Float32List world = Float32List(63);
      for (int i = 0; i < Joint.count; i++) {
        final Pt u = roi.fromFrame(truth.points[i]);
        raw[i * 3] = u.x * landmarkSize;
        raw[i * 3 + 1] = u.y * landmarkSize;
        raw[i * 3 + 2] = truth.depth[i] / roi.width * landmarkSize;
        world[i * 3] = (u.x - 0.5) * 0.2;
        world[i * 3 + 1] = (u.y - 0.5) * 0.2;
        world[i * 3 + 2] = 0;
      }
      return <Float32List>[
        raw,
        Float32List.fromList(<double>[presence]),
        Float32List.fromList(<double>[truth.rightProbability]),
        world,
      ];
    },
  );
}
