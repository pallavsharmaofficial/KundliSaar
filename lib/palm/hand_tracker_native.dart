import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'frame.dart';
import 'frame_scan.dart';
import 'hand_pipeline.dart';
import 'hand_tracker.dart';
import 'tensor_model.dart';

const bool handDetectionSupported = true;

/// One tracker for the whole run of the app. TensorFlow Lite's Dart plugin
/// copies a model into native memory and never gives it back, so loading the
/// two networks again for every visit to the camera would add about eight
/// megabytes each time. Loaded once, kept, and quiet when not in use.
HandTracker createHandTracker() => NativeHandTracker._shared;

const String _detectorAsset = 'assets/models/hand_detector.tflite';
const String _landmarkAsset = 'assets/models/hand_landmarks_detector.tflite';

/// TensorFlow Lite behind the [TensorModel] interface.
///
/// Two CPU threads and the runtime's default kernels. No GPU or NNAPI
/// delegate: on cheap phones they are the thing most likely to misbehave, and
/// these two networks are small enough to run fine without them.
class TfliteModel implements TensorModel {
  TfliteModel(Uint8List bytes) {
    final InterpreterOptions options = InterpreterOptions()..threads = 2;
    _interpreter = Interpreter.fromBuffer(bytes, options: options);
    options.delete();
  }

  late final Interpreter _interpreter;

  @override
  List<int> get inputShape => _interpreter.getInputTensor(0).shape;

  @override
  List<List<int>> get outputShapes => <List<int>>[
    for (final Tensor t in _interpreter.getOutputTensors()) t.shape,
  ];

  @override
  List<String> get outputNames => <String>[
    for (final Tensor t in _interpreter.getOutputTensors()) t.name,
  ];

  @override
  List<Float32List> run(Float32List input) {
    _interpreter.getInputTensor(0).data = input.buffer.asUint8List(
      input.offsetInBytes,
      input.lengthInBytes,
    );
    _interpreter.invoke();
    return <Float32List>[
      for (final Tensor t in _interpreter.getOutputTensors())
        // A copy: the tensor's own memory is reused by the next run.
        Uint8List.fromList(t.data).buffer.asFloat32List(),
    ];
  }

  @override
  void close() => _interpreter.close();
}

// -----------------------------------------------------------------------------
// The worker isolate. Everything heavy happens there; the UI isolate only ever
// posts a frame and waits for the answer.

class _Init {
  _Init(this.reply, this.detector, this.landmarker);

  final SendPort reply;
  final TransferableTypedData detector;
  final TransferableTypedData landmarker;
}

class _WireFrame {
  _WireFrame(this.frame, this.planes);

  final CameraFrame frame;
  final List<TransferableTypedData> planes;
}

class _Job {
  _Job(this.id, this.scan, this.wire, this.timeMs);

  final int id;
  final bool scan;
  final _WireFrame wire;
  final int timeMs;
}

class _Answer {
  _Answer(this.id, {this.track, this.still, this.error});

  final int id;
  final TrackResult? track;
  final StillScan? still;
  final String? error;
}

void _worker(_Init init) {
  final ReceivePort inbox = ReceivePort();
  late final HandPipeline pipeline;
  try {
    pipeline = HandPipeline(
      detector: TfliteModel(init.detector.materialize().asUint8List()),
      landmarker: TfliteModel(init.landmarker.materialize().asUint8List()),
    );
  } catch (e) {
    init.reply.send(_Answer(-1, error: '$e'));
    return;
  }
  init.reply.send(inbox.sendPort);

  inbox.listen((Object? message) {
    if (message is! _Job) {
      pipeline.close();
      inbox.close();
      return;
    }
    try {
      final CameraFrame f = message.wire.frame;
      final CameraFrame real = CameraFrame(
        format: f.format,
        width: f.width,
        height: f.height,
        rotationDegrees: f.rotationDegrees,
        planes: <FramePlane>[
          for (int i = 0; i < f.planes.length; i++)
            FramePlane(
              message.wire.planes[i].materialize().asUint8List(),
              f.planes[i].bytesPerRow,
              f.planes[i].bytesPerPixel,
            ),
        ],
      );
      final PalmFrame frame = real.toPalmFrame();
      if (message.scan) {
        init.reply.send(
          _Answer(message.id, still: scanFrame(pipeline, frame, message.timeMs)),
        );
      } else {
        init.reply.send(
          _Answer(message.id, track: trackFrame(pipeline, frame, message.timeMs)),
        );
      }
    } catch (e) {
      init.reply.send(_Answer(message.id, error: '$e'));
    }
  });
}

