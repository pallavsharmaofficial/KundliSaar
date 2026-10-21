// A drawn palm that MediaPipe's real hand networks accept as a hand, for tests
// that need the whole pipeline to find something without a photograph of
// anyone: a flat open hand with five fingers, three creases and a little
// grain, on a plain wall. Deterministic. It is a cartoon, not a hand, and says
// nothing about how the models do on real ones; it is only a fixed input the
// two runtimes can be compared on.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kundlisaar/palm/frame.dart';

class _Capsule {
  const _Capsule(this.ax, this.ay, this.bx, this.by, this.ra, this.rb);
  final double ax, ay, bx, by, ra, rb;

  /// Signed distance to a capsule whose radius tapers from [ra] to [rb].
  double distance(double x, double y) {
    final double dx = bx - ax, dy = by - ay;
    final double len2 = dx * dx + dy * dy;
    final double t = len2 == 0
        ? 0
        : (((x - ax) * dx + (y - ay) * dy) / len2).clamp(0.0, 1.0);
    final double cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) -
        (ra + t * (rb - ra));
  }
}

double _boxDistance(
  double x,
  double y,
  double cx,
  double cy,
  double hw,
  double hh,
  double r,
) {
  final double qx = (x - cx).abs() - (hw - r);
  final double qy = (y - cy).abs() - (hh - r);
  final double ox = math.max(qx, 0), oy = math.max(qy, 0);
  return math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0) - r;
}

double _segmentDistance(
  double x,
  double y,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final double dx = bx - ax, dy = by - ay;
  final double len2 = dx * dx + dy * dy;
  final double t = len2 == 0
      ? 0
      : (((x - ax) * dx + (y - ay) * dy) / len2).clamp(0.0, 1.0);
  final double px = ax + t * dx - x, py = ay + t * dy - y;
  return math.sqrt(px * px + py * py);
}

/// A repeatable pseudo-random number for a pixel, 0 to 1.
double _grain(int x, int y, int seed) {
  int h = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
  return ((h ^ (h >> 16)) & 0xffff) / 65535.0;
}

/// Draws a palm. [thumbLeft] puts the thumb on the left of the picture, which
/// is how a left palm facing the camera looks. [scale] is the size of the hand
/// (about 550 px from wrist to the tip of the middle finger at 1.0) and
/// [tilt] turns the whole picture, in degrees.
RgbaFrame renderPalm({
  int width = 720,
  int height = 1280,
  List<int> tone = const <int>[205, 150, 118],
  List<int> wall = const <int>[120, 130, 140],
  double scale = 0.7,
  bool thumbLeft = true,
  double tilt = 0,
  int seed = 2,
}) {
  final double cx = width / 2, cy = height * 0.60;
  final double s = scale;
  final double pw = 230 * s, ph = 250 * s;
  final double top = cy - ph / 2 + 10 * s;
  final double sign = thumbLeft ? -1 : 1;

  final List<_Capsule> parts = <_Capsule>[];
  const List<double> xs = <double>[-0.37, -0.125, 0.125, 0.37];
  const List<double> lens = <double>[215, 250, 235, 185];
  const List<double> widths = <double>[50, 54, 52, 44];
  for (int i = 0; i < 4; i++) {
    final double x = cx + xs[i] * pw;
    final double a = xs[i] * 0.22;
    parts.add(
      _Capsule(
        x,
        top + 10 * s,
        x + math.sin(a) * lens[i] * s,
        top - math.cos(a) * lens[i] * s,
        widths[i] * s / 2,
        widths[i] * 0.82 * s / 2,
      ),
    );
  }
  final double p0x = cx + sign * pw * 0.38, p0y = cy + ph * 0.30;
  final double p1x = cx + sign * pw * 0.80, p1y = cy + ph * 0.02;
  final double p2x = cx + sign * pw * 1.02, p2y = cy - ph * 0.22;
  parts.add(_Capsule(p0x, p0y, p1x, p1y, 36 * s, 30 * s));
  parts.add(_Capsule(p1x, p1y, p2x, p2y, 30 * s, 25 * s));

  // Three creases, each a short polyline, in the palm's own proportions.
  final double sg = thumbLeft ? 1 : -1;
  final List<List<double>> creases = <List<double>>[
    <double>[
      cx - sg * pw * 0.08,
      cy - ph * 0.30,
      cx - sg * pw * 0.30,
      cy - ph * 0.05,
      cx - sg * pw * 0.30,
      cy + ph * 0.15,
      cx - sg * pw * 0.18,
      cy + ph * 0.40,
    ],
    <double>[
      cx - sg * pw * 0.36,
      cy - ph * 0.14,
      cx - sg * pw * 0.05,
      cy - ph * 0.06,
      cx + sg * pw * 0.30,
      cy - ph * 0.02,
    ],
    <double>[
      cx - sg * pw * 0.32,
      cy - ph * 0.36,
      cx,
      cy - ph * 0.30,
      cx + sg * pw * 0.40,
      cy - ph * 0.36,
    ],
  ];

  final Uint8List out = Uint8List(width * height * 4);
  final double rad = -tilt * math.pi / 180;
  final double c = math.cos(rad), si = math.sin(rad);
  final double mx = width / 2, my = height / 2;
  for (int py = 0; py < height; py++) {
    for (int px = 0; px < width; px++) {
      // Undo the tilt to find where this pixel sits on the unturned drawing.
      final double ux = mx + (px - mx) * c - (py - my) * si;
      final double uy = my + (px - mx) * si + (py - my) * c;

      double d = _boxDistance(ux, uy, cx, cy, pw / 2, ph / 2, 24 * s);
      d = math.min(
        d,
        _boxDistance(
          ux,
          uy,
          cx,
          cy + ph * 0.55 + height * 0.25,
          pw * 0.34,
          ph * 0.5 + height * 0.25,
          4,
        ),
      );
      for (final _Capsule p in parts) {
        d = math.min(d, p.distance(ux, uy));
      }
      final double inside = (0.5 - d / 3.0).clamp(0.0, 1.0);

      final double light =
          1.0 + 0.10 * ((ux - cx) / 400.0) - 0.06 * ((uy - cy) / 600.0);
      final double g = (_grain(px, py, seed) - 0.5) * 12;
      double r = tone[0] * light + g,
          gr = tone[1] * light + g,
          b = tone[2] * light + g;
      double crease = 0;
      for (final List<double> line in creases) {
        for (int k = 0; k + 3 < line.length; k += 2) {
          final double dd = _segmentDistance(
            ux,
            uy,
            line[k],
            line[k + 1],
            line[k + 2],
            line[k + 3],
          );
          crease = math.max(crease, (1.0 - dd / 2.2).clamp(0.0, 1.0));
        }
      }
      r *= 1 - 0.30 * crease;
      gr *= 1 - 0.30 * crease;
      b *= 1 - 0.30 * crease;

      final double vignette =
          1.0 - 0.12 * math.pow((py - height / 2) / height, 2);
      final double wr = wall[0] * vignette + g,
          wg = wall[1] * vignette + g,
          wb = wall[2] * vignette + g;
      final int o = (py * width + px) * 4;
      out[o] = (r * inside + wr * (1 - inside)).round().clamp(0, 255);
      out[o + 1] = (gr * inside + wg * (1 - inside)).round().clamp(0, 255);
      out[o + 2] = (b * inside + wb * (1 - inside)).round().clamp(0, 255);
      out[o + 3] = 255;
    }
  }
  return RgbaFrame(out, width, height);
}
