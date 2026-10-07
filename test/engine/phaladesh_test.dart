import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/phaladesh.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/shadbala.dart';
import 'package:kundlisaar/engine/jyotish/transits.dart';
import 'package:kundlisaar/engine/jyotish/yogas.dart';

const GeoPlace delhi = GeoPlace(
  name: 'Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);

const Duration ist = Duration(hours: 5, minutes: 30);

Kundli chartAt(DateTime local) => computeKundli(
  BirthData(name: 'Test', localDateTime: local, utcOffset: ist, place: delhi),
);

/// One chart for each of the twelve lagnas, found by walking a day in
/// twenty-minute steps.
List<Kundli> chartForEveryLagna() {
  final Map<Rashi, Kundli> found = <Rashi, Kundli>{};
  for (int step = 0; step < 72 && found.length < 12; step++) {
    final Kundli k = chartAt(
      DateTime(1990, 3, 5).add(Duration(minutes: step * 20)),
    );
    found.putIfAbsent(k.lagnaRashi, () => k);
  }
  return found.values.toList();
}

/// Everything the readings must never say, in either language. The app does
/// not forecast death, illness, pregnancy, examinations, legal outcomes or
/// investment returns, and a hard period is described by what it asks of the
/// person, never as doom.
final RegExp refusedEnglish = RegExp(
  r'\b(death|dead|die|dies|died|dying|fatal\w*|mortal\w*|illness|ill|disease\w*|sick\w*|cancer|surgery|surgical|pregnan\w*|conceive|conception|miscarriage|abortion|childbirth|exams?|examinations?|courts?|lawsuits?|litigation|legal|jail|prison|invest\w*|stocks?|lottery|gambl\w*|speculat\w*|satta)\b',
  caseSensitive: false,
);

final RegExp doomEnglish = RegExp(
  r'(doom|disaster|misfortune|catastroph|tragedy|tragic|curse|suffer|evil|calamit|ruin)',
  caseSensitive: false,
);

const List<String> refusedHindi = <String>[
  'मृत्यु',
  'मौत',
  'मरण',
  'बीमार',
  'रोग',
  'गर्भ',
  'प्रसव',
  'परीक्षा',
  'इम्तिहान',
  'मुकदमा',
  'अदालत',
  'क़ानून',
  'कानून',
  'जेल',
  'कारावास',
  'निवेश',
  'शेयर',
  'सट्टा',
  'लॉटरी',
  'जुआ',
  'अभिशाप',
  'विनाश',
  'तबाही',
  'दुर्भाग्य',
];

final RegExp devanagari = RegExp(r'[ऀ-ॿ]');
final RegExp latin = RegExp(r'[A-Za-z]');

int signOf(Kundli k, Graha g) => k.grahas[g]!.rashi.index;
int houseFrom(int from, int to) => ((to - from + 12) % 12) + 1;

void main() {
  late List<Phaladesh> every; // one chart per lagna
  late Phaladesh sample; // 14 August 1988, 09:35, Delhi
  final DateTime now = DateTime.utc(2026, 10, 7);

  setUpAll(() {
    every = chartForEveryLagna().map(computePhaladesh).toList();
    sample = computePhaladesh(chartAt(DateTime(1988, 8, 14, 9, 35)));
  });

  test('the sweep reaches every lagna', () {
    expect(
      every.map((Phaladesh p) => p.context.kundli.lagnaRashi).toSet().length,
      12,
    );
  });

  group('the life timeline', () {
    test('covers birth to ninety with no gap and no overlap', () {
      for (final Phaladesh p in every) {
        final List<TimelineWindow> windows = p.timeline.windows;
        final double birth = p.context.kundli.instant.julianDayUt;
        final double horizon = birth + lifeHorizonYears * vimshottariYear;
        final String lagna = p.context.kundli.lagnaRashi.name;

        expect(
          windows.first.period.startJdUt,
          birth,
          reason: '$lagna starts at birth',
        );
        for (int i = 0; i < windows.length - 1; i++) {
          expect(
            windows[i].period.endJdUt,
            windows[i + 1].period.startJdUt,
            reason: '$lagna window $i meets window ${i + 1}',
          );
        }
        // The last window is the antardasha running at ninety.
        expect(windows.last.period.startJdUt, lessThan(horizon));
        expect(windows.last.period.endJdUt, greaterThanOrEqualTo(horizon));
        expect(p.timeline.end, windows.last.end);
        for (int i = 0; i < windows.length; i++) {
          expect(windows[i].index, i);
        }
      }
    });

    test('every window has ordered dates and ordered ages', () {
      for (final Phaladesh p in every) {
        for (final TimelineWindow w in p.timeline.windows) {
          expect(w.start.isBefore(w.end), isTrue, reason: '${w.index}');
          expect(w.ageStartYears, lessThan(w.ageEndYears));
          expect(w.ageStartYears, greaterThanOrEqualTo(0));
        }
        for (int i = 0; i < p.timeline.windows.length - 1; i++) {
          final TimelineWindow a = p.timeline.windows[i];
          final TimelineWindow b = p.timeline.windows[i + 1];
          expect(a.start.isBefore(b.start), isTrue);
          expect(a.ageEndYears, closeTo(b.ageStartYears, 1e-9));
        }
      }
    });

    test('chapters partition the windows by mahadasha', () {
      for (final Phaladesh p in every) {
        final LifeTimeline t = p.timeline;
        expect(
          t.chapters.fold<int>(
            0,
            (int sum, TimelineChapter c) => sum + c.windows.length,
          ),
          t.windows.length,
        );
        for (final TimelineChapter c in t.chapters) {
          expect(c.windows.first.startsChapter, isTrue);
          expect(
            c.windows.every((TimelineWindow w) => w.mahaLord == c.maha.lord),
            isTrue,
          );
          expect(
            c.windows.skip(1).every((TimelineWindow w) => !w.startsChapter),
            isTrue,
          );
        }
      }
    });

    test('follows the Vimshottari tree the chart already holds', () {
      for (final Phaladesh p in every) {
        final List<DashaPeriod> antars = <DashaPeriod>[
          for (final DashaPeriod m in p.context.kundli.vimshottari)
            ...m.children,
        ];
        for (final TimelineWindow w in p.timeline.windows) {
          final DashaPeriod expected = antars[w.index];
          expect(w.antarLord, expected.lord);
          expect(w.period.startJdUt, expected.startJdUt);
          expect(w.period.endJdUt, expected.endJdUt);
        }
      }
    });

    test('the window at a moment agrees with the running dasha chain', () {
      final Kundli k = sample.context.kundli;
      final TimelineWindow? w = sample.timeline.windowAt(now);
      final List<DashaPeriod> chain = k.dashaChainAt(now);
      expect(w, isNotNull);
      expect(w!.mahaLord, chain[0].lord);
      expect(w.antarLord, chain[1].lord);
      expect(
        sample.dasha.chainAt(now).map((PeriodReading r) => r.lord),
        <Graha>[chain[0].lord, chain[1].lord, chain[2].lord],
      );
    });

    test(
      'names the dates, the lords, a headline, what to expect and an area',
      () {
        for (final TimelineWindow w in sample.timeline.windows) {
          expect(w.headline.isComplete, isTrue);
          expect(w.expect.isComplete, isTrue);
          expect(LifeArea.values, contains(w.area));
          expect(w.areas, isNotEmpty);
          expect(w.areas.length, lessThanOrEqualTo(2));
        }
      },
    );

    test('childhood windows say they are read through the home', () {
      final TimelineWindow first = sample.timeline.windows.first;
      expect(first.expect.en, contains('childhood'));
      final TimelineWindow late = sample.timeline.windows.last;
      expect(late.expect.en, isNot(contains('childhood')));
    });
  });

  group('every reading is derived from named chart factors', () {
    test('houses, grahas, periods, windows and transits all carry a basis', () {
      for (final Phaladesh p in every) {
        for (final BhavaReading b in p.bhavas) {
          expect(b.basis, isNotEmpty, reason: 'house ${b.house}');
        }
        for (final GrahaReading g in p.grahas) {
          expect(g.basis, isNotEmpty, reason: g.graha.name);
        }
        void walk(PeriodReading r) {
          expect(
            r.basis,
            isNotEmpty,
            reason: '${r.lord.name} level ${r.level}',
          );
          r.children.forEach(walk);
        }

        p.dasha.mahadashas.forEach(walk);
        for (final TimelineWindow w in p.timeline.windows) {
          expect(w.basis, isNotEmpty);
        }
      }
      final GocharPhala gochar = sample.gochar(now: now);
      for (final GocharReading r in gochar.readings) {
        expect(r.basis, isNotEmpty, reason: r.graha.name);
      }
    });

    test('the containers carry their factors too, in both languages', () {
      final GocharPhala gochar = sample.gochar(now: now);
      for (final PhalaReading whole in <PhalaReading>[
        sample.dasha,
        sample.timeline,
        gochar,
      ]) {
        expect(whole.headline.isComplete, isTrue);
        expect(whole.basis, isNotEmpty);
        expect(whole.basis.every((Bi b) => b.isComplete), isTrue);
      }
      final String basis = sample.timeline.basis.map((Bi b) => b.en).join('\n');
      expect(basis, contains('Moon at birth'));
      expect(basis, contains('Vimshottari'));
      expect(basis, contains('Ayanamsa'));
      expect(basis, contains('age 90'));
    });

    test('there are twelve houses, nine grahas and nine mahadashas', () {
      expect(sample.bhavas.map((BhavaReading b) => b.house), <int>[
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, //
      ]);
      expect(sample.grahas.map((GrahaReading g) => g.graha), Graha.values);
      expect(sample.dasha.mahadashas.length, 9);
      for (final PeriodReading m in sample.dasha.mahadashas) {
        for (final PeriodReading a in m.children) {
          expect(a.level, 2);
          for (final PeriodReading c in a.children) {
            expect(c.level, 3);
          }
        }
      }
    });
  });

  group('language', () {
    test('every piece of text is complete in both languages', () {
      for (final Phaladesh p in every) {
        for (final Bi text in p.texts) {
          expect(text.en.trim(), isNotEmpty);
          expect(text.hi.trim(), isNotEmpty);
          expect(text.en, isNot(text.hi));
        }
      }
      for (final Bi text in sample.gochar(now: now).texts) {
        expect(text.isComplete, isTrue);
      }
    });

    test('Hindi is written in Devanagari and English has none', () {
      for (final Phaladesh p in every) {
        for (final Bi text in p.texts) {
          expect(devanagari.hasMatch(text.hi), isTrue, reason: text.hi);
          expect(
            latin.hasMatch(text.hi),
            isFalse,
            reason: 'Latin letters in Hindi: ${text.hi}',
          );
          expect(
            devanagari.hasMatch(text.en),
            isFalse,
            reason: 'Devanagari in English: ${text.en}',
          );
        }
      }
      for (final Bi text in sample.gochar(now: now).texts) {
        expect(latin.hasMatch(text.hi), isFalse, reason: text.hi);
      }
    });

    test('no sentence is left unfinished or doubled', () {
      for (final Bi text in sample.texts) {
        expect(text.en, isNot(contains('  ')), reason: text.en);
        expect(text.hi, isNot(contains('  ')), reason: text.hi);
        expect(text.en, isNot(contains('null')), reason: text.en);
        expect(text.en, isNot(contains(r'$')), reason: text.en);
        expect(text.hi, isNot(contains(r'$')), reason: text.hi);
      }
    });

    test(
      'dates are written the way a person writes them, in both languages',
      () {
        // 22:00 UTC is already the next morning in India.
        final Bi date = phalaDate(DateTime.utc(2031, 8, 14, 22), ist);
        expect(date.en, '15 Aug 2031');
        expect(date.hi, '15 अगस्त 2031');
      },
    );
  });

  group('what the app refuses to predict', () {
    test('the scanners themselves catch what they are meant to catch', () {
      for (final String bad in <String>[
        'the death of a parent',
        'a long illness',
        'pregnancy is likely',
        'a court case',
        'good for exams',
        'invest in property',
        'stock market gains',
        'the lottery',
        'a legal dispute',
      ]) {
        expect(refusedEnglish.hasMatch(bad), isTrue, reason: bad);
      }
      for (final String fine in <String>[
        'courtesy to your partner',
        'for example',
        'a diet of patience',
        'debts and rivals',
        'children and creative work',
      ]) {
        expect(refusedEnglish.hasMatch(fine), isFalse, reason: fine);
      }
      for (final String doom in <String>[
        'doomed',
        'a disaster',
        'misfortune',
      ]) {
        expect(doomEnglish.hasMatch(doom), isTrue, reason: doom);
      }
    });

    test('the refused subjects never appear, in either language', () {
      for (final Phaladesh p in every) {
        for (final Bi text in p.texts) {
          expect(
            refusedEnglish.hasMatch(text.en),
            isFalse,
            reason: refusedEnglish.firstMatch(text.en)?.group(0) ?? text.en,
          );
          for (final String stem in refusedHindi) {
            expect(text.hi, isNot(contains(stem)), reason: text.hi);
          }
        }
      }
      for (final Bi text in sample.gochar(now: now).texts) {
        expect(refusedEnglish.hasMatch(text.en), isFalse, reason: text.en);
        for (final String stem in refusedHindi) {
          expect(text.hi, isNot(contains(stem)), reason: text.hi);
        }
      }
    });

    test('a hard period is described by what it asks, never as doom', () {
      int demanding = 0;
      for (final Phaladesh p in every) {
        for (final Bi text in p.texts) {
          expect(doomEnglish.hasMatch(text.en), isFalse, reason: text.en);
        }
        void walk(PeriodReading r) {
          if (r.tone == Tone.demanding) {
            demanding++;
            expect(r.asks.en, contains('not as a verdict'));
            expect(r.asks.en, contains('asks you to'));
            expect(r.asks.hi, contains('फ़ैसला नहीं'));
          }
          r.children.forEach(walk);
        }

        p.dasha.mahadashas.forEach(walk);
      }
      expect(demanding, greaterThan(0), reason: 'the sweep met hard periods');
    });

    test('an affliction always carries its classical relief', () {
      int strained = 0;
      for (final Phaladesh p in every) {
        for (final GrahaStanding st in p.context.standing.values) {
          final PlacedGraha g = st.placed;
          // A natural malefic in the 6th and Ketu in the 12th are placements
          // the tradition counts as easy, so they are not read as strained.
          final bool easyPlace =
              (!isBenefic(p.context.kundli, g.graha) && g.house == 6) ||
              (g.graha == Graha.ketu && g.house == 12);
          final bool afflicted =
              g.dignity == Dignity.debilitated ||
              g.dignity == Dignity.enemy ||
              g.isCombust ||
              (const <int>[6, 8, 12].contains(g.house) && !easyPlace);
          if (afflicted) {
            strained++;
            expect(
              st.relief,
              isNotNull,
              reason: '${g.graha.name} in house ${g.house} has no relief note',
            );
          }
        }
        for (final BhavaReading b in p.bhavas) {
          if (const <int>[6, 8, 12].contains(b.lordHouse)) {
            expect(b.relief, isNotNull, reason: 'house ${b.house}');
          }
        }
      }
      expect(strained, greaterThan(0));
    });
  });

  group('bhava phala', () {
    test('a lord in a kendra or trikona strengthens, 6/8/12 afflicts', () {
      int kendra = 0, dusthana = 0, protects = 0, twelfth = 0;
      for (final Phaladesh p in every) {
        for (final BhavaReading b in p.bhavas) {
          final String text = b.reading.en;
          if (const <int>[1, 4, 5, 7, 9, 10].contains(b.lordHouse)) {
            kendra++;
            expect(text, contains('strengthens its house'));
            expect(text, isNot(contains('strains its house')));
          }
          if (const <int>[6, 8, 12].contains(b.lordHouse)) {
            dusthana++;
            expect(text, contains('strains its house'));
            expect(text, isNot(contains('strengthens its house')));
          }
          if (const <Dignity>[
            Dignity.own,
            Dignity.exalted,
            Dignity.moolatrikona,
          ].contains(b.lordDignity)) {
            protects++;
            expect(text, contains('own or exaltation sign protects'));
          } else {
            expect(text, isNot(contains('own or exaltation sign protects')));
          }
          // The 12th from a house is the house before it.
          final int twelfthFrom = ((b.house + 10) % 12) + 1;
          if (b.lordHouse == twelfthFrom) {
            twelfth++;
            expect(text, contains('12th from its own house'));
          } else {
            expect(text, isNot(contains('12th from its own house')));
          }
        }
      }
      expect(kendra, greaterThan(0));
      expect(dusthana, greaterThan(0));
      expect(protects, greaterThan(0));
      expect(twelfth, greaterThan(0));
    });

    test(
      'a house is read from its sign, its lord, its occupants and its aspects',
      () {
        for (final Phaladesh p in every) {
          final Kundli k = p.context.kundli;
          for (final BhavaReading b in p.bhavas) {
            expect(b.sign.index, k.signOfHouse(b.house));
            expect(b.lord, rashiInfo(b.sign).lord);
            expect(b.lordHouse, k.grahas[b.lord]!.house);
            expect(
              b.occupants,
              unorderedEquals(
                k.grahasInHouse(b.house).map((PlacedGraha g) => g.graha),
              ),
            );
            // Nothing aspects a sign from inside it.
            for (final Graha a in b.aspectedBy) {
              expect(k.grahas[a]!.rashi, isNot(b.sign));
            }
          }
        }
      },
    );

    test('Jupiter on a house is read as protective', () {
      bool seen = false;
      for (final Phaladesh p in every) {
        final PlacedGraha jupiter = p.context.kundli.grahas[Graha.jupiter]!;
        final bool kind =
            jupiter.dignity != Dignity.debilitated && !jupiter.isCombust;
        for (final BhavaReading b in p.bhavas) {
          if (b.aspectedBy.contains(Graha.jupiter)) {
            if (kind) {
              seen = true;
              expect(b.reading.en, contains('Jupiter’s aspect'));
            } else {
              // Jupiter fallen or combust is not read as a protector.
              expect(b.reading.en, isNot(contains('Jupiter’s aspect')));
            }
          }
        }
      }
      expect(seen, isTrue);
    });
  });

  group('graha phala and functional nature', () {
    test('the yogakaraka of each lagna is the classical one', () {
      const Map<Rashi, Graha> yogakaraka = <Rashi, Graha>{
        Rashi.vrishabha: Graha.saturn,
        Rashi.tula: Graha.saturn,
        Rashi.karka: Graha.mars,
        Rashi.simha: Graha.mars,
        Rashi.makara: Graha.venus,
        Rashi.kumbha: Graha.venus,
      };
      for (final Phaladesh p in every) {
        final Rashi lagna = p.context.kundli.lagnaRashi;
        for (final Graha g in <Graha>[
          Graha.sun,
          Graha.moon,
          Graha.mars,
          Graha.mercury,
          Graha.jupiter,
          Graha.venus,
          Graha.saturn,
        ]) {
          final bool isYk =
              p.context.of(g).nature == FunctionalNature.yogakaraka;
          expect(
            isYk,
            yogakaraka[lagna] == g,
            reason: '${g.name} for ${lagna.name}',
          );
        }
      }
    });

    test('the lagna lord is never a functional malefic', () {
      for (final Phaladesh p in every) {
        final Kundli k = p.context.kundli;
        final Graha lord = rashiInfo(k.lagnaRashi).lord;
        expect(
          p.context.of(lord).nature,
          isNot(FunctionalNature.malefic),
          reason: k.lagnaRashi.name,
        );
      }
    });

    test('lords of the 6th and 8th that rule nothing better are malefic', () {
      for (final Phaladesh p in every) {
        final Kundli k = p.context.kundli;
        for (final Graha g in <Graha>[
          Graha.mars,
          Graha.mercury,
          Graha.jupiter,
          Graha.venus,
          Graha.saturn,
        ]) {
          final List<int> ruled = p.context.of(g).ruled;
          final bool good = ruled.any(const <int>[1, 4, 5, 7, 9, 10].contains);
          if (!good && ruled.contains(6)) {
            expect(
              p.context.of(g).nature,
              FunctionalNature.malefic,
              reason: '${g.name} rules $ruled for ${k.lagnaRashi.name}',
            );
          }
        }
      }
    });

    test('a node is never read as aspected by the other node', () {
      for (final Phaladesh p in every) {
        expect(
          p.context.of(Graha.rahu).aspectedBy,
          isNot(contains(Graha.ketu)),
        );
        expect(
          p.context.of(Graha.ketu).aspectedBy,
          isNot(contains(Graha.rahu)),
        );
      }
    });

    test('Kaal Sarpa claims no classical cancellation', () {
      // Find a chart that carries it; the yoga check alone is cheap.
      Kundli? found;
      for (int i = 0; i < 400 && found == null; i++) {
        final Kundli k = chartAt(
          DateTime(1950 + i % 60, 1 + i % 12, 1 + i % 27, i % 24),
        );
        if (findYogas(k).any((YogaFinding y) => y.key == 'kaal_sarpa')) {
          found = k;
        }
      }
      expect(found, isNotNull, reason: 'no Kaal Sarpa chart in the sweep');
      final List<GrahaReading> grahas = grahaPhala(PhalaContext(found!));
      final List<Bi> notes = <Bi>[
        for (final GrahaReading g in grahas)
          for (final Bi y in g.yogas)
            if (y.en.startsWith('Kaal Sarpa')) y,
      ];
      expect(notes, isNotEmpty);
      for (final Bi y in notes) {
        expect(y.en, contains('not a named yoga'));
        expect(y.en, isNot(contains('cancelled')));
      }
    });

    test('the nodes are read through the lord of the sign they stand in', () {
      for (final Phaladesh p in every) {
        for (final Graha node in <Graha>[Graha.rahu, Graha.ketu]) {
          final GrahaStanding st = p.context.of(node);
          expect(st.ruled, isEmpty);
          expect(st.reader, rashiInfo(st.placed.rashi).lord);
          expect(st.nature, p.context.of(st.reader).nature);
          expect(st.bala, isNull);
        }
      }
    });

    test('neecha bhanga fires exactly when the classical condition holds', () {
      int debilitated = 0;
      int cancelled = 0;
      for (int year = 1940; year < 2020; year += 3) {
        final Kundli k = chartAt(DateTime(year, 1 + year % 12, 9, year % 24));
        final PhalaContext ctx = PhalaContext(k);
        for (final Graha g in Graha.values) {
          final PlacedGraha p = k.grahas[g]!;
          if (p.dignity != Dignity.debilitated) {
            expect(ctx.of(g).neechaBhanga, isNull);
            continue;
          }
          debilitated++;
          final Graha fallLord = rashiInfo(p.rashi).lord;
          final Graha exaltLord = rashiInfo(
            Rashi.values[(grahaInfo(g).exaltationDegree! / 30).floor() % 12],
          ).lord;
          bool kendraFrom(int sign) =>
              const <int>[
                1,
                4,
                7,
                10,
              ].contains(houseFrom(k.lagnaRashi.index, sign)) ||
              const <int>[
                1,
                4,
                7,
                10,
              ].contains(houseFrom(k.moonRashi.index, sign));
          final bool expected = <Graha>{fallLord, exaltLord}
              .where((Graha c) => c != g)
              .any((Graha c) => kendraFrom(signOf(k, c)));
          expect(
            ctx.of(g).neechaBhanga != null,
            expected,
            reason: '${g.name} fell in ${p.rashi.name} in $year',
          );
          if (expected) cancelled++;
        }
      }
      expect(debilitated, greaterThan(5));
      expect(cancelled, greaterThan(0));
    });

    test(
      'a graha is modulated by dignity, combustion, retrogression and company',
      () {
        for (final Phaladesh p in every) {
          for (final GrahaReading g in p.grahas) {
            final PlacedGraha placed = p.context.kundli.grahas[g.graha]!;
            expect(g.house, placed.house);
            expect(g.sign, placed.rashi);
            expect(g.dignity, placed.dignity);
            expect(g.isCombust, placed.isCombust);
            expect(g.isRetrograde, placed.isRetrograde);
            if (placed.isCombust) {
              expect(g.reading.en, contains('combust'));
            }
            if (placed.isRetrograde) {
              expect(g.reading.en, contains('retrograde'));
            }
            if (g.companions.isNotEmpty) {
              expect(g.reading.en, contains('company'));
            }
          }
        }
      },
    );

    test('yogas carry their classical cancellation into the graha reading', () {
      bool sawMangal = false;
      for (final Phaladesh p in every) {
        final GrahaReading mars = p.grahas.firstWhere(
          (GrahaReading g) => g.graha == Graha.mars,
        );
        for (final Bi y in mars.yogas) {
          if (y.en.startsWith('Mangal dosha')) {
            sawMangal = true;
            expect(
              y.en.contains('cancel'),
              isTrue,
              reason: 'a dosha must name its cancellation',
            );
          }
        }
      }
      expect(sawMangal, isTrue);
    });
  });

  group('dasha phala', () {
    test('the antardasha lord is counted from the mahadasha lord', () {
      for (final Phaladesh p in every) {
        final Kundli k = p.context.kundli;
        for (final PeriodReading maha in p.dasha.mahadashas) {
          expect(maha.placeFromParent, isNull);
          expect(maha.modifier, isNull);
          for (final PeriodReading antar in maha.children) {
            expect(
              antar.placeFromParent,
              houseFrom(signOf(k, maha.lord), signOf(k, antar.lord)),
            );
            expect(antar.parentLord, maha.lord);
            expect(antar.modifier, isNotNull);
            expect(antar.relation, mutualRelation(antar.lord, maha.lord));
            for (final PeriodReading praty in antar.children) {
              expect(
                praty.placeFromParent,
                houseFrom(signOf(k, antar.lord), signOf(k, praty.lord)),
              );
              expect(praty.parentLord, antar.lord);
              expect(praty.grandparentLord, maha.lord);
            }
          }
        }
      }
    });

    test('children tile their parent period exactly', () {
      for (final PeriodReading maha in sample.dasha.mahadashas) {
        expect(maha.children.first.startJdUt, maha.startJdUt);
        expect(maha.children.last.endJdUt, maha.endJdUt);
        for (final PeriodReading antar in maha.children) {
          expect(antar.children.first.startJdUt, antar.startJdUt);
          expect(antar.children.last.endJdUt, antar.endJdUt);
          for (int i = 0; i < antar.children.length - 1; i++) {
            expect(antar.children[i].endJdUt, antar.children[i + 1].startJdUt);
          }
        }
      }
    });

    test('a period is read against the one before it and the one after it', () {
      final List<PeriodReading> mahas = sample.dasha.mahadashas;
      expect(mahas.first.context.en, contains('already running at birth'));
      for (int i = 1; i < mahas.length; i++) {
        expect(mahas[i].context.en, contains('It follows'));
        expect(
          mahas[i].context.en,
          contains(grahaInfo(mahas[i - 1].lord).english),
        );
      }
      for (int i = 0; i < mahas.length - 1; i++) {
        expect(
          mahas[i].context.en,
          contains(grahaInfo(mahas[i + 1].lord).english),
        );
      }
    });

    test('an antardasha reading names the mahadasha it sits inside', () {
      for (final PeriodReading maha in sample.dasha.mahadashas) {
        for (final PeriodReading antar in maha.children) {
          expect(
            antar.summary.en,
            contains('Inside the ${grahaInfo(maha.lord).english} mahadasha'),
          );
          expect(antar.context.en, contains('mahadasha'));
        }
      }
    });

    test(
      'the lord’s shadbala, bindus and functional nature are in the basis',
      () {
        for (final PeriodReading maha in sample.dasha.mahadashas) {
          final String basis = maha.basis.map((Bi b) => b.en).join('\n');
          expect(basis, contains('For a Kanya lagna'));
          if (maha.lord != Graha.rahu && maha.lord != Graha.ketu) {
            expect(basis, contains('Shadbala'));
            expect(basis, contains('Ashtakavarga'));
          } else {
            expect(basis, contains('Sarvashtakavarga'));
          }
        }
      },
    );

    test('a graha is not counted from itself or weighed against itself', () {
      int same = 0;
      for (final Phaladesh p in every) {
        for (final PeriodReading maha in p.dasha.mahadashas) {
          for (final PeriodReading antar in maha.children) {
            if (antar.lord != maha.lord) continue;
            same++;
            expect(antar.relation, Relation.friend);
            expect(antar.modifier!.en, contains('plainest form'));
            expect(antar.modifier!.en, isNot(contains('neutral')));
            expect(antar.modifier!.en, isNot(contains('stands in')));
            final String basis = antar.basis.map((Bi b) => b.en).join('\n');
            expect(basis, isNot(contains('place from')));
          }
        }
      }
      expect(same, greaterThan(0));
    });

    test('headlines name the part of life, not the bare sensitive house', () {
      const List<String> bare = <String>['marriage', 'children'];
      for (final Phaladesh p in every) {
        for (final TimelineWindow w in p.timeline.windows) {
          final String text = '${w.headline.en} ${w.expect.en}'.toLowerCase();
          for (final String word in bare) {
            expect(text, isNot(contains(word)), reason: '${w.index} $word');
          }
        }
      }
    });

    test('a child’s windows ask for care, not adult tasks', () {
      final TimelineWindow first = sample.timeline.windows.first;
      expect(first.asks.en, contains('family'));
      expect(first.asks.en, isNot(contains('temper')));
      final TimelineWindow adult = sample.timeline.windows.firstWhere(
        (TimelineWindow w) => w.ageStartYears > 30,
      );
      expect(adult.asks.en, contains('you'));
      expect(adult.asks, adult.period.asks);
    });

    test('friend, neutral and enemy are taken both ways', () {
      expect(mutualRelation(Graha.sun, Graha.moon), Relation.friend);
      expect(mutualRelation(Graha.sun, Graha.saturn), Relation.enemy);
      expect(mutualRelation(Graha.venus, Graha.sun), Relation.enemy);
      // Mercury counts the Moon an enemy but the Moon counts Mercury a friend.
      expect(mutualRelation(Graha.moon, Graha.mercury), Relation.neutral);
      // The Sun is neutral to Mercury, which is a friend of the Sun.
      expect(mutualRelation(Graha.sun, Graha.mercury), Relation.friend);
      // The texts differ about the nodes, so they are neutral to all.
      expect(mutualRelation(Graha.rahu, Graha.sun), Relation.neutral);
      // A graha is its own friend.
      expect(mutualRelation(Graha.saturn, Graha.saturn), Relation.friend);
    });

    test('tones are spread, not stuck on one verdict', () {
      final Set<Tone> seen = <Tone>{};
      for (final Phaladesh p in every) {
        for (final TimelineWindow w in p.timeline.windows) {
          seen.add(w.tone);
        }
      }
      expect(seen, containsAll(Tone.values));
    });

    test('computing a chart twice gives the same readings', () {
      final Phaladesh again = computePhaladesh(
        chartAt(DateTime(1988, 8, 14, 9, 35)),
      );
      final List<String> a = sample.texts.map((Bi b) => b.en).toList();
      final List<String> b = again.texts.map((Bi b) => b.en).toList();
      expect(b, a);
    });
  });

  group('gochar phala', () {
    late GocharPhala gochar;
    setUpAll(() => gochar = sample.gochar(now: now));

    test(
      'reads the four slow grahas, each with the dates it enters and leaves',
      () {
        expect(gochar.readings.map((GocharReading r) => r.graha), gocharGrahas);
        for (final GocharReading r in gochar.readings) {
          expect(r.entered, isNotNull, reason: r.graha.name);
          expect(r.leaves, isNotNull, reason: r.graha.name);
          expect(r.entered!.isBefore(now), isTrue, reason: r.graha.name);
          expect(r.leaves!.isAfter(now), isTrue, reason: r.graha.name);
          expect(r.entered!.isBefore(r.leaves!), isTrue);
        }
      },
    );

    test('the dates are the moments the sign really changes', () {
      final Kundli k = sample.context.kundli;
      int signAt(Graha g, DateTime t) {
        final Instant i = Instant.fromUtc(t);
        return (toSidereal(
                      positionOf(g, i).tropicalLongitude,
                      k.ayanamsa,
                      i.centuriesTt,
                    ) /
                    30)
                .floor() %
            12;
      }

      for (final GocharReading r in gochar.readings) {
        const Duration hour = Duration(hours: 1);
        expect(signAt(r.graha, r.entered!.add(hour)), r.sign.index);
        expect(signAt(r.graha, r.entered!.subtract(hour)), isNot(r.sign.index));
        expect(signAt(r.graha, r.leaves!.subtract(hour)), r.sign.index);
        expect(signAt(r.graha, r.leaves!.add(hour)), isNot(r.sign.index));
      }
    });

    test(
      'slow-planet ingresses land on the dates published panchangs give',
      () {
        // Saturn into Meena on 29 March 2025, Rahu into Kumbha on 18 May 2025,
        // Jupiter into Mithuna on 14 May 2025 and into Karka on 2 June 2026.
        // These guard the frame: with precession applied twice, Saturn and
        // Jupiter arrived two to three days early.
        void expectIngress(Graha g, DateTime probe, int sign, DateTime date) {
          final SignStay stay = signStayAt(g, probe, Ayanamsa.lahiri);
          expect(stay.sign, sign, reason: g.name);
          expect(
            stay.entered!.difference(date).inHours.abs(),
            lessThan(24),
            reason: '${g.name} entered on ${stay.entered}',
          );
        }

        expectIngress(
          Graha.saturn,
          DateTime.utc(2025, 8, 1),
          11,
          DateTime.utc(2025, 3, 29),
        );
        expectIngress(
          Graha.rahu,
          DateTime.utc(2025, 8, 1),
          10,
          DateTime.utc(2025, 5, 18),
        );
        expectIngress(
          Graha.jupiter,
          DateTime.utc(2025, 7, 1),
          2,
          DateTime.utc(2025, 5, 14),
        );
        expectIngress(
          Graha.jupiter,
          DateTime.utc(2026, 7, 1),
          3,
          DateTime.utc(2026, 6, 2),
        );
      },
    );

    test('houses are counted from the Moon and from the lagna', () {
      final Kundli k = sample.context.kundli;
      for (final GocharReading r in gochar.readings) {
        expect(r.houseFromMoon, houseFrom(k.moonRashi.index, r.sign.index));
        expect(r.houseFromLagna, houseFrom(k.lagnaRashi.index, r.sign.index));
        expect(r.area.house, r.houseFromLagna);
      }
    });

    test('the dasha promises and the transit delivers', () {
      expect(gochar.principle.en, contains('promises'));
      expect(gochar.principle.en, contains('delivers'));
      expect(gochar.running.length, 3);
      final Set<int> dashaHouses = <int>{
        for (final PeriodReading p in gochar.running)
          for (final LifeArea a in p.areas) a.house,
      };
      for (final GocharReading r in gochar.readings) {
        expect(r.landsOnDasha, dashaHouses.contains(r.houseFromLagna));
        expect(
          r.reading.en,
          contains(
            r.landsOnDasha ? 'where the dasha promises' : 'outside the areas',
          ),
        );
      }
    });

    test(
      'Saturn’s long tests are named only when the Moon’s count asks for them',
      () {
        final GocharReading saturn = gochar.readings.firstWhere(
          (GocharReading r) => r.graha == Graha.saturn,
        );
        final bool dhaiya =
            saturn.houseFromMoon == 4 || saturn.houseFromMoon == 8;
        expect(saturn.reading.en.contains('dhaiya'), dhaiya);
      },
    );
  });
}
