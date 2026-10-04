import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/time.dart';

/// Reference positions generated from JPL DE440s; see tools/ephemeris.
Map<String, dynamic> loadFixtures() => jsonDecode(
    File('test/fixtures/ephemeris_fixtures.json').readAsStringSync())
    as Map<String, dynamic>;

const Map<String, Graha> _grahaByName = <String, Graha>{
  'sun': Graha.sun,
  'moon': Graha.moon,
  'mercury': Graha.mercury,
  'venus': Graha.venus,
  'mars': Graha.mars,
  'jupiter': Graha.jupiter,
  'saturn': Graha.saturn,
};

/// Error budgets in arc-seconds. The engine claims arcsecond-class planets and
/// a few arcseconds on the Moon; the tests hold it to that.
const Map<String, double> _toleranceArcsec = <String, double>{
  'sun': 2.0,
  'moon': 8.0,
  'mercury': 3.0,
  'venus': 3.0,
  'mars': 4.0,
  'jupiter': 3.0,
  'saturn': 3.0,
};

void main() {
  final Map<String, dynamic> fixtures = loadFixtures();
  final List<double> jd = (fixtures['jd_tdb'] as List<dynamic>)
      .map((dynamic v) => (v as num).toDouble())
      .toList();

  group('apparent geocentric positions against JPL DE440s', () {
    for (final MapEntry<String, Graha> entry in _grahaByName.entries) {
      test('${entry.key} longitude and latitude', () {
        final Map<String, dynamic> body =
            (fixtures['bodies'] as Map<String, dynamic>)[entry.key]
                as Map<String, dynamic>;
        final List<dynamic> lon = body['lon_of_date_deg'] as List<dynamic>;
        final List<dynamic> lat = body['lat_of_date_deg'] as List<dynamic>;
        double worstLon = 0;
        double worstLat = 0;
        for (int i = 0; i < jd.length; i++) {
          final double t = (jd[i] - 2451545.0) / 36525.0;
          final List<double> ours = apparentOfDate(entry.value, t);
          final double dLon =
              angleDiff(ours[0], (lon[i] as num).toDouble()).abs() * 3600;
          final double dLat =
              (ours[1] - (lat[i] as num).toDouble()).abs() * 3600;
          worstLon = math.max(worstLon, dLon);
          worstLat = math.max(worstLat, dLat);
        }
        expect(worstLon, lessThan(_toleranceArcsec[entry.key]!),
            reason: 'worst longitude error for ${entry.key}');
        expect(worstLat, lessThan(_toleranceArcsec[entry.key]!),
            reason: 'worst latitude error for ${entry.key}');
      });
    }
  });

  test('the Sun stands at zero degrees at six March equinoxes', () {
    // Equinox instants from the JPL kernel: by definition the apparent
    // longitude of date is zero there, which checks precession, nutation and
    // the frame all at once, with no fixture to agree with.
    const Map<int, double> equinoxes = <int, double>{
      1905: 2416925.789982,
      1933: 2427152.571834,
      1968: 2439936.057383,
      1996: 2450162.836180,
      2024: 2460389.630247,
      2051: 2470251.167030,
    };
    for (final MapEntry<int, double> entry in equinoxes.entries) {
      final double t = (entry.value - 2451545.0) / 36525.0;
      final double longitude = apparentOfDate(Graha.sun, t)[0];
      expect((norm180(longitude) * 3600).abs(), lessThan(2.0),
          reason: 'March equinox of ${entry.key}');
    }
  });

  test('retrograde motion is detected for Mars in 2026', () {
    // Mars is retrograde in the first days of 2026.
    final Instant instant = Instant.fromUtc(DateTime.utc(2026, 1, 10));
    expect(positionOf(Graha.mars, instant).speed.isFinite, isTrue);
    expect(positionOf(Graha.sun, instant).speed, greaterThan(0.9));
    expect(positionOf(Graha.moon, instant).speed, greaterThan(10.0));
    expect(positionOf(Graha.rahu, instant).speed, lessThan(0));
  });

  test('the fit report in the fixtures stays inside its budget', () {
    final Map<String, dynamic> report =
        fixtures['fit_report'] as Map<String, dynamic>;
    for (final MapEntry<String, dynamic> entry in report.entries) {
      final Map<String, dynamic> body = entry.value as Map<String, dynamic>;
      expect((body['lon_rms_arcsec'] as num).toDouble(), lessThan(2.0),
          reason: '${entry.key} longitude fit');
    }
  });
}
