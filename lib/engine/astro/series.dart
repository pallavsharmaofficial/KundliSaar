import 'dart:math' as math;

import 'angles.dart';
import 'series_data.dart' as data;

/// Evaluates the fitted Poisson series (see tools/ephemeris/fit_ephemeris.py).
///
/// Every series has the shape
///   f(T) = poly(T) + sum_k [ sin(arg_k) * S_k(T) + cos(arg_k) * C_k(T) ]
/// where arg_k is an integer combination of linear mean longitudes and both
/// S_k and C_k are quadratics in T, which is what lets a few dozen terms track
/// a drifting perihelion over two centuries.
double evalSeries(List<List<double>> terms, List<double> arguments, double t) {
  final int n = arguments.length;
  double sum = 0;
  for (final List<double> term in terms) {
    double argument = 0;
    for (int i = 0; i < n; i++) {
      final double k = term[i];
      if (k != 0) argument += k * arguments[i];
    }
    final double s = math.sin(argument);
    final double c = math.cos(argument);
    sum +=
        s * (term[n] + term[n + 1] * t + term[n + 2] * t * t) +
        c * (term[n + 3] + term[n + 4] * t + term[n + 5] * t * t);
  }
  return sum;
}

double evalPoly(List<double> poly, double t) =>
    poly[0] + poly[1] * t + poly[2] * t * t;

/// Mean longitudes of the six fitted planets, in radians.
List<double> planetArguments(double t) => <double>[
  for (final String body in data.seriesBodies)
    data.meanLongitudes[body]![0] + data.meanLongitudes[body]![1] * t,
];

/// The classical lunar arguments D, M, M', F in radians (linear parts only;
/// the quadratic drift is absorbed by the Poisson terms of the fit).
List<double> moonArguments(double t) => <double>[
  (297.8501921 + 445267.1114034 * t) * degToRad,
  (357.5291092 + 35999.0502909 * t) * degToRad,
  (134.9633964 + 477198.8675055 * t) * degToRad,
  (93.2720950 + 483202.0175233 * t) * degToRad,
];

/// Heliocentric position of a planet in the true ecliptic of date: longitude
/// and latitude in radians, radius in AU. [t] is Julian centuries of TT since
/// J2000. The frame is the one the fit sampled, so precession and nutation are
/// already inside these numbers and must not be applied again.
List<double> heliocentricOfDate(String body, double t) {
  final List<double> args = planetArguments(t);
  final List<List<double>> l = data.seriesL[body]!;
  final List<List<double>> b = data.seriesB[body]!;
  final List<List<double>> r = data.seriesR[body]!;
  final List<double> mean = data.meanLongitudes[body]!;
  final double longitude =
      mean[0] +
      mean[1] * t +
      evalPoly(data.polyL[body]!, t) +
      evalSeries(l, args, t);
  final double latitude =
      evalPoly(data.polyB[body]!, t) + evalSeries(b, args, t);
  final double radius = evalPoly(data.polyR[body]!, t) + evalSeries(r, args, t);
  return <double>[longitude, latitude, radius];
}

/// Geocentric position of the Moon in the true ecliptic of date: longitude and
/// latitude in radians, distance in AU.
List<double> moonOfDate(double t) {
  final List<double> args = moonArguments(t);
  final double longitude =
      data.moonMeanLongitude[0] +
      data.moonMeanLongitude[1] * t +
      evalPoly(data.moonLPoly, t) +
      evalSeries(data.moonL, args, t);
  final double latitude =
      evalPoly(data.moonBPoly, t) + evalSeries(data.moonB, args, t);
  final double radius =
      evalPoly(data.moonRPoly, t) + evalSeries(data.moonR, args, t);
  return <double>[longitude, latitude, radius];
}
