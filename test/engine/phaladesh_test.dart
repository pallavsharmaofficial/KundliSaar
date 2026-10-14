import 'dart:io';

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
import 'package:kundlisaar/engine/jyotish/remedies.dart';
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

/// Words that would turn the strength band into a chance of something
/// happening. The band counts agreeing chart factors and nothing else.
final RegExp chanceEnglish = RegExp(
  r'(%|\bper ?cent\w*|probab\w*|likelihood|\blikely\b|\bunlikely\b|\bchances?\b|\b(the|good|long|better|even) odds\b|\bodds (of|are|that|on)\b)',
  caseSensitive: false,
);

const List<String> chanceHindi = <String>[
  '%',
  'प्रतिशत',
  'फ़ीसदी',
  'फीसदी',
  'प्रायिकता',
  'संभावना',
  'संभावित',
  'प्रोबेबिलिटी',
];

/// Anything that must be bought, paid for or worn, or that sells fear.
final RegExp buyingEnglish = RegExp(
  r'\b(buy\w*|bought|purchas\w*|price\w*|cost\w*|pay|pays|paid|payment\w*|fees?|rupees?|rs|sell\w*|sold|shop\w*|vendors?|gems?|gemstones?|stones?|ruby|rubies|pearls?|corals?|emeralds?|sapphires?|diamonds?|hessonite|topaz|cat.s eye|amulets?|talismans?|pendants?|yantras?|rings?|priests?|pandits?|donat\w*|ratti)\b',
  caseSensitive: false,
);

const List<String> buyingHindi = <String>[
  'खरीद',
  'कीमत',
  'मूल्य',
  'रुपय',
  'रुपए',
  '₹',
  'शुल्क',
  'बेचन',
  'बेचें',
  'बिक्री',
  'रत्न',
  'अंगूठी',
  'यंत्र',
  'ताबीज',
  'पंडित',
  'पुजारी',
  'दक्षिणा',
  'माणिक्य',
  'पुखराज',
  'नीलम',
  'गोमेद',
  'लहसुनिया',
  'मूंगा',
  'पन्ना',
  'मोती',
  'हीरा',
];

/// A remedy offered as the tradition's practice must not slip into promising
/// that something will change.
final RegExp promisesEnglish = RegExp(
  r'\b(will|shall|cure[sd]?|heal\w*|remov\w*|ward\w*|guarantee\w*|ensure\w*|solve\w*|fix(es)?|certainly|definitely)\b',
  caseSensitive: false,
);

const List<String> promisesHindi = <String>[
  'होगा',
  'होगी',
  'होंगे',
  'जाएगा',
  'जाएगी',
  'मिलेगा',
  'मिलेगी',
  'मिटेगा',
  'पड़ेगा',
  'गारंटी',
  'पक्का फल',
];

final RegExp monthName = RegExp(
  r'\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept?|oct|nov|dec)\b|जनवरी|फ़रवरी|मार्च|अप्रैल|जुलाई|अगस्त|सितंबर|अक्टूबर|नवंबर|दिसंबर',
  caseSensitive: false,
);

/// Every reading of a chart that carries a band, tends and remedies.
List<IndicatedReading> indicatedReadings(Phaladesh p, [GocharPhala? gochar]) {
  final List<IndicatedReading> out = <IndicatedReading>[
    ...p.bhavas,
    ...p.grahas,
  ];
  void walk(PeriodReading r) {
    out.add(r);
    r.children.forEach(walk);
  }

  p.dasha.mahadashas.forEach(walk);
  out.addAll(p.timeline.windows);
  if (gochar != null) out.addAll(gochar.readings);
  return out;
}

/// A period is difficult when its tone asks for effort, or when its lord
/// stands in the 6th, 8th or 12th from the lord of the period around it.
bool isDifficultPeriod(PeriodReading p) =>
    p.tone == Tone.demanding ||
    (p.parentLord != null &&
        p.lord != p.parentLord &&
        const <int>[6, 8, 12].contains(p.placeFromParent));

/// A finding the rules found strained or demanding, and so one that calls for
/// a remedy.
bool isAdverse(IndicatedReading r) => switch (r) {
  BhavaReading b => b.relief != null || b.tone == Tone.demanding,
  GrahaReading g => g.relief != null || g.tone == Tone.demanding,
  PeriodReading p => isDifficultPeriod(p),
  TimelineWindow w => isDifficultPeriod(w.period),
  GocharReading c => !c.favourable || c.tone == Tone.demanding,
  _ => false,
};

