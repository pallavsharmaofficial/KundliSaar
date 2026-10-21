// The web build's own model runtime (web/litert/), driven from a Dart test.
//
// litert_node_server.mjs loads the same JavaScript and WebAssembly files the
// browser is served and answers over a socket. [NodeModel] is a [TensorModel]
// over it, so the very same HandPipeline can be run once over TensorFlow Lite
// (the phone path, see c_api_model.dart) and once over the browser's runtime,
// and the two compared number for number. Test support only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kundlisaar/palm/tensor_model.dart';

/// A Node process running the web runtime, or null where Node is not there.
class LiteRtNode {
  LiteRtNode._(this._process, this._socket, this.variant);

  final Process _process;
  final RawSynchronousSocket _socket;

  /// Which build of the runtime Node loaded: "standard" or "compat".
  final String variant;

  /// Starts the server. [compat] makes it load the build meant for browsers
  /// without relaxed SIMD. Returns null if Node cannot be started, so a test
  /// can skip rather than fail on a machine without it.
  static Future<LiteRtNode?> start({bool compat = false}) async {
    final Process process;
    try {
      process = await Process.start('node', <String>[
        'test/palm/support/litert_node_server.mjs',
        if (compat) '--compat',
      ]);
    } on ProcessException {
      return null;
    }
    // The runtime logs a good deal; it is not needed, but the pipe must be
    // drained or the server would stall.
    unawaited(process.stderr.drain<void>());
    final Completer<int> port = Completer<int>();
    final StringBuffer seen = StringBuffer();
    process.stdout.transform(utf8.decoder).listen((String chunk) {
      seen.write(chunk);
      final RegExpMatch? m = RegExp(r'PORT (\d+)').firstMatch(seen.toString());
      if (m != null && !port.isCompleted) port.complete(int.parse(m.group(1)!));
    });
    unawaited(
      process.exitCode.then((int code) {
        if (!port.isCompleted) {
          port.completeError(StateError('node exited with $code: $seen'));
        }
      }),
    );
    final int number = await port.future.timeout(const Duration(seconds: 60));
    final RawSynchronousSocket socket = RawSynchronousSocket.connectSync(
      '127.0.0.1',
      number,
    );
    final LiteRtNode node = LiteRtNode._(process, socket, '');
    final Map<String, Object?> info =
        jsonDecode(utf8.decode(node._call(Uint8List.fromList(<int>[3]))))
            as Map<String, Object?>;
    return LiteRtNode._(process, socket, info['variant']! as String);
  }

  Uint8List _readExact(int length) {
    final BytesBuilder out = BytesBuilder(copy: false);
    int have = 0;
    while (have < length) {
      final List<int>? chunk = _socket.readSync(length - have);
      if (chunk == null || chunk.isEmpty) {
        throw StateError('The runtime closed the connection.');
      }
      out.add(chunk);
      have += chunk.length;
    }
    return out.takeBytes();
  }

  /// Sends one request and returns the bytes of a successful answer.
  Uint8List _call(Uint8List body) {
    final ByteData head = ByteData(4)..setUint32(0, body.length, Endian.little);
    _socket.writeFromSync(head.buffer.asUint8List());
    _socket.writeFromSync(body);
    final Uint8List size = _readExact(4);
    final int length = ByteData.sublistView(size).getUint32(0, Endian.little);
    final Uint8List answer = _readExact(length);
    if (answer[0] != 0) {
      throw StateError(utf8.decode(answer.sublist(1)));
    }
    return answer.sublist(1);
  }

  NodeModel load(String path) {
    final Uint8List body = Uint8List.fromList(<int>[1, ...utf8.encode(path)]);
    final Map<String, Object?> info =
        jsonDecode(utf8.decode(_call(body))) as Map<String, Object?>;
    return NodeModel._(this, info);
  }

  void close() {
    _socket.closeSync();
    _process.kill();
  }
}

class NodeModel implements TensorModel {
  NodeModel._(this._node, Map<String, Object?> info)
    : _id = info['id']! as int,
      inputShape = <int>[
        for (final Object? n in info['inputShape']! as List<Object?>) n! as int,
      ],
      outputNames = <String>[
        for (final Object? n in info['outputNames']! as List<Object?>)
          n! as String,
      ],
      outputShapes = <List<int>>[
        for (final Object? s in info['outputShapes']! as List<Object?>)
          <int>[for (final Object? n in s! as List<Object?>) n! as int],
      ];

  final LiteRtNode _node;
  final int _id;

  @override
  final List<int> inputShape;
  @override
  final List<String> outputNames;
  @override
  final List<List<int>> outputShapes;

  @override
  List<Float32List> run(Float32List input) {
    final ByteData head = ByteData(5)
      ..setUint8(0, 2)
      ..setUint32(1, _id, Endian.little);
    final Uint8List body = Uint8List(5 + input.lengthInBytes)
      ..setRange(0, 5, head.buffer.asUint8List())
      ..setRange(
        5,
        5 + input.lengthInBytes,
        input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes),
      );
    final Uint8List answer = _node._call(body);
    final ByteData view = ByteData.sublistView(answer);
    final int count = view.getUint32(0, Endian.little);
    final List<Float32List> out = <Float32List>[];
    int at = 4;
    for (int i = 0; i < count; i++) {
      final int n = view.getUint32(at, Endian.little);
      at += 4;
      out.add(
        Uint8List.fromList(
          answer.sublist(at, at + n * 4),
        ).buffer.asFloat32List(),
      );
      at += n * 4;
    }
    return out;
  }

  @override
  void close() {}
}
