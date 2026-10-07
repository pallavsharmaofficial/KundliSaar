import 'dart:math' as math;

import 'angles.dart';
import 'frames.dart';
import 'series.dart';
import 'time.dart';

/// The nine grahas of Vedic astrology.
enum Graha { sun, moon, mars, mercury, jupiter, venus, saturn, rahu, ketu }

const Map<Graha, String> _seriesBody = <Graha, String>{
  Graha.mercury: 'mercury',
  Graha.venus: 'venus',
  Graha.mars: 'mars',
  Graha.jupiter: 'jupiter',
  Graha.saturn: 'saturn',
};

/// Speed of light in AU per day.
const double _lightSpeedAuPerDay = 173.1446326846693;

/// An apparent geocentric position.
class BodyPosition {
  const BodyPosition({
    required this.graha,
    required this.tropicalLongitude,
    required this.latitude,
    required this.distanceAu,
    required this.speed,
  });

  final Graha graha;

  /// Apparent longitude in the true ecliptic of date, degrees.
  final double tropicalLongitude;
  final double latitude;
  final double distanceAu;

  /// Degrees of longitude per day; negative while retrograde.
  final double speed;

  bool get isRetrograde => speed < 0;
}

List<double> _sphericalToCartesian(double lon, double lat, double r) {
  final double cosLat = math.cos(lat);
  return <double>[
    r * cosLat * math.cos(lon),
    r * cosLat * math.sin(lon),
    r * math.sin(lat),
  ];
}

/// Mass ratio of the Moon to the Earth-Moon system.
const double _moonMassFraction = 0.012150584;

/// Heliocentric position of the centre of the Earth.
///
/// The fitted series describes the Earth-Moon barycentre, which is the smooth
/// quantity; the Earth itself swings about it by some 4,700 km every month,
/// which is 6 arc-seconds of apparent solar longitude and far too much to drop.
List<double> _earthCartesian(double t) {
  final List<double> e = heliocentricOfDate('earth', t);
  final List<double> barycentre = _sphericalToCartesian(e[0], e[1], e[2]);
  final List<double> m = moonOfDate(t);
  final List<double> moon = _sphericalToCartesian(m[0], m[1], m[2]);
  return <double>[
    barycentre[0] - _moonMassFraction * moon[0],
    barycentre[1] - _moonMassFraction * moon[1],
    barycentre[2] - _moonMassFraction * moon[2],
  ];
}

/// Earth's heliocentric velocity in AU per day, by central difference.
List<double> _earthVelocity(double t) {
  const double dtDays = 0.5;
  final double dtCenturies = dtDays / 36525.0;
  final List<double> a = _earthCartesian(t - dtCenturies);
  final List<double> b = _earthCartesian(t + dtCenturies);
  return <double>[
    (b[0] - a[0]) / (2 * dtDays),
    (b[1] - a[1]) / (2 * dtDays),
    (b[2] - a[2]) / (2 * dtDays),
  ];
}

/// Applies first-order annual aberration to a geocentric vector.
List<double> _aberrate(List<double> p, List<double> velocity) {
  final double r = math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
  return <double>[
    p[0] + r * velocity[0] / _lightSpeedAuPerDay,
    p[1] + r * velocity[1] / _lightSpeedAuPerDay,
    p[2] + r * velocity[2] / _lightSpeedAuPerDay,
  ];
}

