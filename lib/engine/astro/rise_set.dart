import 'dart:math' as math;

import 'angles.dart';
import 'ephemeris.dart';
import 'frames.dart';
import 'houses.dart';
import 'time.dart';

/// Altitude of a graha above the horizon, in degrees.
double altitudeOf(Graha graha, Instant instant, GeoPlace place) {
  final BodyPosition position = positionOf(graha, instant);
  final double t = instant.centuriesTt;
  final List<double> equatorial = eclipticToEquatorial(
    position.tropicalLongitude,
    position.latitude,
    trueObliquity(t),
  );
  final double lst = norm360(
    greenwichApparentSiderealTime(instant.julianDayUt, t) + place.longitude,
  );
  final double hourAngle = norm180(lst - equatorial[0]) * degToRad;
  final double declination = equatorial[1] * degToRad;
  final double latitude = place.latitude * degToRad;
  final double sinAltitude =
      math.sin(latitude) * math.sin(declination) +
      math.cos(latitude) * math.cos(declination) * math.cos(hourAngle);
  return math.asin(sinAltitude.clamp(-1.0, 1.0)) * radToDeg;
}

/// Standard horizon depressions, in degrees.
const double sunHorizon = -0.8333;
const double moonHorizon = 0.125;

/// A rising and a setting, as UT Julian days. Either can be null inside the
/// polar circles, where a body may not cross the horizon on a given day.
class RiseSet {
  const RiseSet(this.rise, this.set);

  final double? rise;
  final double? set;
}

/// Scans [spanDays] from [startJdUt] for horizon crossings of [graha].
RiseSet findRiseSet(
  Graha graha,
  double startJdUt,
  GeoPlace place, {
  double horizon = sunHorizon,
  double spanDays = 1.0,
  int steps = 144,
}) {
  double? rise;
  double? set;
  final double step = spanDays / steps;
  double previousJd = startJdUt;
  double previous =
      altitudeOf(graha, Instant.fromJulianDayUt(previousJd), place) - horizon;
  for (int i = 1; i <= steps; i++) {
    final double jd = startJdUt + i * step;
    final double current =
        altitudeOf(graha, Instant.fromJulianDayUt(jd), place) - horizon;
    if (previous.sign != current.sign) {
      final double crossing = _bisect(graha, place, horizon, previousJd, jd);
      if (current > previous) {
        rise ??= crossing;
      } else {
        set ??= crossing;
      }
    }
    previousJd = jd;
    previous = current;
  }
  return RiseSet(rise, set);
}

double _bisect(
  Graha graha,
  GeoPlace place,
  double horizon,
  double low,
  double high,
) {
  double a = low;
  double b = high;
  double fa = altitudeOf(graha, Instant.fromJulianDayUt(a), place) - horizon;
  for (int i = 0; i < 24; i++) {
    final double mid = (a + b) / 2;
    final double fm =
        altitudeOf(graha, Instant.fromJulianDayUt(mid), place) - horizon;
    if (fa.sign == fm.sign) {
      a = mid;
      fa = fm;
    } else {
      b = mid;
    }
    if ((b - a) < 1e-6) break;
  }
  return (a + b) / 2;
}