IndicatorFactor factor(bool eases, {bool firm = true}) => IndicatorFactor(
  kind: FactorKind.placement,
  text: Bi(
    'factor ${eases ? 'for' : 'against'} $firm',
    'कारक ${eases ? 'पक्ष' : 'विपक्ष'}',
  ),
  eases: eases,
  firm: firm,
  grahas: const <Graha>[Graha.sun],
);

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

  group('strength of indication', () {
    late GocharPhala gochar;
    late List<IndicatedReading> all;
    setUpAll(() {
      gochar = sample.gochar(now: now);
      all = <IndicatedReading>[
        for (final Phaladesh p in every) ...indicatedReadings(p),
        ...indicatedReadings(sample, gochar),
        for (final Phaladesh p in every.take(6)) ...p.gochar(now: now).readings,
      ];
    });

    test('every reading carries a band whose count is the factors listed', () {
      expect(all.length, greaterThan(5000));
      for (final IndicatedReading r in all) {
        final Indication ind = r.indication;
        final int a = ind.agreeing.length;
        final int d = ind.disagreeing.length;
        expect(ind.total, a + d, reason: r.headline.en);
        expect(ind.label.isComplete, isTrue);
        expect(ind.summary.en, startsWith(ind.label.en));
        expect(ind.summary.hi, startsWith(ind.label.hi));
        if (ind.band == IndicationBand.mixed) {
          expect(ind.count.en, startsWith('$a '), reason: ind.count.en);
          expect(ind.count.en, endsWith(', $d to effort'));
          expect(ind.count.hi, contains('$a कारक सहारे की ओर'));
          expect(ind.count.hi, contains('$d मेहनत की ओर'));
        } else {
          final int n = a + d;
          expect(
            ind.count.en,
            '$a of $n ${n == 1 ? 'factor agrees' : 'factors agree'}',
          );
          expect(ind.count.hi, '$n में से $a कारक सहमत');
        }
        // The list on screen is exactly the list that was counted, and no
        // fact is counted twice.
        final List<IndicatorFactor> listed = <IndicatorFactor>[
          ...ind.agreeing,
          ...ind.disagreeing,
        ];
        expect(
          listed.map((IndicatorFactor f) => f.text.en).toSet().length,
          a + d,
          reason: r.headline.en,
        );
        for (final IndicatorFactor f in listed) {
          expect(f.text.isComplete, isTrue);
          expect(f.grahas, isNotEmpty, reason: f.text.en);
          expect(
            ind.texts.any((Bi t) => identical(t, f.text)),
            isTrue,
            reason: 'a counted factor is shown',
          );
        }
      }
    });

    test('agreeing factors point the way of the tone, the rest the other', () {
      for (final IndicatedReading r in all) {
        final Indication ind = r.indication;
        final bool effort = ind.direction == Tone.demanding;
        for (final IndicatorFactor f in ind.agreeing) {
          expect(f.eases, !effort, reason: '${r.headline.en}: ${f.text.en}');
        }
        for (final IndicatorFactor f in ind.disagreeing) {
          expect(f.eases, effort, reason: '${r.headline.en}: ${f.text.en}');
        }
      }
    });

    test('the scale is the one the docs name', () {
      Indication of(Tone t, int agree, int disagree, {int firm = 99}) {
        final bool eases = t != Tone.demanding;
        return Indication(t, <IndicatorFactor>[
          for (int i = 0; i < agree; i++) factor(eases, firm: i < firm),
          for (int i = 0; i < disagree; i++) factor(!eases),
        ]);
      }

      expect(of(Tone.supportive, 5, 0).band, IndicationBand.strong);
      expect(of(Tone.supportive, 4, 1).band, IndicationBand.strong);
      expect(of(Tone.demanding, 4, 1).band, IndicationBand.strong);
      expect(of(Tone.supportive, 4, 1, firm: 1).band, IndicationBand.moderate);
      expect(of(Tone.supportive, 4, 2).band, IndicationBand.moderate);
      expect(of(Tone.supportive, 3, 0).band, IndicationBand.moderate);
      expect(of(Tone.supportive, 3, 1).band, IndicationBand.moderate);
      expect(of(Tone.supportive, 3, 2).band, IndicationBand.weak);
      expect(of(Tone.supportive, 2, 0).band, IndicationBand.weak);
      expect(of(Tone.demanding, 2, 2).band, IndicationBand.weak);
      expect(of(Tone.supportive, 1, 0).band, IndicationBand.weak);
      expect(of(Tone.supportive, 0, 0).band, IndicationBand.weak);
      expect(of(Tone.mixed, 3, 3).band, IndicationBand.mixed);
      expect(of(Tone.mixed, 6, 0).band, IndicationBand.mixed);
      final Indication four = of(Tone.supportive, 4, 1);
      expect(four.summary.en, 'Strong indication — 4 of 5 factors agree');
      expect(four.summary.hi, 'प्रबल संकेत — 5 में से 4 कारक सहमत');
    });

    test('a reading resting on a single factor is never labelled strong', () {
      final Indication firm = Indication(Tone.supportive, <IndicatorFactor>[
        factor(true),
      ]);
      expect(firm.band, isNot(IndicationBand.strong));
      expect(firm.band, IndicationBand.weak);
      expect(firm.caution!.en, contains('single factor'));
      expect(firm.caution!.en, isNot(contains('light')));
      expect(firm.caution!.hi, contains('एक कारक'));
      final Indication light = Indication(Tone.supportive, <IndicatorFactor>[
        factor(true, firm: false),
      ]);
      expect(light.band, IndicationBand.weak);
      expect(light.caution!.en, contains('single factor'));
      expect(light.caution!.en, contains('a light one'));
      expect(light.caution!.hi, contains('हल्का'));
      // A mixed reading with one factor is not dressed up either, and a
      // reading with none says that nothing but the app's weighing is behind it.
      final Indication lone = Indication(Tone.mixed, <IndicatorFactor>[
        factor(false),
      ]);
      expect(lone.caution!.en, contains('single factor'));
      final Indication none = Indication(Tone.supportive, <IndicatorFactor>[]);
      expect(none.caution!.en, contains('No chart factor'));

      int single = 0;
      for (final IndicatedReading r in all) {
        final Indication ind = r.indication;
        if (ind.band == IndicationBand.mixed) continue;
        if (ind.agreeing.length <= 2) {
          expect(ind.band, IndicationBand.weak, reason: r.headline.en);
        }
        if (ind.agreeing.length == 1) {
          single++;
          expect(ind.caution, isNotNull, reason: r.headline.en);
          expect(ind.caution!.en, contains('single factor'));
        }
        if (ind.band == IndicationBand.strong) {
          expect(ind.agreeing.length, greaterThanOrEqualTo(4));
          expect(ind.disagreeing.length, lessThanOrEqualTo(1));
          expect(ind.firmAgreeing, greaterThanOrEqualTo(2));
        }
        if (ind.band == IndicationBand.moderate) {
          expect(ind.agreeing.length, greaterThanOrEqualTo(3));
          expect(
            ind.agreeing.length - ind.disagreeing.length,
            greaterThanOrEqualTo(2),
          );
        }
      }
      expect(
        single,
        greaterThan(0),
        reason: 'the sweep met readings that rest on one factor',
      );
    });

    test('the sweep meets every band, so the scale tells readings apart', () {
      final Set<IndicationBand> seen = <IndicationBand>{
        for (final IndicatedReading r in all) r.indication.band,
      };
      expect(seen, containsAll(IndicationBand.values));
    });

    test('a divided reading shows the split as it stands', () {
      final Indication split = Indication(Tone.mixed, <IndicatorFactor>[
        factor(true),
        factor(true),
        factor(true),
        factor(false),
        factor(false),
      ]);
      expect(split.band, IndicationBand.mixed);
      expect(split.count.en, '3 factors point to support, 2 to effort');
      expect(split.count.hi, '3 कारक सहारे की ओर, 2 मेहनत की ओर');
      expect(split.agreeHeading.en, 'Factors pointing to support');
      expect(split.disagreeHeading.en, 'Factors pointing to effort');
    });

    test('the factors mirror the numbers the engine already holds', () {
      for (final Phaladesh p in every) {
        for (final GrahaReading r in p.grahas) {
          final GrahaStanding st = p.context.of(r.graha);
          final List<IndicatorFactor> listed = <IndicatorFactor>[
            ...r.indication.agreeing,
            ...r.indication.disagreeing,
          ];
          Iterable<IndicatorFactor> of(FactorKind k) =>
              listed.where((IndicatorFactor f) => f.kind == k);
          final bool isNode = r.graha == Graha.rahu || r.graha == Graha.ketu;

          // Shadbala: present only where it is worked out, and on the side
          // of the engine's own comparison with the minimum.
          final BalaBreakdown? bala = st.bala;
          if (bala == null) {
            expect(of(FactorKind.shadbala), isEmpty, reason: r.graha.name);
          } else {
            expect(of(FactorKind.shadbala).length, 1, reason: r.graha.name);
            expect(
              of(FactorKind.shadbala).single.eases,
              bala.isStrong,
              reason: r.graha.name,
            );
            expect(
              of(FactorKind.shadbala).single.text.en,
              contains(bala.totalRupas.toStringAsFixed(1)),
            );
          }

          // Ashtakavarga: five or more bindus eases, three or fewer presses.
          final int? own = st.ownBindus;
          final Iterable<IndicatorFactor> av = of(FactorKind.ashtakavarga);
          expect(av.length, lessThanOrEqualTo(1), reason: r.graha.name);
          if (own != null && own >= 5) {
            expect(av.single.eases, isTrue);
            expect(av.single.text.en, contains('$own bindus'));
          }
          if (own != null && own <= 3) {
            expect(av.single.eases, isFalse);
            expect(av.single.text.en, contains('$own bindus'));
          }

          // Dignity: the engine's own placement decides it.
          final Dignity d = st.placed.dignity;
          final Iterable<IndicatorFactor> dig = of(FactorKind.dignity);
          if (d == Dignity.exalted ||
              d == Dignity.own ||
              d == Dignity.moolatrikona) {
            expect(dig.single.eases, isTrue, reason: r.graha.name);
          } else if (d == Dignity.debilitated) {
            expect(dig.single.eases, isFalse, reason: r.graha.name);
            // A cancelled fall is its own factor, pointing the other way.
            expect(
              of(
                FactorKind.relief,
              ).any((IndicatorFactor f) => f.text.en.contains('Neecha bhanga')),
              st.neechaBhanga != null,
            );
          } else if (d == Dignity.neutral || isNode) {
            expect(dig, isEmpty, reason: '${r.graha.name} ${d.name}');
          }

          // Combustion is a factor exactly when the engine says so.
          expect(
            of(FactorKind.condition).length,
            st.placed.isCombust ? 1 : 0,
            reason: r.graha.name,
          );
        }
      }
    });

    test('a house reads its factors from its lord, occupants and aspects', () {
      for (final Phaladesh p in every) {
        for (final BhavaReading b in p.bhavas) {
          final List<IndicatorFactor> fs = <IndicatorFactor>[
            ...b.indication.agreeing,
            ...b.indication.disagreeing,
          ];
          final bool kendraTrikona = const <int>[
            1,
            4,
            5,
            7,
            9,
            10,
          ].contains(b.lordHouse);
          final bool dusthana = const <int>[6, 8, 12].contains(b.lordHouse);
          final IndicatorFactor? place = fs
              .where(
                (IndicatorFactor f) =>
                    f.kind == FactorKind.placement &&
                    f.text.en.contains('lord of'),
              )
              .firstOrNull;
          if (kendraTrikona) {
            expect(place?.eases, isTrue, reason: 'house ${b.house}');
          } else if (dusthana) {
            expect(place?.eases, isFalse, reason: 'house ${b.house}');
          }
          // The sarvashtakavarga count decides its factor.
          final IndicatorFactor? av = fs
              .where(
                (IndicatorFactor f) =>
                    f.kind == FactorKind.ashtakavarga &&
                    f.text.en.contains('sarvashtakavarga'),
              )
              .firstOrNull;
          if (b.signBindus >= 30) expect(av?.eases, isTrue);
          if (b.signBindus <= 24) expect(av?.eases, isFalse);
          if (b.signBindus > 24 && b.signBindus < 30) expect(av, isNull);
          // A graha is only counted on a house it rules, sits in or looks at.
          for (final IndicatorFactor f in fs) {
            for (final Graha g in f.grahas) {
              expect(
                g == b.lord ||
                    b.occupants.contains(g) ||
                    b.aspectedBy.contains(g),
                isTrue,
                reason: 'house ${b.house}: ${g.name} in ${f.text.en}',
              );
            }
          }
        }
      }
    });

    test('the scale is named plainly, in the docs and for the screen', () {
      expect(indicationScaleNote.en, contains('not a classical measure'));
      expect(indicationScaleNote.en, contains('not a probability'));
      expect(indicationScaleNote.en, contains('own convention'));
      expect(indicationScaleNote.hi, contains('शास्त्रीय माप नहीं'));
      expect(indicationScaleNote.hi, contains('संभावना'));
      expect(indicationScaleNote.isComplete, isTrue);
      final String docs = File('docs/ENGINE.md').readAsStringSync();
      expect(docs, contains('Strength of indication'));
      expect(docs, contains('not a classical measure'));
      expect(docs, contains('not a probability'));
    });

    test('no reading speaks of a percentage or of the chance of anything', () {
      // The scanners must catch what they are meant to catch.
      for (final String bad in <String>[
        'a 65% chance of a job change',
        'probability of a promotion',
        'likely to move house',
        'the odds are good',
        'about 70 percent',
        'an unlikely outcome',
      ]) {
        expect(chanceEnglish.hasMatch(bad), isTrue, reason: bad);
      }
      for (final String fine in <String>[
        '4 of 5 factors agree',
        'Strong indication',
        'a single factor',
        'Questions of home tend to come up',
      ]) {
        expect(chanceEnglish.hasMatch(fine), isFalse, reason: fine);
      }
      void scan(Iterable<Bi> texts) {
        for (final Bi t in texts) {
          expect(chanceEnglish.hasMatch(t.en), isFalse, reason: t.en);
          for (final String stem in chanceHindi) {
            expect(t.hi, isNot(contains(stem)), reason: t.hi);
          }
        }
      }

      for (final Phaladesh p in every) {
        scan(p.texts);
      }
      scan(gochar.texts);
      for (final IndicatedReading r in all) {
        scan(r.indication.texts);
      }
    });

    test('Phaladesh carries the bands, the tendencies and the remedies', () {
      final Set<String> texts = sample.texts.map((Bi b) => b.en).toSet();
      expect(texts, contains(sample.bhavas.first.indication.summary.en));
      expect(texts, contains(sample.bhavas.first.tends.en));
      expect(texts, contains(remedyStance.en));
      for (final PeriodReading m in sample.dasha.mahadashas) {
        expect(texts, contains(m.indication.summary.en));
        expect(texts, contains(m.tends.en));
      }
    });
  });

  group('what tends to come up', () {
    late GocharPhala gochar;
    setUpAll(() => gochar = sample.gochar(now: now));

    const List<String> houseWords = <String>[
      'who you are',
      'money',
      'effort and initiative',
      'home and peace of mind',
      'learning, creative work and children',
      'daily work',
      'partnership',
      'change, shared resources',
      'purpose, guidance',
      'work, responsibility and standing',
      'income, friends',
      'expense, rest',
    ];

    List<(IndicatedReading, int)> everyTendency() {
      final List<(IndicatedReading, int)> out = <(IndicatedReading, int)>[];
      for (final Phaladesh p in every) {
        for (final BhavaReading b in p.bhavas) {
          out.add((b, b.house));
        }
        void walk(PeriodReading r) {
          out.add((r, r.area.house));
          r.children.forEach(walk);
        }

        p.dasha.mahadashas.forEach(walk);
      }
      for (final GocharReading r in gochar.readings) {
        out.add((r, r.houseFromLagna));
      }
      return out;
    }

    test('every house, every period and every transit carries it', () {
      for (final (IndicatedReading r, int house) in everyTendency()) {
        final Bi? tends = r.tends;
        expect(tends, isNotNull, reason: r.headline.en);
        expect(tends!.isComplete, isTrue);
        // It names the area of life the house or period concentrates on.
        expect(
          tends.en,
          contains(houseWords[house - 1]),
          reason: '${r.headline.en} house $house',
        );
        // It is a tendency, not a statement of fact.
        expect(tends.en, contains('tend'), reason: tends.en);
        expect(tends.hi, contains('अक्सर'), reason: tends.hi);
      }
    });

    test('a tendency is never an event, a forecast or a date', () {
      for (final (IndicatedReading r, _) in everyTendency()) {
        final Bi tends = r.tends!;
        expect(tends.en, isNot(matches(RegExp(r'\d'))), reason: tends.en);
        expect(tends.hi, isNot(matches(RegExp(r'\d'))), reason: tends.hi);
        expect(monthName.hasMatch(tends.en), isFalse, reason: tends.en);
        expect(monthName.hasMatch(tends.hi), isFalse, reason: tends.hi);
        expect(promisesEnglish.hasMatch(tends.en), isFalse, reason: tends.en);
        for (final String stem in promisesHindi) {
          expect(tends.hi, isNot(contains(stem)), reason: tends.hi);
        }
        expect(refusedEnglish.hasMatch(tends.en), isFalse, reason: tends.en);
        for (final String stem in refusedHindi) {
          expect(tends.hi, isNot(contains(stem)), reason: tends.hi);
        }
      }
    });

    test('the tone of the reading colours the tendency', () {
      int supportive = 0;
      int demanding = 0;
      for (final (IndicatedReading r, _) in everyTendency()) {
        final Tone tone = switch (r) {
          BhavaReading b => b.tone,
          PeriodReading p => p.tone,
          GocharReading g => g.tone,
          _ => Tone.mixed,
        };
        switch (tone) {
          case Tone.supportive:
            supportive++;
            expect(r.tends!.en, contains('less friction'));
          case Tone.demanding:
            demanding++;
            expect(r.tends!.en, contains('more deliberate handling'));
          case Tone.mixed:
            expect(r.tends!.en, contains('some ease and some effort'));
        }
      }
      expect(supportive, greaterThan(0));
      expect(demanding, greaterThan(0));
    });

    test('a transit says how its graha tends to colour what it touches', () {
      for (final GocharReading r in gochar.readings) {
        final String name = grahaInfo(r.graha).english;
        expect(r.tends.en, contains('A $name transit tends to'));
        expect(r.tends.hi, contains('${grahaInfo(r.graha).hindi} का गोचर'));
        expect(
          r.tends.en,
          contains(
            r.landsOnDasha
                ? 'already concern this area'
                : 'concern other areas',
          ),
        );
      }
    });

    test('a house with occupants says what they tend to bring', () {
      for (final Phaladesh p in every) {
        for (final BhavaReading b in p.bhavas) {
          if (b.occupants.isEmpty) {
            expect(b.tends.en, isNot(contains(' here, ')));
          } else {
            expect(
              b.tends.en,
              contains('With ${grahaInfo(b.occupants.first).english}'),
              reason: 'house ${b.house}',
            );
          }
        }
      }
    });

    test('a child’s window says the home carries it', () {
      final TimelineWindow first = sample.timeline.windows.first;
      expect(first.tends.en, contains('childhood'));
      expect(first.tends.en, contains('the family around the child'));
      final TimelineWindow adult = sample.timeline.windows.firstWhere(
        (TimelineWindow w) => w.ageStartYears > 30,
      );
      expect(adult.tends, adult.period.tends);
    });
  });

  group('remedies for what is strained', () {
    late GocharPhala gochar;
    late List<IndicatedReading> all;
    setUpAll(() {
      gochar = sample.gochar(now: now);
      all = <IndicatedReading>[
        for (final Phaladesh p in every) ...indicatedReadings(p),
        ...indicatedReadings(sample, gochar),
        for (final Phaladesh p in every.take(6)) ...p.gochar(now: now).readings,
      ];
    });

    test('every adverse finding carries at least one remedy', () {
      int adverse = 0;
      int calm = 0;
      final Set<String> kinds = <String>{};
      for (final IndicatedReading r in all) {
        if (isAdverse(r)) {
          adverse++;
          kinds.add(r.runtimeType.toString());
          expect(r.remedies, isNotEmpty, reason: r.headline.en);
          expect(r.remedies.length, lessThanOrEqualTo(3));
        } else {
          // A remedy is for a finding that calls for one, not for everyone.
          calm++;
          expect(r.remedies, isEmpty, reason: r.headline.en);
        }
      }
      expect(adverse, greaterThan(0));
      expect(calm, greaterThan(0));
      // Every kind of reading met something strained.
      expect(
        kinds,
        containsAll(<String>[
          'BhavaReading',
          'GrahaReading',
          'PeriodReading',
          'TimelineWindow',
          'GocharReading',
        ]),
      );
    });

    test(
      'a remedy says which graha it is for and which affliction it meets',
      () {
        for (final IndicatedReading r in all) {
          final List<IndicatorFactor> factors = <IndicatorFactor>[
            ...r.indication.agreeing,
            ...r.indication.disagreeing,
          ];
          for (final Remedy remedy in r.remedies) {
            final GrahaInfo info = grahaInfo(remedy.graha);
            expect(remedy.addresses.en, contains(info.english));
            expect(remedy.addresses.hi, contains(info.hindi));
            expect(remedy.addresses.en, startsWith('This remedy is for '));
            // The affliction it names is one of the reading's own pressing
            // factors about that graha, word for word.
            final List<IndicatorFactor> pressing = factors
                .where(
                  (IndicatorFactor f) =>
                      !f.eases && f.grahas.contains(remedy.graha),
                )
                .toList();
            if (pressing.isEmpty) {
              expect(
                remedy.addresses.en,
                contains('asking for effort'),
                reason: remedy.addresses.en,
              );
            } else {
              expect(
                pressing.any(
                  (IndicatorFactor f) =>
                      remedy.addresses.en.contains(f.text.en),
                ),
                isTrue,
                reason: remedy.addresses.en,
              );
              expect(
                pressing.any(
                  (IndicatorFactor f) =>
                      remedy.addresses.hi.contains(f.text.hi),
                ),
                isTrue,
                reason: remedy.addresses.hi,
              );
            }
          }
          // Never the same graha twice in one finding.
          expect(
            r.remedies.map((Remedy x) => x.graha).toSet().length,
            r.remedies.length,
          );
        }
      },
    );

    test(
      'a strained house is remedied through its lord or what presses on it',
      () {
        for (final Phaladesh p in every) {
          for (final BhavaReading b in p.bhavas) {
            for (final Remedy r in b.remedies) {
              expect(
                r.graha == b.lord ||
                    b.occupants.contains(r.graha) ||
                    b.aspectedBy.contains(r.graha),
                isTrue,
                reason: 'house ${b.house}: ${r.graha.name}',
              );
            }
          }
          for (final GrahaReading g in p.grahas) {
            for (final Remedy r in g.remedies) {
              expect(r.graha, g.graha);
            }
          }
        }
      },
    );

    test('a difficult period is remedied through its own lord first', () {
      int checked = 0;
      for (final Phaladesh p in every) {
        void walk(PeriodReading r) {
          if (r.remedies.isNotEmpty) {
            final bool lordPressed = r.indication.agreeing
                .followedBy(r.indication.disagreeing)
                .any(
                  (IndicatorFactor f) => !f.eases && f.grahas.contains(r.lord),
                );
            if (lordPressed) {
              expect(r.remedies.first.graha, r.lord);
              checked++;
            }
            for (final Remedy x in r.remedies) {
              expect(
                x.graha == r.lord ||
                    x.graha == r.parentLord ||
                    x.graha == r.grandparentLord,
                isTrue,
              );
            }
          }
          r.children.forEach(walk);
        }

        p.dasha.mahadashas.forEach(walk);
      }
      expect(checked, greaterThan(100));
    });

    test('a testing transit is remedied through the transiting graha', () {
      int testing = 0;
      for (final GocharReading g in all.whereType<GocharReading>()) {
        if (!g.favourable) {
          testing++;
          expect(g.remedies.single.graha, g.graha);
        }
      }
      expect(testing, greaterThan(0));
    });

    test('every adverse yoga carries a remedy, and no other does', () {
      // A wide sweep of births, so that every dosha the chart can carry turns
      // up. Only the yoga notes are needed, so the dasha tree is not built.
      final Set<String> adverse = <String>{};
      final Set<String> unmapped = <String>{};
      for (int i = 0; i < 150; i++) {
        final Kundli k = chartAt(
          DateTime(1960, 1, 3).add(Duration(days: i * 97, hours: (i * 7) % 24)),
        );
        final PhalaContext ctx = PhalaContext(k);
        final Map<String, List<YogaNote>> notes = <String, List<YogaNote>>{};
        for (final GrahaReading g in grahaPhala(ctx)) {
          for (final YogaNote n in g.yogaNotes) {
            notes.putIfAbsent(n.key, () => <YogaNote>[]).add(n);
          }
        }
        for (final YogaFinding y in ctx.yogas) {
          if (!y.isDosha || y.isCancelled) continue;
          // A Nabhasa mould describes the pattern of the whole chart; no
          // graha is the one afflicted, so it has no graha to address.
          if (y.family == YogaFamily.nabhasa) continue;
          adverse.add(y.key);
          if (!notes.containsKey(y.key)) unmapped.add(y.key);
        }
        for (final List<YogaNote> list in notes.values) {
          for (final YogaNote n in list) {
            final YogaFinding y = ctx.yogas.firstWhere(
              (YogaFinding f) => f.key == n.key,
            );
            if (y.isDosha && !y.isCancelled) {
              expect(n.isAdverse, isTrue, reason: n.key);
              expect(n.remedies, isNotEmpty, reason: n.key);
              expect(n.remedies.length, lessThanOrEqualTo(2));
              for (final Remedy r in n.remedies) {
                expect(r.addresses.en, contains(y.nameEnglish));
                expect(r.addresses.hi, contains(y.nameHindi));
                expect(r.addresses.en, contains('It works through'));
              }
            } else {
              expect(n.isAdverse, isFalse, reason: n.key);
              expect(n.remedies, isEmpty, reason: n.key);
            }
          }
        }
      }
      expect(
        unmapped,
        isEmpty,
        reason:
            'These doshas are in the chart but in no graha reading, so they '
            'carry no remedy. Map them in _yogaGrahas: $unmapped',
      );
      expect(
        adverse,
        containsAll(<String>[
          'mangal_dosha',
          'kaal_sarpa',
          'kemadruma',
          'grahan_surya',
          'pitra_dosha',
        ]),
      );
    });

    test(
      'Kaal Sarpa is remedied through both nodes and says it is practice',
      () {
        for (int i = 0; i < 150; i++) {
          final Kundli k = chartAt(
            DateTime(
              1960,
              1,
              3,
            ).add(Duration(days: i * 97, hours: (i * 7) % 24)),
          );
          final PhalaContext ctx = PhalaContext(k);
          if (!ctx.yogas.any((YogaFinding y) => y.key == 'kaal_sarpa')) {
            continue;
          }
          final GrahaReading rahu = grahaPhala(
            ctx,
          ).firstWhere((GrahaReading g) => g.graha == Graha.rahu);
          final YogaNote note = rahu.yogaNotes.firstWhere(
            (YogaNote n) => n.key == 'kaal_sarpa',
          );
          expect(note.remedies.map((Remedy r) => r.graha), <Graha>[
            Graha.rahu,
            Graha.ketu,
          ]);
          expect(note.text.en, contains('not a named yoga'));
          return;
        }
        fail('the sweep never met Kaal Sarpa');
      },
    );

    test(
      'each remedy is the classical kit: mantra, count, fast, deity, daan, act',
      () {
        const Map<Graha, int> expected = <Graha, int>{
          Graha.sun: 7000,
          Graha.moon: 11000,
          Graha.mars: 10000,
          Graha.mercury: 9000,
          Graha.jupiter: 19000,
          Graha.venus: 16000,
          Graha.saturn: 23000,
          Graha.rahu: 18000,
          Graha.ketu: 17000,
        };
        const List<String> daysEn = <String>[
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ];
        const List<String> daysHi = <String>[
          'रविवार',
          'सोमवार',
          'मंगलवार',
          'बुधवार',
          'गुरुवार',
          'शुक्रवार',
          'शनिवार',
        ];
        expect(grahaRemedyKits.keys.toSet(), Graha.values.toSet());
        for (final Graha g in Graha.values) {
          final GrahaRemedyKit kit = grahaRemedyKits[g]!;
          final GrahaInfo info = grahaInfo(g);
          expect(kit.graha, g);
          expect(kit.japaCount, expected[g], reason: g.name);
          expect(japaCounts[g], expected[g], reason: g.name);
          final String shown = expected[g].toString().replaceFirstMapped(
            RegExp(r'^(\d+)(\d{3})$'),
            (Match m) => '${m[1]},${m[2]}',
          );
          expect(kit.japa.en, contains(shown));
          expect(kit.japa.hi, contains(shown));
          expect(kit.japa.en, contains('108'));
          expect(kit.mantra.en, info.mantra);
          expect(kit.mantra.en, startsWith('Om '));
          expect(kit.mantra.hi, startsWith('ॐ '));
          expect(kit.mantra.hi, endsWith('नमः'));
          expect(kit.fastDay, info.weekday);
          expect(kit.fast.en, startsWith(daysEn[info.weekday]));
          expect(kit.fast.hi, startsWith(daysHi[info.weekday]));
          for (final Bi t in kit.texts) {
            expect(t.isComplete, isTrue, reason: g.name);
            expect(t.en, isNot(t.hi));
          }
          expect(kit.deity.en, isNotEmpty);
          expect(kit.daan.en, startsWith('Traditionally: '));
          expect(kit.daan.hi, startsWith('परंपरा में: '));
          expect(kit.simpleAct.en, endsWith('.'));
        }
      },
    );

    test('the scanners themselves catch what they are meant to catch', () {
      for (final String bad in <String>[
        'buy a ruby',
        'wear a gemstone of five ratti',
        'pay the priest for a puja',
        'a yantra from the shop',
        'an amulet or a ring',
        'purchase a pearl',
        'at a price of nine thousand',
        'make a donation',
      ]) {
        expect(buyingEnglish.hasMatch(bad), isTrue, reason: bad);
      }
      for (final String bad in <String>[
        'अंगूठी पहनें',
        'पुखराज खरीदें',
        'पंडित को दक्षिणा दें',
        'यंत्र की कीमत',
      ]) {
        expect(buyingHindi.any(bad.contains), isTrue, reason: bad);
      }
      for (final String bad in <String>[
        'this will cure it',
        'the trouble will pass',
        'it removes the dosha',
        'guaranteed relief',
      ]) {
        expect(promisesEnglish.hasMatch(bad), isTrue, reason: bad);
      }
      for (final String fine in <String>[
        'Give what you already have at home',
        'a light fast on Saturday',
        'Offer water to the rising Sun',
        'Feed a street dog',
        'one mala of 108 a day',
      ]) {
        expect(buyingEnglish.hasMatch(fine), isFalse, reason: fine);
        expect(promisesEnglish.hasMatch(fine), isFalse, reason: fine);
      }
    });

    test('no remedy asks for anything to be bought, paid for or worn', () {
      void scan(Iterable<Bi> texts, String where) {
        for (final Bi t in texts) {
          expect(
            buyingEnglish.hasMatch(t.en),
            isFalse,
            reason:
                '$where: ${buyingEnglish.firstMatch(t.en)?.group(0)} in ${t.en}',
          );
          for (final String stem in buyingHindi) {
            expect(t.hi, isNot(contains(stem)), reason: '$where: ${t.hi}');
          }
        }
      }

      // All nine kits, the stance, and every remedy actually attached.
      for (final GrahaRemedyKit kit in grahaRemedyKits.values) {
        scan(kit.texts, kit.graha.name);
      }
      scan(<Bi>[remedyStance], 'stance');
      int attached = 0;
      for (final IndicatedReading r in all) {
        for (final Remedy remedy in r.remedies) {
          attached++;
          scan(remedy.texts, r.headline.en);
        }
        if (r is GrahaReading) {
          for (final YogaNote n in r.yogaNotes) {
            for (final Remedy remedy in n.remedies) {
              attached++;
              scan(remedy.texts, n.key);
            }
          }
        }
      }
      expect(attached, greaterThan(500));
    });

    test('a remedy is the tradition’s practice and promises nothing', () {
      for (final GrahaRemedyKit kit in grahaRemedyKits.values) {
        for (final Bi t in kit.texts) {
          expect(promisesEnglish.hasMatch(t.en), isFalse, reason: t.en);
          for (final String stem in promisesHindi) {
            expect(t.hi, isNot(contains(stem)), reason: t.hi);
          }
          expect(refusedEnglish.hasMatch(t.en), isFalse, reason: t.en);
          expect(doomEnglish.hasMatch(t.en), isFalse, reason: t.en);
          for (final String stem in refusedHindi) {
            expect(t.hi, isNot(contains(stem)), reason: t.hi);
          }
        }
      }
      for (final IndicatedReading r in all) {
        for (final Remedy remedy in r.remedies) {
          expect(promisesEnglish.hasMatch(remedy.addresses.en), isFalse);
          for (final String stem in promisesHindi) {
            expect(remedy.addresses.hi, isNot(contains(stem)));
          }
        }
      }
      // The stance is said whenever remedies are shown, and says what they are.
      expect(remedyStance.en, contains('common practice'));
      expect(remedyStance.en, contains('no verse is quoted'));
      expect(remedyStance.en, contains('promise nothing'));
      expect(remedyStance.hi, contains('कोई श्लोक नहीं'));
      expect(remedyStance.hi, contains('कोई वादा नहीं'));
      bool shows(IndicatedReading r) => switch (r) {
        GrahaReading g =>
          g.remedies.isNotEmpty ||
              g.yogaNotes.any((YogaNote n) => n.remedies.isNotEmpty),
        // A period's texts hold the texts of the periods inside it.
        PeriodReading p => p.remedies.isNotEmpty || p.children.any(shows),
        _ => r.remedies.isNotEmpty,
      };
      for (final IndicatedReading r in all) {
        expect(
          r.texts.any((Bi t) => identical(t, remedyStance)),
          shows(r),
          reason: r.headline.en,
        );
      }
      // The fast is never forced and the giving is never fixed.
      for (final GrahaRemedyKit kit in grahaRemedyKits.values) {
        expect(kit.fast.en, contains('does not suit'));
        expect(kit.daan.en, contains('are not fixed'));
        expect(kit.daan.en, contains('already have'));
      }
    });

    test(
      'the remedies appear in the reading’s own texts, in both languages',
      () {
        for (final IndicatedReading r in all.take(400)) {
          final Set<String> en = r.texts.map((Bi b) => b.en).toSet();
          final Set<String> hi = r.texts.map((Bi b) => b.hi).toSet();
          for (final Remedy remedy in r.remedies) {
            for (final Bi t in remedy.texts) {
              expect(en, contains(t.en));
              expect(hi, contains(t.hi));
            }
          }
        }
      },
    );
  });
}
