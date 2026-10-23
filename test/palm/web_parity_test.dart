// Holds the web build's hand models to the phone's.
//
// The browser runs the same two .tflite files through LiteRT.js, the WebAssembly
// build of TensorFlow Lite, wrapped by web/litert/litert_hand.js; the phone runs
// them through TensorFlow Lite itself. The arithmetic around the networks
// (anchors, box decoding, the turn of the hand, projection, the measurements) is
// one body of Dart shared by both. So the two paths can only differ in what the
// networks say, and that is what these tests compare, number for number:
//
//  * the runtime that the browser would load, driven under Node, against
//    TensorFlow Lite's own C library, on the very inputs the pipeline makes
//    from drawn hands (these need Node and, on a Mac, the TensorFlow Lite
//    library the tflite_flutter package ships; they skip where either is
//    missing);
//  * the same, against numbers recorded once from TensorFlow Lite and kept in
//    test/palm/fixtures/phone_path.json, which needs only Node, so CI holds the
//    line on a machine that has no TensorFlow Lite;
//  * the web build's pipeline itself: the Dart that the browser runs
//    (HandPipeline over the adapter, web_litert.dart's loading of the runtime)
//    compiled to JavaScript by dart2js, as `flutter build web` does, and run
//    under Node over the same WebAssembly. That needs Dart and Node.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/hand_pipeline.dart';
import 'package:kundlisaar/palm/palm_scan.dart' show borderlineBand;
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/palm/tensor_model.dart';

import 'support/c_api_model.dart';
import 'support/litert_node_model.dart';
import 'support/parity.dart';
import 'support/summary.dart';

const String _detectorFile = 'assets/models/hand_detector.tflite';
const String _landmarkFile = 'assets/models/hand_landmarks_detector.tflite';
const String _recording = 'test/palm/fixtures/phone_path.json';

