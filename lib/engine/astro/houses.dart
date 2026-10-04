import 'dart:math' as math;

import 'angles.dart';
import 'frames.dart';
import 'time.dart';

/// A place on Earth. Longitude is positive east of Greenwich.
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timeZoneId,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String timeZoneId;
}

/// The rising and culminating points of the ecliptic, tropical degrees of date.
class Angles {
  const Angles({
    required this.ascendant,
    required this.midheaven,
    required this.localSiderealTime,
  });

  final double ascendant;
  final double midheaven;

  /// Local apparent sidereal time in degrees (the RAMC).
  final double localSiderealTime;
}

Angles computeAngles(Instant instant, double latitude, double longitude) {
  final double t = instant.centuriesTt;
  final double ramc = norm360(
    greenwichApparentSiderealTime(instant.julianDayUt, t) + longitude,
  );
  final double eps = trueObliquity(t) * degToRad;
  final double theta = ramc * degToRad;
  final double phi = latitude * degToRad;

  final double mc = math.atan2(
    math.sin(theta),
    math.cos(theta) * math.cos(eps),
  );
  final double ascendant = math.atan2(
    math.cos(theta),
    -(math.sin(theta) * math.cos(eps) + math.tan(phi) * math.sin(eps)),
  );
  return Angles(
    ascendant: norm360(ascendant * radToDeg),
    midheaven: norm360(mc * radToDeg),
    localSiderealTime: ramc,
  );
}

/// Sripati (Porphyry) house cusps, used for the bhava chalit chart.
///
/// The quadrants between the four angles are trisected, which is the
/// convention most Indian software calls "bhava chalit".
List<double> sripatiCusps(double ascendant, double midheaven) => _buildCusps(
  ascendant,
  midheaven,
  norm360(ascendant + 180.0),
  norm360(midheaven + 180.0),
);

double _third(double from, double to, int index) =>
    norm360(from + norm360(to - from) * index / 3.0);

List<double> _buildCusps(
  double ascendant,
  double midheaven,
  double descendant,
  double ic,
) {
  final List<double> cusps = List<double>.filled(12, 0);
  cusps[0] = ascendant;
  cusps[1] = _third(ascendant, ic, 1);
  cusps[2] = _third(ascendant, ic, 2);
  cusps[3] = ic;
  cusps[4] = _third(ic, descendant, 1);
  cusps[5] = _third(ic, descendant, 2);
  cusps[6] = descendant;
  cusps[7] = _third(descendant, midheaven, 1);
  cusps[8] = _third(descendant, midheaven, 2);
  cusps[9] = midheaven;
  cusps[10] = _third(midheaven, ascendant, 1);
  cusps[11] = _third(midheaven, ascendant, 2);
  return cusps;
}

/// Whole-sign house of a longitude given the ascendant, 1..12.
int wholeSignHouse(double longitude, double ascendant) {
  final int ascSign = (ascendant / 30.0).floor();
  final int sign = (longitude / 30.0).floor();
  return ((sign - ascSign + 12) % 12) + 1;
}

/// House of a longitude against explicit cusps, 1..12.
int cuspHouse(double longitude, List<double> cusps) {
  for (int i = 0; i < 12; i++) {
    final double start = cusps[i];
    final double end = cusps[(i + 1) % 12];
    final double span = norm360(end - start);
    final double offset = norm360(longitude - start);
    if (offset < span) return i + 1;
  }
  return 1;
}
