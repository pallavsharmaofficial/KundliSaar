import 'dart:math' as math;

import 'angles.dart';

/// Mean obliquity of the ecliptic, in degrees (Meeus 22.2).
double meanObliquity(double t) {
  final double arcsec =
      23.0 * 3600.0 +
      26.0 * 60.0 +
      21.448 -
      46.8150 * t -
      0.00059 * t * t +
      0.001813 * t * t * t;
  return arcsec / 3600.0;
}

/// Nutation in longitude and obliquity, in degrees.
class Nutation {
  const Nutation(this.longitude, this.obliquity);

  final double longitude;
  final double obliquity;
}

Nutation nutation(double t) {
  final double omega =
      (125.04452 - 1934.136261 * t + 0.0020708 * t * t + t * t * t / 450000.0) *
      degToRad;
  final double lSun = (280.4665 + 36000.7698 * t) * degToRad;
  final double lMoon = (218.3165 + 481267.8813 * t) * degToRad;
  final double dPsi =
      -17.20 * math.sin(omega) -
      1.32 * math.sin(2 * lSun) -
      0.23 * math.sin(2 * lMoon) +
      0.21 * math.sin(2 * omega);
  final double dEps =
      9.20 * math.cos(omega) +
      0.57 * math.cos(2 * lSun) +
      0.10 * math.cos(2 * lMoon) -
      0.09 * math.cos(2 * omega);
  return Nutation(dPsi / 3600.0, dEps / 3600.0);
}

double trueObliquity(double t) => meanObliquity(t) + nutation(t).obliquity;

/// An ecliptic direction: longitude and latitude in degrees.
class Ecliptic {
  const Ecliptic(this.longitude, this.latitude);

  final double longitude;
  final double latitude;
}

/// Precesses an ecliptic position from J2000 to the mean ecliptic and equinox
/// of date, through the equatorial frame so the rotation is the standard
/// IAU 1976 one rather than an ecliptic approximation.
Ecliptic precessFromJ2000(Ecliptic position, double t) {
  final double eps0 = meanObliquity(0) * degToRad;
  final double lon = position.longitude * degToRad;
  final double lat = position.latitude * degToRad;

  // J2000 ecliptic -> J2000 equatorial.
  final double x0 = math.cos(lat) * math.cos(lon);
  final double y0 = math.cos(lat) * math.sin(lon);
  final double z0 = math.sin(lat);
  final double xe = x0;
  final double ye = y0 * math.cos(eps0) - z0 * math.sin(eps0);
  final double ze = y0 * math.sin(eps0) + z0 * math.cos(eps0);

  // Equatorial precession, IAU 1976 angles in arc-seconds.
  final double zeta =
      (2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) /
      3600.0 *
      degToRad;
  final double z =
      (2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) /
      3600.0 *
      degToRad;
  final double theta =
      (2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) /
      3600.0 *
      degToRad;
  final double cosZeta = math.cos(zeta), sinZeta = math.sin(zeta);
  final double cosZ = math.cos(z), sinZ = math.sin(z);
  final double cosTheta = math.cos(theta), sinTheta = math.sin(theta);
  final double x1 =
      (cosZeta * cosTheta * cosZ - sinZeta * sinZ) * xe +
      (-sinZeta * cosTheta * cosZ - cosZeta * sinZ) * ye +
      (-sinTheta * cosZ) * ze;
  final double y1 =
      (cosZeta * cosTheta * sinZ + sinZeta * cosZ) * xe +
      (-sinZeta * cosTheta * sinZ + cosZeta * cosZ) * ye +
      (-sinTheta * sinZ) * ze;
  final double z1 =
      (cosZeta * sinTheta) * xe + (-sinZeta * sinTheta) * ye + cosTheta * ze;

  // Equatorial of date -> ecliptic of date.
  final double eps = meanObliquity(t) * degToRad;
  final double xd = x1;
  final double yd = y1 * math.cos(eps) + z1 * math.sin(eps);
  final double zd = -y1 * math.sin(eps) + z1 * math.cos(eps);
  return Ecliptic(
    norm360(math.atan2(yd, xd) * radToDeg),
    math.asin(zd.clamp(-1.0, 1.0)) * radToDeg,
  );
}

/// General precession in longitude since J2000, in degrees.
double precessionInLongitude(double t) =>
    (5029.0966 * t + 1.11113 * t * t - 0.000006 * t * t * t) / 3600.0;

/// Greenwich mean sidereal time in degrees for a UT Julian day.
double greenwichMeanSiderealTime(double jdUt) {
  final double t = (jdUt - 2451545.0) / 36525.0;
  final double theta =
      280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000.0;
  return norm360(theta);
}

/// Greenwich apparent sidereal time in degrees.
double greenwichApparentSiderealTime(double jdUt, double tTt) {
  final Nutation n = nutation(tTt);
  return norm360(
    greenwichMeanSiderealTime(jdUt) +
        n.longitude * math.cos(trueObliquity(tTt) * degToRad),
  );
}

/// Converts ecliptic to equatorial coordinates; angles in degrees.
List<double> eclipticToEquatorial(
  double longitude,
  double latitude,
  double obliquity,
) {
  final double l = longitude * degToRad;
  final double b = latitude * degToRad;
  final double e = obliquity * degToRad;
  final double ra = math.atan2(
    math.sin(l) * math.cos(e) - math.tan(b) * math.sin(e),
    math.cos(l),
  );
  final double dec = math.asin(
    math.sin(b) * math.cos(e) + math.cos(b) * math.sin(e) * math.sin(l),
  );
  return <double>[norm360(ra * radToDeg), dec * radToDeg];
}
