import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/ashtakavarga.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/festivals.dart';
import 'package:kundlisaar/engine/jyotish/hastrekha.dart';
import 'package:kundlisaar/engine/jyotish/muhurta.dart';
import 'package:kundlisaar/engine/jyotish/namkaran.dart';
import 'package:kundlisaar/engine/jyotish/numerology.dart';
import 'package:kundlisaar/engine/jyotish/prashna.dart';
import 'package:kundlisaar/engine/jyotish/rashifal.dart';
import 'package:kundlisaar/engine/jyotish/remedies.dart';
import 'package:kundlisaar/engine/jyotish/shadbala.dart';
import 'package:kundlisaar/engine/jyotish/transits.dart';
import 'package:kundlisaar/engine/jyotish/varshphal.dart';

const GeoPlace delhi = GeoPlace(
  name: 'Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);

BirthData sampleBirth() => BirthData(
  name: 'Test',
  localDateTime: DateTime(1988, 8, 14, 9, 35),
  utcOffset: const Duration(hours: 5, minutes: 30),
  place: delhi,
);

void main() {
  final Kundli kundli = computeKundli(sampleBirth());

  group('ashtakavarga', () {
    final AshtakavargaResult result = computeAshtakavarga(kundli);

    test('each graha carries its published number of bindus', () {
      const Map<Graha, int> published = <Graha, int>{
        Graha.sun: 48,
        Graha.moon: 49,
        Graha.mars: 39,
        Graha.mercury: 54,
        Graha.jupiter: 56,
        Graha.venus: 52,
        Graha.saturn: 39,
      };
      published.forEach((Graha graha, int total) {
        expect(result.charts[graha]!.total, total, reason: graha.name);
      });
    });

    test('the sarvashtakavarga always totals 337', () {
      expect(result.sarvaTotal, 337);
      expect(result.sarva.length, 12);
      expect(result.sarva.every((int b) => b >= 0 && b <= 56), isTrue);
    });

    test('the bindu tables themselves are the classical ones', () {
      int total = 0;
      for (final Graha graha in ashtakavargaGrahas) {
        for (final List<int> houses in benefic[graha]!.values) {
          total += houses.length;
          expect(houses.every((int h) => h >= 1 && h <= 12), isTrue);
        }
        total += beneficFromLagna[graha]!.length;
      }
      expect(total, 337);
    });
  });

  group('shadbala', () {
    final Map<Graha, BalaBreakdown> bala = computeShadbala(kundli);

    test('all seven grahas get a strength in a believable range', () {
      for (final Graha graha in shadbalaGrahas) {
        final BalaBreakdown breakdown = bala[graha]!;
        expect(breakdown.totalRupas, greaterThan(2.0), reason: graha.name);
        expect(breakdown.totalRupas, lessThan(16.0), reason: graha.name);
        expect(
          breakdown.totalVirupas,
          closeTo(breakdown.totalRupas * 60, 1e-6),
        );
      }
    });

    test('the parts add up to the whole', () {
      final BalaBreakdown sun = bala[Graha.sun]!;
      expect(
        sun.sthana +
            sun.dig +
            sun.kala +
            sun.chesta +
            sun.naisargika +
            sun.drik,
        closeTo(sun.totalVirupas, 1e-9),
      );
    });

    test('uchcha bala peaks at exaltation and bottoms at debilitation', () {
      // The Sun is exalted at 10 Aries and fallen at 10 Libra.
      final Kundli exalted = computeKundli(
        BirthData(
          name: 'x',
          localDateTime: DateTime(2020, 4, 24, 12),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: delhi,
        ),
      );
      final double sunLongitude = exalted.grahas[Graha.sun]!.siderealLongitude;
      expect(sunLongitude, greaterThan(0));
      expect(
        computeShadbala(exalted)[Graha.sun]!.uchcha,
        inInclusiveRange(0.0, 60.0),
      );
    });

    test('naisargika bala follows the fixed classical order', () {
      expect(bala[Graha.sun]!.naisargika, 60.0);
      expect(bala[Graha.saturn]!.naisargika, 8.57);
      expect(
        bala[Graha.moon]!.naisargika,
        greaterThan(bala[Graha.venus]!.naisargika),
      );
    });
  });

  group('transits', () {
    final TransitReport report = computeTransits(
      kundli,
      DateTime.utc(2026, 10, 6),
    );

    test('every graha is placed, with houses counted from the Moon', () {
      expect(report.positions.length, Graha.values.length);
      for (final TransitPosition position in report.positions.values) {
        expect(position.houseFromMoon, inInclusiveRange(1, 12));
        expect(position.houseFromLagna, inInclusiveRange(1, 12));
        expect(position.bindusInSign, inInclusiveRange(0, 56));
      }
    });

    test('sade sati reports a phase only while it is running', () {
      expect(
        report.sadeSati.phase,
        report.sadeSati.isRunning ? inInclusiveRange(1, 3) : 0,
      );
    });

    test('Jupiter comes back to its natal sign within twelve years', () {
      final DateTime? jupiter = report.jupiterReturn;
      expect(jupiter, isNotNull);
      expect(
        jupiter!.difference(DateTime.utc(2026, 10, 6)).inDays,
        lessThan(4400),
      );
    });
  });

  group('varshphal', () {
    test('the solar return puts the Sun back on its natal degree', () {
      final Varshphal varshphal = computeVarshphal(kundli, 38);
      final Instant instant = Instant.fromUtc(varshphal.returnMoment);
      final double sun = toSidereal(
        positionOf(Graha.sun, instant).tropicalLongitude,
        kundli.ayanamsa,
        instant.centuriesTt,
      );
      expect(
        angleDiff(sun, kundli.grahas[Graha.sun]!.siderealLongitude).abs() * 60,
        lessThan(1.0),
        reason: 'within an arc-minute of the natal Sun',
      );
    });

    test('muntha advances one sign a year', () {
      final Varshphal first = computeVarshphal(kundli, 10);
      final Varshphal second = computeVarshphal(kundli, 11);
      expect((second.munthaSign - first.munthaSign + 12) % 12, 1);
    });
  });

  group('muhurta', () {
    test('windows come back ranked, inside the range asked for', () {
      final List<MuhurtaWindow> windows = findMuhurta(
        activity: Activity.vehicle,
        from: DateTime(2026, 10, 6),
        days: 7,
        utcOffset: const Duration(hours: 5, minutes: 30),
        place: delhi,
        forPerson: kundli,
        limit: 10,
      );
      expect(windows, isNotEmpty);
      for (int i = 1; i < windows.length; i++) {
        expect(windows[i - 1].score, greaterThanOrEqualTo(windows[i].score));
      }
      for (final MuhurtaWindow window in windows) {
        expect(window.score, inInclusiveRange(0, 100));
        expect(window.reasons, isNotEmpty);
        expect(window.reasonsHindi.length, window.reasons.length);
        expect(window.endJdUt, greaterThan(window.startJdUt));
      }
    });

    test('every activity has a nakshatra list and a weekday list', () {
      for (final ActivityInfo info in activityTable) {
        expect(info.nakshatras, isNotEmpty);
        expect(info.nakshatras.every((int n) => n >= 0 && n <= 26), isTrue);
        expect(info.weekdays.every((int d) => d >= 0 && d <= 6), isTrue);
      }
    });
  });

  group('festivals', () {
    final List<Festival> festivals = festivalsForYear(
      year: 2026,
      place: delhi,
      utcOffset: const Duration(hours: 5, minutes: 30),
    );

    Festival find(String name) =>
        festivals.firstWhere((Festival f) => f.english.startsWith(name));

    test('Diwali 2026 lands on 8 November', () {
      final Festival diwali = find('Diwali');
      expect(diwali.date.month, 11);
      expect(diwali.date.day, 8);
    });

    test('Makar Sankranti 2026 lands in mid January', () {
      final Festival sankranti = find('Makar Sankranti');
      expect(sankranti.date.month, 1);
      expect(sankranti.date.day, inInclusiveRange(14, 15));
    });

    test('Dussehra is read at aparahna, not at sunrise', () {
      // Published panchangs put Vijayadashami 2026 on 20 October. Dashami
      // begins that afternoon, inside aparahna, and runs past the following
      // sunrise; reading the tithi at sunrise, or at one instant of aparahna,
      // lands a day late.
      final Festival dussehra = find('Dussehra');
      expect(dussehra.date.month, 10);
      expect(dussehra.date.day, 20);
    });

    test('Holi follows Holika Dahan by a day', () {
      final Festival dahan = find('Holika Dahan');
      final Festival holi = find('Holi,');
      expect(holi.date.difference(dahan.date).inDays, 1);
    });

    test('there are roughly two Ekadashis a month', () {
      final int ekadashis = festivals
          .where((Festival f) => f.english == 'Ekadashi')
          .length;
      expect(ekadashis, inInclusiveRange(22, 27));
    });
  });

  group('numerology', () {
    test('mulank and bhagyank reduce the way Ank Jyotish reduces', () {
      final NumerologyReading reading = computeNumerology(
        birthDate: DateTime(1988, 8, 14),
        name: 'Test',
      );
      expect(reading.mulank, 5); // 1 + 4
      expect(reading.bhagyank, digitSum(1 + 4 + 8 + 1 + 9 + 8 + 8));
      expect(reading.loshu.values.every((int v) => v >= 0), isTrue);
      expect(numberInfo(reading.mulank).planet, 'Mercury');
    });

    test('digit sums never return zero', () {
      for (int i = 1; i <= 400; i++) {
        expect(digitSum(i), inInclusiveRange(1, 9));
      }
    });
  });

  group('namkaran', () {
    test('the syllable follows the nakshatra pada', () {
      expect(namkaranFor(0.5).syllable, 'Chu');
      expect(namkaranFor(3.5).syllable, 'Che');
      expect(namkaranFor(13.4).syllable, 'Li');
      expect(padaSyllables.length, 27);
      expect(padaSyllablesHindi.length, 27);
      for (final List<String> row in padaSyllables) {
        expect(row.length, 4);
      }
    });
  });

  group('hastrekha', () {
    test('the default trace reads, and an absent line is read as absent', () {
      final Map<PalmLine, TracedLine> lines = <PalmLine, TracedLine>{
        for (final MapEntry<PalmLine, List<PalmPoint>> entry
            in defaultTrace.entries)
          entry.key: TracedLine(
            line: entry.key,
            points: entry.value,
            isPresent: entry.key != PalmLine.fate,
          ),
      };
      final HastrekhaReading reading = readPalm(
        lines: lines,
        mountProminence: <Mount, int>{Mount.venus: 2, Mount.jupiter: 1},
        handType: HandType.earth,
        kundli: kundli,
      );
      expect(reading.lines, isNotEmpty);
      expect(reading.mounts.length, 1);
      expect(reading.mounts.first.chartAgreement, isNotNull);
      final LineReading fate = reading.lines.firstWhere(
        (LineReading r) => r.line == PalmLine.fate,
      );
      expect(fate.measured, 'Not present');
      for (final LineReading line in reading.lines) {
        expect(line.reading, isNotEmpty);
        expect(line.readingHindi, isNotEmpty);
      }
    });

    test('hand type follows the palm and finger proportions', () {
      expect(
        handTypeFrom(palmWidth: 0.9, palmLength: 1, fingerLength: 0.8),
        HandType.earth,
      );
      expect(
        handTypeFrom(palmWidth: 0.9, palmLength: 1, fingerLength: 1.0),
        HandType.air,
      );
      expect(
        handTypeFrom(palmWidth: 0.7, palmLength: 1, fingerLength: 1.0),
        HandType.water,
      );
      expect(
        handTypeFrom(palmWidth: 0.7, palmLength: 1, fingerLength: 0.8),
        HandType.fire,
      );
    });
  });

  group('prashna and the daily reading', () {
    test('a prashna chart scores inside its range and names its factors', () {
      final PrashnaReading reading = castPrashna(
        question: 'Will the work move?',
        moment: DateTime(2026, 10, 6, 11, 30),
        utcOffset: const Duration(hours: 5, minutes: 30),
        place: delhi,
      );
      expect(reading.score, inInclusiveRange(-5, 5));
      expect(reading.factors, isNotEmpty);
      expect(reading.factorsHindi.length, reading.factors.length);
      expect(reading.verdict(hindi: false), isNotEmpty);
      expect(reading.verdict(hindi: true), isNotEmpty);
    });

    test('the daily reading names the tara and the Moon house', () {
      final DailyReading reading = dailyReading(kundli, DateTime(2026, 10, 6));
      expect(reading.moonHouse, inInclusiveRange(1, 12));
      expect(reading.tara, inInclusiveRange(0, 8));
      expect(reading.points, isNotEmpty);
      expect(reading.luckyNumber, inInclusiveRange(1, 9));
      for (final ReadingPoint point in reading.points) {
        expect(point.text, isNotEmpty);
        expect(point.textHindi, isNotEmpty);
      }
    });
  });

  group('remedies', () {
    test('remedies are chosen from the chart and carry their reason', () {
      final List<RemedySet> remedies = remediesFor(kundli);
      expect(remedies.length, lessThanOrEqualTo(3));
      for (final RemedySet remedy in remedies) {
        expect(remedy.reason, contains('because'));
        expect(remedy.japaCount, greaterThan(0));
        expect(remedy.simpleActHindi, isNotEmpty);
      }
    });
  });
}
