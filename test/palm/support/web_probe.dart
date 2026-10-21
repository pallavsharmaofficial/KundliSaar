// The web build's hand pipeline, compiled to JavaScript and run under Node.
//
// It is the same Dart as the app's (HandPipeline over the adapter in
// web_model.dart) and the same Dart-to-JavaScript step as `flutter build web`
// uses, calling the same web_litert.dart, which loads web/litert/litert_hand.js
// and the WebAssembly runtime exactly as the page does. Only the page around
// it is missing (a Node script stands in for it: run_web_probe.mjs). Given
// the models and some frames, it answers with what it made of each, for a test
// to hold against what the phone path made of the same frames.
//
// Not part of the app; nothing imports it.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/hand_pipeline.dart';
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/palm/web_litert.dart';
import 'package:kundlisaar/palm/web_model.dart';

import 'summary.dart';

Future<void> main() async {
  void done(Map<String, Object?> answer) {
    globalContext.callMethod('__probeDone'.toJS, jsonEncode(answer).toJS);
  }

  try {
    final JSObject models = globalContext.getProperty<JSObject>(
      '__models'.toJS,
    );
    final JSArray<JSObject> frames = globalContext
        .getProperty<JSArray<JSObject>>('__frames'.toJS);

    final LiteRtRuntime runtime = await LiteRtRuntime.load();
    final HandPipeline pipeline = HandPipeline(
      detector: RunnerTensorModel(
        await runtime.loadModel(
          models.getProperty<JSUint8Array>('detector'.toJS).toDart,
        ),
      ),
      landmarker: RunnerTensorModel(
        await runtime.loadModel(
          models.getProperty<JSUint8Array>('landmarker'.toJS).toDart,
        ),
      ),
    );

    final Map<String, Object?> out = <String, Object?>{};
    for (final JSObject f in frames.toDart) {
      final String name = f.getProperty<JSString>('name'.toJS).toDart;
      final int width = f.getProperty<JSNumber>('width'.toJS).toDartInt;
      final int height = f.getProperty<JSNumber>('height'.toJS).toDartInt;
      final Uint8List rgba = f.getProperty<JSUint8Array>('rgba'.toJS).toDart;
      final RgbaFrame frame = RgbaFrame(rgba, width, height);
      final Stopwatch clock = Stopwatch()..start();
      final HandObservation? hand = pipeline.refine(frame);
      final int look = clock.elapsedMilliseconds;
      final Map<String, Object?> summary = summarise(
        hand,
        creasesFor(frame, hand),
      );
      summary['millis'] = <String, int>{
        'refine': look,
        'withCreases': clock.elapsedMilliseconds,
      };
      out[name] = summary;
    }
    done(<String, Object?>{'variant': runtime.variant, 'frames': out});
  } catch (e, st) {
    done(<String, Object?>{'error': '$e\n$st'});
  }
}
