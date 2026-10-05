import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';

/// A chart published in many places, used as an end-to-end check: birth data
/// in, local mean time resolved, ayanamsa applied, houses counted.
///
/// M K Gandhi, 2 October 1869, 07:11:58 local mean time, Porbandar. Published
/// charts give a Libra lagna near four degrees, the Moon in Cancer in
/// Ashlesha, the Sun in Virgo, Mars, Venus and Mercury in Libra, Jupiter in
/// Capricorn and Saturn retrograde in Cancer.
void main() {
  final Kundli kundli = computeKundli(
    BirthData(
      name: 'Gandhi',
      localDateTime: DateTime(1869, 10, 2, 7, 11, 58),
      utcOffset: const Duration(hours: 4, minutes: 38, seconds: 24),
      place: const GeoPlace(
        name: 'Porbandar',
        latitude: 21.6417,
        longitude: 69.6293,
        timeZoneId: 'Asia/Kolkata',
      ),
    ),
  );

  test('the lagna matches the published chart', () {
    expect(kundli.lagnaRashi, Rashi.tula);
    expect(kundli.ascendant % 30, closeTo(4.6, 0.5));
  });

  test('the grahas land in their published signs', () {
    expect(kundli.grahas[Graha.sun]!.rashi, Rashi.kanya);
    expect(kundli.grahas[Graha.moon]!.rashi, Rashi.karka);
    expect(kundli.grahas[Graha.moon]!.nakshatra.english, 'Ashlesha');
    expect(kundli.grahas[Graha.mars]!.rashi, Rashi.tula);
    expect(kundli.grahas[Graha.mercury]!.rashi, Rashi.tula);
    expect(kundli.grahas[Graha.venus]!.rashi, Rashi.tula);
    expect(kundli.grahas[Graha.jupiter]!.rashi, Rashi.makara);
    expect(kundli.grahas[Graha.saturn]!.rashi, Rashi.karka);
    expect(kundli.grahas[Graha.rahu]!.rashi, Rashi.karka);
  });

  test('retrogression matches the published chart', () {
    expect(kundli.grahas[Graha.jupiter]!.isRetrograde, isTrue);
    expect(kundli.grahas[Graha.saturn]!.isRetrograde, isTrue);
    expect(kundli.grahas[Graha.mars]!.isRetrograde, isFalse);
  });

  test('houses are counted from the lagna', () {
    expect(kundli.grahas[Graha.mars]!.house, 1);
    expect(kundli.grahas[Graha.moon]!.house, 10);
    expect(kundli.grahas[Graha.sun]!.house, 12);
    expect(kundli.grahas[Graha.jupiter]!.house, 4);
  });
}
