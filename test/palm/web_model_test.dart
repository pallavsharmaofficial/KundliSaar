import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/hand_pipeline.dart';
import 'package:kundlisaar/palm/hand_tracker.dart';
import 'package:kundlisaar/palm/palm_geometry.dart';
import 'package:kundlisaar/palm/palm_scan.dart';
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/palm/web_model.dart';

import 'support/fixture_networks.dart';
import 'support/hands.dart';

FixtureRunner _runner({
  List<Float32List> Function(Float32List)? answer,
  List<int> inputShape = const <int>[1, 2, 2, 3],
  List<String> names = const <String>['a', 'b'],
  List<List<int>> shapes = const <List<int>>[
    <int>[1, 3],
    <int>[1, 1],
  ],
}) => FixtureRunner(
  inputShape: inputShape,
  outputNames: names,
  outputShapes: shapes,
  answer:
      answer ??
      (Float32List _) => <Float32List>[
        Float32List.fromList(<double>[1, 2, 3]),
        Float32List.fromList(<double>[0.5]),
      ],
);

void main() {
  group('the adapter between the browser\'s runtime and the hand pipeline', () {
    test('passes the shapes and names of the network through', () {
      final RunnerTensorModel m = RunnerTensorModel(_runner());
      expect(m.inputShape, <int>[1, 2, 2, 3]);
      expect(m.outputNames, <String>['a', 'b']);
      expect(m.outputShapes, <List<int>>[
        <int>[1, 3],
        <int>[1, 1],
      ]);
    });

    test(
      'hands floats in and gives the runtime\'s floats back, in its order',
      () {
        final FixtureRunner r = _runner();
        final RunnerTensorModel m = RunnerTensorModel(r);
        final List<Float32List> out = m.run(Float32List(12));
        expect(out.length, 2);
        expect(out[0], <double>[1, 2, 3]);
        expect(out[1], <double>[0.5]);
        expect(r.runs, 1);
      },
    );

    test('and closes the runtime\'s model when it is closed', () {
      final FixtureRunner r = _runner();
      RunnerTensorModel(r).close();
      expect(r.closed, isTrue);
    });

    test('refuses an input of the wrong size, saying so', () {
      final RunnerTensorModel m = RunnerTensorModel(_runner());
      expect(() => m.run(Float32List(11)), throwsArgumentError);
    });

    test(
      'stops on an output of the wrong size instead of placing a hand with it',
      () {
        final RunnerTensorModel m = RunnerTensorModel(
          _runner(
            answer: (Float32List _) => <Float32List>[
              Float32List(2),
              Float32List(1),
            ],
          ),
        );
        expect(() => m.run(Float32List(12)), throwsA(isA<ModelOutputError>()));
      },
    );

    test('stops when an output is missing', () {
      final RunnerTensorModel m = RunnerTensorModel(
        _runner(answer: (Float32List _) => <Float32List>[Float32List(3)]),
      );
      expect(() => m.run(Float32List(12)), throwsA(isA<ModelOutputError>()));
    });

    test('stops on numbers that are not numbers', () {
      for (final double bad in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final RunnerTensorModel m = RunnerTensorModel(
          _runner(
            answer: (Float32List _) => <Float32List>[
              Float32List.fromList(<double>[1, bad, 3]),
              Float32List.fromList(<double>[0.5]),
            ],
          ),
        );
        expect(
          () => m.run(Float32List(12)),
          throwsA(isA<ModelOutputError>()),
          reason: '$bad',
        );
      }
    });

    test(
      'will not be built on a runtime that names more outputs than it describes',
      () {
        expect(
          () => RunnerTensorModel(_runner(names: <String>['a', 'b', 'c'])),
          throwsA(isA<ModelOutputError>()),
        );
      },
    );
  });

  group('the hand pipeline over the adapter, against known landmarks', () {
    // Hands of the four types the reading tells apart, left and right, as the
    // 21 landmarks the network would report for them.
    final Map<String, HandObservation> truths = <String, HandObservation>{
      'earth, left': syntheticHand(widthRatio: 0.70, fingerRatio: 0.85),
      'air, left': syntheticHand(widthRatio: 0.70, fingerRatio: 1.05),
      'water, right': syntheticHand(
        widthRatio: 0.58,
        fingerRatio: 1.05,
        thumbLeft: false,
      ),
      'fire, right': syntheticHand(
        widthRatio: 0.58,
        fingerRatio: 0.85,
        thumbLeft: false,
      ),
      'turned and small, left': syntheticHand(
        handLength: 420,
        rotationDegrees: 25,
        centreX: 330,
        centreY: 700,
      ),
      'in a landscape frame, right': syntheticHand(
        frameWidth: 1280,
        frameHeight: 720,
        centreX: 640,
        centreY: 380,
        handLength: 430,
        thumbLeft: false,
      ),
    };

    PalmFrame blank(HandObservation h) {
      final Uint8List px = Uint8List(h.frameWidth * h.frameHeight * 4)
        ..fillRange(0, h.frameWidth * h.frameHeight * 4, 140);
      return RgbaFrame(px, h.frameWidth, h.frameHeight);
    }

    for (final MapEntry<String, HandObservation> e in truths.entries) {
      test('puts every one of the 21 points back where it was: ${e.key}', () {
        final FixtureNetworks nets = FixtureNetworks(e.value);
        final HandPipeline pipeline = HandPipeline(
          detector: RunnerTensorModel(nets.detector),
          landmarker: RunnerTensorModel(nets.landmarker),
        );
        final HandObservation? hand = pipeline.process(blank(e.value));
        expect(hand, isNotNull);
        for (int i = 0; i < Joint.count; i++) {
          // Float32 holds a pixel position to a few thousandths.
          expect(
            hand!.points[i].distanceTo(e.value.points[i]),
            lessThan(0.01),
            reason: 'point $i',
          );
        }
        expect(hand!.presence, closeTo(0.97, 1e-6));
        expect(hand.rightProbability, closeTo(e.value.rightProbability, 1e-6));
        expect(hand.frameWidth, e.value.frameWidth);
        expect(hand.frameHeight, e.value.frameHeight);
      });

      test(
        'and the phone\'s way of holding the model gives the very same hand: ${e.key}',
        () {
          final FixtureNetworks nets = FixtureNetworks(e.value);
          final HandObservation? onWeb = HandPipeline(
            detector: RunnerTensorModel(nets.detector),
            landmarker: RunnerTensorModel(nets.landmarker),
          ).process(blank(e.value));
          final HandObservation? onPhone = HandPipeline(
            detector: DirectModel(nets.detector),
            landmarker: DirectModel(nets.landmarker),
          ).process(blank(e.value));
          expect(onWeb, isNotNull);
          expect(onPhone, isNotNull);
          for (int i = 0; i < Joint.count; i++) {
            expect(
              onWeb!.points[i].x,
              onPhone!.points[i].x,
              reason: 'point $i, x',
            );
            expect(
              onWeb.points[i].y,
              onPhone.points[i].y,
              reason: 'point $i, y',
            );
          }
          expect(onWeb!.presence, onPhone!.presence);
          expect(onWeb.rightProbability, onPhone.rightProbability);
        },
      );

      test(
        'and the measurements made from them are the same, and are the hand\'s: ${e.key}',
        () {
          final FixtureNetworks nets = FixtureNetworks(e.value);
          final HandObservation onWeb = HandPipeline(
            detector: RunnerTensorModel(nets.detector),
            landmarker: RunnerTensorModel(nets.landmarker),
          ).process(blank(e.value))!;
          final HandObservation onPhone = HandPipeline(
            detector: DirectModel(nets.detector),
            landmarker: DirectModel(nets.landmarker),
          ).process(blank(e.value))!;

          final PalmScan web = buildScan(hand: onWeb);
          final PalmScan phone = buildScan(hand: onPhone);
          final PalmScan truth = buildScan(hand: e.value);
          for (final PalmScan s in <PalmScan>[web, phone]) {
            expect(s.outcome, truth.outcome);
            expect(s.side, truth.side);
            expect(s.facing, truth.facing);
            expect(s.handType, truth.handType);
            expect(s.borderline, truth.borderline);
            expect(s.widthRatio, closeTo(truth.widthRatio, 1e-3));
            expect(s.fingerRatio, closeTo(truth.fingerRatio, 1e-3));
          }
          // Between the two paths there is nothing at all to tell apart.
          expect(web.widthRatio, phone.widthRatio);
          expect(web.fingerRatio, phone.fingerRatio);
          expect(web.handType, phone.handType);
          expect(
            web.measured.map((Say s) => s.english),
            phone.measured.map((Say s) => s.english),
          );
          expect(
            web.measured.map((Say s) => s.hindi),
            phone.measured.map((Say s) => s.hindi),
          );
          expect(web.reading?.handType, phone.reading?.handType);

          // And the guidance, which is what decides when the picture is taken.
          final HandGeometry gw = HandGeometry.of(onWeb);
          final HandGeometry gp = HandGeometry.of(onPhone);
          expect(gw.fill, gp.fill);
          expect(gw.facing, gp.facing);
          expect(gw.minExtension, gp.minExtension);
          expect(gw.thumbOnLeft, gp.thumbOnLeft);
        },
      );
    }

    test(
      'a network that finds no palm leaves the pipeline with no hand, not a guess',
      () {
        final FixtureNetworks nets = FixtureNetworks(truths.values.first);
        final FixtureRunner silent = FixtureRunner(
          inputShape: nets.detector.inputShape,
          outputNames: nets.detector.outputNames,
          outputShapes: nets.detector.outputShapes,
          answer: (Float32List _) => <Float32List>[
            Float32List(2016 * 18),
            Float32List(2016)..fillRange(0, 2016, -20.0),
          ],
        );
        final HandPipeline pipeline = HandPipeline(
          detector: RunnerTensorModel(silent),
          landmarker: RunnerTensorModel(nets.landmarker),
        );
        expect(pipeline.process(blank(truths.values.first)), isNull);
      },
    );

    test('a hand the landmark network is not sure of is not reported', () {
      final FixtureNetworks nets = FixtureNetworks(
        truths.values.first,
        presence: 0.2,
      );
      final HandPipeline pipeline = HandPipeline(
        detector: RunnerTensorModel(nets.detector),
        landmarker: RunnerTensorModel(nets.landmarker),
      );
      expect(pipeline.process(blank(truths.values.first)), isNull);
    });

    test(
      'a runtime that returns rubbish stops the pipeline, which the screen turns into the hand tracer',
      () {
        final FixtureNetworks nets = FixtureNetworks(truths.values.first);
        final FixtureRunner rubbish = FixtureRunner(
          inputShape: nets.detector.inputShape,
          outputNames: nets.detector.outputNames,
          outputShapes: nets.detector.outputShapes,
          answer: (Float32List _) => <Float32List>[
            Float32List(2016 * 18)..fillRange(0, 2016 * 18, double.nan),
            Float32List(2016),
          ],
        );
        final HandPipeline pipeline = HandPipeline(
          detector: RunnerTensorModel(rubbish),
          landmarker: RunnerTensorModel(nets.landmarker),
        );
        expect(
          () => pipeline.process(blank(truths.values.first)),
          throwsA(isA<ModelOutputError>()),
        );
      },
    );
  });

  group('frames from the browser', () {
    test('a canvas\'s RGBA bytes are read as the picture they are', () {
      final Uint8List px = Uint8List(4 * 2 * 4);
      // Second pixel of the first row is pure red; first of the second, blue.
      px[4] = 255;
      px[3] = 255;
      px[7] = 255;
      px[(1 * 4 + 0) * 4 + 2] = 255;
      px[(1 * 4 + 0) * 4 + 3] = 255;
      final CameraFrame frame = CameraFrame(
        format: FrameFormat.rgba8888,
        width: 4,
        height: 2,
        rotationDegrees: 0,
        planes: <FramePlane>[FramePlane(px, 16, 4)],
      );
      final PalmFrame f = frame.toPalmFrame();
      expect(f.width, 4);
      expect(f.height, 2);
      final Float32List out = Float32List(3);
      f.rgbAt(1, 0, out, 0);
      expect(out, <double>[1, 0, 0]);
      f.rgbAt(0, 1, out, 0);
      expect(out, <double>[0, 0, 1]);
      expect(f.lumaAt(1, 0), closeTo(0.299, 1e-6));
    });
  });
}
