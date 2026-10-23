import 'guidance.dart';

/// Where the automatic capture has got to.
enum CapturePhase {
  /// Looking for a hand, or telling the person what to fix.
  aiming,

  /// The hand is well placed; waiting a beat to see that it stays so.
  steadying,

  /// The visible count: 3, 2, 1.
  counting,

  /// The count reached zero; the picture is being taken.
  captured,
}

class CaptureStatus {
  const CaptureStatus({
    required this.phase,
    required this.guidance,
    this.digit,
    this.progress = 0,
  });

  final CapturePhase phase;
  final Guidance guidance;

  /// 3, 2 or 1 while counting.
  final int? digit;

  /// How far through the steadying beat, 0 to 1, for the ring around the guide.
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is CaptureStatus &&
      other.phase == phase &&
      other.guidance == guidance &&
      other.digit == digit &&
      (other.progress - progress).abs() < 0.02;

  @override
  int get hashCode => Object.hash(phase, guidance, digit);
}

/// Decides when to take the picture, and never before the person can see it
/// coming.
///
/// The hand has to be well placed and steady for [steadyMs]. Then a count of
/// [steps] runs, one every [stepMs], so the shot is a thing the person watches
/// arrive and not something that went off. If the hand goes wrong during the
/// count the count is dropped, but only once it has stayed wrong for
/// [graceMs]: a single missed look should not undo a good hand.
///
/// All times are milliseconds on one clock the caller keeps, passed in, so a
/// test can run it without waiting.
class CaptureFlow {
  CaptureFlow({
    this.steadyMs = 400,
    this.steps = 3,
    this.stepMs = 550,
    // A hand held out wobbles; the count now survives most of a second of
    // looks that miss, which is what kept it from ever reaching one.
    this.graceMs = 900,
  });

  final int steadyMs;
  final int steps;
  final int stepMs;
  final int graceMs;

  CapturePhase _phase = CapturePhase.aiming;
  Guidance _guidance = Guidance.noHand;
  int? _readySince;
  int? _lastReady;
  int? _countStart;

  CapturePhase get phase => _phase;

  /// Feed this each time the hand has been looked at.
  void observe(Guidance guidance, int nowMs) {
    _guidance = guidance;
    if (_phase == CapturePhase.captured) return;
    if (guidance == Guidance.ready) {
      _readySince ??= nowMs;
      _lastReady = nowMs;
      if (_phase == CapturePhase.aiming) _phase = CapturePhase.steadying;
    }
    _advance(nowMs);
  }

  /// Feed this on every frame, so the digits change on time even when no new
  /// look has arrived.
  CaptureStatus tick(int nowMs) {
    _advance(nowMs);
    return status(nowMs);
  }

  void _advance(int nowMs) {
    if (_phase == CapturePhase.captured) return;
    final int? lastReady = _lastReady;
    if (_phase != CapturePhase.aiming &&
        (lastReady == null || nowMs - lastReady > graceMs)) {
      _drop();
      return;
    }
    if (_phase == CapturePhase.steadying &&
        _readySince != null &&
        nowMs - _readySince! >= steadyMs) {
      _phase = CapturePhase.counting;
      _countStart = nowMs;
    }
    if (_phase == CapturePhase.counting &&
        nowMs - _countStart! >= steps * stepMs) {
      _phase = CapturePhase.captured;
    }
  }

  void _drop() {
    _phase = CapturePhase.aiming;
    _readySince = null;
    _lastReady = null;
    _countStart = null;
  }

  CaptureStatus status(int nowMs) {
    switch (_phase) {
      case CapturePhase.aiming:
        return CaptureStatus(phase: _phase, guidance: _guidance);
      case CapturePhase.steadying:
        final double p = _readySince == null
            ? 0
            : ((nowMs - _readySince!) / steadyMs).clamp(0.0, 1.0);
        return CaptureStatus(
          phase: _phase,
          guidance: Guidance.ready,
          progress: p,
        );
      case CapturePhase.counting:
        final int elapsed = nowMs - _countStart!;
        final int digit = steps - (elapsed ~/ stepMs);
        return CaptureStatus(
          phase: _phase,
          guidance: Guidance.ready,
          digit: digit.clamp(1, steps),
          progress: 1,
        );
      case CapturePhase.captured:
        return CaptureStatus(
          phase: _phase,
          guidance: Guidance.ready,
          progress: 1,
        );
    }
  }

  /// Start again, for a retake.
  void reset() {
    _drop();
    _guidance = Guidance.noHand;
    _phase = CapturePhase.aiming;
  }
}
