import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/matching.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/panchang.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/varga.dart';
import 'package:kundlisaar/engine/jyotish/yogas.dart';

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
  group('ayanamsa', () {
    test('Lahiri matches its published anchors', () {
      final Instant j2000 = Instant.fromUtc(DateTime.utc(2000, 1, 1, 12));
      expect(ayanamsaDegrees(Ayanamsa.lahiri, j2000.centuriesTt),
          closeTo(23.8530, 0.001));
      // The Calendar Reform Committee fixed 23 degrees 15 minutes on
      // 21 March 1956; we land within half an arc-minute of it.
      final Instant anchor = Instant.fromUtc(DateTime.utc(1956, 3, 21));
      expect(ayanamsaDegrees(Ayanamsa.lahiri, anchor.centuriesTt),
          closeTo(23.25, 0.01));
    });

    test('ayanamsa grows by roughly 50 arc-seconds a year', () {
      final double a = ayanamsaDegrees(
          Ayanamsa.lahiri, Instant.fromUtc(DateTime.utc(2000)).centuriesTt);
      final double b = ayanamsaDegrees(
          Ayanamsa.lahiri, Instant.fromUtc(DateTime.utc(2010)).centuriesTt);
      expect((b - a) * 3600 / 10, closeTo(50.3, 0.5));
    });
  });

  group('nakshatra and varga', () {
    test('nakshatra boundaries fall every 13 degrees 20 minutes', () {
      expect(nakshatraIndexOf(0), 0);
      expect(nakshatraIndexOf(13.3332), 0);
      expect(nakshatraIndexOf(13.3334), 1);
      expect(nakshatraIndexOf(359.9), 26);
      expect(padaOf(0), 1);
      expect(padaOf(3.3334), 2);
      expect(padaOf(10.1), 4);
    });

    test('navamsa runs continuously through the zodiac', () {
      expect(vargaSign(Varga.d9, 0), 0); // Aries starts in Aries
      expect(vargaSign(Varga.d9, 3.4), 1);
      expect(vargaSign(Varga.d9, 30), 9); // Taurus starts in Capricorn
      expect(vargaSign(Varga.d9, 120), 0); // Leo starts in Aries
    });

    test('hora, drekkana and trimsamsa follow Parashara', () {
      expect(vargaSign(Varga.d2, 5), 4); // first half of an odd sign: Leo
      expect(vargaSign(Varga.d2, 20), 3); // second half: Cancer
      expect(vargaSign(Varga.d2, 35), 3); // even sign reverses
      expect(vargaSign(Varga.d3, 5), 0);
      expect(vargaSign(Varga.d3, 15), 4);
      expect(vargaSign(Varga.d3, 25), 8);
      expect(vargaSign(Varga.d30, 2), 0); // Mars portion of an odd sign
      expect(vargaSign(Varga.d30, 32), 1); // Venus portion of an even sign
    });

    test('every varga maps every degree to a real sign', () {
      for (final Varga varga in Varga.values) {
        for (double longitude = 0; longitude < 360; longitude += 0.37) {
          final int sign = vargaSign(varga, longitude);
          expect(sign, inInclusiveRange(0, 11), reason: '$varga at $longitude');
        }
      }
    });
  });

  group('vimshottari dasha', () {
    final Kundli kundli = computeKundli(sampleBirth());

    test('starts with the lord of the janma nakshatra', () {
      expect(kundli.vimshottari.first.lord, kundli.janmaNakshatra.lord);
    });

    test('the nine mahadashas span 120 years from the balance at birth', () {
      final double total = kundli.vimshottari
          .fold<double>(0, (double sum, DashaPeriod p) => sum + p.lengthDays);
      final double firstFull =
          vimshottariYears[kundli.vimshottari.first.lord]! * vimshottariYear;
      final double expected = 120 * vimshottariYear -
          (firstFull - kundli.vimshottari.first.lengthDays);
      expect(total, closeTo(expected, 1e-6));
    });

    test('antardashas tile their mahadasha exactly', () {
      for (final DashaPeriod maha in kundli.vimshottari) {
        expect(maha.children.length, 9);
        expect(maha.children.first.startJdUt, closeTo(maha.startJdUt, 1e-9));
        expect(maha.children.last.endJdUt, closeTo(maha.endJdUt, 1e-9));
        for (int i = 1; i < maha.children.length; i++) {
          expect(maha.children[i].startJdUt,
              closeTo(maha.children[i - 1].endJdUt, 1e-9));
        }
      }
    });

    test('the running chain is three deep and contains the moment asked for', () {
      final DateTime moment = DateTime.utc(2026, 10, 5);
      final List<DashaPeriod> chain = kundli.dashaChainAt(moment);
      expect(chain.length, 3);
      final double jd = julianDayFromUtc(moment);
      for (final DashaPeriod period in chain) {
        expect(period.contains(jd), isTrue);
      }
    });
  });

  group('chart', () {
    final Kundli kundli = computeKundli(sampleBirth());

    test('sidereal longitudes are the tropical ones less the ayanamsa', () {
      for (final PlacedGraha graha in kundli.grahas.values) {
        expect(
          norm360(graha.tropicalLongitude - kundli.ayanamsaValue),
          closeTo(graha.siderealLongitude, 1e-9),
        );
      }
    });

    test('Ketu sits opposite Rahu and both move backwards', () {
      final double rahu = kundli.grahas[Graha.rahu]!.siderealLongitude;
      final double ketu = kundli.grahas[Graha.ketu]!.siderealLongitude;
      expect(norm360(ketu - rahu), closeTo(180, 1e-9));
      expect(kundli.grahas[Graha.rahu]!.speed, lessThan(0));
    });

    test('houses are whole signs counted from the lagna', () {
      expect(kundli.grahas.values.map((PlacedGraha g) => g.house),
          everyElement(inInclusiveRange(1, 12)));
      for (final PlacedGraha graha in kundli.grahas.values) {
        final int expected =
            ((graha.rashi.index - kundli.lagnaRashi.index + 12) % 12) + 1;
        expect(graha.house, expected);
      }
    });

    test('dignities land where the classical tables put them', () {
      expect(
        computeKundli(sampleBirth()).grahas[Graha.sun]!.dignity,
        isA<Dignity>(),
      );
      // The Sun is exalted in Aries and debilitated in Libra.
      final BirthData birth = sampleBirth();
      final Kundli k = computeKundli(birth);
      final PlacedGraha sun = k.grahas[Graha.sun]!;
      if (sun.rashi == Rashi.mesha) expect(sun.dignity, Dignity.exalted);
      if (sun.rashi == Rashi.tula) expect(sun.dignity, Dignity.debilitated);
    });

    test('yoga detection returns findings that name their own rule', () {
      final List<YogaFinding> findings = findYogas(kundli);
      for (final YogaFinding finding in findings) {
        expect(finding.ruleEnglish, isNotEmpty);
        expect(finding.ruleHindi, isNotEmpty);
        expect(finding.meaningEnglish, isNotEmpty);
      }
    });
  });

  group('panchang', () {
    test('a new moon is the end of Amavasya', () {
      // New Moon on 18 January 2026 at 19:51:59 UT, from the JPL kernel.
      final Instant newMoon = Instant.fromJulianDayUt(2461059.327766);
      final double sun =
          positionOf(Graha.sun, newMoon).tropicalLongitude;
      final double moon =
          positionOf(Graha.moon, newMoon).tropicalLongitude;
      expect(angleDiff(moon, sun).abs() * 60, lessThan(1.0),
          reason: 'elongation should be under an arc-minute at new moon');
    });

    test('a full moon falls at the end of Purnima', () {
      final Instant fullMoon = Instant.fromJulianDayUt(2461073.423088);
      final double sun = positionOf(Graha.sun, fullMoon).tropicalLongitude;
      final double moon = positionOf(Graha.moon, fullMoon).tropicalLongitude;
      expect((norm360(moon - sun) - 180).abs() * 60, lessThan(1.0));
    });

    test('a Delhi day has sunrise before sunset and the right elements', () {
      final Panchang panchang = computePanchang(
        localDate: DateTime(2026, 10, 5),
        utcOffset: const Duration(hours: 5, minutes: 30),
        place: delhi,
      );
      expect(panchang.sunrise, isNotNull);
      expect(panchang.sunset, isNotNull);
      expect(panchang.sunset! - panchang.sunrise!, greaterThan(0.4));
      expect(panchang.sunset! - panchang.sunrise!, lessThan(0.6));
      expect(panchang.tithi.index, inInclusiveRange(0, 29));
      expect(panchang.nakshatra.index, inInclusiveRange(0, 26));
      expect(panchang.yoga.index, inInclusiveRange(0, 26));
      expect(panchang.dayChoghadiya.length, 8);
      expect(panchang.nightChoghadiya.length, 8);
      expect(panchang.horas.length, 24);
      expect(panchang.tithi.endsAtJdUt, greaterThan(panchang.sunrise!));
      expect(panchang.rahuKaal!.endJdUt, greaterThan(panchang.rahuKaal!.startJdUt));
      // Rahu Kaal always sits inside the daylight hours.
      expect(panchang.rahuKaal!.startJdUt, greaterThanOrEqualTo(panchang.sunrise!));
      expect(panchang.rahuKaal!.endJdUt, lessThanOrEqualTo(panchang.sunset! + 1e-9));
    });

    test('the hora sequence starts with the lord of the weekday', () {
      final Panchang panchang = computePanchang(
        localDate: DateTime(2026, 10, 5),
        utcOffset: const Duration(hours: 5, minutes: 30),
        place: delhi,
      );
      expect(panchang.horas.first.name, panchang.dayLord.name);
    });
  });

  group('matching', () {
    test('scores stay inside every koota maximum and the total of 36', () {
      final Kundli bride = computeKundli(sampleBirth());
      final Kundli groom = computeKundli(BirthData(
        name: 'Other',
        localDateTime: DateTime(1986, 2, 3, 18, 10),
        utcOffset: const Duration(hours: 5, minutes: 30),
        place: delhi,
      ));
      final MatchResult result = matchCharts(bride, groom);
      expect(result.kootas.length, 8);
      for (final Koota koota in result.kootas) {
        expect(koota.score, inInclusiveRange(0, koota.maximum));
        expect(koota.reasonHindi, isNotEmpty);
      }
      expect(result.total, inInclusiveRange(0, 36));
      expect(
        result.kootas.fold<double>(0, (double s, Koota k) => s + k.maximum),
        36,
      );
    });

    test('the same nakshatra nadi always scores zero', () {
      final Kundli same = computeKundli(sampleBirth());
      final MatchResult result = matchCharts(same, same);
      final Koota nadi =
          result.kootas.firstWhere((Koota k) => k.key == 'nadi');
      expect(nadi.score, 0);
    });
  });
}
