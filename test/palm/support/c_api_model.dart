// A TensorModel over TensorFlow Lite's C API, loaded from an explicit path.
//
// The app reaches TensorFlow Lite through the tflite_flutter plugin, which on
// a Mac looks for its library in a place `flutter test` does not use. Tests
// that want to run the real models on a laptop load the same library by hand
// and wrap it the same way the plugin does. It is test support only; nothing
// in lib/ imports it.
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
// ignore: implementation_imports
import 'package:tflite_flutter/src/bindings/tensorflow_lite_bindings_generated.dart';

import 'package:kundlisaar/palm/tensor_model.dart';

/// Where this machine keeps TensorFlow Lite's C library, or null. On a Mac the
/// tflite_flutter package ships a universal build of it, found through the
/// package config.
String? findTfliteLibrary() {
  final String? override = Platform.environment['TFLITE_C_LIB'];
  if (override != null && File(override).existsSync()) return override;
  if (!Platform.isMacOS) return null;
  final File config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final RegExpMatch? m = RegExp(
    r'"name":\s*"tflite_flutter",\s*"rootUri":\s*"([^"]+)"',
  ).firstMatch(config.readAsStringSync());
  if (m == null) return null;
  String root = m.group(1)!;
  if (root.startsWith('file://')) root = Uri.parse(root).toFilePath();
  final String path = '$root/macos/libtensorflowlite_c-mac.dylib';
  return File(path).existsSync() ? path : null;
}

class CApiModel implements TensorModel {
  CApiModel._(
    this._b,
    this._model,
    this._options,
    this._interpreter,
    this._modelData,
  );

  factory CApiModel.load(String libraryPath, Uint8List modelBytes) {
    final TensorFlowLiteBindings b = TensorFlowLiteBindings(
      ffi.DynamicLibrary.open(libraryPath),
    );
    final ffi.Pointer<ffi.Uint8> data = malloc<ffi.Uint8>(modelBytes.length);
    data.asTypedList(modelBytes.length).setAll(0, modelBytes);
    final ffi.Pointer<TfLiteModel> model = b.TfLiteModelCreate(
      data.cast(),
      modelBytes.length,
    );
    final ffi.Pointer<TfLiteInterpreterOptions> options = b
        .TfLiteInterpreterOptionsCreate();
    b.TfLiteInterpreterOptionsSetNumThreads(options, 2);
    final ffi.Pointer<TfLiteInterpreter> interpreter = b
        .TfLiteInterpreterCreate(model, options);
    if (b.TfLiteInterpreterAllocateTensors(interpreter) != 0) {
      throw StateError('allocateTensors failed');
    }
    return CApiModel._(b, model, options, interpreter, data);
  }

  final TensorFlowLiteBindings _b;
  final ffi.Pointer<TfLiteModel> _model;
  final ffi.Pointer<TfLiteInterpreterOptions> _options;
  final ffi.Pointer<TfLiteInterpreter> _interpreter;
  final ffi.Pointer<ffi.Uint8> _modelData;

  List<int> _shape(ffi.Pointer<TfLiteTensor> t) => <int>[
    for (int i = 0; i < _b.TfLiteTensorNumDims(t); i++) _b.TfLiteTensorDim(t, i),
  ];

  @override
  List<int> get inputShape =>
      _shape(_b.TfLiteInterpreterGetInputTensor(_interpreter, 0));

  int get _outputs => _b.TfLiteInterpreterGetOutputTensorCount(_interpreter);

  @override
  List<List<int>> get outputShapes => <List<int>>[
    for (int i = 0; i < _outputs; i++)
      _shape(
        _b
            .TfLiteInterpreterGetOutputTensor(_interpreter, i)
            .cast<TfLiteTensor>(),
      ),
  ];

  @override
  List<String> get outputNames => <String>[
    for (int i = 0; i < _outputs; i++)
      _b
          .TfLiteTensorName(
            _b.TfLiteInterpreterGetOutputTensor(_interpreter, i).cast(),
          )
          .cast<Utf8>()
          .toDartString(),
  ];

  @override
  List<Float32List> run(Float32List input) {
    final ffi.Pointer<TfLiteTensor> t = _b.TfLiteInterpreterGetInputTensor(
      _interpreter,
      0,
    );
    final ffi.Pointer<ffi.Uint8> dst = _b.TfLiteTensorData(t).cast();
    dst
        .asTypedList(_b.TfLiteTensorByteSize(t))
        .setAll(0, input.buffer.asUint8List());
    if (_b.TfLiteInterpreterInvoke(_interpreter) != 0) {
      throw StateError('invoke failed');
    }
    return <Float32List>[
      for (int i = 0; i < _outputs; i++)
        () {
          final ffi.Pointer<TfLiteTensor> o = _b
              .TfLiteInterpreterGetOutputTensor(_interpreter, i)
              .cast();
          final ffi.Pointer<ffi.Uint8> src = _b.TfLiteTensorData(o).cast();
          final Uint8List bytes = Uint8List.fromList(
            src.asTypedList(_b.TfLiteTensorByteSize(o)),
          );
          return bytes.buffer.asFloat32List();
        }(),
    ];
  }

  @override
  void close() {
    _b.TfLiteInterpreterDelete(_interpreter);
    _b.TfLiteInterpreterOptionsDelete(_options);
    _b.TfLiteModelDelete(_model);
    malloc.free(_modelData);
  }
}
