import 'dart:math' as math;

/// Julian day numbers and the UT -> TT bridge.
///
/// Astrology works in local civil time; astronomy works in Terrestrial Time.
/// Everything inside the engine carries both so a caller can never mix them up.
class Instant {
  const Instant._(this.julianDayUt, this.deltaT);

  /// Builds an instant from a UTC date-time.
  factory Instant.fromUtc(DateTime utc) {
    final double jd = julianDayFromUtc(utc);
    return Instant._(jd, deltaTSeconds(jd));
  }

  /// Builds an instant from a wall-clock time and its offset from UTC.
  factory Instant.fromLocal(DateTime local, Duration utcOffset) =>
      Instant.fromUtc(
        DateTime.utc(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        ).subtract(utcOffset),
      );

  factory Instant.fromJulianDayUt(double jdUt) =>
      Instant._(jdUt, deltaTSeconds(jdUt));

  final double julianDayUt;
  /// TT - UT1 in seconds at this instant.
  final double deltaT;

  double get julianDayTt => julianDayUt + deltaT / 86400.0;

  /// Julian centuries of TT since J2000.0.
  double get centuriesTt => (julianDayTt - 2451545.0) / 36525.0;

  Instant plusDays(double days) => Instant.fromJulianDayUt(julianDayUt + days);

  DateTime get utc => utcFromJulianDay(julianDayUt);

  @override
  String toString() => 'Instant(jdUt: $julianDayUt)';
}

double julianDayFromUtc(DateTime utc) {
  final DateTime u = utc.toUtc();
  int year = u.year;
  int month = u.month;
  final double day =
      u.day +
      (u.hour +
              (u.minute + (u.second + u.millisecond / 1000.0) / 60.0) / 60.0) /
          24.0;
  if (month <= 2) {
    year -= 1;
    month += 12;
  }
  final int a = (year / 100).floor();
  // Gregorian calendar only: the app never casts charts before 1583.
  final int b = 2 - a + (a / 4).floor();
  return (365.25 * (year + 4716)).floor() +
      (30.6001 * (month + 1)).floor() +
      day +
      b -
      1524.5;
}

DateTime utcFromJulianDay(double jd) {
  final double z = (jd + 0.5).floorToDouble();
  final double f = jd + 0.5 - z;
  double a = z;
  if (z >= 2299161) {
    final double alpha = ((z - 1867216.25) / 36524.25).floorToDouble();
    a = z + 1 + alpha - (alpha / 4).floorToDouble();
  }
  final double b = a + 1524;
  final double c = ((b - 122.1) / 365.25).floorToDouble();
  final double d = (365.25 * c).floorToDouble();
  final double e = ((b - d) / 30.6001).floorToDouble();
  final double dayWithFraction = b - d - (30.6001 * e).floorToDouble() + f;
  final int day = dayWithFraction.floor();
  final int month = e < 14 ? e.toInt() - 1 : e.toInt() - 13;
  final int year = month > 2 ? c.toInt() - 4716 : c.toInt() - 4715;
  final double dayFraction = dayWithFraction - day;
  final int millis = (dayFraction * 86400000).round();
  return DateTime.utc(year, month, day).add(Duration(milliseconds: millis));
}

/// TT - UT1 in seconds, following the Espenak & Meeus polynomial set.
double deltaTSeconds(double jd) {
  final double year = 2000.0 + (jd - 2451545.0) / 365.25;
  double t;
  if (year < 1900) {
    t = year - 1860;
    return 7.62 +
        0.5737 * t -
        0.251754 * math.pow(t, 2) +
        0.01680668 * math.pow(t, 3) -
        0.0004473624 * math.pow(t, 4) +
        math.pow(t, 5) / 233174;
  } else if (year < 1920) {
    t = year - 1900;
    return -2.79 +
        1.494119 * t -
        0.0598939 * t * t +
        0.0061966 * t * t * t -
        0.000197 * t * t * t * t;
  } else if (year < 1941) {
    t = year - 1920;
    return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * t * t * t;
  } else if (year < 1961) {
    t = year - 1950;
    return 29.07 + 0.407 * t - t * t / 233 + t * t * t / 2547;
  } else if (year < 1986) {
    t = year - 1975;
    return 45.45 + 1.067 * t - t * t / 260 - t * t * t / 718;
  } else if (year < 2005) {
    t = year - 2000;
    return 63.86 +
        0.3345 * t -
        0.060374 * t * t +
        0.0017275 * t * t * t +
        0.000651814 * t * t * t * t +
        0.00002373599 * t * t * t * t * t;
  } else if (year < 2050) {
    t = year - 2000;
    return 62.92 + 0.32217 * t + 0.005589 * t * t;
  } else if (year < 2150) {
    final double u = (year - 1820) / 100;
    return -20 + 32 * u * u - 0.5628 * (2150 - year);
  }
  final double u = (year - 1820) / 100;
  return -20 + 32 * u * u;
}
