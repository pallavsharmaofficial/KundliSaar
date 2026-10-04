import 'dart:math' as math;

const double degToRad = math.pi / 180.0;
const double radToDeg = 180.0 / math.pi;
const double arcsecToDeg = 1.0 / 3600.0;

/// Wraps [deg] into [0, 360).
double norm360(double deg) {
  final double r = deg % 360.0;
  return r < 0 ? r + 360.0 : r;
}

/// Wraps [deg] into [-180, 180).
double norm180(double deg) {
  final double r = norm360(deg + 180.0);
  return r - 180.0;
}

/// Shortest signed difference a - b, in [-180, 180).
double angleDiff(double a, double b) => norm180(a - b);

/// Degrees, arc-minutes and arc-seconds of a positive angle.
class Dms {
  const Dms(this.degrees, this.minutes, this.seconds);

  factory Dms.fromDegrees(double value) {
    final double abs = value.abs();
    int d = abs.floor();
    double rest = (abs - d) * 60.0;
    int m = rest.floor();
    double s = (rest - m) * 60.0;
    if (s >= 59.9995) {
      s = 0;
      m += 1;
    }
    if (m >= 60) {
      m = 0;
      d += 1;
    }
    return Dms(d, m, s);
  }

  final int degrees;
  final int minutes;
  final double seconds;

  @override
  String toString() =>
      "$degrees°${minutes.toString().padLeft(2, '0')}'${seconds.round().toString().padLeft(2, '0')}\"";
}

String formatDegrees(double value) => Dms.fromDegrees(value).toString();