/// Apparent geocentric direction of [graha] in the true ecliptic of date, as
/// [longitude, latitude] in degrees plus distance in AU.
List<double> apparentOfDate(Graha graha, double t) {
  final List<double> earth = _earthCartesian(t);
  final List<double> velocity = _earthVelocity(t);
  List<double> geo;
  double distance;
  if (graha == Graha.sun) {
    geo = <double>[-earth[0], -earth[1], -earth[2]];
    distance = math.sqrt(geo[0] * geo[0] + geo[1] * geo[1] + geo[2] * geo[2]);
  } else if (graha == Graha.moon) {
    // The Moon travels with the Earth, so its light-time displacement and the
    // annual aberration cancel to first order: correcting for light time from
    // the geocentric series and then aberrating as well would add a false 20
    // arc-seconds. Light time alone, then.
    final List<double> m = moonOfDate(t);
    final double lightDays = m[2] / _lightSpeedAuPerDay;
    final List<double> retarded = moonOfDate(t - lightDays / 36525.0);
    geo = _sphericalToCartesian(retarded[0], retarded[1], retarded[2]);
    final double longitude = math.atan2(geo[1], geo[0]) * radToDeg;
    final double latitude =
        math.atan2(geo[2], math.sqrt(geo[0] * geo[0] + geo[1] * geo[1])) *
        radToDeg;
    return <double>[norm360(longitude), latitude, retarded[2]];
  } else {
    final String body = _seriesBody[graha]!;
    double lightDays = 0;
    geo = <double>[0, 0, 0];
    distance = 0;
    for (int i = 0; i < 3; i++) {
      final List<double> p = heliocentricOfDate(body, t - lightDays / 36525.0);
      final List<double> c = _sphericalToCartesian(p[0], p[1], p[2]);
      geo = <double>[c[0] - earth[0], c[1] - earth[1], c[2] - earth[2]];
      distance = math.sqrt(geo[0] * geo[0] + geo[1] * geo[1] + geo[2] * geo[2]);
      lightDays = distance / _lightSpeedAuPerDay;
    }
  }
  geo = _aberrate(geo, velocity);
  final double longitude = math.atan2(geo[1], geo[0]) * radToDeg;
  final double latitude =
      math.atan2(geo[2], math.sqrt(geo[0] * geo[0] + geo[1] * geo[1])) *
      radToDeg;
  return <double>[norm360(longitude), latitude, distance];
}

/// Mean longitude of the ascending lunar node (Rahu), degrees of date.
double meanNodeLongitude(double t) {
  final double omega =
      125.0445479 -
      1934.1362891 * t +
      0.0020754 * t * t +
      t * t * t / 467441.0 -
      t * t * t * t / 60616000.0;
  // The mean node is referred to the mean equinox of date already.
  return norm360(omega + nutation(t).longitude);
}

/// Apparent geocentric position in the true ecliptic of date.
BodyPosition positionOf(Graha graha, Instant instant) {
  final double t = instant.centuriesTt;
  final double speed = _speedOf(graha, instant);
  if (graha == Graha.rahu || graha == Graha.ketu) {
    final double node = meanNodeLongitude(t);
    final double longitude = graha == Graha.rahu ? node : norm360(node + 180.0);
    return BodyPosition(
      graha: graha,
      tropicalLongitude: longitude,
      latitude: 0,
      distanceAu: 0.00257,
      speed: speed,
    );
  }
  // Already in the true ecliptic of date: precession and nutation are inside
  // the fitted series, so neither is applied again here. Applying them a
  // second time moved every planet by the precession since J2000 (0.36 degrees
  // in 2026, 8 hours of the Sun's motion) and put each Sankranti hours early.
  final List<double> ofDate = apparentOfDate(graha, t);
  return BodyPosition(
    graha: graha,
    tropicalLongitude: ofDate[0],
    latitude: ofDate[1],
    distanceAu: ofDate[2],
    speed: speed,
  );
}

double _rawLongitude(Graha graha, double t) {
  if (graha == Graha.rahu) return meanNodeLongitude(t);
  if (graha == Graha.ketu) return norm360(meanNodeLongitude(t) + 180.0);
  return apparentOfDate(graha, t)[0];
}

double _speedOf(Graha graha, Instant instant) {
  const double stepDays = 0.25;
  final double t = instant.centuriesTt;
  final double step = stepDays / 36525.0;
  final double before = _rawLongitude(graha, t - step);
  final double after = _rawLongitude(graha, t + step);
  return angleDiff(after, before) / (2 * stepDays);
}

/// All nine grahas at one instant.
Map<Graha, BodyPosition> allPositions(Instant instant) => <Graha, BodyPosition>{
  for (final Graha graha in Graha.values) graha: positionOf(graha, instant),
};
