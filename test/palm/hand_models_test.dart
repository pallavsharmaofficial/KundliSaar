// Runs the two bundled MediaPipe networks for real, through TensorFlow Lite's
// C library. That library is not on a Linux CI machine, so these tests run
// where it is (a Mac with the tflite_flutter package fetched) and say so
// when they cannot.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/hand_pipeline.dart';
import 'package:kundlisaar/palm/mediapipe_hand.dart';

import 'support/c_api_model.dart';

void main() {
  final String? library = findTfliteLibrary();
  final File detectorFile = File('assets/models/hand_detector.tflite');
  final File landmarkFile = File('assets/models/hand_landmarks_detector.tflite');
  final String? skip = library == null
      ? 'TensorFlow Lite\'s C library is not available on this machine'
      : (!detectorFile.existsSync() || !landmarkFile.existsSync())
      ? 'the model files are missing'
      : null;

  group('the bundled models', () {
    late CApiModel detector;
    late CApiModel landmarker;

    setUpAll(() {
      if (skip != null) return;
      detector = CApiModel.load(library!, detectorFile.readAsBytesSync());
      landmarker = CApiModel.load(library, landmarkFile.readAsBytesSync());
    });

    tearDownAll(() {
      if (skip != null) return;
      detector.close();
      landmarker.close();
    });

    test('have the inputs and outputs the pipeline is written for', () {
      expect(detector.inputShape, <int>[1, detectorSize, detectorSize, 3]);
      expect(detector.outputShapes, <List<int>>[
        <int>[1, 2016, 18],
        <int>[1, 2016, 1],
      ]);
      expect(landmarker.inputShape, <int>[1, landmarkSize, landmarkSize, 3]);
      expect(landmarker.outputShapes, <List<int>>[
        <int>[1, 63],
        <int>[1, 1],
        <int>[1, 1],
        <int>[1, 63],
      ]);
    }, skip: skip);

    test('find no hand in an empty room', () {
      final HandPipeline pipeline = HandPipeline(
        detector: detector,
        landmarker: landmarker,
      );
      final Uint8List grey = Uint8List(640 * 480 * 4)..fillRange(0, 640 * 480 * 4, 120);
      expect(pipeline.process(RgbaFrame(grey, 640, 480)), isNull);
    }, skip: skip);

    test('find no hand in noise, or in the dark', () {
      final HandPipeline pipeline = HandPipeline(
        detector: detector,
        landmarker: landmarker,
      );
      final math.Random rng = math.Random(3);
      final Uint8List noise = Uint8List(640 * 480 * 4);
      for (int i = 0; i < noise.length; i++) {
        noise[i] = i % 4 == 3 ? 255 : rng.nextInt(256);
      }
      expect(pipeline.process(RgbaFrame(noise, 640, 480)), isNull);
      final Uint8List black = Uint8List(640 * 480 * 4);
      for (int i = 3; i < black.length; i += 4) {
        black[i] = 255;
      }
      expect(pipeline.process(RgbaFrame(black, 640, 480)), isNull);
    }, skip: skip);
  });
}
