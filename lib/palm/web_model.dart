import 'dart:typed_data';

import 'tensor_model.dart';

/// A compiled network as the browser's runtime hands it over: shapes and names
/// it reports, and a synchronous call that takes floats and gives floats.
///
/// This is the whole of what the web build needs from LiteRT.js, so the part
/// that touches JavaScript (web_litert.dart) is a few lines, and everything
/// that decides whether the numbers are usable is here, where a test can run
/// it.
abstract class ModelRunner {
  List<int> get inputShape;
  List<String> get outputNames;
  List<List<int>> get outputShapes;

  /// Runs the network. Every output is a fresh array the caller may keep.
  List<Float32List> run(Float32List input);

  void close();
}

/// Thrown when the browser's runtime answers with something the hand pipeline
/// could not safely read.
class ModelOutputError extends StateError {
  ModelOutputError(super.message);
}

int _elements(List<int> shape) => shape.fold<int>(1, (int a, int b) => a * b);

/// A [ModelRunner] seen as a [TensorModel], so the same [HandPipeline] that
/// runs on the phone runs in the browser.
///
/// It checks what comes back rather than trust it. A model that answers with
/// the wrong number of values, or with anything that is not a finite number,
/// would not fail loudly further down: it would place a hand somewhere and the
/// reading would be built on that. Here it stops instead, and the screen offers
/// the hand tracer.
class RunnerTensorModel implements TensorModel {
  RunnerTensorModel(this._runner)
    : _inputLength = _elements(_runner.inputShape) {
    if (_runner.outputNames.length != _runner.outputShapes.length) {
      throw ModelOutputError(
        'The model names ${_runner.outputNames.length} outputs but '
        'describes ${_runner.outputShapes.length}.',
      );
    }
  }

  final ModelRunner _runner;
  final int _inputLength;

  @override
  List<int> get inputShape => _runner.inputShape;

  @override
  List<String> get outputNames => _runner.outputNames;

  @override
  List<List<int>> get outputShapes => _runner.outputShapes;

  @override
  List<Float32List> run(Float32List input) {
    if (input.length != _inputLength) {
      throw ArgumentError(
        'The model takes $_inputLength values, not ${input.length}.',
      );
    }
    final List<Float32List> out = _runner.run(input);
    final List<List<int>> shapes = _runner.outputShapes;
    if (out.length != shapes.length) {
      throw ModelOutputError(
        'The model gave ${out.length} outputs, not ${shapes.length}.',
      );
    }
    for (int i = 0; i < out.length; i++) {
      if (out[i].length != _elements(shapes[i])) {
        throw ModelOutputError(
          'Output $i has ${out[i].length} values, not ${_elements(shapes[i])}.',
        );
      }
      for (final double v in out[i]) {
        if (!v.isFinite) {
          throw ModelOutputError('Output $i holds a value that is not a number.');
        }
      }
    }
    return out;
  }

  @override
  void close() => _runner.close();
}

/// Where the runtime's files are served from, given the page's base URL
/// (`document.baseURI`, which already carries the `<base href>`): the
/// `litert/` folder the build copies next to the app. Relative to the base, so
/// it is right under a sub-path such as /KundliSaar/app/ as well as at the
/// root, and it is always on the page's own origin.
Uri litertDirectory(String baseUri) => Uri.parse(baseUri).resolve('litert/');