bool _nodeIsHere() {
  try {
    return Process.runSync('node', <String>['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// The share of its route that must sit on evidence for each line to be kept,
/// from crease_finder.dart. A line that sits right at its bar can go either
/// way on a machine whose arithmetic differs in the last place, so the lines
/// are compared as sets only where no line is that close.
const Map<String, double> _bars = <String, double>{
  'life': 0.80,
  'head': 0.70,
  'heart': 0.70,
};
const double _nearTheBar = 0.06;

HandObservation? _look(TensorModel det, TensorModel lm, PalmFrame frame) =>
    HandPipeline(detector: det, landmarker: lm).refine(frame);

void _expectSameMeasurements(
  Map<String, Object?> web,
  Map<String, Object?> phone, {
  required String reason,
}) {
  expect(web['found'], phone['found'], reason: reason);
  final List<double> a = (web['points']! as List<Object?>).cast<double>();
  final List<double> b = (phone['points']! as List<Object?>).cast<double>();
  expect(a.length, b.length, reason: reason);
  // Pixels. Measured, the two paths differ by under 0.02 px on a hand 400 px
  // long. A quarter of a pixel is wide enough that another CPU's rounding
  // cannot trip it, and narrow enough that a different pipeline (which moves
  // points by whole pixels) or a swapped output would.
  expect(maxDifference(a, b), lessThan(0.25), reason: '$reason: landmarks');
  expect(
    (web['presence']! as double) - (phone['presence']! as double),
    closeTo(0, 5e-3),
    reason: '$reason: presence',
  );
  expect(
    (web['rightProbability']! as double) -
        (phone['rightProbability']! as double),
    closeTo(0, 5e-3),
    reason: '$reason: which hand',
  );
  for (final String k in <String>[
    'outcome',
    'side',
    'facing',
    'handType',
    'borderline',
  ]) {
    expect(web[k], phone[k], reason: '$reason: $k');
  }
  // Read as numbers: JavaScript writes a cover of exactly 1.0 as 1.
  Map<String, double> covers(Object? m) => <String, double>{
    for (final MapEntry<String, Object?> e
        in (m! as Map<String, Object?>).entries)
      e.key: (e.value! as num).toDouble(),
  };
  final Map<String, double> coverWeb = covers(web['cover']);
  final Map<String, double> coverPhone = covers(phone['cover']);
  expect(
    coverWeb.keys.toSet(),
    coverPhone.keys.toSet(),
    reason: '$reason: lines searched for',
  );
  bool close = false;
  for (final String k in coverWeb.keys) {
    // One step along a route is about a fiftieth.
    expect(
      coverWeb[k]! - coverPhone[k]!,
      closeTo(0, _nearTheBar),
      reason: '$reason: evidence for the $k line',
    );
    close = close || (coverPhone[k]! - _bars[k]!).abs() < _nearTheBar;
  }
  if (!close) {
    expect(web['lines'], phone['lines'], reason: '$reason: the lines found');
  }
  expect(
    (web['widthRatio']! as double) - (phone['widthRatio']! as double),
    closeTo(0, 5e-3),
    reason: '$reason: palm width over length',
  );
  expect(
    (web['fingerRatio']! as double) - (phone['fingerRatio']! as double),
    closeTo(0, 5e-3),
    reason: '$reason: finger over palm length',
  );
}

void main() {
  final bool node = _nodeIsHere();
  final String? tflite = findTfliteLibrary();
  final bool models =
      File(_detectorFile).existsSync() && File(_landmarkFile).existsSync();
  final String? noNode = !node
      ? 'Node is not available on this machine'
      : !models
      ? 'the model files are missing'
      : null;
  final String? noTflite =
      noNode ??
      (tflite == null
          ? 'TensorFlow Lite\'s C library is not available on this machine'
          : null);

  final Map<String, RgbaFrame> frames = parityFrames();

  for (final bool compat in <bool>[false, true]) {
    group(
      'the browser\'s ${compat ? 'compat' : 'default'} runtime against TensorFlow Lite',
      () {
        late LiteRtNode web;
        late CApiModel phoneDetector, phoneLandmarker;
        late NodeModel webDetector, webLandmarker;

        setUpAll(() async {
          if (noTflite != null) return;
          final LiteRtNode? started = await LiteRtNode.start(compat: compat);
          web = started!;
          phoneDetector = CApiModel.load(
            tflite!,
            File(_detectorFile).readAsBytesSync(),
          );
          phoneLandmarker = CApiModel.load(
            tflite,
            File(_landmarkFile).readAsBytesSync(),
          );
          webDetector = web.load(_detectorFile);
          webLandmarker = web.load(_landmarkFile);
        });

        tearDownAll(() {
          if (noTflite != null) return;
          phoneDetector.close();
          phoneLandmarker.close();
          web.close();
        });

        test('loads the build it was asked for', () {
          // Which build Node picks for itself depends on its version; the compat
          // run forces the one for browsers without relaxed SIMD.
          print('runtime build used: ${web.variant}');
          if (compat) expect(web.variant, 'compat');
        }, skip: noTflite);

        test('describe the networks the same way, outputs in the same order', () {
          expect(webDetector.inputShape, phoneDetector.inputShape);
          expect(webLandmarker.inputShape, phoneLandmarker.inputShape);
          expect(webDetector.outputShapes, phoneDetector.outputShapes);
          expect(webLandmarker.outputShapes, phoneLandmarker.outputShapes);
          print(
            'detector outputs: web ${webDetector.outputNames}, phone ${phoneDetector.outputNames}',
          );
          print(
            'landmark outputs: web ${webLandmarker.outputNames}, phone ${phoneLandmarker.outputNames}',
          );
        }, skip: noTflite);

        test(
          'say the same thing about the same inputs, every output of both networks',
          () {
            double worstDetector = 0, worstLandmark = 0;
            for (final MapEntry<String, RgbaFrame> e in frames.entries) {
              // The inputs are the ones the pipeline itself builds from the picture,
              // recorded as it runs on the phone's runtime.
              final RecordingModel det = RecordingModel(phoneDetector);
              final RecordingModel lm = RecordingModel(phoneLandmarker);
              final HandObservation? hand = _look(det, lm, e.value);
              expect(
                hand,
                isNotNull,
                reason: '${e.key}: the drawn hand is found',
              );
              expect(lm.inputs, isNotEmpty);
              for (int i = 0; i < det.inputs.length; i++) {
                final List<Float32List> w = webDetector.run(det.inputs[i]);
                expect(w.length, det.outputs[i].length);
                for (int k = 0; k < w.length; k++) {
                  worstDetector =
                      worstDetector < maxDifference(w[k], det.outputs[i][k])
                      ? maxDifference(w[k], det.outputs[i][k])
                      : worstDetector;
                }
              }
              for (int i = 0; i < lm.inputs.length; i++) {
                final List<Float32List> w = webLandmarker.run(lm.inputs[i]);
                expect(w.length, lm.outputs[i].length);
                for (int k = 0; k < w.length; k++) {
                  final double d = maxDifference(w[k], lm.outputs[i][k]);
                  worstLandmark = worstLandmark < d ? d : worstLandmark;
                }
              }
            }
            print(
              'largest difference in any output: detector $worstDetector, landmarks $worstLandmark',
            );
            // The detector's boxes are in pixels of a 192 square, the landmarks in
            // pixels of a 224 one, and the two kinds of output sit at tens to
            // hundreds. Measured, they differ by under a thousandth: a few
            // millionths of the numbers themselves. A hundredth leaves room for
            // another CPU's rounding and not for a different network, a different
            // kernel or a swapped output.
            expect(worstDetector, lessThan(1e-2));
            expect(worstLandmark, lessThan(1e-2));
          },
          skip: noTflite,
        );

        test('and on inputs that are no hand at all', () {
          final Float32List noise = Float32List(
            webLandmarker.inputShape.fold<int>(1, (int a, int b) => a * b),
          );
          int seed = 7;
          for (int i = 0; i < noise.length; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            noise[i] = (seed >> 8) / 8388608.0;
          }
          final List<Float32List> w = webLandmarker.run(noise);
          final List<Float32List> p = phoneLandmarker.run(noise);
          for (int k = 0; k < w.length; k++) {
            expect(
              maxDifference(w[k], p[k]),
              lessThan(1e-2),
              reason: 'output $k',
            );
          }
        }, skip: noTflite);

        for (final MapEntry<String, RgbaFrame> e in frames.entries) {
          test('place the same hand and make the same measurements: ${e.key}', () {
            final HandObservation? onWeb = _look(
              webDetector,
              webLandmarker,
              e.value,
            );
            final HandObservation? onPhone = _look(
              phoneDetector,
              phoneLandmarker,
              e.value,
            );
            expect(onPhone, isNotNull);
            expect(onWeb, isNotNull);
            print(
              '${e.key}: landmarks differ by at most ${worstPointGap(onWeb!, onPhone!).toStringAsExponential(2)} px, '
              'presence by ${(onWeb.presence - onPhone.presence).abs().toStringAsExponential(1)}, '
              'which hand by ${(onWeb.rightProbability - onPhone.rightProbability).abs().toStringAsExponential(1)}',
            );
            _expectSameMeasurements(
              summarise(onWeb, creasesFor(e.value, onWeb)),
              summarise(onPhone, creasesFor(e.value, onPhone)),
              reason: e.key,
            );
          }, skip: noTflite);
        }
      },
    );
  }

  group('a real photograph, if one is given', () {
    // The drawn hands above are a fixed input, not a hand. To hold the two
    // runtimes to each other on a photograph of a real one, point this at a
    // JPEG or PNG of an open palm, upright or not:
    //
    //   PALM_PHOTO=/path/to/palm.jpg flutter test test/palm/web_parity_test.dart
    //
    // The photograph is only read, in memory, by this test.
    final String? photo = Platform.environment['PALM_PHOTO'];
    late LiteRtNode web;
    late CApiModel phoneDetector, phoneLandmarker;
    late NodeModel webDetector, webLandmarker;

    setUpAll(() async {
      if (photo == null || noTflite != null) return;
      web = (await LiteRtNode.start())!;
      phoneDetector = CApiModel.load(
        tflite!,
        File(_detectorFile).readAsBytesSync(),
      );
      phoneLandmarker = CApiModel.load(
        tflite,
        File(_landmarkFile).readAsBytesSync(),
      );
      webDetector = web.load(_detectorFile);
      webLandmarker = web.load(_landmarkFile);
    });

    tearDownAll(() {
      if (photo == null || noTflite != null) return;
      phoneDetector.close();
      phoneLandmarker.close();
      web.close();
    });

    test(
      'is read as the same hand by both runtimes',
      () async {
        final Uint8List bytes = File(photo!).readAsBytesSync();
        ui.Codec codec = await ui.instantiateImageCodec(bytes);
        ui.Image image = (await codec.getNextFrame()).image;
        final int long = image.width > image.height
            ? image.width
            : image.height;
        if (long > 1280) {
          // The size a camera frame is on the phone and in the browser.
          final double k = 1280 / long;
          final int width = (image.width * k).round();
          final int height = (image.height * k).round();
          image.dispose();
          codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: width,
            targetHeight: height,
          );
          image = (await codec.getNextFrame()).image;
        }
        final ByteData data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final RgbaFrame frame = RgbaFrame(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          image.width,
          image.height,
        );
        final HandObservation? onPhone = _look(
          phoneDetector,
          phoneLandmarker,
          frame,
        );
        final HandObservation? onWeb = _look(webDetector, webLandmarker, frame);
        print(
          'photograph ${frame.width} x ${frame.height}: phone path ${onPhone == null ? 'finds no hand' : 'finds a hand'}, web path ${onWeb == null ? 'finds no hand' : 'finds a hand'}',
        );
        if (onPhone != null && onWeb != null) {
          print(
            'landmarks differ by at most ${worstPointGap(onWeb, onPhone).toStringAsExponential(2)} px',
          );
        }
        _expectSameMeasurements(
          summarise(onWeb, creasesFor(frame, onWeb)),
          summarise(onPhone, creasesFor(frame, onPhone)),
          reason: 'the photograph',
        );
      },
      skip: photo == null
          ? 'set PALM_PHOTO=/path/to/photo to try a real photograph'
          : noTflite,
    );
  });

  group('the same picture in the browser\'s format and the phone\'s', () {
    late CApiModel det, lm;

    setUpAll(() {
      if (noTflite != null) return;
      det = CApiModel.load(tflite!, File(_detectorFile).readAsBytesSync());
      lm = CApiModel.load(tflite, File(_landmarkFile).readAsBytesSync());
    });

    tearDownAll(() {
      if (noTflite != null) return;
      det.close();
      lm.close();
    });

    test('is read as the same hand', () {
      // A browser delivers RGBA; Android delivers YUV with the colour at a
      // quarter of the resolution. Same picture, same model, so any difference
      // is the format's.
      final RgbaFrame rgba = frames.values.first;
      final Yuv420Frame yuv = toYuv420(rgba);
      final HandObservation? a = _look(det, lm, rgba);
      final HandObservation? b = _look(det, lm, yuv);
      expect(a, isNotNull);
      expect(b, isNotNull);
      final Map<String, Object?> sa = summarise(a, null);
      final Map<String, Object?> sb = summarise(b, null);
      final double gap = worstPointGap(a!, b!);
      final double hand = a.points[Joint.wrist].distanceTo(
        a.points[Joint.middleTip],
      );
      print(
        'RGBA against YUV: landmarks differ by at most ${gap.toStringAsFixed(2)} px '
        'on a hand ${hand.toStringAsFixed(0)} px long; palm width ${sa['widthRatio']} '
        'against ${sb['widthRatio']}, finger ${sa['fingerRatio']} against ${sb['fingerRatio']}',
      );
      // The colour in a YUV frame is a quarter of the resolution, so the
      // picture is not quite the same one; the hand is the same hand to within
      // a pixel or two in a few hundred.
      expect(gap, lessThan(0.015 * hand));
      for (final String k in <String>['side', 'facing', 'handType']) {
        expect(sa[k], sb[k], reason: k);
      }
      // Different pixels in give a slightly different hand out, from any
      // camera; the app already treats a measure within the borderline band of
      // a cut-off as too near to call, and the format moves it by less than
      // that.
      expect(
        (sa['widthRatio']! as double) - (sb['widthRatio']! as double),
        closeTo(0, borderlineBand),
      );
      expect(
        (sa['fingerRatio']! as double) - (sb['fingerRatio']! as double),
        closeTo(0, borderlineBand),
      );
    }, skip: noTflite);
  });

  group(
    'the browser\'s runtime against what TensorFlow Lite said when it was recorded',
    () {
      late LiteRtNode web;
      late NodeModel det, lm;

      setUpAll(() async {
        if (noNode != null) return;
        web = (await LiteRtNode.start())!;
        det = web.load(_detectorFile);
        lm = web.load(_landmarkFile);
      });

      tearDownAll(() {
        if (noNode != null) return;
        web.close();
      });

      // Run with RECORD_PHONE_PATH=1 on a machine that has TensorFlow Lite to
      // write the recording again.
      test(
        'is recorded from TensorFlow Lite when asked to be',
        () {
          final CApiModel pd = CApiModel.load(
            tflite!,
            File(_detectorFile).readAsBytesSync(),
          );
          final CApiModel pl = CApiModel.load(
            tflite,
            File(_landmarkFile).readAsBytesSync(),
          );
          final Map<String, Object?> out = <String, Object?>{
            'about':
                'What the phone path (TensorFlow Lite, through HandPipeline) made of '
                'each drawn hand in test/palm/support/parity.dart. The browser path '
                'is held to these in web_parity_test.dart. Rewrite with '
                'RECORD_PHONE_PATH=1 flutter test test/palm/web_parity_test.dart',
            'frames': <String, Object?>{
              for (final MapEntry<String, RgbaFrame> e in frames.entries)
                e.key: () {
                  final HandObservation? h = _look(pd, pl, e.value);
                  return summarise(h, creasesFor(e.value, h));
                }(),
            },
          };
          File(_recording)
            ..createSync(recursive: true)
            ..writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(out),
            );
          pd.close();
          pl.close();
        },
        skip: Platform.environment['RECORD_PHONE_PATH'] == '1'
            ? noTflite
            : 'only when RECORD_PHONE_PATH=1',
      );

      for (final MapEntry<String, RgbaFrame> e in frames.entries) {
        test(
          'place the same hand and make the same measurements: ${e.key}',
          () {
            // Read here, not before the group, so a recording made earlier in
            // this same run is the one that is used.
            final File file = File(_recording);
            expect(file.existsSync(), isTrue, reason: '$_recording is missing');
            final Map<String, Object?> recorded =
                jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
            final Map<String, Object?> phone =
                (recorded['frames']! as Map<String, Object?>)[e.key]!
                    as Map<String, Object?>;
            final HandObservation? hand = _look(det, lm, e.value);
            _expectSameMeasurements(
              summarise(hand, creasesFor(e.value, hand)),
              phone,
              reason: e.key,
            );
          },
          skip: noNode,
        );
      }
    },
  );

  group(
    'the web build\'s own pipeline, compiled to JavaScript, against the phone\'s recording',
    () {
      for (final bool compat in <bool>[false, true]) {
        test(
          'makes the same measurements from the same pictures (${compat ? 'compat' : 'default'} runtime)',
          () async {
            final String? dart = _findDart();
            if (dart == null) {
              markTestSkipped(
                'no dart executable found to compile the probe with',
              );
              return;
            }
            final Directory work = Directory.systemTemp.createTempSync(
              'web_probe_',
            );
            addTearDown(() => work.deleteSync(recursive: true));

            // The pictures go to Node as plain RGBA bytes.
            final List<Map<String, Object?>> index = <Map<String, Object?>>[];
            int n = 0;
            for (final MapEntry<String, RgbaFrame> e in frames.entries) {
              final String file = 'frame${n++}.rgba';
              File('${work.path}/$file').writeAsBytesSync(e.value.bytes);
              index.add(<String, Object?>{
                'name': e.key,
                'width': e.value.width,
                'height': e.value.height,
                'file': file,
              });
            }
            File(
              '${work.path}/frames.json',
            ).writeAsStringSync(jsonEncode(index));

            final ProcessResult compiled = await Process.run(dart, <String>[
              'compile',
              'js',
              '-O1',
              '-o',
              '${work.path}/probe.js',
              'test/palm/support/web_probe.dart',
            ]);
            expect(
              compiled.exitCode,
              0,
              reason: '${compiled.stdout}${compiled.stderr}',
            );

            final ProcessResult ran = await Process.run('node', <String>[
              // A script run by Node's vm may only import() with this on, on the
              // older Nodes; it is a no-op on newer ones.
              '--experimental-vm-modules',
              'test/palm/support/run_web_probe.mjs',
              '${work.path}/probe.js',
              work.path,
              if (compat) '--compat',
            ]);
            expect(ran.exitCode, 0, reason: '${ran.stderr}');
            final String last = (ran.stdout as String).trim().split('\n').last;
            final Map<String, Object?> answer =
                jsonDecode(last) as Map<String, Object?>;
            expect(answer['error'], isNull, reason: '${answer['error']}');
            // Which build the engine picks for itself depends on its version; a
            // refusal to use relaxed SIMD is what the compat run forces.
            print('runtime build used: ${answer['variant']}');
            if (compat) expect(answer['variant'], 'compat');

            final Map<String, Object?> recorded =
                jsonDecode(File(_recording).readAsStringSync())
                    as Map<String, Object?>;
            final Map<String, Object?> got =
                answer['frames']! as Map<String, Object?>;
            for (final String name in frames.keys) {
              final Map<String, Object?> web =
                  got[name]! as Map<String, Object?>;
              final Map<String, Object?> millis =
                  (web['millis']! as Map<String, Object?>);
              final Map<String, Object?> phone =
                  (recorded['frames']! as Map<String, Object?>)[name]!
                      as Map<String, Object?>;
              final double gap = maxDifference(
                (web['points']! as List<Object?>).cast<double>(),
                (phone['points']! as List<Object?>).cast<double>(),
              );
              print(
                '$name: landmarks differ from the phone path\'s by at most ${gap.toStringAsExponential(2)} px; '
                'refine ${millis['refine']} ms, with the lines ${millis['withCreases']} ms (under Node, one thread)',
              );
              _expectSameMeasurements(web, phone, reason: name);
            }
          },
          skip: noNode,
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    },
  );
}

/// The Dart executable that can compile to JavaScript: the Flutter SDK's, found
/// from the environment, or the one on the path.
String? _findDart() {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && File('$root/bin/dart').existsSync()) {
    return '$root/bin/dart';
  }
  try {
    if (Process.runSync('dart', <String>['--version']).exitCode == 0) {
      return 'dart';
    }
  } on ProcessException {
    // not on the path
  }
  return null;
}
