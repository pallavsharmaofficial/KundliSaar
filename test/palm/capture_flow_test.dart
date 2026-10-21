import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/capture_flow.dart';
import 'package:kundlisaar/palm/guidance.dart';

/// Looks arrive about every 120 ms. This plays a run of them against a clock
/// that only moves when told.
void main() {
  CaptureFlow flow() => CaptureFlow();

  group('the automatic capture', () {
    test('nothing happens while the hand is wrong', () {
      final CaptureFlow f = flow();
      for (int t = 0; t < 3000; t += 120) {
        f.observe(Guidance.tooFar, t);
        expect(f.tick(t).phase, CapturePhase.aiming);
      }
    });

    test('a well placed hand is first watched, then counted down, then taken', () {
      final CaptureFlow f = flow();
      final List<String> seen = <String>[];
      for (int t = 0; t <= 3200; t += 40) {
        if (t % 120 == 0) f.observe(Guidance.ready, t);
        final CaptureStatus s = f.tick(t);
        final String mark = s.phase == CapturePhase.counting
            ? 'count${s.digit}'
            : s.phase.name;
        if (seen.isEmpty || seen.last != mark) seen.add(mark);
      }
      expect(seen, <String>[
        'steadying',
        'count3',
        'count2',
        'count1',
        'captured',
      ]);
    });

    test('the count is visible for a few seconds, never a flash', () {
      final CaptureFlow f = flow();
      int? countStart;
      int? taken;
      for (int t = 0; t <= 6000; t += 20) {
        if (t % 120 == 0) f.observe(Guidance.ready, t);
        final CaptureStatus s = f.tick(t);
        if (s.phase == CapturePhase.counting) countStart ??= t;
        if (s.phase == CapturePhase.captured) {
          taken ??= t;
        }
      }
      expect(countStart, isNotNull);
      expect(taken, isNotNull);
      // The hand is watched for half a second, then three digits of 650 ms.
      expect(countStart, inInclusiveRange(480, 640));
      expect(taken! - countStart!, inInclusiveRange(1900, 2050));
      expect(taken, greaterThan(2400));
    });

    test('the steadying ring fills', () {
      final CaptureFlow f = flow();
      f.observe(Guidance.ready, 0);
      final double early = f.tick(100).progress;
      f.observe(Guidance.ready, 360);
      final double late = f.tick(400).progress;
      expect(early, lessThan(late));
      expect(late, lessThanOrEqualTo(1));
    });

    test('a hand that goes wrong during the count stops it', () {
      final CaptureFlow f = flow();
      int t = 0;
      for (; t <= 1200; t += 40) {
        if (t % 120 == 0) f.observe(Guidance.ready, t);
        f.tick(t);
      }
      expect(f.phase, CapturePhase.counting);
      // The hand moves and stays moved.
      for (; t <= 2000; t += 40) {
        if (t % 120 == 0) f.observe(Guidance.holdSteady, t);
        f.tick(t);
      }
      expect(f.phase, CapturePhase.aiming);
      expect(f.tick(t).guidance, Guidance.holdSteady);
    });

    test('one missed look does not undo a good hand', () {
      final CaptureFlow f = flow();
      int t = 0;
      for (; t <= 1000; t += 40) {
        if (t % 120 == 0) f.observe(Guidance.ready, t);
        f.tick(t);
      }
      expect(f.phase, CapturePhase.counting);
      f.observe(Guidance.holdSteady, t);
      t += 120;
      f.observe(Guidance.ready, t);
      expect(f.tick(t).phase, CapturePhase.counting);
    });

    test('after a dropped count the next one starts from the top', () {
      final CaptureFlow f = flow();
      int t = 0;
      for (; t <= 1300; t += 40) {
        if (t % 120 == 0) f.observe(Guidance.ready, t);
        f.tick(t);
      }
      for (int i = 0; i < 20; i++, t += 120) {
        f.observe(Guidance.noHand, t);
        f.tick(t);
      }
      expect(f.phase, CapturePhase.aiming);
      f.observe(Guidance.ready, t);
      expect(f.tick(t).phase, CapturePhase.steadying);
      for (int i = 0; i < 6; i++) {
        t += 100;
        f.observe(Guidance.ready, t);
        f.tick(t);
      }
      expect(f.tick(t).digit, 3);
    });

    test('once taken, it stays taken until reset', () {
      final CaptureFlow f = flow();
      for (int t = 0; t <= 4000; t += 40) {
        if (t % 120 == 0) f.observe(Guidance.ready, t);
        f.tick(t);
      }
      expect(f.phase, CapturePhase.captured);
      f.observe(Guidance.noHand, 5000);
      expect(f.tick(6000).phase, CapturePhase.captured);
      f.reset();
      expect(f.phase, CapturePhase.aiming);
    });
  });
}
