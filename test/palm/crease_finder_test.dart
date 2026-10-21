import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/crease_finder.dart';
import 'package:kundlisaar/palm/palm_types.dart';

import 'support/hands.dart';

double _meanGap(FoundLine line, List<Pt> drawn) {
  // Mean distance from each traced point to the drawn polyline, in box units.
  double total = 0;
  for (final Pt p in line.box) {
    double best = 1e9;
    for (int i = 1; i < drawn.length; i++) {
      best = math.min(best, _seg(p, drawn[i - 1], drawn[i]));
    }
    total += best;
  }
  return total / line.box.length;
}

double _seg(Pt p, Pt a, Pt b) {
  final double dx = b.x - a.x, dy = b.y - a.y;
  final double t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy))
      .clamp(0.0, 1.0);
  return math.sqrt(math.pow(p.x - a.x - t * dx, 2) + math.pow(p.y - a.y - t * dy, 2));
}

void main() {
  group('finding the great lines', () {
    test('lines that are drawn are found, and where they were drawn', () {
      final SyntheticPalm palm = syntheticPalm();
      final CreaseResult r = findCreases(
        palm.frame,
        palm.landmarks,
        thumbOnLeft: true,
      );
      expect(r.usable, isTrue);
      expect(r.lines.keys, containsAll(FoundLineKind.values));
      for (final FoundLineKind k in FoundLineKind.values) {
        expect(
          _meanGap(r.lines[k]!, drawnLines[k]!),
          lessThan(0.04),
          reason: '$k should sit on the line that was drawn',
        );
        expect(r.lines[k]!.box, hasLength(7));
        expect(r.lines[k]!.image, hasLength(7));
      }
    });

    test('a palm with no lines on it gets none: nothing is invented', () {
      final SyntheticPalm palm = syntheticPalm(lines: <FoundLineKind>{});
      final CreaseResult r = findCreases(
        palm.frame,
        palm.landmarks,
        thumbOnLeft: true,
      );
      expect(r.lines, isEmpty);
      expect(r.usable, isFalse, reason: 'a smooth palm has no detail to search');
    });

    test('only the lines that are there are found', () {
      final SyntheticPalm palm = syntheticPalm(
        lines: <FoundLineKind>{FoundLineKind.life, FoundLineKind.heart},
      );
      final CreaseResult r = findCreases(
        palm.frame,
        palm.landmarks,
        thumbOnLeft: true,
      );
      expect(r.lines.keys, containsAll(<FoundLineKind>[FoundLineKind.life, FoundLineKind.heart]));
      expect(r.lines.containsKey(FoundLineKind.head), isFalse);
    });

    test('a dark skin with faint creases still gives its lines', () {
      final SyntheticPalm palm = syntheticPalm(
        skin: <int>[96, 62, 46],
        creaseDepth: 0.20,
      );
      final CreaseResult r = findCreases(
        palm.frame,
        palm.landmarks,
        thumbOnLeft: true,
      );
      expect(r.lines.length, greaterThanOrEqualTo(2));
    });

    test('a pale skin gives its lines too', () {
      final SyntheticPalm palm = syntheticPalm(
        skin: <int>[246, 214, 196],
        creaseDepth: 0.20,
      );
      final CreaseResult r = findCreases(
        palm.frame,
        palm.landmarks,
        thumbOnLeft: true,
      );
      expect(r.lines.length, greaterThanOrEqualTo(2));
    });

    test('creases fainter than the grain of the picture are not found', () {
      final SyntheticPalm palm = syntheticPalm(creaseDepth: 0.012, grain: 0.04);
      final CreaseResult r = findCreases(
        palm.frame,
        palm.landmarks,
        thumbOnLeft: true,
      );
      expect(r.lines, isEmpty);
    });

    test('a right palm is turned into the same box as a left one', () {
      final SyntheticPalm left = syntheticPalm();
      final SyntheticPalm right = syntheticPalm(thumbLeft: false);
      final CreaseResult a = findCreases(left.frame, left.landmarks, thumbOnLeft: true);
      final CreaseResult b = findCreases(right.frame, right.landmarks, thumbOnLeft: false);
      expect(b.lines.keys, containsAll(a.lines.keys));
      for (final FoundLineKind k in a.lines.keys) {
        expect(_meanGap(b.lines[k]!, a.lines[k]!.box), lessThan(0.03));
      }
    });

    test('a picture too small to show creases is declined, not guessed at', () {
      final SyntheticPalm palm = syntheticPalm();
      // The same hand, as if photographed from three times as far: the palm
      // box is a hundred and some pixels wide.
      final List<Pt> far = <Pt>[
        for (final Pt p in palm.landmarks) Pt(450 + (p.x - 450) / 4, 550 + (p.y - 550) / 4),
      ];
      final CreaseResult r = findCreases(palm.frame, far, thumbOnLeft: true);
      expect(r.usable, isFalse);
      expect(r.lines, isEmpty);
    });
  });
}
