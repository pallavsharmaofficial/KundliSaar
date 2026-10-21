import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:kundlisaar/palm/camera_source.dart';
import 'package:kundlisaar/palm/crease_finder.dart';
import 'package:kundlisaar/palm/hand_tracker.dart';
import 'package:kundlisaar/palm/palm_types.dart';

import 'hands.dart';

/// A camera that plays a script instead of looking at anything.
class FakeCamera implements CameraSource {
  FakeCamera({this.failWith});

  final CameraUnavailable? failWith;
  final StreamController<CameraFrame> _controller =
      StreamController<CameraFrame>.broadcast();
  bool opened = false;
  bool closed = false;

  static CameraFrame frame() => CameraFrame(
    format: FrameFormat.yuv420,
    width: 4,
    height: 2,
    rotationDegrees: 90,
    planes: <FramePlane>[
      FramePlane(Uint8List(8), 4, 1),
      FramePlane(Uint8List(2), 2, 1),
      FramePlane(Uint8List(2), 2, 1),
    ],
  );

  /// One frame arrives, as one would from the lens.
  void push() => _controller.add(frame());

  @override
  Future<void> open() async {
    if (failWith != null) throw failWith!;
    opened = true;
  }

  @override
  Stream<CameraFrame> get frames => _controller.stream;

  @override
  double get previewAspectRatio => 0.5625;

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF222222));

  @override
  Future<void> pause() async {}

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

/// A tracker that answers from a list, one look at a time, and repeats the last.
class ScriptedTracker implements HandTracker {
  ScriptedTracker({
    required this.looks,
    this.scanHand,
    this.scanCreases,
    this.failToStart = false,
  });

  final List<HandObservation?> looks;
  final HandObservation? scanHand;
  final CreaseResult? scanCreases;
  final bool failToStart;
  int _i = 0;

  /// Start the script again from its first look.
  void rewind() => _i = 0;

  void say(Iterable<HandObservation?> next) {
    looks
      ..clear()
      ..addAll(next);
    _i = 0;
  }

  int tracked = 0;
  int scans = 0;
  double frameBrightness = 0.5;

  @override
  Future<void> start() async {
    if (failToStart) throw StateError('no models');
  }

  @override
  Future<TrackResult?> track(CameraFrame frame, int timeMs) async {
    tracked++;
    final HandObservation? h = looks.isEmpty
        ? null
        : looks[_i < looks.length ? _i : looks.length - 1];
    _i++;
    return TrackResult(
      hand: h == null
          ? null
          : HandObservation(
              points: h.points,
              depth: h.depth,
              presence: h.presence,
              rightProbability: h.rightProbability,
              frameWidth: h.frameWidth,
              frameHeight: h.frameHeight,
              look: h.look,
              timeMs: timeMs,
            ),
      frameBrightness: frameBrightness,
      timeMs: timeMs,
    );
  }

  @override
  Future<StillScan> scan(CameraFrame frame, int timeMs) async {
    scans++;
    return StillScan(
      hand: scanHand,
      creases: scanCreases,
      previewRgba: Uint8List(8 * 6 * 4)..fillRange(0, 8 * 6 * 4, 200),
      previewWidth: 8,
      previewHeight: 6,
      previewScale: 0.01,
    );
  }

  @override
  Future<void> dispose() async {}
}

CreaseResult someLines(Iterable<FoundLineKind> kinds) => CreaseResult(
  lines: <FoundLineKind, FoundLine>{
    for (final FoundLineKind k in kinds)
      k: FoundLine(
        kind: k,
        box: drawnLines[k]!,
        image: <Pt>[for (final Pt p in drawnLines[k]!) Pt(p.x * 700, p.y * 900)],
        cover: 0.9,
      ),
  },
  tried: const <FoundLineKind, double>{},
  pixelsPerBoxWidth: 400,
  usable: true,
);
