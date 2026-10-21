import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/jyotish/hastrekha.dart';
import 'package:kundlisaar/palm/crease_finder.dart';
import 'package:kundlisaar/palm/palm_geometry.dart';
import 'package:kundlisaar/palm/palm_scan.dart';
import 'package:kundlisaar/palm/palm_types.dart';

import 'support/hands.dart';

final RegExp _devanagari = RegExp(r'[ऀ-ॿ]');

FoundLine _line(FoundLineKind kind) => FoundLine(
  kind: kind,
  box: <Pt>[for (final Pt p in drawnLines[kind]!) p],
  image: <Pt>[for (final Pt p in drawnLines[kind]!) p],
  cover: 0.9,
);

CreaseResult _creases(Iterable<FoundLineKind> kinds, {bool usable = true}) =>
    CreaseResult(
      lines: <FoundLineKind, FoundLine>{for (final FoundLineKind k in kinds) k: _line(k)},
      tried: const <FoundLineKind, double>{},
      pixelsPerBoxWidth: 400,
      usable: usable,
    );

String _allText(PalmScan scan) => <String>[
  for (final Say s in scan.measured) ...<String>[s.english, s.hindi],
  for (final Say s in scan.caveats) ...<String>[s.english, s.hindi],
  if (scan.reading != null) ...<String>[
    scan.reading!.summary,
    scan.reading!.summaryHindi,
    for (final LineReading l in scan.reading!.lines) ...<String>[
      l.measured,
      l.measuredHindi,
      l.reading,
      l.readingHindi,
    ],
    for (final MountReading m in scan.reading!.mounts) ...<String>[
      m.reading,
      m.readingHindi,
    ],
  ],
].join('\n');

