import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/frames.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';

/// Altitude of an ecliptic point of date, for the brute-force check.
double _altitudeOfEclipticPoint(
  double longitude,
  Instant instant,
  double latitude,
  double placeLongitude,
) {
  final double t = instant.centuriesTt;
  final List<double> eq = eclipticToEquatorial(longitude, 0, trueObliquity(t));
  final double lst = norm360(
    greenwichApparentSiderealTime(instant.julianDayUt, t) + placeLongitude,
  );
  final double h = norm180(lst - eq[0]) * degToRad;
  final double dec = eq[1] * degToRad;
  final double phi = latitude * degToRad;
  return math.asin(
        math.sin(phi) * math.sin(dec) +
            math.cos(phi) * math.cos(dec) * math.cos(h),
      ) *
      radToDeg;
}

void main() {
  test('the closed-form ascendant is the point rising on the horizon', () {
    final List<List<double>> places = <List<double>>[
      <double>[28.6139, 77.2090], // Delhi
      <double>[13.0827, 80.2707], // Chennai
      <double>[-33.8688, 151.2093], // Sydney
      <double>[51.5072, -0.1276], // London
    ];
    for (final List<double> place in places) {
      for (int hour = 0; hour < 24; hour += 3) {
        final Instant instant = Instant.fromUtc(
          DateTime.utc(1994, 7, 21, hour, 17),
        );
        final Angles angles = computeAngles(instant, place[0], place[1]);
        final double altitude = _altitudeOfEclipticPoint(
          angles.ascendant,
          instant,
          place[0],
          place[1],
        );
        expect(
          altitude.abs(),
          lessThan(0.02),
          reason: 'ascendant should sit on the horizon at ${place[0]}',
        );
        // Degrees that follow the ascendant have not risen yet; degrees
        // behind it are already up. That is what tells the rising point from
        // the setting one.
        final double ahead = _altitudeOfEclipticPoint(
          norm360(angles.ascendant + 1),
          instant,
          place[0],
          place[1],
        );
        final double behind = _altitudeOfEclipticPoint(
          norm360(angles.ascendant - 1),
          instant,
          place[0],
          place[1],
        );
        expect(
          ahead,
          lessThan(0),
          reason: 'the degree after the lagna is still below the horizon',
        );
        expect(
          behind,
          greaterThan(0),
          reason: 'the degree before the lagna has already risen',
        );
      }
    }
  });

  test('the midheaven has the right ascension of the meridian', () {
    final Instant instant = Instant.fromUtc(DateTime.utc(2001, 3, 14, 6, 30));
    final Angles angles = computeAngles(instant, 19.0760, 72.8777);
    final List<double> eq = eclipticToEquatorial(
      angles.midheaven,
      0,
      trueObliquity(instant.centuriesTt),
    );
    expect(angleDiff(eq[0], angles.localSiderealTime).abs(), lessThan(0.001));
  });

  test('whole-sign houses run forward from the lagna', () {
    expect(wholeSignHouse(15.0, 5.0), 1);
    expect(wholeSignHouse(35.0, 5.0), 2);
    expect(wholeSignHouse(355.0, 5.0), 12);
  });

  test('Sripati cusps start at the lagna and reach the midheaven', () {
    final List<double> cusps = sripatiCusps(100.0, 10.0);
    expect(cusps[0], closeTo(100.0, 1e-9));
    expect(cusps[9], closeTo(10.0, 1e-9));
    expect(cusps[6], closeTo(280.0, 1e-9));
    for (int i = 0; i < 12; i++) {
      expect(norm360(cusps[(i + 1) % 12] - cusps[i]), greaterThan(0));
    }
  });
}
