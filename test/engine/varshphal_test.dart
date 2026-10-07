import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/rise_set.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/saham.dart';
import 'package:kundlisaar/engine/jyotish/tajika_aspects.dart';
import 'package:kundlisaar/engine/jyotish/tajika_bala.dart';
import 'package:kundlisaar/engine/jyotish/tajika_common.dart';
import 'package:kundlisaar/engine/jyotish/varshphal.dart';
import 'package:kundlisaar/engine/jyotish/varshphal_dasha.dart';
import 'package:kundlisaar/engine/jyotish/varshphal_months.dart';

const GeoPlace delhi = GeoPlace(
  name: 'Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);

const Duration ist = Duration(hours: 5, minutes: 30);

BirthData birthAt(DateTime local, {GeoPlace place = delhi}) =>
    BirthData(name: 'Test', localDateTime: local, utcOffset: ist, place: place);

BirthData sampleBirth() => birthAt(DateTime(1988, 8, 14, 9, 35));

/// A chart whose grahas stand exactly where the test puts them, so a number can
/// be worked out by hand and compared. Houses are whole-sign from [asc].
Kundli synthetic(
  Map<Graha, double> longitudes, {
  double asc = 0,
  Map<Graha, Dignity> dignity = const <Graha, Dignity>{},
  Set<Graha> retrograde = const <Graha>{},
  Set<Graha> combust = const <Graha>{},
}) {
  final Map<Graha, PlacedGraha> grahas = <Graha, PlacedGraha>{
    for (final Graha g in Graha.values)
      g: PlacedGraha(
        graha: g,
        siderealLongitude: longitudes[g] ?? 0,
        tropicalLongitude: longitudes[g] ?? 0,
        latitude: 0,
        speed: retrograde.contains(g) ? -0.2 : 1.0,
        house: wholeSignHouse(longitudes[g] ?? 0, asc),
        dignity: dignity[g] ?? Dignity.neutral,
        isCombust: combust.contains(g),
      ),
  };
  return Kundli(
    birth: sampleBirth(),
    instant: Instant.fromUtc(DateTime.utc(2026, 1, 1)),
    ayanamsa: computeKundli(sampleBirth()).ayanamsa,
    ayanamsaValue: 24.0,
    ascendant: asc,
    midheaven: norm360(asc + 270),
    cusps: List<double>.generate(12, (int i) => norm360(asc + 30.0 * i)),
    grahas: grahas,
    vimshottari: const <DashaPeriod>[],
  );
}

/// Degrees of a sign and degree: sign 0 is Mesha.
double at(int sign, double degree) => sign * 30.0 + degree;

TajikaReport readTajika(Kundli chart, {bool isDay = true}) {
  final double end = chart.instant.julianDayUt + 365.25;
  return computeTajika(
    chart,
    computePanchaVargiyaBala(chart),
    YearGrid.build(chart, end),
    isDay: isDay,
  );
}

/// Every piece of reading text a [Varshphal] carries, with where it came from,
/// leaving out names. It is what the honesty and completeness tests walk.
List<(String, Bi)> allTexts(Varshphal v) {
  final List<(String, Bi)> out = <(String, Bi)>[];
  void add(String where, Bi? text) {
    if (text != null) out.add((where, text));
  }

  add('varshesh.reading', v.varshesh.reading);
  add('varshesh.rule', v.varshesh.rule);
  for (final Bi f in v.varshesh.factors) {
    add('varshesh.factor', f);
  }
  for (final VarshaOfficer o in v.varshesh.officers) {
    add('officer.basis', o.basis);
  }
  for (final TajikaAspect a in v.tajika.aspects) {
    add('aspect.reading', a.reading);
    for (final Bi f in a.factors) {
      add('aspect.factor', f);
    }
  }
  for (final TajikaYoga y in v.tajika.allYogas) {
    add('yoga.condition', y.condition);
    add('yoga.indicates', y.indicates);
    for (final Bi f in y.factors) {
      add('yoga.factor', f);
    }
  }
  for (final TajikaMatter m in v.tajika.matters) {
    add('matter.reading', m.reading);
    for (final Bi f in m.factors) {
      add('matter.factor', f);
    }
  }
  for (final Saham s in v.sahams) {
    add('saham.reading', s.reading);
    add('saham.governs', s.governs);
    add('saham.note', s.note);
    for (final Bi f in s.factors) {
      add('saham.factor', f);
    }
    for (final Bi f in s.clauses) {
      add('saham.clause', f);
    }
    add('saham.formula', s.formulaUsed);
  }
  for (final Bi f in v.mudda.factors) {
    add('mudda.factor', f);
  }
  for (final PatyayiniPeriod p in v.patyayini.periods) {
    add('patyayini.reading', p.reading);
    for (final Bi f in p.factors) {
      add('patyayini.factor', f);
    }
  }
  for (final Bi f in v.patyayini.factors) {
    add('patyayini.factor', f);
  }
  for (final YearWindow w in v.windows) {
    add('window.reading', w.reading);
    add('window.title', w.title);
    for (final Bi f in w.factors) {
      add('window.factor', f);
    }
    for (final WindowEvent e in w.events) {
      add('window.event', e.text);
    }
  }
  return out;
}

void main() {
  final Kundli natal = computeKundli(sampleBirth());
  final Map<int, Varshphal> years = <int, Varshphal>{
    for (final int age in <int>[0, 1, 8, 25, 38, 52])
      age: computeVarshphal(natal, age),
  };

  group('the year in dated windows', () {
    test('windows tile the whole year with no gap and no overlap', () {
      years.forEach((int age, Varshphal v) {
        expect(v.windows, isNotEmpty, reason: 'age $age');
        expect(v.windows.first.startJd, v.startJd, reason: 'age $age start');
        expect(v.windows.last.endJd, v.endJd, reason: 'age $age end');
        for (int i = 0; i < v.windows.length; i++) {
          final YearWindow w = v.windows[i];
          expect(w.endJd, greaterThan(w.startJd), reason: 'age $age window $i');
          if (i > 0) {
            expect(
              w.startJd,
              v.windows[i - 1].endJd,
              reason: 'age $age: window $i starts where the last ended',
            );
          }
        }
        final double covered = v.windows.fold(
          0.0,
          (double sum, YearWindow w) => sum + w.days,
        );
        expect(covered, closeTo(v.yearDays, 1e-9), reason: 'age $age');
      });
    });

    test('the year is one solar year, pravesh to pravesh', () {
      years.forEach((int age, Varshphal v) {
        // The sidereal year is 365.2564 days; the sun's pace varies by a few
        // minutes between two returns.
        expect(v.yearDays, closeTo(365.2564, 0.01), reason: 'age $age');
        expect(
          julianDayFromUtc(v.nextReturnMoment) -
              julianDayFromUtc(v.returnMoment),
          closeTo(v.yearDays, 1e-9),
        );
      });
    });

    test('local dates match the UT dates shifted by the birth offset', () {
      final Varshphal v = years[38]!;
      for (final YearWindow w in v.windows) {
        expect(w.startLocal, utcFromJulianDay(w.startJd).add(ist));
        expect(w.endLocal, utcFromJulianDay(w.endJd).add(ist));
      }
    });

    test('every dated event falls inside the window that lists it', () {
      years.forEach((int age, Varshphal v) {
        for (final YearWindow w in v.windows) {
          for (final WindowEvent e in w.events) {
            expect(e.jd, greaterThanOrEqualTo(w.startJd));
            expect(e.jd, lessThan(w.endJd));
          }
        }
      });
    });

    test('a window never mentions the three sahams the app does not read', () {
      years.forEach((int age, Varshphal v) {
        for (final YearWindow w in v.windows) {
          expect(w.sahams, isNot(contains(SahamId.roga)));
          expect(w.sahams, isNot(contains(SahamId.mrityu)));
          expect(w.sahams, isNot(contains(SahamId.jeeva)));
        }
      });
    });
  });

  group('mudda dasha', () {
    test('the periods sum to the length of the year', () {
      years.forEach((int age, Varshphal v) {
        expect(
          v.mudda.totalDays,
          closeTo(v.yearDays, 1e-9),
          reason: 'age $age',
        );
        expect(v.mudda.periods.first.startJd, v.startJd);
        expect(v.mudda.periods.last.endJd, v.endJd);
      });
    });

    test('it starts from the birth nakshatra lord advanced by the year', () {
      final Graha base = natal.janmaNakshatra.lord;
      final int index = vimshottariOrder.indexOf(base);
      years.forEach((int age, Varshphal v) {
        expect(
          v.mudda.startLord,
          vimshottariOrder[(index + age) % 9],
          reason: 'age $age',
        );
        expect(v.mudda.periods.first.lord, v.mudda.startLord);
        expect(v.mudda.periods.first.isBalance, isTrue);
      });
    });

    test('at age 0 it is the natal Vimshottari compressed into the year', () {
      final Varshphal v = years[0]!;
      final double elapsed =
          (natal.grahas[Graha.moon]!.siderealLongitude % nakshatraSpan) /
          nakshatraSpan;
      final Graha first = natal.janmaNakshatra.lord;
      expect(v.mudda.startLord, first);
      expect(
        v.mudda.periods.first.days,
        closeTo(
          (1 - elapsed) * v.yearDays * vimshottariYears[first]! / 120,
          1e-6,
        ),
        reason: 'the balance of the first dasha',
      );
      // Every whole period is its share of the year: years / 120.
      for (final MuddaPeriod p in v.mudda.periods) {
        if (p.isBalance || p.isCarryOver) continue;
        expect(
          p.days,
          closeTo(v.yearDays * vimshottariYears[p.lord]! / 120, 1e-6),
          reason: '${p.lord} period',
        );
      }
    });

    test(
      'the lords run in Vimshottari order and the first comes round again',
      () {
        years.forEach((int age, Varshphal v) {
          final List<MuddaPeriod> ps = v.mudda.periods;
          for (int i = 1; i < ps.length; i++) {
            final int before = vimshottariOrder.indexOf(ps[i - 1].lord);
            expect(
              ps[i].lord,
              vimshottariOrder[(before + 1) % 9],
              reason: 'age $age',
            );
          }
          if (ps.last.isCarryOver) {
            expect(ps.last.lord, ps.first.lord);
          }
        });
      },
    );

    test('antardashas tile each period exactly', () {
      years.forEach((int age, Varshphal v) {
        for (final MuddaPeriod p in v.mudda.periods) {
          expect(p.subPeriods, isNotEmpty);
          expect(p.subPeriods.first.startJd, p.startJd);
          expect(p.subPeriods.last.endJd, closeTo(p.endJd, 1e-9));
          for (int i = 1; i < p.subPeriods.length; i++) {
            expect(p.subPeriods[i].startJd, p.subPeriods[i - 1].endJd);
          }
        }
      });
    });
  });

  group('patyayini dasha', () {
    test('it divides the whole year and runs in order of degrees', () {
      years.forEach((int age, Varshphal v) {
        expect(v.patyayini.totalDays, closeTo(v.yearDays, 1e-9));
        expect(v.patyayini.periods.first.startJd, v.startJd);
        expect(v.patyayini.periods.last.endJd, v.endJd);
        for (int i = 1; i < v.patyayini.periods.length; i++) {
          expect(
            v.patyayini.periods[i].degree,
            greaterThanOrEqualTo(v.patyayini.periods[i - 1].degree),
          );
          expect(
            v.patyayini.periods[i].startJd,
            v.patyayini.periods[i - 1].endJd,
          );
        }
      });
    });

    test(
      'shares are the degrees between neighbours, as the books give them',
      () {
        final Varshphal v = years[38]!;
        final double span = v.patyayini.periods.last.degree;
        for (final PatyayiniPeriod p in v.patyayini.periods) {
          expect(
            p.days,
            closeTo(v.yearDays * p.deducted / span, 1e-6),
            reason: p.name.en,
          );
        }
      },
    );
  });

  group('sahams', () {
    test('every longitude is in [0, 360) and every saham is placed', () {
      years.forEach((int age, Varshphal v) {
        expect(
          v.sahams.map((Saham s) => s.id).toSet().length,
          SahamId.values.length,
        );
        for (final Saham s in v.sahams) {
          expect(s.longitude, greaterThanOrEqualTo(0), reason: '${s.id}');
          expect(s.longitude, lessThan(360), reason: '${s.id}');
          expect(s.sign, (s.longitude / 30).floor());
          expect(s.degreeInSign, closeTo(s.longitude % 30, 1e-9));
          expect(s.house, inInclusiveRange(1, 12));
          expect(s.house, ((s.sign - v.chart.lagnaRashi.index + 12) % 12) + 1);
          expect(s.lord, rashiInfo(Rashi.values[s.sign]).lord);
        }
      });
    });

    test('Punya follows the Neelakanthi formula, day and night', () {
      // Sun 100, Moon 160, Lagna 0. By day Moon - Sun + Lagna = 60, and the
      // lagna is outside the arc from the Sun to the Moon, so a sign is added.
      final Kundli day = synthetic(<Graha, double>{
        Graha.sun: 100,
        Graha.moon: 160,
        Graha.mars: 10,
        Graha.mercury: 20,
        Graha.jupiter: 30,
        Graha.venus: 40,
        Graha.saturn: 50,
      });
      final Map<Graha, PanchaVargiyaBala> bala = computePanchaVargiyaBala(day);
      final Saham byDay = computeSahams(
        day,
        bala,
        isDay: true,
      ).firstWhere((Saham s) => s.id == SahamId.punya);
      expect(byDay.longitude, closeTo(90, 1e-9));
      // By night Sun - Moon + Lagna = 300; the lagna is inside the arc from the
      // Moon to the Sun, so nothing is added.
      final Saham byNight = computeSahams(
        day,
        bala,
        isDay: false,
      ).firstWhere((Saham s) => s.id == SahamId.punya);
      expect(byNight.longitude, closeTo(300, 1e-9));
      expect(byDay.isDay, isTrue);
      expect(byNight.isDay, isFalse);
    });

    test(
      'the formulas for the sahams built on Punya, the lagna lord and houses',
      () {
        // Lagna Mesha 0, so Mars is the lagna lord. Fixed, round longitudes.
        final Kundli chart = synthetic(<Graha, double>{
          Graha.sun: 100,
          Graha.moon: 160,
          Graha.mars: 200,
          Graha.mercury: 220,
          Graha.jupiter: 250,
          Graha.venus: 280,
          Graha.saturn: 310,
        });
        final Map<Graha, PanchaVargiyaBala> bala = computePanchaVargiyaBala(
          chart,
        );
        final List<Saham> day = computeSahams(chart, bala, isDay: true);
        final List<Saham> night = computeSahams(chart, bala, isDay: false);
        double of(List<Saham> list, SahamId id) =>
            list.firstWhere((Saham s) => s.id == id).longitude;

        // Bhratri: Jupiter - Saturn + Lagna, the same by day and night:
        // 250 - 310 + 0 = -60 -> 300. The lagna (0) is inside the arc from
        // Saturn (310) forward to Jupiter (250), so no sign is added.
        expect(of(day, SahamId.bhratri), closeTo(300, 1e-9));
        expect(of(night, SahamId.bhratri), closeTo(300, 1e-9));

        // Putra: Jupiter - Moon + Lagna by day and night = 90; the lagna is not
        // between the Moon (160) and Jupiter (250), so 120.
        expect(of(day, SahamId.putra), closeTo(120, 1e-9));
        expect(of(night, SahamId.putra), closeTo(120, 1e-9));

        // Samartha: Mars is the lagna lord, so Jupiter stands in for Mars.
        // Day: Jupiter - lagna lord(Mars) + Lagna = 250 - 200 + 0 = 50; the
        // lagna (0) is not in the arc from Mars (200) to Jupiter (250): +30.
        expect(of(day, SahamId.samartha), closeTo(80, 1e-9));
        // Night: lagna lord - Jupiter + Lagna = 200 - 250 = -50 -> 310; the arc
        // from Jupiter (250) to Mars (200) is 310 long and holds the lagna.
        expect(of(night, SahamId.samartha), closeTo(310, 1e-9));

        // Mrityu: 8th house - Moon + Saturn. The 8th house point is 210 for
        // Lagna 0: 210 - 160 + 310 = 360 -> 0. The lagna is on the arc from the
        // Moon (160) to 210? No: 0 is outside, so 30.
        expect(of(day, SahamId.mrityu), closeTo(30, 1e-9));
        expect(of(night, SahamId.mrityu), closeTo(30, 1e-9));

        // Artha: 2nd house - 2nd lord + Lagna. 2nd house point 30, its lord
        // Venus (Vrishabha) at 280: 30 - 280 + 0 = -250 -> 110; the lagna 0 is
        // in the arc from Venus (280) to 30 (110 long): 0 - 280 = 80 <= 110.
        expect(of(day, SahamId.artha), closeTo(110, 1e-9));

        // Karyasiddhi by day: Saturn - Sun + lord of the Sun's sign (Sun in
        // Karka: Moon at 160) = 310 - 100 + 160 = 370 -> 10. The lagna is not
        // between the Sun (100) and Saturn (310): +30.
        expect(of(day, SahamId.karyasiddhi), closeTo(40, 1e-9));
        // By night: Saturn - Moon + lord of Moon's sign (Moon in Kanya, Mercury
        // at 220) = 310 - 160 + 220 = 370 -> 10; lagna not between 160 and 310.
        expect(of(night, SahamId.karyasiddhi), closeTo(40, 1e-9));

        // Jalapatana by day: Cancer 15 (105) - Saturn + Lagna = 105 - 310 =
        // -205 -> 155; the lagna is not between Saturn (310) and 105: 0-310 =
        // 50 <= 155 so it IS between: no sign.
        expect(of(day, SahamId.jalapatana), closeTo(155, 1e-9));
        // Night: Saturn - 105 + Lagna = 205; arc from 105 to 310 is 205 and
        // holds the lagna? 0 - 105 = 255 > 205: no, +30.
        expect(of(night, SahamId.jalapatana), closeTo(235, 1e-9));

        // Gaurava: Jupiter - Moon + Sun by day, Jupiter - Sun + Moon by night.
        // By day 250 - 160 + 100 = 190, and the lagna is not between the Moon
        // and Jupiter: 220. By night 250 - 100 + 160 = 310, the lagna is not
        // between the Sun and Jupiter either: 340.
        expect(of(day, SahamId.gaurava), closeTo(220, 1e-9));
        expect(of(night, SahamId.gaurava), closeTo(340, 1e-9));
      },
    );

    test('a night chart swaps A and B, except where the formula is fixed', () {
      final Varshphal v = years[38]!;
      final Kundli chart = v.chart;
      final Map<Graha, PanchaVargiyaBala> bala = computePanchaVargiyaBala(
        chart,
      );
      final List<Saham> day = computeSahams(chart, bala, isDay: true);
      final List<Saham> night = computeSahams(chart, bala, isDay: false);
      const Set<SahamId> fixed = <SahamId>{
        SahamId.bhratri,
        SahamId.putra,
        SahamId.roga,
        SahamId.paradesha,
        SahamId.artha,
        SahamId.labha,
        SahamId.mrityu,
      };
      for (int i = 0; i < day.length; i++) {
        final SahamId id = day[i].id;
        expect(night[i].id, id);
        expect(day[i].reversesAtNight, !fixed.contains(id), reason: '$id');
        if (fixed.contains(id)) {
          expect(
            night[i].longitude,
            closeTo(day[i].longitude, 1e-9),
            reason: '$id',
          );
        }
      }
    });

    test('day and night switch at the sunrise and the sunset', () {
      final double midnight = Instant.fromLocal(
        DateTime(2026, 8, 14),
        ist,
      ).julianDayUt;
      final RiseSet sun = findRiseSet(
        Graha.sun,
        midnight,
        delhi,
        spanDays: 1.0,
      );
      expect(sun.rise, isNotNull);
      expect(sun.set, isNotNull);

      DateTime localAt(double jd, int minutes) =>
          utcFromJulianDay(jd).add(ist).add(Duration(minutes: minutes));

      bool dayAt(double jd, int minutes) {
        final DateTime when = localAt(jd, minutes);
        final Kundli chart = computeKundli(
          birthAt(
            DateTime(when.year, when.month, when.day, when.hour, when.minute),
          ),
        );
        final Saham punya = computeSahams(
          chart,
          computePanchaVargiyaBala(chart),
          isDay: isDayAt(chart.instant, delhi),
        ).firstWhere((Saham s) => s.id == SahamId.punya);
        // The saham itself switched formula with the day.
        final double sunLon = chart.grahas[Graha.sun]!.siderealLongitude;
        final double moonLon = chart.grahas[Graha.moon]!.siderealLongitude;
        final bool isDay = isDayAt(chart.instant, delhi);
        final double a = isDay ? moonLon : sunLon;
        final double b = isDay ? sunLon : moonLon;
        double expected = a - b + chart.ascendant;
        if (norm360(chart.ascendant - b) > norm360(a - b)) expected += 30;
        expect(punya.longitude, closeTo(norm360(expected), 1e-6));
        expect(punya.isDay, isDay);
        return isDay;
      }

      expect(
        dayAt(sun.rise!, -4),
        isFalse,
        reason: 'four minutes before sunrise',
      );
      expect(dayAt(sun.rise!, 4), isTrue, reason: 'four minutes after sunrise');
      expect(dayAt(sun.set!, -4), isTrue, reason: 'four minutes before sunset');
      expect(dayAt(sun.set!, 4), isFalse, reason: 'four minutes after sunset');
    });

    test('a year cast at night uses the night formulas', () {
      // The 38th year of the sample chart returns at 03:13 local time.
      final Varshphal v = years[38]!;
      expect(v.isDay, isFalse);
      final Saham punya = v.saham(SahamId.punya);
      expect(punya.isDay, isFalse);
      expect(punya.formulaUsed.en, 'Sun − Moon + Lagna');
    });

    test('Roga, Mrityu and Jeeva are computed and never read', () {
      years.forEach((int age, Varshphal v) {
        for (final SahamId id in uninterpretedSahams) {
          final Saham s = v.saham(id);
          expect(s.reading, isNull, reason: '$id');
          expect(s.governs, isNull, reason: '$id');
          expect(s.tone, isNull, reason: '$id');
          expect(s.isInterpreted, isFalse);
          expect(s.clauses, isEmpty);
          expect(s.formulaDay.isComplete, isTrue);
          expect(s.longitude, inInclusiveRange(0, 360));
        }
      });
    });

    test('every read saham names its lord, its house and its tone', () {
      years.forEach((int age, Varshphal v) {
        for (final Saham s in v.sahams.where((Saham s) => s.isInterpreted)) {
          expect(s.tone, isNotNull);
          expect(s.reading, isNotNull);
          expect(s.reading!.en, contains(grahaInfo(s.lord).english));
          expect(s.clauses, isNotEmpty);
        }
      });
    });

    test('the Sun passes through each saham sign inside the year', () {
      final Varshphal v = years[25]!;
      for (final Saham s in v.sahams) {
        if (s.sunFromJd == null) continue;
        // The grid starts at the annual chart's own second, within a second of
        // the exact pravesh.
        expect(s.sunFromJd, greaterThanOrEqualTo(v.startJd - 2e-5));
        expect(s.sunToJd, lessThanOrEqualTo(v.endJd + 2e-5));
        expect(s.sunToJd, greaterThan(s.sunFromJd!));
        expect(s.sunToJd! - s.sunFromJd!, lessThan(32));
      }
    });
  });

  group('five-fold strength', () {
    test('a hand-worked graha: the Sun at 10°30′ Mesha', () {
      // Sign lord Mars in Simha (5th from Mesha: friend) -> 30 * 3/4 = 22.5.
      // Uchcha: 10°30′ is half a degree from deep exaltation, 179.5/180 * 20.
      // Hadda: Mesha 6-12 is Venus's; Venus in Mithuna (3rd: friend) -> 11.25.
      // Drekkana: Mesha 10-20 is the Sun's own -> 10.
      // Navamsha: the 4th ninth-part is Karka, Moon's; the Moon in Vrishabha
      // (2nd from Mesha: neutral) -> 5 * 1/2 = 2.5.
      final Kundli chart = synthetic(<Graha, double>{
        Graha.sun: at(0, 10.5),
        Graha.moon: at(1, 3),
        Graha.mars: at(4, 5),
        Graha.mercury: at(1, 5),
        Graha.jupiter: at(8, 5),
        Graha.venus: at(2, 20),
        Graha.saturn: at(6, 5),
      });
      final PanchaVargiyaBala sun = computePanchaVargiyaBala(chart)[Graha.sun]!;
      expect(sun.griha.points, closeTo(22.5, 1e-9));
      expect(sun.griha.divisionLord, Graha.mars);
      expect(sun.griha.relation, PvRelation.friend);
      expect(sun.uchcha.points, closeTo(179.5 / 180 * 20, 1e-9));
      expect(sun.hadda.divisionLord, Graha.venus);
      expect(sun.hadda.points, closeTo(11.25, 1e-9));
      expect(sun.drekkana.divisionLord, Graha.sun);
      expect(sun.drekkana.relation, PvRelation.own);
      expect(sun.drekkana.points, closeTo(10, 1e-9));
      expect(sun.navamsha.divisionLord, Graha.moon);
      expect(sun.navamsha.relation, PvRelation.neutral);
      expect(sun.navamsha.points, closeTo(2.5, 1e-9));
      expect(
        sun.total,
        closeTo(22.5 + 179.5 / 180 * 20 + 11.25 + 10 + 2.5, 1e-9),
      );
      expect(sun.vishwa, closeTo(sun.total / 4, 1e-12));
      expect(sun.band, PvBand.excellent);
    });

    test(
      'the weights are 30, 20, 15, 10 and 5 and a graha in its own sign takes all',
      () {
        expect(pvWeight.values.fold(0.0, (double a, double b) => a + b), 80);
        // The Moon at 3° Vrishabha is deep-exalted; put its own sign Karka, hadda
        // lord Venus (Vrishabha 0-8), decan Mercury, navamsha ... to read the
        // weights straight off a graha that is its own lord in the sign.
        final Kundli chart = synthetic(<Graha, double>{
          Graha.sun: at(4, 1),
          Graha.moon: at(3, 1),
          Graha.mars: at(0, 1),
          Graha.mercury: at(2, 1),
          Graha.jupiter: at(8, 1),
          Graha.venus: at(1, 1),
          Graha.saturn: at(9, 1),
        });
        final PanchaVargiyaBala moon = computePanchaVargiyaBala(
          chart,
        )[Graha.moon]!;
        expect(moon.griha.points, 30);
        expect(moon.griha.relation, PvRelation.own);
        expect(moon.griha.max, 30);
        expect(moon.uchcha.max, 20);
        expect(moon.hadda.max, 15);
        expect(moon.drekkana.max, 10);
        expect(moon.navamsha.max, 5);
      },
    );

    test(
      'every graha: components sum to the total, and the total quartered is vishwa',
      () {
        years.forEach((int age, Varshphal v) {
          for (final Graha g in tajikaGrahas) {
            final PanchaVargiyaBala b = v.bala[g]!;
            final double sum = b.components.fold(
              0.0,
              (double s, PvComponent c) => s + c.points,
            );
            expect(sum, closeTo(b.total, 1e-12), reason: '$g age $age');
            expect(b.vishwa, closeTo(b.total / 4, 1e-12));
            expect(b.total, inInclusiveRange(0, 80));
            expect(b.vishwa, inInclusiveRange(0, 20));
            for (final PvComponent c in b.components) {
              expect(
                c.points,
                inInclusiveRange(0, c.max),
                reason: '$g ${c.division}',
              );
              expect(c.max, pvWeight[c.division]);
              if (c.relation != null) {
                expect(
                  c.points,
                  closeTo(c.max * pvFraction[c.relation]!, 1e-12),
                );
              }
            }
          }
        });
      },
    );

    test(
      'the hadda table covers each sign in five terms that sum to thirty',
      () {
        expect(haddaTable.length, 12);
        for (int sign = 0; sign < 12; sign++) {
          final List<(double, Graha)> row = haddaTable[sign];
          expect(row.length, 5, reason: 'sign $sign');
          expect(row.last.$1, 30);
          expect(row.map(((double, Graha) t) => t.$2).toSet().length, 5);
          for (int i = 1; i < row.length; i++) {
            expect(row[i].$1, greaterThan(row[i - 1].$1));
          }
        }
        // Mesha: Jupiter, Venus, Mercury, Mars, Saturn to 6, 12, 20, 25, 30.
        expect(haddaLordOf(at(0, 5.9)), Graha.jupiter);
        expect(haddaLordOf(at(0, 6)), Graha.venus);
        expect(haddaLordOf(at(0, 19.9)), Graha.mercury);
        expect(haddaLordOf(at(0, 24.9)), Graha.mars);
        expect(haddaLordOf(at(0, 29.9)), Graha.saturn);
        // The two places the Tajika table departs from the Egyptian.
        expect(haddaLordOf(at(2, 7)), Graha.venus);
        expect(haddaLordOf(at(2, 13)), Graha.jupiter);
        expect(haddaLordOf(at(8, 23)), Graha.mars);
        expect(haddaLordOf(at(8, 28)), Graha.saturn);
      },
    );

    test(
      'the decans run Mars, Sun, Venus, Mercury, Moon, Saturn, Jupiter round',
      () {
        expect(drekkanaLordOf(at(0, 1)), Graha.mars);
        expect(drekkanaLordOf(at(0, 11)), Graha.sun);
        expect(drekkanaLordOf(at(0, 21)), Graha.venus);
        expect(drekkanaLordOf(at(1, 1)), Graha.mercury);
        expect(drekkanaLordOf(at(1, 11)), Graha.moon);
        expect(drekkanaLordOf(at(1, 21)), Graha.saturn);
        expect(drekkanaLordOf(at(2, 1)), Graha.jupiter);
        expect(drekkanaLordOf(at(2, 11)), Graha.mars);
        expect(drekkanaLordOf(at(11, 21)), Graha.mars);
      },
    );

    test(
      'the triplicity lords are Sun/Jupiter, Venus/Moon, Saturn/Mercury, Venus/Mars',
      () {
        expect(trirashiLordOf(0, isDay: true), Graha.sun);
        expect(trirashiLordOf(4, isDay: false), Graha.jupiter);
        expect(trirashiLordOf(1, isDay: true), Graha.venus);
        expect(trirashiLordOf(5, isDay: false), Graha.moon);
        expect(trirashiLordOf(2, isDay: true), Graha.saturn);
        expect(trirashiLordOf(10, isDay: false), Graha.mercury);
        expect(trirashiLordOf(3, isDay: true), Graha.venus);
        expect(trirashiLordOf(11, isDay: false), Graha.mars);
      },
    );
  });

  group('the lord of the year', () {
    test('the same chart always gives the same lord, officers and scores', () {
      final Varshphal again = computeVarshphal(natal, 38);
      final Varshphal first = years[38]!;
      expect(again.yearLord, first.yearLord);
      expect(
        again.varshesh.officers.map((VarshaOfficer o) => o.graha).toList(),
        first.varshesh.officers.map((VarshaOfficer o) => o.graha).toList(),
      );
      expect(again.varshesh.eligible, first.varshesh.eligible);
      for (final Graha g in tajikaGrahas) {
        expect(again.bala[g]!.total, first.bala[g]!.total);
      }
      expect(again.candidates, first.candidates);
    });

    test('the five offices are the five the books name', () {
      years.forEach((int age, Varshphal v) {
        final List<VarshaOfficer> o = v.varshesh.officers;
        expect(o.length, 5);
        expect(o.map((VarshaOfficer x) => x.office).toList(), <VarshaOffice>[
          VarshaOffice.muntha,
          VarshaOffice.varshaLagna,
          VarshaOffice.trirashi,
          VarshaOffice.dinaRatri,
          VarshaOffice.janmaLagna,
        ]);
        Graha lordOfSign(int sign) => rashiInfo(Rashi.values[sign]).lord;
        expect(o[0].graha, lordOfSign(v.munthaSign), reason: 'age $age muntha');
        expect(o[0].graha, v.munthaLord);
        expect(o[1].graha, lordOfSign(v.chart.lagnaRashi.index));
        expect(
          o[2].graha,
          trirashiLordOf(v.chart.lagnaRashi.index, isDay: v.isDay),
        );
        expect(
          o[3].graha,
          lordOfSign(
            v.isDay ? v.chart.sunRashi.index : v.chart.moonRashi.index,
          ),
        );
        expect(o[4].graha, lordOfSign(natal.lagnaRashi.index));
        for (final VarshaOfficer x in o) {
          expect(x.vishwa, closeTo(v.bala[x.graha]!.vishwa, 1e-12));
        }
      });
    });

    test(
      'the lord aspects the Lagna and is the strongest that does, else Muntha',
      () {
        years.forEach((int age, Varshphal v) {
          final VarsheshResult r = v.varshesh;
          final List<VarshaOfficer> aspecting = r.officers
              .where((VarshaOfficer o) => o.aspectsLagna)
              .toList();
          if (aspecting.isEmpty) {
            expect(r.usedFallback, isTrue, reason: 'age $age');
            expect(r.lord, v.munthaLord);
          } else {
            expect(r.usedFallback, isFalse);
            expect(
              aspecting.map((VarshaOfficer o) => o.graha),
              contains(r.lord),
            );
            final double best = aspecting
                .map((VarshaOfficer o) => o.vishwa)
                .reduce((double a, double b) => a > b ? a : b);
            expect(
              v.bala[r.lord]!.vishwa,
              closeTo(best, 1e-12),
              reason: 'age $age',
            );
          }
        });
      },
    );

    test(
      'a sign aspects the Lagna unless it is the 2nd, 6th, 8th or 12th from it',
      () {
        years.forEach((int age, Varshphal v) {
          for (final VarshaOfficer o in v.varshesh.officers) {
            final int distance = signDistance(
              v.chart.grahas[o.graha]!.rashi.index,
              v.chart.lagnaRashi.index,
            );
            expect(
              o.aspectsLagna,
              !const <int>[2, 6, 8, 12].contains(distance),
              reason: '${o.graha} age $age',
            );
          }
        });
      },
    );
  });

  group('Tajika aspects', () {
    test(
      'the deeptamsha are the classical ones and a pair shares half the sum',
      () {
        expect(deeptamsha[Graha.sun], 15);
        expect(deeptamsha[Graha.moon], 12);
        expect(deeptamsha[Graha.mars], 8);
        expect(deeptamsha[Graha.mercury], 7);
        expect(deeptamsha[Graha.jupiter], 9);
        expect(deeptamsha[Graha.venus], 7);
        expect(deeptamsha[Graha.saturn], 9);
        expect(meanOrb(Graha.sun, Graha.moon), 13.5);
        expect(meanOrb(Graha.mercury, Graha.venus), 7);
        expect(meanOrb(Graha.mars, Graha.saturn), 8.5);
      },
    );

    test(
      'only the conjunction and the 3rd, 4th, 5th, 7th, 9th, 10th, 11th aspect',
      () {
        for (final int d in <int>[2, 6, 8, 12]) {
          expect(signAspectOf(d), isNull, reason: 'distance $d');
        }
        expect(signAspectOf(1), SignAspect.conjunction);
        expect(signAspectOf(3), SignAspect.sextile);
        expect(signAspectOf(11), SignAspect.sextile);
        expect(signAspectOf(5), SignAspect.trine);
        expect(signAspectOf(9), SignAspect.trine);
        expect(signAspectOf(4), SignAspect.square);
        expect(signAspectOf(10), SignAspect.square);
        expect(signAspectOf(7), SignAspect.opposition);
        expect(natureOf(SignAspect.trine), AspectNature.friendly);
        expect(natureOf(SignAspect.opposition), AspectNature.inimical);
      },
    );

    test(
      'Ittasala is the swifter behind, Ishrafa the swifter ahead, by degrees in the sign',
      () {
        Map<Graha, double> base(double moon) => <Graha, double>{
          Graha.sun: at(8, 1),
          Graha.moon: moon,
          Graha.mars: at(8, 8),
          Graha.mercury: at(8, 12),
          Graha.jupiter: at(8, 20),
          Graha.venus: at(8, 25),
          Graha.saturn: at(6, 14),
        };
        // The Moon at 10° Mesha, Saturn at 14° Tula: opposition, Moon 4° behind.
        TajikaAspect? find(Map<Graha, double> lons) =>
            readTajika(synthetic(lons)).aspectBetween(Graha.moon, Graha.saturn);
        final TajikaAspect? applying = find(base(at(0, 10)));
        expect(applying, isNotNull);
        expect(applying!.kind, TajikaYogaId.ittasala);
        expect(applying.faster, Graha.moon);
        expect(applying.signAspect, SignAspect.opposition);
        expect(applying.gap, closeTo(4, 1e-9));
        expect(applying.orb, 10.5);
        expect(applying.name.en, contains('Muthashila'));

        // Moon at 18° Mesha is 4° past Saturn's 14° Tula: separating.
        final TajikaAspect? separating = find(base(at(0, 18)));
        expect(separating!.kind, TajikaYogaId.ishrafa);
        expect(separating.gap, closeTo(4, 1e-9));
        expect(separating.name.en, contains('Mushariph'));

        // 12° beyond is outside the 10.5° orb.
        expect(find(base(at(0, 26))), isNull);
        // The 2nd sign from Saturn's has no aspect whatever the degrees.
        expect(find(base(at(5, 10))), isNull);
      },
    );

    test(
      'a retrograde swifter graha does not apply, a retrograde slower one does',
      () {
        Map<Graha, double> lons() => <Graha, double>{
          Graha.sun: at(8, 1),
          Graha.moon: at(0, 1),
          Graha.mars: at(0, 15),
          Graha.mercury: at(4, 10),
          Graha.jupiter: at(8, 20),
          Graha.venus: at(2, 10),
          Graha.saturn: at(6, 25),
        };
        // Venus (swifter) 10° Mithuna behind Mars 15° Mesha: 11th sign aspect.
        expect(
          readTajika(
            synthetic(lons()),
          ).aspectBetween(Graha.venus, Graha.mars)?.kind,
          TajikaYogaId.ittasala,
        );
        expect(
          readTajika(
            synthetic(lons(), retrograde: <Graha>{Graha.venus}),
          ).aspectBetween(Graha.venus, Graha.mars),
          isNull,
        );
        expect(
          readTajika(
            synthetic(lons(), retrograde: <Graha>{Graha.mars}),
          ).aspectBetween(Graha.venus, Graha.mars)?.kind,
          TajikaYogaId.ittasala,
        );
      },
    );

    test(
      'every aspect in a real year is inside its orb and in a sign aspect',
      () {
        years.forEach((int age, Varshphal v) {
          for (final TajikaAspect a in v.tajika.aspects) {
            expect(a.gap, lessThanOrEqualTo(a.orb), reason: 'age $age');
            expect(a.orb, meanOrb(a.faster, a.slower));
            expect(isSwifter(a.faster, a.slower), isTrue);
            final PlacedGraha f = v.chart.grahas[a.faster]!;
            final PlacedGraha s = v.chart.grahas[a.slower]!;
            expect(
              signAspectOf(signDistance(f.rashi.index, s.rashi.index)),
              a.signAspect,
            );
            final double gap = s.degreesInSign - f.degreesInSign;
            expect(
              a.kind,
              gap >= 0 ? TajikaYogaId.ittasala : TajikaYogaId.ishrafa,
            );
            expect(a.gap, closeTo(gap.abs(), 1e-9));
            if (a.event != null) {
              expect(a.event!.jd, greaterThanOrEqualTo(v.startJd - 1e-3));
              expect(a.event!.jd, lessThanOrEqualTo(v.endJd + 1e-3));
            }
          }
        });
      },
    );

    test(
      'an applying pair becomes exact when the swifter reaches the same degree',
      () {
        // The moment the engine gives must put the two on the same degree of
        // their signs.
        int checked = 0;
        years.forEach((int age, Varshphal v) {
          for (final TajikaAspect a in v.tajika.aspects) {
            final TajikaEvent? e = a.event;
            if (e == null || e.kind != TajikaEventKind.perfects) continue;
            final Instant when = Instant.fromJulianDayUt(e.jd);
            double lon(Graha g) => toSiderealDegrees(v.chart, g, when);
            final double faster = lon(a.faster) % 30;
            final double slower = lon(a.slower) % 30;
            expect(
              (faster - slower).abs(),
              lessThan(0.02),
              reason: '${a.faster}-${a.slower} age $age',
            );
            checked++;
          }
        });
        expect(checked, greaterThan(5));
      },
    );
  });

  group('Tajika yogas', () {
    // Lagna Mesha: Mars is the lagna lord; Venus rules the 7th (Tula).
    Map<Graha, double> kamboolaChart() => <Graha, double>{
      Graha.mars: at(0, 15),
      Graha.venus: at(2, 10),
      Graha.moon: at(0, 8),
      Graha.sun: at(8, 20),
      Graha.mercury: at(9, 25),
      Graha.jupiter: at(6, 3),
      Graha.saturn: at(1, 3),
    };

    List<TajikaYogaId> forMatter(TajikaReport r, int house) => r.matters
        .firstWhere((TajikaMatter m) => m.house == house)
        .yogas
        .map((TajikaYoga y) => y.id)
        .toList();

    test('Ittasala between the lords, with the Moon: Kamboola', () {
      final TajikaReport r = readTajika(
        synthetic(
          kamboolaChart(),
          dignity: <Graha, Dignity>{Graha.mars: Dignity.own},
        ),
      );
      final List<TajikaYogaId> seventh = forMatter(r, 7);
      expect(seventh, contains(TajikaYogaId.ittasala));
      expect(seventh, contains(TajikaYogaId.kamboola));
      // Mars (slower) is in its own sign and Venus (swifter) holds none.
      expect(seventh, contains(TajikaYogaId.duhphaliKuttha));
      expect(seventh, isNot(contains(TajikaYogaId.radda)));
      expect(seventh, isNot(contains(TajikaYogaId.khallasara)));
    });

    test('a retrograde slower lord spoils the Ittasala: Radda', () {
      final TajikaReport r = readTajika(
        synthetic(
          kamboolaChart(),
          dignity: <Graha, Dignity>{Graha.mars: Dignity.own},
          retrograde: <Graha>{Graha.mars},
        ),
      );
      expect(forMatter(r, 7), contains(TajikaYogaId.radda));
      expect(forMatter(r, 7), contains(TajikaYogaId.ittasala));
    });

    test(
      'an Ittasala with no Moon on either lord: Khallasara, and not Kamboola',
      () {
        final Map<Graha, double> lons = kamboolaChart()
          ..[Graha.moon] = at(5, 20);
        final TajikaReport r = readTajika(synthetic(lons));
        final List<TajikaYogaId> seventh = forMatter(r, 7);
        expect(seventh, contains(TajikaYogaId.ittasala));
        expect(seventh, contains(TajikaYogaId.khallasara));
        expect(seventh, isNot(contains(TajikaYogaId.kamboola)));
      },
    );

    test('Mars or Saturn in an inimical aspect to the swifter graha: Manau', () {
      // Saturn at 12° Karka is in the 4th sign from Mesha's Mars... the swifter
      // graha is Venus in Mithuna: Karka is its next sign (no aspect). Put
      // Saturn in Kanya (4th from Mithuna) at 12°, 2° from Venus's 10°.
      final Map<Graha, double> lons = kamboolaChart()
        ..[Graha.saturn] = at(5, 12);
      final TajikaReport r = readTajika(synthetic(lons));
      expect(forMatter(r, 7), contains(TajikaYogaId.manau));
    });

    test(
      'with no aspect between the lords, a swifter graha between them: Nakta',
      () {
        // Lagna lord Mars at 5° Mesha and the 10th lord Saturn at 15° Karka are
        // 10° apart: outside their 8.5° orb. The Moon at 10° Tula looks at both
        // signs (7th and 10th) and stands between them, 5° from each.
        final TajikaReport r = readTajika(
          synthetic(<Graha, double>{
            Graha.mars: at(0, 5),
            Graha.saturn: at(3, 15),
            Graha.moon: at(6, 10),
            Graha.sun: at(8, 28),
            Graha.mercury: at(9, 28),
            Graha.jupiter: at(10, 28),
            Graha.venus: at(11, 28),
          }),
        );
        expect(forMatter(r, 10), contains(TajikaYogaId.nakta));
        expect(forMatter(r, 10), isNot(contains(TajikaYogaId.ittasala)));
      },
    );

    test(
      'with no aspect between the lords, a slower graha ahead of both: Yamaya',
      () {
        // Lagna lord Mars at 5° Mesha; the 3rd lord Mercury at 13° Vrishabha
        // (the 2nd sign, no aspect). Jupiter in Simha at 13°30′ looks at both
        // (9th and 10th) and stands ahead of both within its own 9°.
        final TajikaReport r = readTajika(
          synthetic(<Graha, double>{
            Graha.mars: at(0, 5),
            Graha.mercury: at(1, 13),
            Graha.jupiter: at(4, 13.5),
            Graha.moon: at(11, 20),
            Graha.sun: at(8, 28),
            Graha.venus: at(9, 28),
            Graha.saturn: at(10, 28),
          }),
        );
        expect(forMatter(r, 3), contains(TajikaYogaId.yamaya));
      },
    );

    test('both lords weak but helped by a strong third: Dutthottha-davira', () {
      // Lagna Mesha: Mars (lagna lord) in Vrishabha and Venus (7th lord) in
      // Vrishchika are both weak, and each applies to Saturn, which holds its
      // own sign in Makara.
      final Kundli chart = synthetic(
        <Graha, double>{
          Graha.mars: at(1, 2),
          Graha.venus: at(7, 3),
          Graha.saturn: at(9, 8),
          Graha.moon: at(7, 25),
          Graha.sun: at(3, 28),
          Graha.mercury: at(3, 25),
          Graha.jupiter: at(4, 28),
        },
        dignity: <Graha, Dignity>{Graha.saturn: Dignity.own},
      );
      final Map<Graha, PanchaVargiyaBala> bala = computePanchaVargiyaBala(
        chart,
      );
      // Only meaningful if the two lords really are under 10 vishwa.
      expect(bala[Graha.mars]!.vishwa, lessThan(10));
      expect(bala[Graha.venus]!.vishwa, lessThan(10));
      final TajikaReport r = readTajika(chart);
      expect(forMatter(r, 7), contains(TajikaYogaId.dutthotthaDavira));
    });

    test('Ikkabala holds when every graha is in a kendra or panaphara', () {
      final TajikaReport r = readTajika(
        synthetic(<Graha, double>{
          Graha.sun: at(0, 5),
          Graha.moon: at(1, 5),
          Graha.mars: at(3, 5),
          Graha.mercury: at(4, 5),
          Graha.jupiter: at(6, 5),
          Graha.venus: at(7, 5),
          Graha.saturn: at(9, 5),
        }),
      );
      expect(r.chartYogas.map((TajikaYoga y) => y.id), <TajikaYogaId>[
        TajikaYogaId.ikkabala,
      ]);
      final TajikaReport cadent = readTajika(
        synthetic(<Graha, double>{
          Graha.sun: at(2, 5),
          Graha.moon: at(5, 5),
          Graha.mars: at(8, 5),
          Graha.mercury: at(11, 5),
          Graha.jupiter: at(2, 25),
          Graha.venus: at(5, 25),
          Graha.saturn: at(8, 25),
        }),
      );
      expect(cadent.chartYogas.map((TajikaYoga y) => y.id), <TajikaYogaId>[
        TajikaYogaId.induvara,
      ]);
    });

    test(
      'every yoga carries its condition, what it indicates and its factors',
      () {
        years.forEach((int age, Varshphal v) {
          for (final TajikaYoga y in v.tajika.allYogas) {
            expect(y.condition.isComplete, isTrue);
            expect(y.indicates.isComplete, isTrue);
            expect(y.name.isComplete, isTrue);
            expect(y.factors, isNotEmpty, reason: '${y.id} age $age');
          }
        });
      },
    );

    test('only the twelve yogas the engine can establish exist', () {
      expect(TajikaYogaId.values.length, 12);
      final Set<String> names = TajikaYogaId.values
          .map((TajikaYogaId id) => id.name)
          .toSet();
      for (final String omitted in <String>[
        'gairiKamboola',
        'tambira',
        'kuttha',
        'durapha',
      ]) {
        expect(names, isNot(contains(omitted)));
      }
    });
  });

  group('reading and honesty', () {
    test('every reading names at least one chart factor', () {
      years.forEach((int age, Varshphal v) {
        expect(v.varshesh.factors, isNotEmpty);
        expect(v.mudda.factors, isNotEmpty);
        expect(v.patyayini.factors, isNotEmpty);
        for (final YearWindow w in v.windows) {
          expect(w.factors, isNotEmpty, reason: 'window ${w.index} age $age');
        }
        for (final Saham s in v.sahams) {
          expect(s.factors, isNotEmpty, reason: '${s.id}');
        }
        for (final TajikaAspect a in v.tajika.aspects) {
          expect(a.factors, isNotEmpty);
        }
        for (final TajikaMatter m in v.tajika.matters) {
          expect(m.factors, isNotEmpty);
        }
        for (final PatyayiniPeriod p in v.patyayini.periods) {
          expect(p.factors, isNotEmpty);
        }
      });
    });

    test('Hindi and English are both present in every text', () {
      years.forEach((int age, Varshphal v) {
        for (final (String where, Bi text) in allTexts(v)) {
          expect(text.en.trim(), isNotEmpty, reason: '$where (en) age $age');
          expect(text.hi.trim(), isNotEmpty, reason: '$where (hi) age $age');
          // Hindi is in Devanagari, not a copy of the English.
          expect(
            RegExp('[ऀ-ॿ]').hasMatch(text.hi),
            isTrue,
            reason: '$where has no Devanagari: ${text.hi}',
          );
        }
      });
    });

    test(
      'no reading mentions death, illness, pregnancy, exams, courts or investments',
      () {
        for (final Varshphal v in years.values) {
          for (final (String where, Bi text) in allTexts(v)) {
            final String? hit = forbiddenTermIn(text);
            expect(hit, isNull, reason: '$where: ${text.en} / ${text.hi}');
          }
        }
      },
    );

    test('the same holds across other births and years', () {
      final List<BirthData> births = <BirthData>[
        birthAt(DateTime(1975, 1, 2, 23, 10)),
        birthAt(DateTime(2001, 6, 21, 14, 0)),
        birthAt(DateTime(1960, 3, 9, 6, 20)),
      ];
      for (final BirthData b in births) {
        final Kundli k = computeKundli(b);
        for (final int age in <int>[3, 14, 31, 47]) {
          final Varshphal v = computeVarshphal(k, age);
          for (final (String where, Bi text) in allTexts(v)) {
            expect(forbiddenTermIn(text), isNull, reason: '$where ${text.en}');
            expect(text.isComplete, isTrue, reason: where);
          }
          expect(v.windows.first.startJd, v.startJd);
          expect(v.windows.last.endJd, v.endJd);
          expect(v.mudda.totalDays, closeTo(v.yearDays, 1e-9));
          for (final Saham s in v.sahams) {
            expect(s.longitude, inInclusiveRange(0, 359.9999999));
          }
        }
      }
    });

    test('the scanner itself catches what it should', () {
      expect(forbiddenTermIn(const Bi('He may die this year', 'अच्छा')), 'die');
      expect(
        forbiddenTermIn(const Bi('ok', 'इस वर्ष मृत्यु का योग')),
        'मृत्यु',
      );
      expect(forbiddenTermIn(const Bi('a health scare', 'ठीक')), 'health');
      expect(forbiddenTermIn(const Bi('she will conceive', 'ठीक')), 'conceive');
      expect(forbiddenTermIn(const Bi('the exam result', 'ठीक')), 'exam');
      expect(
        forbiddenTermIn(const Bi('win the case in court', 'ठीक')),
        'court',
      );
      expect(
        forbiddenTermIn(const Bi('good returns on an investment', 'ठीक')),
        'invest',
      );
      expect(
        forbiddenTermIn(const Bi('a year of steady effort', 'धैर्य')),
        isNull,
      );
    });

    test('the house themes and graha themes speak of no forbidden matter', () {
      for (final Bi theme in houseThemes) {
        expect(forbiddenTermIn(theme), isNull, reason: theme.en);
      }
      for (final Bi theme in grahaThemes.values) {
        expect(forbiddenTermIn(theme), isNull, reason: theme.en);
      }
      for (final TajikaYogaId id in TajikaYogaId.values) {
        expect(forbiddenTermIn(tajikaYogaCondition(id)), isNull, reason: '$id');
        expect(forbiddenTermIn(tajikaYogaIndicates(id)), isNull, reason: '$id');
      }
    });
  });

  group('the earlier varshphal behaviour is kept', () {
    test('the solar return puts the Sun back on its natal degree', () {
      final Varshphal v = years[38]!;
      final Instant instant = Instant.fromUtc(v.returnMoment);
      final double sun = toSidereal(
        positionOf(Graha.sun, instant).tropicalLongitude,
        natal.ayanamsa,
        instant.centuriesTt,
      );
      expect(
        angleDiff(sun, natal.grahas[Graha.sun]!.siderealLongitude).abs() * 60,
        lessThan(1.0),
      );
    });

    test('muntha advances one sign a year', () {
      final Varshphal a = years[0]!;
      final Varshphal b = years[1]!;
      expect((b.munthaSign - a.munthaSign + 12) % 12, 1);
      expect(years[38]!.munthaSign, (natal.lagnaRashi.index + 38) % 12);
    });
  });
}

/// Sidereal longitude of [graha] at [instant], on the ayanamsa of [chart].
double toSiderealDegrees(Kundli chart, Graha graha, Instant instant) =>
    toSidereal(
      positionOf(graha, instant).tropicalLongitude,
      chart.ayanamsa,
      instant.centuriesTt,
    );