void main() {
  group('the hand type, from the shape of the hand in the photograph', () {
    // Raw knuckle span over palm length: square above about 0.66. Fingers: long
    // from 0.95.
    final Map<HandType, (double, double)> shapes = <HandType, (double, double)>{
      HandType.earth: (0.78, 0.80),
      HandType.air: (0.78, 1.05),
      HandType.water: (0.52, 1.05),
      HandType.fire: (0.52, 0.80),
    };
    for (final MapEntry<HandType, (double, double)> e in shapes.entries) {
      test('${e.key.name}: a ${e.value.$1} palm with ${e.value.$2} fingers', () {
        final PalmScan scan = buildScan(
          hand: syntheticHand(widthRatio: e.value.$1, fingerRatio: e.value.$2),
          creases: _creases(const <FoundLineKind>[]),
        );
        expect(scan.handType, e.key);
        expect(scan.reading!.summary, handTypeText[e.key]![0]);
      });
    }

    test('the same hand is the same type however it is held or how big it looks', () {
      final HandType upright = buildScan(
        hand: syntheticHand(widthRatio: 0.78, fingerRatio: 1.05),
      ).handType;
      for (final double angle in <double>[20, 45, 90, 180]) {
        for (final double length in <double>[450, 700]) {
          final PalmScan s = buildScan(
            hand: syntheticHand(
              widthRatio: 0.78,
              fingerRatio: 1.05,
              rotationDegrees: angle,
              handLength: length,
            ),
          );
          expect(s.handType, upright, reason: '$angle degrees, $length px');
        }
      }
    });

    test('a hand near a dividing line is said to be near it', () {
      final PalmScan near = buildScan(
        hand: syntheticHand(widthRatio: squareFromRaw + 0.01),
      );
      expect(near.borderline, isTrue);
      expect(
        near.caveats.map((Say s) => s.english).join(' '),
        contains('dividing line'),
      );
      final PalmScan clear = buildScan(
        hand: syntheticHand(widthRatio: 0.50, fingerRatio: 0.80),
      );
      expect(clear.borderline, isFalse);
    });

    test('the numbers shown are the ones measured and the cut-offs are the ones used', () {
      final PalmScan scan = buildScan(
        hand: syntheticHand(widthRatio: 0.60, fingerRatio: 0.80),
      );
      final String text = scan.measured.map((Say s) => s.english).join(' ');
      expect(text, contains('0.60'));
      expect(text, contains('0.80'));
      expect(text, contains(squareFromRaw.toStringAsFixed(2)));
      expect(text, contains('0.95'));
      // The engine is given the scaled span, and its own 0.82 rule then holds.
      expect(squareFromRaw * palmWidthScale, closeTo(0.82, 1e-9));
    });
  });

  group('which hand, and what is not read', () {
    test('no hand: nothing is read', () {
      final PalmScan s = buildScan(hand: null);
      expect(s.outcome, ScanOutcome.noHand);
      expect(s.reading, isNull);
    });

    test('the back of a hand is not read', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(thumbLeft: true, rightProbability: 0.95),
        creases: _creases(FoundLineKind.values),
      );
      expect(s.outcome, ScanOutcome.backOfHand);
      expect(s.reading, isNull);
      expect(s.found, isEmpty);
    });

    test('a hand cut off by the edge of the picture is not measured', () {
      final PalmScan s = buildScan(hand: syntheticHand(centreX: 100));
      expect(s.outcome, ScanOutcome.cutOff);
      expect(s.reading, isNull);
    });

    test('the hand that was read is named', () {
      expect(buildScan(hand: syntheticHand()).side, HandSide.left);
      expect(buildScan(hand: syntheticHand(thumbLeft: false)).side, HandSide.right);
      expect(buildScan(hand: syntheticHand()).sideSaid.english, 'Left hand');
      expect(
        buildScan(hand: syntheticHand(thumbLeft: false)).sideSaid.hindi,
        'दायाँ हाथ',
      );
    });

    test('a palm too small in the picture is still measured, and is said to be', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(handLength: 260),
        creases: CreaseResult(
          lines: const <FoundLineKind, FoundLine>{},
          tried: const <FoundLineKind, double>{},
          pixelsPerBoxWidth: 80,
          usable: false,
        ),
      );
      expect(s.outcome, ScanOutcome.shapeOnly);
      expect(
        s.caveats.map((Say c) => c.english).join(' '),
        contains('too little fine detail'),
      );
    });
  });

  group('the lines', () {
    test('lines that were clear are read, with the engine, and no others', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(),
        creases: _creases(<FoundLineKind>[FoundLineKind.life, FoundLineKind.heart]),
      );
      expect(s.outcome, ScanOutcome.read);
      expect(
        s.reading!.lines.map((LineReading l) => l.line).toSet(),
        <PalmLine>{PalmLine.life, PalmLine.heart},
      );
      expect(s.notMadeOut, <PalmLine>[PalmLine.head]);
    });

    test('a line that was not clear is said to be unclear, and nothing is said of it', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(),
        creases: _creases(<FoundLineKind>[FoundLineKind.life]),
      );
      expect(s.notMadeOut, containsAll(<PalmLine>[PalmLine.head, PalmLine.heart]));
      final String caveats = s.caveats.map((Say c) => c.english).join('\n');
      expect(caveats, contains('head line was not clear enough'));
      expect(caveats, contains('heart line was not clear enough'));
      expect(
        s.reading!.lines.where((LineReading l) => l.line == PalmLine.head),
        isEmpty,
      );
    });

    test('with no line clear, only the hand shape is read, and it says so', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(),
        creases: _creases(const <FoundLineKind>[]),
      );
      expect(s.outcome, ScanOutcome.shapeOnly);
      expect(s.reading!.lines, isEmpty);
      expect(s.notMadeOut, hasLength(3));
    });

    test('the fate and sun lines, marks and mounts are never read from a photograph', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(),
        creases: _creases(FoundLineKind.values),
      );
      final Set<PalmLine> read = s.reading!.lines.map((LineReading l) => l.line).toSet();
      expect(read, isNot(contains(PalmLine.fate)));
      expect(read, isNot(contains(PalmLine.sun)));
      expect(read, isNot(contains(PalmLine.marriage)));
      expect(s.reading!.mounts, isEmpty);
      final String said = s.caveats.map((Say c) => c.english).join(' ');
      expect(said, contains('fate and sun lines'));
      expect(said, contains('how raised each mount is'));
    });

    test('a palm that could not be told from a back needs two lines to be believed', () {
      final HandObservation unsure = syntheticHand(rightProbability: 0.55);
      expect(HandGeometry.of(unsure).facing, Facing.unclear);
      final PalmScan one = buildScan(
        hand: unsure,
        creases: _creases(<FoundLineKind>[FoundLineKind.life]),
      );
      expect(one.found, isEmpty);
      expect(one.outcome, ScanOutcome.shapeOnly);
      final PalmScan two = buildScan(
        hand: unsure,
        creases: _creases(<FoundLineKind>[FoundLineKind.life, FoundLineKind.head]),
      );
      expect(two.found, hasLength(2));
      expect(
        two.caveats.map((Say c) => c.english).join(' '),
        contains('could not be sure which side'),
      );
    });

    test('the lines reach the engine in the order and shape it reads', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(),
        creases: _creases(FoundLineKind.values),
      );
      final LineReading life = s.reading!.lines.firstWhere(
        (LineReading l) => l.line == PalmLine.life,
      );
      // Measured by the engine from the traced points, in its own words.
      expect(life.measured, contains('Length'));
      expect(life.measuredHindi, contains('लंबाई'));
    });
  });

  group('the words', () {
    test('everything said is in both languages, and the Hindi is Hindi', () {
      final PalmScan s = buildScan(
        hand: syntheticHand(widthRatio: squareFromRaw + 0.01),
        creases: _creases(<FoundLineKind>[FoundLineKind.life]),
      );
      for (final Say say in <Say>[...s.measured, ...s.caveats, s.sideSaid]) {
        expect(say.english.trim(), isNotEmpty);
        expect(say.hindi.trim(), isNotEmpty);
        expect(_devanagari.hasMatch(say.hindi), isTrue, reason: say.english);
        expect(say.of(true), say.hindi);
        expect(say.of(false), say.english);
      }
    });

    test('nothing predicts death, illness, pregnancy, exams, courts or investments', () {
      final RegExp forbidden = RegExp(
        r'will (die|fall ill)|death|dying|illness|disease|cancer|pregnan|child ?birth|exam result|pass the exam|court|lawsuit|invest|stock|profit|lottery',
        caseSensitive: false,
      );
      for (final HandType type in HandType.values) {
        final (double, double) shape = switch (type) {
          HandType.earth => (0.78, 0.8),
          HandType.air => (0.78, 1.05),
          HandType.water => (0.52, 1.05),
          HandType.fire => (0.52, 0.8),
        };
        final PalmScan s = buildScan(
          hand: syntheticHand(widthRatio: shape.$1, fingerRatio: shape.$2),
          creases: _creases(FoundLineKind.values),
        );
        // The caveats name these subjects only to say they are never read, so
        // the check is on what is measured and on the reading itself.
        final String claims = <String>[
          for (final Say say in s.measured) ...<String>[say.english, say.hindi],
          s.reading!.summary,
          for (final LineReading l in s.reading!.lines) ...<String>[l.reading, l.readingHindi],
        ].join('\n');
        expect(forbidden.hasMatch(claims), isFalse, reason: '${type.name}: $claims');
      }
      final String all = _allText(
        buildScan(hand: syntheticHand(), creases: _creases(FoundLineKind.values)),
      );
      // Where they are named, it is to disclaim them.
      expect(all, isNot(contains('will die')));
    });
  });
}
