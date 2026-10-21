import 'dart:typed_data';

/// One compiled neural network, seen the only way the hand pipeline needs it:
/// floats in, floats out.
///
/// The pipeline is written against this rather than against TensorFlow Lite so
/// that the arithmetic around the models (anchors, boxes, the turn of the
/// hand) is plain Dart that runs in tests, and so that the native runtime is
/// kept to one small file.
abstract class TensorModel {
  /// Shape of the first input, for example [1, 224, 224, 3].
  List<int> get inputShape;

  /// Runs the network on [input] (row-major floats, the size of the input
  /// tensor) and returns every output tensor, flattened, in the model's order.
  List<Float32List> run(Float32List input);

  /// Names of the output tensors, in the model's order. Used to tell the
  /// outputs apart when shapes alone would not.
  List<String> get outputNames;

  /// Shapes of the output tensors, in the model's order.
  List<List<int>> get outputShapes;

  void close();
}