class NativeHandTracker implements HandTracker {
  NativeHandTracker._();

  static final NativeHandTracker _shared = NativeHandTracker._();

  Future<void>? _starting;
  SendPort? _toWorker;
  final Map<int, Completer<_Answer>> _pending = <int, Completer<_Answer>>{};
  int _next = 0;
  bool _busy = false;
  int _lastStartMs = -1 << 30;

  /// The tracker's own clock for pacing, so a camera that is closed and
  /// opened again, and restarts the screen's clock at zero, cannot stall it.
  final Stopwatch _clock = Stopwatch()..start();

  /// The least gap between two live looks. About eight a second: plenty for
  /// guidance, and what a budget phone can keep up with.
  static const int minGapMs = 120;

  @override
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    final ByteData det = await rootBundle.load(_detectorAsset);
    final ByteData lm = await rootBundle.load(_landmarkAsset);
    final ReceivePort port = ReceivePort();
    final Completer<void> ready = Completer<void>();
    port.listen((Object? message) {
      if (message is SendPort) {
        _toWorker = message;
        if (!ready.isCompleted) ready.complete();
      } else if (message is _Answer) {
        if (message.id < 0) {
          if (!ready.isCompleted) ready.completeError(message.error ?? 'worker');
          return;
        }
        _pending.remove(message.id)?.complete(message);
      }
    });
    await Isolate.spawn(
      _worker,
      _Init(
        port.sendPort,
        TransferableTypedData.fromList(<Uint8List>[
          det.buffer.asUint8List(det.offsetInBytes, det.lengthInBytes),
        ]),
        TransferableTypedData.fromList(<Uint8List>[
          lm.buffer.asUint8List(lm.offsetInBytes, lm.lengthInBytes),
        ]),
      ),
    );
    await ready.future;
  }

  _WireFrame _wire(CameraFrame frame) => _WireFrame(
    frame,
    <TransferableTypedData>[
      for (final FramePlane p in frame.planes)
        TransferableTypedData.fromList(<Uint8List>[p.bytes]),
    ],
  );

  Future<_Answer> _post(CameraFrame frame, int timeMs, {required bool scan}) {
    final int id = _next++;
    final Completer<_Answer> done = Completer<_Answer>();
    _pending[id] = done;
    // The planes travel inside the message's wire form only; the frame record
    // that goes with it carries empty planes so nothing is sent twice.
    final _WireFrame wire = _wire(frame);
    _toWorker!.send(
      _Job(
        id,
        scan,
        _WireFrame(
          CameraFrame(
            format: frame.format,
            width: frame.width,
            height: frame.height,
            rotationDegrees: frame.rotationDegrees,
            planes: <FramePlane>[
              for (final FramePlane p in frame.planes)
                FramePlane(Uint8List(0), p.bytesPerRow, p.bytesPerPixel),
            ],
          ),
          wire.planes,
        ),
        timeMs,
      ),
    );
    return done.future;
  }

  @override
  Future<TrackResult?> track(CameraFrame frame, int timeMs) async {
    final int now = _clock.elapsedMilliseconds;
    if (_toWorker == null || _busy || now - _lastStartMs < minGapMs) {
      return null;
    }
    _busy = true;
    _lastStartMs = now;
    try {
      final _Answer a = await _post(frame, timeMs, scan: false);
      return a.track;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<StillScan> scan(CameraFrame frame, int timeMs) async {
    // Wait for any live look in flight, then take the careful one.
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    _busy = true;
    try {
      final _Answer a = await _post(frame, timeMs, scan: true);
      if (a.still == null) {
        throw StateError(a.error ?? 'The hand could not be scanned.');
      }
      return a.still!;
    } finally {
      _busy = false;
    }
  }

  /// Leaves the worker loaded for the next visit (see [createHandTracker]);
  /// only abandons whatever was in flight.
  @override
  Future<void> dispose() async {
    for (final Completer<_Answer> c in _pending.values) {
      if (!c.isCompleted) c.complete(_Answer(-2, error: 'closed'));
    }
    _pending.clear();
    _busy = false;
  }
}
