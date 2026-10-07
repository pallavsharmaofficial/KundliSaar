import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/ghat_chakra.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/sarvatobhadra.dart';
import 'package:kundlisaar/engine/jyotish/sudarshan.dart';
import 'package:kundlisaar/engine/jyotish/upagrahas.dart';
import 'package:kundlisaar/engine/jyotish/yogas.dart';

const GeoPlace delhi = GeoPlace(
  name: 'Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);

const List<GeoPlace> places = <GeoPlace>[
  delhi,
  GeoPlace(
    name: 'Chennai',
    latitude: 13.0827,
    longitude: 80.2707,
    timeZoneId: 'Asia/Kolkata',
  ),
  GeoPlace(
    name: 'London',
    latitude: 51.5074,
    longitude: -0.1278,
    timeZoneId: 'Europe/London',
  ),
  GeoPlace(
    name: 'Sydney',
    latitude: -33.8688,
    longitude: 151.2093,
    timeZoneId: 'Australia/Sydney',
  ),
  GeoPlace(
    name: 'New York',
    latitude: 40.7128,
    longitude: -74.0060,
    timeZoneId: 'America/New_York',
  ),
];

const List<Duration> offsets = <Duration>[
  Duration(hours: 5, minutes: 30),
  Duration(hours: 5, minutes: 30),
  Duration.zero,
  Duration(hours: 10),
  Duration(hours: -5),
];

Kundli real(DateTime local, {int place = 0}) => computeKundli(
  BirthData(
    name: 'Test',
    localDateTime: local,
    utcOffset: offsets[place],
    place: places[place],
  ),
);

List<Kundli> manyCharts(int n, {int seed = 3}) {
  final math.Random rnd = math.Random(seed);
  return <Kundli>[
    for (int i = 0; i < n; i++)
      real(
        DateTime(
          1935 + rnd.nextInt(85),
          1 + rnd.nextInt(12),
          1 + rnd.nextInt(28),
          rnd.nextInt(24),
          rnd.nextInt(60),
        ),
        place: rnd.nextInt(places.length),
      ),
  ];
}

// -----------------------------------------------------------------------------
// A chart built from chosen longitudes, so a yoga can be tested on exactly the
// placement that defines it.
// -----------------------------------------------------------------------------

Dignity dignityOf(Graha graha, double lon) {
  final GrahaInfo info = grahaInfo(graha);
  final int sign = (lon / 30).floor() % 12;
  final double degree = lon % 30;
  final double? exaltation = info.exaltationDegree;
  if (exaltation != null) {
    final int exaltSign = (exaltation / 30).floor();
    if (sign == exaltSign) return Dignity.exalted;
    if (sign == (exaltSign + 6) % 12) return Dignity.debilitated;
  }
  final List<double>? mt = info.moolatrikona;
  if (mt != null &&
      sign == mt[0].toInt() &&
      degree >= mt[1] &&
      degree < mt[2]) {
    return Dignity.moolatrikona;
  }
  final Graha lord = rashiInfo(Rashi.values[sign]).lord;
  if (lord == graha || info.ownSigns.contains(sign)) return Dignity.own;
  return switch (relationBetween(graha, lord)) {
    Relation.friend => Dignity.friend,
    Relation.neutral => Dignity.neutral,
    Relation.enemy => Dignity.enemy,
  };
}

/// Longitudes are given as "sign index + degrees": 0 is Mesha 0°.
Kundli synth(Map<Graha, double> lon, {double ascendant = 15}) {
  final Map<Graha, PlacedGraha> grahas = <Graha, PlacedGraha>{
    for (final Graha g in Graha.values)
      g: PlacedGraha(
        graha: g,
        siderealLongitude: lon[g]!,
        tropicalLongitude: norm360(lon[g]! + 24),
        latitude: 0,
        speed: 1,
        house: wholeSignHouse(lon[g]!, ascendant),
        dignity: dignityOf(g, lon[g]!),
        isCombust: false,
      ),
  };
  return Kundli(
    birth: BirthData(
      name: 'Synthetic',
      localDateTime: DateTime(2000, 1, 1, 12),
      utcOffset: Duration.zero,
      place: delhi,
    ),
    instant: Instant.fromUtc(DateTime.utc(2000, 1, 1, 12)),
    ayanamsa: Ayanamsa.lahiri,
    ayanamsaValue: 24,
    ascendant: ascendant,
    midheaven: 0,
    cusps: List<double>.filled(12, 0),
    grahas: grahas,
    vimshottari: const [],
  );
}

/// Places each graha at 10 degrees into the sign it is given. Lagna is Mesha,
/// so a graha in sign s stands in house s + 1.
Kundli bySigns({
  int sun = 0,
  int moon = 0,
  int mars = 0,
  int mercury = 0,
  int jupiter = 0,
  int venus = 0,
  int saturn = 0,
  int rahu = 4,
  int ketu = 10,
  double ascendant = 15,
}) => synth(<Graha, double>{
  Graha.sun: sun * 30 + 10,
  Graha.moon: moon * 30 + 10,
  Graha.mars: mars * 30 + 10,
  Graha.mercury: mercury * 30 + 10,
  Graha.jupiter: jupiter * 30 + 10,
  Graha.venus: venus * 30 + 10,
  Graha.saturn: saturn * 30 + 10,
  Graha.rahu: rahu * 30 + 10,
  Graha.ketu: ketu * 30 + 10,
}, ascendant: ascendant);

Set<String> keys(Kundli k) =>
    findYogas(k).map((YogaFinding f) => f.key).toSet();

YogaFinding find(Kundli k, String key) =>
    findYogas(k).firstWhere((YogaFinding f) => f.key == key);

// -----------------------------------------------------------------------------
// The statements that must never appear, in either language.
// -----------------------------------------------------------------------------

final RegExp banned = RegExp(
  r'\b(death|dies|die|dying|dead|illness|disease|sick|sickness|cancer|tumou?r|pregnan\w*|miscarriage|abortion|court|lawsuit|jail|prison\w*|invest\w*|lottery|gambl\w*|longevity|fatal|surgery|injur\w*|accident|exam|exams|examination|poverty)\b',
  caseSensitive: false,
);

final RegExp bannedHindi = RegExp(
  r'(मृत्यु|मौत|बीमारी|रोग|गर्भ|मुकदमा|कारावास|जेल|शेयर|सट्टा|निवेश|परीक्षा|कैंसर|दुर्घटना|आयु|ग़रीबी|गरीबी)',
);

List<String> statementsOf(YogaFinding f) => <String>[
  f.ruleEnglish,
  f.ruleHindi,
  f.meaningEnglish,
  f.meaningHindi,
  ?f.cancellationEnglish,
  ?f.cancellationHindi,
  ?f.mitigationEnglish,
  ?f.mitigationHindi,
  ?f.sourceEnglish,
  ?f.sourceHindi,
  ...f.factorsEnglish,
  ...f.factorsHindi,
];

void expectClean(String text, String where) {
  expect(banned.hasMatch(text), isFalse, reason: '$where: "$text"');
  expect(bannedHindi.hasMatch(text), isFalse, reason: '$where: "$text"');
}

void main() {
  group('ghat chakra', () {
    test('the table has twelve complete rows, one for each rashi', () {
      expect(ghatChakraTable.length, 12);
      for (int i = 0; i < 12; i++) {
        final GhatRow row = ghatChakraTable[i];
        expect(row.rashi, Rashi.values[i], reason: 'row $i is in rashi order');
        expect(row.monthEnglish, isNotEmpty);
        expect(row.monthHindi, isNotEmpty);
        expect(row.tithiGroup.english, isNotEmpty);
        expect(row.tithiGroup.hindi, isNotEmpty);
        expect(row.tithiGroup.tithis.length, 3);
        expect(row.weekdayEnglish, isNotEmpty);
        expect(row.weekdayHindi, isNotEmpty);
        expect(row.nakshatraIndex, inInclusiveRange(0, 26));
        expect(row.yogaEnglish, isNotEmpty);
        expect(row.yogaHindi, isNotEmpty);
        expect(row.karanaEnglish, isNotEmpty);
        expect(row.karanaHindi, isNotEmpty);
        expect(row.prahar, inInclusiveRange(1, 8));
        expect(row.chandra, isA<Rashi>());
      }
    });

    test(
      'Yama Ghantaka is Jupiter\'s part, which is the traditional Yamaganda kaal',
      () {
        // Yamaganda by weekday, Sunday first: the 5th, 4th, 3rd, 2nd, 1st, 7th
        // and 6th part of the day.
        const List<int> yamagandaPart = <int>[5, 4, 3, 2, 1, 7, 6];
        int checked = 0;
        for (final Kundli k in manyCharts(80, seed: 6)) {
          final UpagrahaResult r = computeUpagrahas(k);
          if (!r.isDayBirth) continue;
          checked++;
          expect(
            r.of(Upagraha.yamaghantaka).partNumber,
            yamagandaPart[r.weekday],
          );
        }
        expect(checked, greaterThan(10));
      },
    );

    test(
      'the printed columns agree with the sources they were checked against',
      () {
        GhatRow row(Rashi r) => ghatRowFor(r);
        // Mesha (Slideshare sample): Kartika, 1-6-11, Sunday, Magha,
        // Vishkambha, Bava, prahar 1, Moon in Mesha.
        expect(row(Rashi.mesha).monthEnglish, 'Kartika');
        expect(row(Rashi.mesha).tithiGroup.tithis, <int>[1, 6, 11]);
        expect(row(Rashi.mesha).weekdayEnglish, 'Sunday');
        expect(row(Rashi.mesha).nakshatra.english, 'Magha');
        expect(row(Rashi.mesha).yogaEnglish, 'Vishkambha');
        expect(row(Rashi.mesha).prahar, 1);
        // Karka (IndiaDivine sample): Pausha, 2-7-12, Wednesday, Anuradha,
        // Vyaghata, Naga.
        expect(row(Rashi.karka).monthEnglish, 'Pausha');
        expect(row(Rashi.karka).tithiGroup.tithis, <int>[2, 7, 12]);
        expect(row(Rashi.karka).weekdayEnglish, 'Wednesday');
        expect(row(Rashi.karka).nakshatra.english, 'Anuradha');
        expect(row(Rashi.karka).karanaEnglish, 'Naga');
        // Dhanu (astrologyapi.com sample): Shravana, 3-8-13, Friday, Bharani,
        // Vajra, Taitila, prahar 1.
        expect(row(Rashi.dhanu).monthEnglish, 'Shravana');
        expect(row(Rashi.dhanu).tithiGroup.tithis, <int>[3, 8, 13]);
        expect(row(Rashi.dhanu).weekdayEnglish, 'Friday');
        expect(row(Rashi.dhanu).nakshatra.english, 'Bharani');
        expect(row(Rashi.dhanu).yogaEnglish, 'Vajra');
        expect(row(Rashi.dhanu).karanaEnglish, 'Taitila');
        // Mithuna (Sanjay Rath's example): 2-7-12, Monday, Swati.
        expect(row(Rashi.mithuna).tithiGroup.tithis, <int>[2, 7, 12]);
        expect(row(Rashi.mithuna).weekdayEnglish, 'Monday');
        expect(row(Rashi.mithuna).nakshatra.english, 'Swati');
        // Makara: Rikta tithis (Rath), Rohini.
        expect(row(Rashi.makara).tithiGroup, TithiGroup.rikta);
        expect(row(Rashi.makara).nakshatra.english, 'Rohini');
        // Vrishabha: Saturday, Poorna, Hasta, Margashirsha, Sukarma, Shakuni, 4.
        expect(row(Rashi.vrishabha).weekdayEnglish, 'Saturday');
        expect(row(Rashi.vrishabha).tithiGroup, TithiGroup.poorna);
        expect(row(Rashi.vrishabha).nakshatra.english, 'Hasta');
        expect(row(Rashi.vrishabha).monthEnglish, 'Margashirsha');
        expect(row(Rashi.vrishabha).yogaEnglish, 'Sukarma');
        expect(row(Rashi.vrishabha).prahar, 4);
      },
    );

    test(
      'the ghat Moon follows the published sequence 1,5,9,2,6,10,3,7,4,8,11,12',
      () {
        expect(
          ghatChakraTable.map((GhatRow r) => r.chandra.index + 1).toList(),
          <int>[1, 5, 9, 2, 6, 10, 3, 7, 4, 8, 11, 12],
        );
      },
    );

    test(
      'every nakshatra and every month appears once, and tithi groups cover all fifteen tithis',
      () {
        expect(
          ghatChakraTable.map((GhatRow r) => r.nakshatraIndex).toSet().length,
          12,
        );
        expect(
          ghatChakraTable.map((GhatRow r) => r.monthIndex).toSet().length,
          12,
        );
        final Set<int> tithis = <int>{
          for (final TithiGroup g in TithiGroup.values) ...g.tithis,
        };
        expect(tithis, <int>{for (int i = 1; i <= 15; i++) i});
      },
    );

    test('a person is keyed on the janma rashi, in both languages', () {
      for (final Kundli k in manyCharts(12)) {
        final GhatChakraReading r = ghatChakraOf(k);
        expect(r.row.rashi, k.moonRashi);
        expect(r.statementEnglish, isNotEmpty);
        expect(r.statementHindi, isNotEmpty);
        expect(r.cautionEnglish, isNotEmpty);
        expect(r.cautionHindi, isNotEmpty);
        expect(r.factorsEnglish, isNotEmpty);
        expect(r.factorsHindi, isNotEmpty);
        for (final String s in <String>[
          r.statementEnglish,
          r.statementHindi,
          r.cautionEnglish,
          r.cautionHindi,
        ]) {
          expectClean(s, 'ghat chakra');
        }
      }
    });
  });

  group('sarvatobhadra chakra', () {
    final SbcGrid grid = sarvatobhadraGrid;

    test('the grid has exactly 81 cells', () {
      expect(grid.cells.length, 9);
      for (final List<SbcCell> row in grid.cells) {
        expect(row.length, 9);
      }
      expect(grid.all.length, 81);
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          expect(grid.at(r, c).row, r);
          expect(grid.at(r, c).col, c);
        }
      }
    });

    test('all 28 nakshatras are placed once, on the rim, seven to a side', () {
      final List<SbcCell> naks = grid.all
          .where((SbcCell c) => c.kind == SbcCellKind.nakshatra)
          .toList();
      expect(naks.length, 28);
      expect(naks.map((SbcCell c) => c.nakshatra28).toSet().length, 28);
      expect(naks.map((SbcCell c) => c.nakshatra28!).toList()..sort(), <int>[
        for (int i = 0; i < 28; i++) i,
      ]);
      for (final SbcCell c in naks) {
        expect(c.isRim, isTrue);
        expect(c.english, isNotEmpty);
        expect(c.hindi, isNotEmpty);
      }
      int side(bool Function(SbcCell) test) => naks.where(test).length;
      expect(side((SbcCell c) => c.row == 0), 7);
      expect(side((SbcCell c) => c.row == 8), 7);
      expect(side((SbcCell c) => c.col == 0), 7);
      expect(side((SbcCell c) => c.col == 8), 7);
      // Abhijit sits between Uttara Ashadha and Shravana.
      expect(grid.nakshatraCell(21).english, 'Abhijit');
      expect(grid.nakshatraCell(20).col, 0);
      expect(grid.nakshatraCell(22).col, 0);
      expect(
        (grid.nakshatraCell(21).row - grid.nakshatraCell(20).row).abs(),
        1,
      );
      // Krittika is the first beside the north-east corner, on the east side.
      expect(grid.nakshatraCell(2).row, 1);
      expect(grid.nakshatraCell(2).col, 8);
    });

    test(
      'the four corners and the diagonals hold the sixteen vowels, once each',
      () {
        for (final (int, int) corner in <(int, int)>[
          (0, 0),
          (0, 8),
          (8, 0),
          (8, 8),
        ]) {
          expect(grid.at(corner.$1, corner.$2).kind, SbcCellKind.vowel);
        }
        final List<SbcCell> vowels = grid.all
            .where((SbcCell c) => c.kind == SbcCellKind.vowel)
            .toList();
        expect(vowels.length, 16);
        expect(vowels.map((SbcCell c) => c.letter).toSet().length, 16);
        for (final SbcCell v in vowels) {
          expect(
            v.row == v.col || v.row + v.col == 8,
            isTrue,
            reason: '${v.hindi} is on a diagonal',
          );
          expect(!(v.row == 4 && v.col == 4), isTrue);
        }
        // Dealt clockwise from the north-east corner: a, ā, i, ī on the corners.
        expect(grid.at(0, 8).letter, 'अ');
        expect(grid.at(8, 8).letter, 'आ');
        expect(grid.at(8, 0).letter, 'इ');
        expect(grid.at(0, 0).letter, 'ई');
      },
    );

    test(
      'twenty consonants, twelve rashis and five tithi cells fill the rest',
      () {
        final List<SbcCell> consonants = grid.all
            .where((SbcCell c) => c.kind == SbcCellKind.consonant)
            .toList();
        expect(consonants.length, 20);
        expect(consonants.map((SbcCell c) => c.letter).toSet().length, 20);
        final List<SbcCell> rashis = grid.all
            .where((SbcCell c) => c.kind == SbcCellKind.rashi)
            .toList();
        expect(rashis.length, 12);
        expect(rashis.map((SbcCell c) => c.rashi).toSet().length, 12);
        // Taurus is the first sign on the east side, Aries the last on the north.
        expect(grid.rashiCell(1).col, 6);
        expect(grid.rashiCell(0).row, 2);
        final List<SbcCell> tithis = grid.all
            .where((SbcCell c) => c.kind == SbcCellKind.tithi)
            .toList();
        expect(tithis.length, 5);
        expect(tithis.map((SbcCell c) => c.tithiGroup).toSet().length, 5);
        expect(tithis.expand((SbcCell c) => c.weekdays).toList()..sort(), <int>[
          0,
          1,
          2,
          3,
          4,
          5,
          6,
        ]);
        expect(grid.at(4, 4).tithiGroup, TithiGroup.poorna);
        expect(81, 28 + 16 + consonants.length + rashis.length + tithis.length);
      },
    );

    test('vedha lines are straight or diagonal and end on the rim', () {
      for (final SbcCell origin in grid.all.where(
        (SbcCell c) => c.kind == SbcCellKind.nakshatra,
      )) {
        for (final VedhaLine line in VedhaLine.values) {
          final List<SbcCell> path = vedhaPath(grid, origin, line);
          expect(path, isNotEmpty);
          expect(path.last.isRim, isTrue);
          for (final SbcCell c in path.take(path.length - 1)) {
            expect(c.isRim, isFalse);
          }
          int dr = 0;
          int dc = 0;
          SbcCell prev = origin;
          for (final SbcCell c in path) {
            final int r = c.row - prev.row;
            final int cc = c.col - prev.col;
            if (dr == 0 && dc == 0) {
              dr = r;
              dc = cc;
              expect(dr.abs() <= 1 && dc.abs() <= 1, isTrue);
            }
            expect((r, cc), (dr, dc), reason: 'a line does not bend');
            prev = c;
          }
        }
      }
    });

    test(
      'Ashwini casts its three lines to Purva Phalguni, Rohini and Jyeshtha',
      () {
        final SbcCell ashwini = grid.nakshatraCell(0);
        expect(
          vedhaPath(grid, ashwini, VedhaLine.front).last.english,
          'Purva Phalguni',
        );
        expect(vedhaPath(grid, ashwini, VedhaLine.left).last.english, 'Rohini');
        expect(
          vedhaPath(grid, ashwini, VedhaLine.right).last.english,
          'Jyeshtha',
        );
      },
    );

    test('the Abhijit span is 276°40′ to 280°53′20″', () {
      expect(sbcNakshatraIndexOf(276.0), 20);
      expect(sbcNakshatraIndexOf(277.0), 21);
      expect(sbcNakshatraIndexOf(280.8), 21);
      expect(sbcNakshatraIndexOf(281.0), 22);
      expect(sbcNakshatraIndexOf(0.5), 0);
      expect(sbcNakshatraIndexOf(359.9), 27);
    });

    test(
      'a syllable is placed on the chakra, and the substitution is said aloud',
      () {
        final SbcSyllable chu = sbcSyllableOf('चू')!;
        expect(chu.consonant, 'च');
        expect(chu.vowel, 'ऊ');
        expect(chu.exact, isTrue);
        final SbcSyllable chha = sbcSyllableOf('छ')!;
        expect(chha.consonant, 'च');
        expect(chha.exact, isFalse);
        expect(chha.basisEnglish, contains('nearest'));
        final SbcSyllable a = sbcSyllableOf('अ')!;
        expect(a.consonant, isNull);
        expect(a.vowel, 'अ');
        expect(sbcSyllableOf('x'), isNull);
      },
    );

    test('the reading has a vedha for each graha and names its own points', () {
      final Kundli k = real(DateTime(1988, 8, 14, 9, 35));
      final SarvatobhadraReading r = computeSarvatobhadra(
        k,
        moment: DateTime(2026, 10, 7, 12),
      );
      expect(r.vedhas.length, 9);
      expect(r.natalPoints.length, greaterThanOrEqualTo(4));
      expect(r.syllable, isNotNull);
      expect(
        r.natalPoints.first.cell.nakshatra28,
        sbcNakshatraIndexOf(k.grahas[Graha.moon]!.siderealLongitude),
      );
      for (final SbcVedha v in r.vedhas) {
        expect(v.path, isNotEmpty);
        expect(v.origin.kind, SbcCellKind.nakshatra);
        expect(v.basisEnglish, isNotEmpty);
        expect(v.basisHindi, isNotEmpty);
        if (v.graha == Graha.rahu || v.graha == Graha.ketu) {
          expect(v.line, VedhaLine.right);
        }
        if (v.graha == Graha.sun || v.graha == Graha.moon) {
          expect(v.line, VedhaLine.left);
        }
        if (v.isRetrograde) expect(v.line, VedhaLine.right);
      }
      for (final SbcVedha v in r.active) {
        final ({String en, String hi}) text = describeVedha(v);
        expect(text.en, isNotEmpty);
        expect(text.hi, isNotEmpty);
        expectClean(text.en, 'vedha');
        expectClean(text.hi, 'vedha');
      }
    });
  });

  group('upagrahas', () {
    test('the Sun-derived five follow the formulas', () {
      for (final double sun in <double>[0, 17.3, 117.9, 200, 359.99]) {
        final Map<Upagraha, double> s = solarUpagrahaLongitudes(sun);
        final double dhuma = norm360(sun + 133 + 20 / 60);
        expect(s[Upagraha.dhuma], closeTo(dhuma, 1e-9));
        expect(s[Upagraha.vyatipata], closeTo(norm360(360 - dhuma), 1e-9));
        expect(
          s[Upagraha.parivesha],
          closeTo(norm360(360 - dhuma + 180), 1e-9),
        );
        expect(
          s[Upagraha.indrachapa],
          closeTo(norm360(360 - s[Upagraha.parivesha]!), 1e-9),
        );
        // Indrachapa + 16°40' is the same as the Sun less thirty degrees.
        expect(s[Upagraha.upaketu], closeTo(norm360(sun - 30), 1e-9));
        for (final double v in s.values) {
          expect(v, inInclusiveRange(0, 359.999999999));
        }
      }
    });

    test(
      'every upagraha longitude is in [0, 360) for day and night births at five places',
      () {
        for (final Kundli k in manyCharts(60, seed: 9)) {
          final UpagrahaResult r = computeUpagrahas(k);
          expect(r.placed.length, 11);
          expect(
            r.placed.map((PlacedUpagraha p) => p.upagraha).toSet().length,
            11,
          );
          for (final PlacedUpagraha p in r.placed) {
            expect(p.siderealLongitude >= 0, isTrue, reason: '${p.upagraha}');
            expect(p.siderealLongitude < 360, isTrue, reason: '${p.upagraha}');
            expect(p.house, inInclusiveRange(1, 12));
            expect(p.info.formulaEnglish, isNotEmpty);
            expect(p.info.formulaHindi, isNotEmpty);
            expect(p.info.readingEnglish, isNotEmpty);
            expect(p.info.readingHindi, isNotEmpty);
            expectClean(p.info.readingEnglish, p.info.english);
            expectClean(p.info.readingHindi, p.info.english);
          }
        }
      },
    );

    test(
      'Gulika takes the same part of the day as the panchang Gulika Kaal',
      () {
        // 7th part on Sunday, falling by one each weekday, 1st on Saturday.
        const List<int> gulikaPartByWeekday = <int>[7, 6, 5, 4, 3, 2, 1];
        int checked = 0;
        for (final Kundli k in manyCharts(80, seed: 4)) {
          final UpagrahaResult r = computeUpagrahas(k);
          if (!r.isDayBirth) continue;
          checked++;
          expect(
            r.of(Upagraha.gulika).partNumber,
            gulikaPartByWeekday[r.weekday],
          );
          expect(r.of(Upagraha.gulika).partLord, Graha.saturn);
          expect(r.of(Upagraha.kaala).partLord, Graha.sun);
          expect(r.of(Upagraha.mrityu).partLord, Graha.mars);
          expect(r.of(Upagraha.ardhaprahara).partLord, Graha.mercury);
          expect(r.of(Upagraha.yamaghantaka).partLord, Graha.jupiter);
          // The day parts run from the weekday lord in weekday order.
          expect(r.of(Upagraha.kaala).partNumber, ((7 - r.weekday) % 7) + 1);
        }
        expect(checked, greaterThan(10));
      },
    );

    test(
      'night parts are counted from the fifth lord from the weekday lord',
      () {
        int checked = 0;
        for (final Kundli k in manyCharts(80, seed: 5)) {
          final UpagrahaResult r = computeUpagrahas(k);
          if (r.isDayBirth) continue;
          checked++;
          final int first = (r.weekday + 4) % 7;
          expect(r.of(Upagraha.gulika).partNumber, ((6 - first + 7) % 7) + 1);
          expect(r.of(Upagraha.kaala).partNumber, ((0 - first + 7) % 7) + 1);
        }
        expect(checked, greaterThan(10));
      },
    );

    test('Mandi is taken at the end of the same part that Gulika begins', () {
      final Kundli k = real(DateTime(1988, 8, 14, 9, 35));
      final UpagrahaResult r = computeUpagrahas(k);
      expect(r.of(Upagraha.mandi).partNumber, r.of(Upagraha.gulika).partNumber);
      expect(
        r.of(Upagraha.mandi).siderealLongitude,
        isNot(closeTo(r.of(Upagraha.gulika).siderealLongitude, 0.5)),
      );
      final UpagrahaResult same = computeUpagrahas(
        k,
        convention: const UpagrahaConvention(
          gulika: UpagrahaPoint.begin,
          mandi: UpagrahaPoint.begin,
        ),
      );
      expect(
        same.of(Upagraha.mandi).siderealLongitude,
        closeTo(same.of(Upagraha.gulika).siderealLongitude, 1e-9),
      );
    });

    test('a birth before sunrise belongs to the previous Hindu day', () {
      // 14 August 1988 was a Sunday. At 03:00 the Hindu day is still Saturday's.
      final UpagrahaResult r = computeUpagrahas(
        real(DateTime(1988, 8, 14, 3, 0)),
      );
      expect(r.isDayBirth, isFalse);
      expect(r.weekday, 6);
      final UpagrahaResult sunday = computeUpagrahas(
        real(DateTime(1988, 8, 14, 9, 35)),
      );
      expect(sunday.weekday, 0);
      expect(sunday.isDayBirth, isTrue);
    });
  });

  group('sudarshan chakra', () {
    test('twelve houses are read from three references', () {
      for (final Kundli k in manyCharts(25, seed: 8)) {
        final SudarshanChakra s = computeSudarshan(k);
        expect(s.houses.length, 12);
        expect(s.noteEnglish, isNotEmpty);
        expect(s.noteHindi, isNotEmpty);
        for (int i = 0; i < 12; i++) {
          final SudarshanHouse h = s.houses[i];
          expect(h.house, i + 1);
          expect(h.standings.length, 3);
          expect(
            h.standings.map((HouseStanding x) => x.reference).toSet(),
            SudarshanReference.values.toSet(),
          );
          expect(h.fromLagna.sign, (k.lagnaRashi.index + i) % 12);
          expect(h.fromChandra.sign, (k.moonRashi.index + i) % 12);
          expect(h.fromSurya.sign, (k.sunRashi.index + i) % 12);
          expect(h.readingEnglish, isNotEmpty);
          expect(h.readingHindi, isNotEmpty);
          expect(h.areaEnglish, isNotEmpty);
          expect(h.areaHindi, isNotEmpty);
          for (final HouseStanding st in h.standings) {
            expect(st.factorsEnglish, isNotEmpty);
            expect(st.factorsEnglish.length, st.factorsHindi.length);
          }
          expect(h.strongCount, inInclusiveRange(0, 3));
          expect(h.agreement, switch (h.strongCount) {
            3 => SudarshanAgreement.all,
            2 => SudarshanAgreement.two,
            1 => SudarshanAgreement.one,
            _ => SudarshanAgreement.none,
          });
          expectClean(h.readingEnglish, 'sudarshan');
          expectClean(h.readingHindi, 'sudarshan');
        }
        final bool coincide =
            k.lagnaRashi == k.moonRashi ||
            k.lagnaRashi == k.sunRashi ||
            k.moonRashi == k.sunRashi;
        expect(s.referencesCoincide, coincide);
      }
    });

    test(
      'a house is strong from all three only when each ring supports it',
      () {
        for (final Kundli k in manyCharts(25, seed: 12)) {
          for (final SudarshanHouse h in computeSudarshan(k).houses) {
            if (h.agreement == SudarshanAgreement.all) {
              for (final HouseStanding s in h.standings) {
                expect(s.verdict, HouseVerdict.strong);
              }
            }
          }
        }
      },
    );
  });

  group('the yoga library', () {
    final List<Kundli> charts = manyCharts(150, seed: 21);

    test(
      'every finding names at least one chart factor, in both languages',
      () {
        for (final Kundli k in charts) {
          for (final YogaFinding f in findYogas(k)) {
            expect(f.factorsEnglish, isNotEmpty, reason: f.key);
            expect(f.factorsHindi, isNotEmpty, reason: f.key);
            expect(
              f.factorsEnglish.length,
              f.factorsHindi.length,
              reason: f.key,
            );
            for (final String s in <String>[
              ...f.factorsEnglish,
              ...f.factorsHindi,
            ]) {
              expect(s.trim(), isNotEmpty, reason: f.key);
            }
          }
        }
      },
    );

    test('every dosha carries a cancellation or a mitigation', () {
      int doshas = 0;
      for (final Kundli k in charts) {
        for (final YogaFinding f in findYogas(k)) {
          if (!f.isDosha) continue;
          doshas++;
          expect(f.hasRelief, isTrue, reason: '${f.key} has no relief');
          if (f.cancellationEnglish != null) {
            expect(f.cancellationHindi, isNotEmpty, reason: f.key);
          }
          if (f.mitigationEnglish != null) {
            expect(f.mitigationEnglish, isNotEmpty, reason: f.key);
            expect(f.mitigationHindi, isNotEmpty, reason: f.key);
          }
        }
      }
      expect(doshas, greaterThan(50));
    });

    test(
      'names, rules, meanings and sources are non-empty in both languages',
      () {
        for (final Kundli k in charts) {
          for (final YogaFinding f in findYogas(k)) {
            expect(f.key, isNotEmpty);
            expect(f.nameEnglish.trim(), isNotEmpty, reason: f.key);
            expect(f.nameHindi.trim(), isNotEmpty, reason: f.key);
            expect(f.ruleEnglish.trim(), isNotEmpty, reason: f.key);
            expect(f.ruleHindi.trim(), isNotEmpty, reason: f.key);
            expect(f.meaningEnglish.trim(), isNotEmpty, reason: f.key);
            expect(f.meaningHindi.trim(), isNotEmpty, reason: f.key);
            expect(f.sourceEnglish?.trim() ?? '', isNotEmpty, reason: f.key);
            expect(f.sourceHindi?.trim() ?? '', isNotEmpty, reason: f.key);
            expect(f.family.english, isNotEmpty);
            expect(f.family.hindi, isNotEmpty);
          }
        }
      },
    );

    test(
      'no finding ever produces a health, death, pregnancy, exam, court or investment statement',
      () {
        final Set<String> seen = <String>{};
        for (final Kundli k in charts) {
          for (final YogaFinding f in findYogas(k)) {
            seen.add(f.key.startsWith('raja_yoga') ? 'raja_yoga' : f.key);
            for (final String s in statementsOf(f)) {
              expectClean(s, f.key);
            }
          }
        }
        // The scan has to have seen a good spread of findings to mean anything.
        expect(seen.length, greaterThan(25));
      },
    );

    test(
      'every statement in the Nabhasa table is clean, whether or not a chart shows it',
      () {
        // Each Nabhasa yoga, built directly, so none escapes the scan for want of
        // a chart that carries it.
        final List<Kundli> shapes = <Kundli>[
          bySigns(
            sun: 0,
            moon: 3,
            mars: 6,
            mercury: 9,
            jupiter: 0,
            venus: 3,
            saturn: 6,
          ), // movable
          bySigns(
            sun: 1,
            moon: 4,
            mars: 7,
            mercury: 10,
            jupiter: 1,
            venus: 4,
            saturn: 7,
          ), // fixed
          bySigns(
            sun: 2,
            moon: 5,
            mars: 8,
            mercury: 11,
            jupiter: 2,
            venus: 5,
            saturn: 8,
          ), // dual
          bySigns(), // all in one sign
          bySigns(
            sun: 0,
            moon: 0,
            mars: 6,
            mercury: 6,
            jupiter: 6,
            venus: 0,
            saturn: 0,
          ), // 1 and 7
          bySigns(
            sun: 3,
            moon: 3,
            mars: 9,
            mercury: 9,
            jupiter: 3,
            venus: 9,
            saturn: 3,
          ), // 4 and 10
          bySigns(
            sun: 0,
            moon: 4,
            mars: 8,
            mercury: 0,
            jupiter: 4,
            venus: 8,
            saturn: 0,
          ), // 1 5 9
          bySigns(
            sun: 1,
            moon: 5,
            mars: 9,
            mercury: 1,
            jupiter: 5,
            venus: 9,
            saturn: 1,
          ), // hala
          bySigns(
            sun: 0,
            moon: 3,
            mars: 6,
            mercury: 9,
            jupiter: 3,
            venus: 6,
            saturn: 0,
          ), // kamala
          bySigns(
            sun: 0,
            moon: 1,
            mars: 2,
            mercury: 3,
            jupiter: 3,
            venus: 2,
            saturn: 1,
          ), // yupa
          bySigns(
            sun: 3,
            moon: 4,
            mars: 5,
            mercury: 6,
            jupiter: 6,
            venus: 5,
            saturn: 4,
          ), // shara
          bySigns(
            sun: 6,
            moon: 7,
            mars: 8,
            mercury: 9,
            jupiter: 9,
            venus: 8,
            saturn: 7,
          ), // shakti
          bySigns(
            sun: 9,
            moon: 10,
            mars: 11,
            mercury: 0,
            jupiter: 0,
            venus: 11,
            saturn: 10,
          ), // danda
          bySigns(
            sun: 0,
            moon: 1,
            mars: 2,
            mercury: 3,
            jupiter: 4,
            venus: 5,
            saturn: 6,
          ), // nauka
          bySigns(
            sun: 3,
            moon: 4,
            mars: 5,
            mercury: 6,
            jupiter: 7,
            venus: 8,
            saturn: 9,
          ), // koota
          bySigns(
            sun: 6,
            moon: 7,
            mars: 8,
            mercury: 9,
            jupiter: 10,
            venus: 11,
            saturn: 0,
          ), // chhatra
          bySigns(
            sun: 9,
            moon: 10,
            mars: 11,
            mercury: 0,
            jupiter: 1,
            venus: 2,
            saturn: 3,
          ), // chapa
          bySigns(
            sun: 0,
            moon: 2,
            mars: 4,
            mercury: 6,
            jupiter: 8,
            venus: 10,
            saturn: 10,
          ), // chakra
          bySigns(
            sun: 1,
            moon: 3,
            mars: 5,
            mercury: 7,
            jupiter: 9,
            venus: 11,
            saturn: 11,
          ), // samudra
        ];
        final Set<String> found = <String>{};
        for (final Kundli k in shapes) {
          for (final YogaFinding f in findYogas(k)) {
            if (f.family != YogaFamily.nabhasa) continue;
            found.add(f.key);
            for (final String s in statementsOf(f)) {
              expectClean(s, f.key);
            }
          }
        }
        expect(found.length, greaterThanOrEqualTo(15));
      },
    );
  });

  group('yogas on exactly the placement that defines them', () {
    test('the three Asraya yogas by the quality of the signs', () {
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 3,
            mars: 6,
            mercury: 9,
            jupiter: 0,
            venus: 3,
            saturn: 6,
          ),
        ),
        contains('nabhasa_rajju'),
      );
      expect(
        keys(
          bySigns(
            sun: 1,
            moon: 4,
            mars: 7,
            mercury: 10,
            jupiter: 1,
            venus: 4,
            saturn: 7,
          ),
        ),
        contains('nabhasa_musala'),
      );
      expect(
        keys(
          bySigns(
            sun: 2,
            moon: 5,
            mars: 8,
            mercury: 11,
            jupiter: 2,
            venus: 5,
            saturn: 8,
          ),
        ),
        contains('nabhasa_nala'),
      );
      // One graha in a different quality breaks it.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 3,
            mars: 6,
            mercury: 9,
            jupiter: 0,
            venus: 3,
            saturn: 7,
          ),
        ),
        isNot(contains('nabhasa_rajju')),
      );
    });

    test('Dala: benefics or malefics in three kendras', () {
      final Kundli mala = bySigns(
        sun: 1,
        moon: 1,
        mars: 2,
        mercury: 3,
        jupiter: 0,
        venus: 6,
        saturn: 2,
      );
      // Jupiter in the 1st, Mercury in the 4th, Venus in the 7th.
      expect(keys(mala), contains('nabhasa_mala'));
      expect(keys(mala), isNot(contains('nabhasa_sarpa')));
      final Kundli sarpa = bySigns(
        sun: 0,
        moon: 1,
        mars: 3,
        mercury: 2,
        jupiter: 4,
        venus: 5,
        saturn: 6,
      );
      // Sun in the 1st, Mars in the 4th, Saturn in the 7th.
      expect(keys(sarpa), contains('nabhasa_sarpa'));
      final YogaFinding f = find(sarpa, 'nabhasa_sarpa');
      expect(f.isDosha, isTrue);
      expect(f.hasRelief, isTrue);
    });

    test('Akriti yogas need every named house occupied and no graha outside', () {
      // Kamala: all four kendras, nothing elsewhere.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 3,
            mars: 6,
            mercury: 9,
            jupiter: 3,
            venus: 6,
            saturn: 0,
          ),
        ),
        contains('nabhasa_kamala'),
      );
      // The same with one kendra left empty is a Gada pair or nothing, not Kamala.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 3,
            mars: 6,
            mercury: 6,
            jupiter: 3,
            venus: 6,
            saturn: 0,
          ),
        ),
        isNot(contains('nabhasa_kamala')),
      );
      // Shakata (Nabhasa): only the 1st and 7th, both occupied.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 0,
            mars: 6,
            mercury: 6,
            jupiter: 6,
            venus: 0,
            saturn: 0,
          ),
        ),
        contains('nabhasa_shakata'),
      );
      // Gada: two adjacent kendras, here the 4th and 7th.
      expect(
        keys(
          bySigns(
            sun: 3,
            moon: 3,
            mars: 6,
            mercury: 6,
            jupiter: 3,
            venus: 6,
            saturn: 3,
          ),
        ),
        contains('nabhasa_gada'),
      );
      // Vihaga: the 4th and 10th.
      expect(
        keys(
          bySigns(
            sun: 3,
            moon: 3,
            mars: 9,
            mercury: 9,
            jupiter: 3,
            venus: 9,
            saturn: 3,
          ),
        ),
        contains('nabhasa_vihaga'),
      );
      // Shringataka: the 1st, 5th and 9th.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 4,
            mars: 8,
            mercury: 0,
            jupiter: 4,
            venus: 8,
            saturn: 0,
          ),
        ),
        contains('nabhasa_shringataka'),
      );
      // Hala: the 2nd, 6th and 10th.
      expect(
        keys(
          bySigns(
            sun: 1,
            moon: 5,
            mars: 9,
            mercury: 1,
            jupiter: 5,
            venus: 9,
            saturn: 1,
          ),
        ),
        contains('nabhasa_hala'),
      );
      // Yupa: the four houses from the 1st.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 1,
            mars: 2,
            mercury: 3,
            jupiter: 3,
            venus: 2,
            saturn: 1,
          ),
        ),
        contains('nabhasa_yupa'),
      );
      // Nauka: the seven houses from the 1st, each with one graha.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 1,
            mars: 2,
            mercury: 3,
            jupiter: 4,
            venus: 5,
            saturn: 6,
          ),
        ),
        contains('nabhasa_nauka'),
      );
      // Shara, Shakti, Danda: the four houses from the 4th, 7th and 10th.
      expect(
        keys(
          bySigns(
            sun: 3,
            moon: 4,
            mars: 5,
            mercury: 6,
            jupiter: 6,
            venus: 5,
            saturn: 4,
          ),
        ),
        contains('nabhasa_shara'),
      );
      expect(
        keys(
          bySigns(
            sun: 6,
            moon: 7,
            mars: 8,
            mercury: 9,
            jupiter: 9,
            venus: 8,
            saturn: 7,
          ),
        ),
        contains('nabhasa_shakti'),
      );
      expect(
        keys(
          bySigns(
            sun: 9,
            moon: 10,
            mars: 11,
            mercury: 0,
            jupiter: 0,
            venus: 11,
            saturn: 10,
          ),
        ),
        contains('nabhasa_danda'),
      );
      // Koota, Chhatra, Chapa: the seven houses from the 4th, 7th and 10th.
      expect(
        keys(
          bySigns(
            sun: 3,
            moon: 4,
            mars: 5,
            mercury: 6,
            jupiter: 7,
            venus: 8,
            saturn: 9,
          ),
        ),
        contains('nabhasa_koota'),
      );
      expect(
        keys(
          bySigns(
            sun: 6,
            moon: 7,
            mars: 8,
            mercury: 9,
            jupiter: 10,
            venus: 11,
            saturn: 0,
          ),
        ),
        contains('nabhasa_chhatra'),
      );
      expect(
        keys(
          bySigns(
            sun: 9,
            moon: 10,
            mars: 11,
            mercury: 0,
            jupiter: 1,
            venus: 2,
            saturn: 3,
          ),
        ),
        contains('nabhasa_chapa'),
      );
      // Vapi: the four succedent houses, all occupied.
      expect(
        keys(
          bySigns(
            sun: 1,
            moon: 4,
            mars: 7,
            mercury: 10,
            jupiter: 1,
            venus: 4,
            saturn: 7,
          ),
        ),
        contains('nabhasa_vapi'),
      );
      // Chakra: the six odd houses.
      expect(
        keys(
          bySigns(
            sun: 0,
            moon: 2,
            mars: 4,
            mercury: 6,
            jupiter: 8,
            venus: 10,
            saturn: 10,
          ),
        ),
        contains('nabhasa_chakra'),
      );
      // Samudra: the six even houses.
      expect(
        keys(
          bySigns(
            sun: 1,
            moon: 3,
            mars: 5,
            mercury: 7,
            jupiter: 9,
            venus: 11,
            saturn: 11,
          ),
        ),
        contains('nabhasa_samudra'),
      );
    });

    test('Vajra and Yava by benefics and malefics in the kendras', () {
      // Benefics (Jupiter, Venus, Mercury) in the 1st and 7th; Sun, Mars,
      // Saturn in the 4th and 10th.
      final Kundli vajra = bySigns(
        sun: 3,
        moon: 1,
        mars: 9,
        mercury: 0,
        jupiter: 6,
        venus: 6,
        saturn: 3,
      );
      expect(keys(vajra), contains('nabhasa_vajra'));
      final Kundli yava = bySigns(
        sun: 0,
        moon: 1,
        mars: 6,
        mercury: 3,
        jupiter: 9,
        venus: 3,
        saturn: 0,
      );
      expect(keys(yava), contains('nabhasa_yava'));
    });

    test(
      'Sankhya yogas count the signs, and only when no other Nabhasa yoga holds',
      () {
        // All seven in one sign always satisfies an Asraya yoga, so under BPHS
        // 35.17 the Sankhya yoga Gola is not reported.
        final Set<String> one = keys(bySigns());
        expect(one, contains('nabhasa_rajju'));
        expect(one, isNot(contains('nabhasa_gola')));
        // Two signs of different quality: Yuga.
        expect(
          keys(
            bySigns(
              sun: 0,
              moon: 0,
              mars: 1,
              mercury: 1,
              jupiter: 0,
              venus: 1,
              saturn: 0,
            ),
          ),
          contains('nabhasa_yuga'),
        );
        // Three signs: Shoola.
        expect(
          keys(
            bySigns(
              sun: 0,
              moon: 1,
              mars: 3,
              mercury: 3,
              jupiter: 0,
              venus: 1,
              saturn: 3,
            ),
          ),
          contains('nabhasa_shoola'),
        );
        // Four signs: Kedara.
        expect(
          keys(
            bySigns(
              sun: 0,
              moon: 1,
              mars: 3,
              mercury: 5,
              jupiter: 0,
              venus: 1,
              saturn: 3,
            ),
          ),
          contains('nabhasa_kedara'),
        );
        // Five signs: Pasha.
        expect(
          keys(
            bySigns(
              sun: 0,
              moon: 1,
              mars: 3,
              mercury: 5,
              jupiter: 7,
              venus: 1,
              saturn: 3,
            ),
          ),
          contains('nabhasa_pasha'),
        );
        // Six signs: Dama.
        expect(
          keys(
            bySigns(
              sun: 0,
              moon: 1,
              mars: 3,
              mercury: 5,
              jupiter: 7,
              venus: 9,
              saturn: 3,
            ),
          ),
          contains('nabhasa_dama'),
        );
        // Seven signs: Veena.
        expect(
          keys(
            bySigns(
              sun: 0,
              moon: 1,
              mars: 2,
              mercury: 4,
              jupiter: 7,
              venus: 9,
              saturn: 11,
            ),
          ),
          contains('nabhasa_veena'),
        );
        // Exactly one Sankhya yoga is ever reported.
        final Set<String> sankhya = <String>{
          'nabhasa_veena',
          'nabhasa_dama',
          'nabhasa_pasha',
          'nabhasa_kedara',
          'nabhasa_shoola',
          'nabhasa_yuga',
          'nabhasa_gola',
        };
        for (final Kundli k in manyCharts(60, seed: 31)) {
          expect(keys(k).where(sankhya.contains).length, lessThanOrEqualTo(1));
        }
        // The hard readings carry their asking, never a verdict.
        final YogaFinding shoola = find(
          bySigns(
            sun: 0,
            moon: 1,
            mars: 3,
            mercury: 3,
            jupiter: 0,
            venus: 1,
            saturn: 3,
          ),
          'nabhasa_shoola',
        );
        expect(shoola.isDosha, isTrue);
        expect(shoola.hasRelief, isTrue);
        // All seven in the 1st and 7th are two signs, which would be Yuga, but
        // Shakata holds, so the Sankhya yoga is not reported (BPHS 35.17).
        final Set<String> shakata = keys(
          bySigns(
            sun: 0,
            moon: 0,
            mars: 6,
            mercury: 6,
            jupiter: 6,
            venus: 0,
            saturn: 0,
          ),
        );
        expect(shakata, contains('nabhasa_shakata'));
        expect(shakata, isNot(contains('nabhasa_yuga')));
      },
    );

    test('Vipreet Raja: the lord of a dusthana stands in a dusthana', () {
      // Mesha lagna: the 6th is Kanya (Mercury), the 8th Vrischika (Mars), the
      // 12th Meena (Jupiter).
      final Kundli harsha = bySigns(mercury: 5); // Mercury in Kanya, the 6th
      expect(keys(harsha), contains('harsha'));
      final Kundli sarala = bySigns(mars: 5); // the 8th lord in the 6th
      expect(keys(sarala), contains('sarala'));
      final Kundli vimala = bySigns(jupiter: 7); // the 12th lord in the 8th
      expect(keys(vimala), contains('vimala'));
      expect(keys(bySigns(mercury: 4)), isNot(contains('harsha')));
      expect(find(harsha, 'harsha').isDosha, isFalse);
    });

    test('Chandra yogas are exclusive, and either one rules out Kemadruma', () {
      // Moon in Karka (3); Mars in Simha (2nd from the Moon).
      final Kundli sunapha = bySigns(
        moon: 3,
        mars: 4,
        sun: 9,
        mercury: 9,
        jupiter: 9,
        venus: 9,
        saturn: 9,
      );
      expect(keys(sunapha), contains('sunapha'));
      expect(keys(sunapha), isNot(contains('anapha')));
      expect(keys(sunapha), isNot(contains('kemadruma')));
      final Kundli anapha = bySigns(
        moon: 3,
        mars: 2,
        sun: 9,
        mercury: 9,
        jupiter: 9,
        venus: 9,
        saturn: 9,
      );
      expect(keys(anapha), contains('anapha'));
      final Kundli duradhara = bySigns(
        moon: 3,
        mars: 2,
        jupiter: 4,
        sun: 9,
        mercury: 9,
        venus: 9,
        saturn: 9,
      );
      expect(keys(duradhara), contains('duradhara'));
      expect(keys(duradhara), isNot(contains('sunapha')));
      // The Sun alone beside the Moon is not enough (BPHS 37.7).
      final Kundli sunOnly = bySigns(
        moon: 3,
        sun: 4,
        mars: 9,
        mercury: 9,
        jupiter: 9,
        venus: 9,
        saturn: 9,
      );
      expect(keys(sunOnly), isNot(contains('sunapha')));
    });

    test(
      'Kemadruma carries the BPHS cancellation when a graha is in a kendra',
      () {
        // Moon in Kumbha (10), nothing beside it. Jupiter in the 1st (Mesha) is
        // in a kendra from the lagna, which cancels it (BPHS 37.11).
        final Kundli cancelled = bySigns(
          moon: 10,
          sun: 5,
          mars: 5,
          mercury: 5,
          jupiter: 0,
          venus: 5,
          saturn: 5,
        );
        final YogaFinding f = find(cancelled, 'kemadruma');
        expect(f.isDosha, isTrue);
        expect(f.isCancelled, isTrue);
        expect(f.cancellationEnglish, contains('Jupiter'));
        // With every other graha out of the kendras it stands, with a mitigation.
        final Kundli standing = bySigns(
          moon: 10,
          sun: 5,
          mars: 5,
          mercury: 5,
          jupiter: 7,
          venus: 5,
          saturn: 5,
        );
        final YogaFinding g = find(standing, 'kemadruma');
        expect(g.isCancelled, isFalse);
        expect(g.mitigationEnglish, isNotNull);
      },
    );

    test('Sun yogas: Vesi, Vasi and Ubhayachari', () {
      // Sun in Karka (3); Mars in Simha (2nd): Vesi.
      expect(
        keys(
          bySigns(
            sun: 3,
            mars: 4,
            moon: 9,
            mercury: 9,
            jupiter: 9,
            venus: 9,
            saturn: 9,
          ),
        ),
        contains('vesi'),
      );
      // Mars in Mithuna (12th): Vasi.
      expect(
        keys(
          bySigns(
            sun: 3,
            mars: 2,
            moon: 9,
            mercury: 9,
            jupiter: 9,
            venus: 9,
            saturn: 9,
          ),
        ),
        contains('vasi'),
      );
      // Both: Ubhayachari.
      final Set<String> both = keys(
        bySigns(
          sun: 3,
          mars: 2,
          jupiter: 4,
          moon: 9,
          mercury: 9,
          venus: 9,
          saturn: 9,
        ),
      );
      expect(both, contains('ubhayachari'));
      expect(both, isNot(contains('vesi')));
      // The Moon alone beside the Sun does not make Vesi.
      expect(
        keys(
          bySigns(
            sun: 3,
            moon: 4,
            mars: 9,
            mercury: 9,
            jupiter: 9,
            venus: 9,
            saturn: 9,
          ),
        ),
        isNot(contains('vesi')),
      );
    });

    test('Shakata (Moon from Jupiter) and its two cancellations', () {
      // Jupiter in Mesha, Moon in Kanya (6th from Jupiter), Moon in the 6th
      // house from a Mesha lagna, so not a kendra.
      final Kundli plain = bySigns(jupiter: 0, moon: 5);
      final YogaFinding f = find(plain, 'shakata_chandra');
      expect(f.isDosha, isTrue);
      expect(f.isCancelled, isFalse);
      expect(f.mitigationEnglish, isNotNull);
      // Moon in Makara (kendra from a Mesha lagna) with Jupiter in Karka:
      // Makara is the 6th from Karka, and a kendra from the lagna.
      final Kundli kendra = bySigns(jupiter: 10, moon: 3);
      expect(find(kendra, 'shakata_chandra').isCancelled, isTrue);
    });

    test('Dhana yoga and Daridra yoga from the lords of the 2nd and 11th', () {
      // Mesha lagna: the 2nd lord is Venus, the 11th lord Saturn.
      final Kundli joined = bySigns(venus: 6, saturn: 6);
      expect(keys(joined), contains('dhana_2_11'));
      final Kundli bothLow = bySigns(venus: 5, saturn: 7); // 6th and 8th
      final YogaFinding d = find(bothLow, 'daridra');
      expect(d.isDosha, isTrue);
      expect(d.hasRelief, isTrue);
      expect(keys(joined), isNot(contains('daridra')));
    });

    test(
      'the doshas: Guru Chandal, Grahan, Shrapit, Angarak, Vish and Pitra',
      () {
        Kundli base({
          int sun = 9,
          int moon = 10,
          int mars = 9,
          int mercury = 9,
          int jupiter = 9,
          int venus = 9,
          int saturn = 9,
          int rahu = 4,
          int ketu = 10,
        }) => bySigns(
          sun: sun,
          moon: moon,
          mars: mars,
          mercury: mercury,
          jupiter: jupiter,
          venus: venus,
          saturn: saturn,
          rahu: rahu,
          ketu: ketu,
        );
        expect(keys(base(jupiter: 4, rahu: 4)), contains('guru_chandal'));
        expect(keys(base(sun: 4, rahu: 4)), contains('grahan_surya'));
        expect(keys(base(moon: 4, rahu: 4)), contains('grahan_chandra'));
        expect(keys(base(saturn: 4, rahu: 4)), contains('shrapit'));
        expect(keys(base(mars: 4, rahu: 4)), contains('angarak'));
        expect(keys(base(moon: 7, saturn: 7)), contains('vish_yoga'));
        // Rahu in the 9th (Dhanu) is Pitra dosha.
        expect(keys(base(rahu: 8, ketu: 2)), contains('pitra_dosha'));
        for (final String key in <String>[
          'guru_chandal',
          'grahan_surya',
          'shrapit',
          'angarak',
          'vish_yoga',
        ]) {
          final Kundli k = switch (key) {
            'guru_chandal' => base(jupiter: 4, rahu: 4),
            'grahan_surya' => base(sun: 4, rahu: 4),
            'shrapit' => base(saturn: 4, rahu: 4),
            'angarak' => base(mars: 4, rahu: 4),
            _ => base(moon: 7, saturn: 7),
          };
          final YogaFinding f = find(k, key);
          expect(f.isDosha, isTrue, reason: key);
          expect(f.hasRelief, isTrue, reason: key);
          expect(f.sourceEnglish, contains('popular'), reason: key);
        }
      },
    );

    test('a dosha is cancelled when its classical softening is present', () {
      // Jupiter in his own sign (Dhanu) with Rahu: strong Jupiter eases it.
      final Kundli eased = bySigns(jupiter: 8, rahu: 8, ketu: 2);
      expect(find(eased, 'guru_chandal').isCancelled, isTrue);
      final Kundli hard = bySigns(jupiter: 6, rahu: 6, ketu: 0);
      expect(find(hard, 'guru_chandal').isCancelled, isFalse);
      expect(find(hard, 'guru_chandal').mitigationEnglish, isNotNull);
    });

    test(
      'the larger yogas: Amala, Chamara, Adhi, Lakshmi, Saraswati, Kalanidhi, Kahala',
      () {
        // Amala: Jupiter alone in the 10th from the lagna (Makara).
        final Kundli amala = bySigns(
          jupiter: 9,
          sun: 1,
          moon: 1,
          mars: 2,
          mercury: 2,
          venus: 2,
          saturn: 2,
        );
        expect(keys(amala), contains('amala'));
        // Chamara: the lagna lord (Mars) exalted in a kendra, aspected by Jupiter.
        // Mars exalted in Makara (the 10th); Jupiter in Karka aspects it (7th).
        final Kundli chamara = bySigns(
          mars: 9,
          jupiter: 3,
          sun: 2,
          moon: 2,
          mercury: 2,
          venus: 2,
          saturn: 2,
        );
        expect(keys(chamara), contains('chamara'));
        // Adhi: Jupiter, Venus, Mercury in the 6th, 7th, 8th from the Moon.
        final Kundli adhi = bySigns(
          moon: 0,
          jupiter: 5,
          venus: 6,
          mercury: 7,
          sun: 2,
          mars: 2,
          saturn: 2,
        );
        expect(keys(adhi), contains('adhi'));
        // Lakshmi: the 9th lord (Jupiter) in Karka (exalted, a kendra from Mesha)
        // with the lagna lord Mars strong in Mesha.
        final Kundli lakshmi = bySigns(
          jupiter: 3,
          mars: 0,
          sun: 2,
          moon: 2,
          mercury: 2,
          venus: 2,
          saturn: 2,
        );
        expect(keys(lakshmi), contains('lakshmi'));
        // Saraswati: Jupiter (Dhanu, own, the 9th), Venus (Meena, the 12th? no).
        // Jupiter in Dhanu (9th), Venus in Vrishabha (2nd), Mercury in Mithuna?
        // Mithuna is the 3rd, so Mercury goes to Karka (4th).
        final Kundli saraswati = bySigns(
          jupiter: 8,
          venus: 1,
          mercury: 3,
          sun: 2,
          moon: 2,
          mars: 2,
          saturn: 2,
        );
        expect(keys(saraswati), contains('saraswati'));
        // Kalanidhi: Jupiter in the 2nd house (Vrishabha, a sign of Venus).
        final Kundli kalanidhi = bySigns(
          jupiter: 1,
          sun: 2,
          moon: 2,
          mars: 2,
          mercury: 2,
          venus: 2,
          saturn: 2,
        );
        expect(keys(kalanidhi), contains('kalanidhi'));
        // Kahala: the 4th lord (Moon) and Jupiter in mutual kendras, with the
        // lagna lord strong. Moon in Karka (own), Jupiter in Tula (7th from it).
        final Kundli kahala = bySigns(
          moon: 3,
          jupiter: 6,
          mars: 0,
          sun: 2,
          mercury: 2,
          venus: 2,
          saturn: 2,
        );
        expect(keys(kahala), contains('kahala'));
      },
    );

    test('the original eleven kinds keep their keys', () {
      // Mars exalted in Makara in a kendra: Ruchaka. Mercury with the Sun in
      // one sign: Budhaditya. Jupiter in a kendra from the Moon: Gaja Kesari.
      final Kundli k = bySigns(
        mars: 9,
        sun: 2,
        mercury: 2,
        moon: 2,
        jupiter: 5,
        venus: 7,
        saturn: 7,
      );
      final Set<String> ks = keys(k);
      expect(ks, contains('mahapurusha_mars'));
      expect(ks, contains('budhaditya'));
      expect(ks, contains('gaja_kesari'));
      final YogaFinding m = find(bySigns(mars: 6), 'mangal_dosha');
      expect(m.nameEnglish, 'Mangal dosha');
      expect(m.hasRelief, isTrue);
    });
  });
}
