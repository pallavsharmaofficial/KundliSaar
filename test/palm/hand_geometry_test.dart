import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/palm_geometry.dart';
import 'package:kundlisaar/palm/palm_types.dart';

import 'support/hands.dart';

void main() {
  group('measuring a hand from its 21 points', () {
    test('the two proportions come out as they were built', () {
      final HandGeometry g = HandGeometry.of(
        syntheticHand(widthRatio: 0.60, fingerRatio: 0.80),
      );
      expect(g.widthRatio, closeTo(0.60, 0.01));
      expect(g.fingerRatio, closeTo(0.80, 0.01));
    });

    test(
      'turning the hand in the picture does not change what is measured',
      () {
        final HandGeometry upright = HandGeometry.of(syntheticHand());
        for (final double angle in <double>[25, 40, 90, 135, 180, 270]) {
          final HandGeometry g = HandGeometry.of(
            syntheticHand(rotationDegrees: angle, handLength: 560),
          );
          expect(
            g.widthRatio,
            closeTo(upright.widthRatio, 0.01),
            reason: '$angle',
          );
          expect(
            g.fingerRatio,
            closeTo(upright.fingerRatio, 0.01),
            reason: '$angle',
          );
          expect(
            g.minExtension,
            closeTo(upright.minExtension, 0.01),
            reason: '$angle',
          );
          expect(g.facing, upright.facing, reason: '$angle');
          expect(g.palmSide, upright.palmSide, reason: '$angle');
        }
      },
    );

    test('the angle of the hand in the picture is reported', () {
      expect(HandGeometry.of(syntheticHand()).angleDegrees.abs(), lessThan(5));
      expect(
        HandGeometry.of(syntheticHand(rotationDegrees: 30)).angleDegrees,
        closeTo(30, 5),
      );
    });

    test(
      'size changes how much of the frame the hand fills, not its shape',
      () {
        final HandGeometry small = HandGeometry.of(
          syntheticHand(handLength: 300),
        );
        final HandGeometry large = HandGeometry.of(
          syntheticHand(handLength: 1000),
        );
        expect(small.fill, lessThan(0.4));
        expect(large.fill, greaterThan(0.75));
        expect(small.widthRatio, closeTo(large.widthRatio, 0.01));
        expect(small.fingerRatio, closeTo(large.fingerRatio, 0.01));
      },
    );

    test('a hand going past the edge of the frame is seen to be cut off', () {
      expect(HandGeometry.of(syntheticHand()).partlyOutside, isFalse);
      expect(
        HandGeometry.of(syntheticHand(centreX: 120)).partlyOutside,
        isTrue,
      );
      expect(
        HandGeometry.of(syntheticHand(centreY: 1180)).partlyOutside,
        isTrue,
      );
      expect(
        HandGeometry.of(syntheticHand(handLength: 1400)).partlyOutside,
        isTrue,
      );
    });

    test('curled fingers are told from open ones', () {
      expect(HandGeometry.of(syntheticHand()).minExtension, greaterThan(1.5));
      expect(
        HandGeometry.of(syntheticHand(curl: 0.8)).minExtension,
        lessThan(1.35),
      );
    });
  });

  group('which hand, and which side of it', () {
    test('a left palm has its thumb on the left and the network says left', () {
      final HandGeometry g = HandGeometry.of(syntheticHand());
      expect(g.thumbOnLeft, isTrue);
      expect(g.facing, Facing.palm);
      expect(g.palmSide, HandSide.left);
    });

    test(
      'a right palm has its thumb on the right and the network says right',
      () {
        final HandGeometry g = HandGeometry.of(syntheticHand(thumbLeft: false));
        expect(g.thumbOnLeft, isFalse);
        expect(g.facing, Facing.palm);
        expect(g.palmSide, HandSide.right);
      },
    );

    test(
      'the back of a right hand has the outline of a left palm and is told apart',
      () {
        // Thumb on the left, but the network says right: a right hand seen from
        // behind. The outline alone cannot tell it from a left palm.
        final HandGeometry g = HandGeometry.of(
          syntheticHand(thumbLeft: true, rightProbability: 0.93),
        );
        expect(g.facing, Facing.back);
      },
    );

    test('the back of a left hand likewise', () {
      final HandGeometry g = HandGeometry.of(
        syntheticHand(thumbLeft: false, rightProbability: 0.07),
      );
      expect(g.facing, Facing.back);
    });

    test('a network that cannot tell leaves it unclear, not decided', () {
      final HandGeometry g = HandGeometry.of(
        syntheticHand(rightProbability: 0.5),
      );
      expect(g.facing, Facing.unclear);
      expect(
        HandGeometry.of(syntheticHand(rightProbability: 0.7)).facing,
        Facing.unclear,
      );
    });
  });
}
