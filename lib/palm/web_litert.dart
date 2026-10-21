import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_model.dart';

// The browser's side of the hand models: Google's LiteRT.js (Apache 2.0), the
// WebAssembly build of the same TensorFlow Lite kernels the phone apps use,
// reached through the small wrapper in vendor/litert_web/src/hand_runtime.js.
//
// Everything it loads comes from this site's own directory, web/litert/, which
// the build copies next to the app. Nothing is fetched from anywhere else and
// nothing is sent anywhere.

extension type _HandRuntime._(JSObject _) implements JSObject {
  /// Loads the WebAssembly runtime from a directory URL. Answers which build
  /// it picked, "standard" or "compat".
  external JSPromise<JSString> loadRuntime(JSString directory);

  external JSPromise<_JsModel> loadModel(JSUint8Array bytes);
}

extension type _JsModel._(JSObject _) implements JSObject {
  external JSArray<JSNumber> get inputShape;
  external JSArray<JSString> get outputNames;
  external JSArray<JSArray<JSNumber>> get outputShapes;
  external JSArray<JSFloat32Array> run(JSFloat32Array input);
  external void close();
}

class _JsRunner implements ModelRunner {
  _JsRunner(this._model)
    : inputShape = <int>[for (final JSNumber n in _model.inputShape.toDart) n.toDartInt],
      outputNames = <String>[
        for (final JSString s in _model.outputNames.toDart) s.toDart,
      ],
      outputShapes = <List<int>>[
        for (final JSArray<JSNumber> shape in _model.outputShapes.toDart)
          <int>[for (final JSNumber n in shape.toDart) n.toDartInt],
      ];

  final _JsModel _model;

  @override
  final List<int> inputShape;
  @override
  final List<String> outputNames;
  @override
  final List<List<int>> outputShapes;

  @override
  List<Float32List> run(Float32List input) => <Float32List>[
    for (final JSFloat32Array out in _model.run(input.toJS).toDart) out.toDart,
  ];

  @override
  void close() => _model.close();
}

/// Whether this browser can run the models at all: WebAssembly is there, and
/// so is a camera it will let a page ask for. The camera is only offered on a
/// secure page (https or localhost), which GitHub Pages is.
bool browserCanDetectHands() {
  if (!globalContext.has('WebAssembly')) return false;
  final JSAny? devices = web.window.navigator.getProperty('mediaDevices'.toJS);
  if (devices == null || devices.isUndefinedOrNull) return false;
  return (devices as JSObject).has('getUserMedia');
}

/// The runtime, loaded once.
class LiteRtRuntime {
  LiteRtRuntime._(this._handRuntime, this.variant);

  final _HandRuntime _handRuntime;

  /// "standard" for browsers with relaxed SIMD, "compat" for those without.
  final String variant;

  static Future<LiteRtRuntime>? _loading;

  static Future<LiteRtRuntime> load() => _loading ??= _load().catchError((
    Object error,
    StackTrace trace,
  ) {
    // A failed load (the network dropped halfway through nine megabytes) must
    // not stick: the person's "try again" should try again.
    _loading = null;
    Error.throwWithStackTrace(error, trace);
  });

  static Future<LiteRtRuntime> _load() async {
    // The page's own base URL, so this works under a sub-path such as
    // /KundliSaar/app/ as well as at the root.
    final Uri directory = litertDirectory(web.document.baseURI);
    final _HandRuntime module = _HandRuntime._(
      await importModule(
        directory.resolve('litert_hand.js').toString().toJS,
      ).toDart,
    );
    final String variant = (await module
            .loadRuntime(directory.toString().toJS)
            .toDart)
        .toDart;
    return LiteRtRuntime._(module, variant);
  }

  /// Compiles a .tflite model, given as bytes, for the CPU.
  Future<ModelRunner> loadModel(Uint8List bytes) async {
    final _JsModel model = await _handRuntime.loadModel(bytes.toJS).toDart;
    return _JsRunner(model);
  }
}
