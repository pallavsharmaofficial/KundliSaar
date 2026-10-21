import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/guidance.dart';
import 'package:kundlisaar/palm/palm_types.dart';

import 'support/hands.dart';

final RegExp _devanagari = RegExp(r'[ऀ-ॿ]');

void main() {
  group('what the person is told', () {
    test('no hand in the picture', () {
      expect(assess(null), Guidance.noHand);
      expect(assessNothing(0.5), Guidance.noHand);
    });

    test('a dark picture with no hand is put down to the light', () {
      expect(assessNothing(0.05), Guidance.tooDark);
    });

    test('a dark palm is told so', () {
      final HandObservation h = syntheticHand(
        look: const FrameLook(palmBrightness: 0.10, sharpness: 0.1),
      );
      expect(assess(h), Guidance.tooDark);
    });

    test('a blown-out palm is told so', () {
      expect(
        assess(
          syntheticHand(
            look: const FrameLook(palmBrightness: 0.95, clipped: 0.5, sharpness: 0.1),
          ),
        ),
        Guidance.tooBright,
      );
    });

    test('a hand too far away: move closer', () {
      expect(assess(syntheticHand(handLength: 300)), Guidance.tooFar);
    });

    test('a hand too big for the frame: move back', () {
      expect(assess(syntheticHand(handLength: 1500)), Guidance.tooClose);
    });

    test('a hand off to one side but not too big: bring it into the frame', () {
      expect(assess(syntheticHand(centreX: 100)), Guidance.partlyOut);
    });

    test('the back of the hand: show the palm', () {
      expect(
        assess(syntheticHand(thumbLeft: true, rightProbability: 0.95)),
        Guidance.showPalm,
      );
    });

    test('curled fingers: open them', () {
      expect(assess(syntheticHand(curl: 0.9)), Guidance.openFingers);
    });

    test('a hand that is moving: hold it steady', () {
      expect(assess(syntheticHand(), steady: false), Guidance.holdSteady);
    });

    test('a hand that is steady but out of focus: let it focus', () {
      expect(
        assess(
          syntheticHand(look: const FrameLook(palmBrightness: 0.5, sharpness: 0.01)),
        ),
        Guidance.blurry,
      );
    });

    test('a hand well placed and still is ready', () {
      expect(assess(syntheticHand()), Guidance.ready);
    });

    test('a turned hand is as welcome as an upright one', () {
      expect(
        assess(syntheticHand(rotationDegrees: 25, handLength: 700)),
        Guidance.ready,
      );
    });

    test('the most important thing is said first', () {
      // Too dark, too far and curled all at once: the light comes first.
      expect(
        assess(
          syntheticHand(
            handLength: 300,
            curl: 0.9,
            look: const FrameLook(palmBrightness: 0.1, sharpness: 0.1),
          ),
        ),
        Guidance.tooDark,
      );
      // Then the side of the hand, then the distance, then the fingers.
      expect(
        assess(syntheticHand(handLength: 300, curl: 0.9)),
        Guidance.tooFar,
      );
    });
  });

  group('the words', () {
    test('every instruction exists in both languages', () {
      for (final Guidance g in Guidance.values) {
        final GuidanceText t = guidanceText[g]!;
        expect(t.english.trim(), isNotEmpty, reason: '$g');
        expect(t.hindi.trim(), isNotEmpty, reason: '$g');
        expect(_devanagari.hasMatch(t.hindi), isTrue, reason: '$g is in Hindi');
        expect(_devanagari.hasMatch(t.english), isFalse, reason: '$g');
        expect(t.of(false), t.english);
        expect(t.of(true), t.hindi);
      }
    });

    test('the instructions are short enough to read at a glance', () {
      for (final Guidance g in Guidance.values) {
        expect(guidanceText[g]!.english.length, lessThan(70), reason: '$g');
        expect(guidanceText[g]!.hindi.length, lessThan(70), reason: '$g');
      }
    });

    test('no instruction says anything beyond how to hold the hand', () {
      final RegExp forbidden = RegExp(
        r'death|die|illness|disease|pregnan|exam|court|invest|cancer|future|predict',
        caseSensitive: false,
      );
      for (final Guidance g in Guidance.values) {
        expect(forbidden.hasMatch(guidanceText[g]!.english), isFalse, reason: '$g');
      }
    });
  });

  group('holding still', () {
    test('a hand that barely moves over the window is steady', () {
      final SteadyTracker t = SteadyTracker();
      for (int i = 0; i < 6; i++) {
        t.add(syntheticHand(centreX: 360 + (i.isEven ? 2 : -2), timeMs: i * 120));
      }
      expect(t.steady, isTrue);
    });

    test('a hand drifting across the frame is not', () {
      final SteadyTracker t = SteadyTracker();
      for (int i = 0; i < 6; i++) {
        t.add(syntheticHand(centreX: 300 + i * 25, timeMs: i * 120));
      }
      expect(t.steady, isFalse);
    });

    test('a hand moving toward the camera is not', () {
      final SteadyTracker t = SteadyTracker();
      for (int i = 0; i < 6; i++) {
        t.add(syntheticHand(handLength: 600 + i * 40, timeMs: i * 120));
      }
      expect(t.steady, isFalse);
    });

    test('a couple of looks are not yet enough', () {
      final SteadyTracker t = SteadyTracker();
      t.add(syntheticHand(timeMs: 0));
      t.add(syntheticHand(timeMs: 120));
      expect(t.steady, isFalse);
    });

    test('clearing forgets', () {
      final SteadyTracker t = SteadyTracker();
      for (int i = 0; i < 6; i++) {
        t.add(syntheticHand(timeMs: i * 120));
      }
      expect(t.steady, isTrue);
      t.clear();
      expect(t.steady, isFalse);
    });
  });

  group('the message does not flicker', () {
    test('one odd look does not change what is shown', () {
      final GuidanceSmoother s = GuidanceSmoother();
      expect(s.push(Guidance.tooFar), Guidance.noHand);
      expect(s.push(Guidance.tooFar), Guidance.tooFar);
      expect(s.push(Guidance.tooClose), Guidance.tooFar);
      expect(s.push(Guidance.tooFar), Guidance.tooFar);
    });

    test('a change that persists is shown', () {
      final GuidanceSmoother s = GuidanceSmoother();
      s.push(Guidance.ready);
      s.push(Guidance.ready);
      expect(s.shown, Guidance.ready);
      s.push(Guidance.holdSteady);
      expect(s.shown, Guidance.ready);
      s.push(Guidance.holdSteady);
      expect(s.shown, Guidance.holdSteady);
    });
  });
}
