import 'dart:math' as math;
import 'dart:typed_data';

import 'frame.dart';
import 'palm_map.dart';
import 'palm_types.dart';

// =============================================================================
// Finding the three great lines on a photographed palm.
//
// What this does, and does not. The picture is laid into the palm box (see
// PalmMap), lit evenly, and searched for thin dark creases at two widths. The
// creases that run on for a good length are kept as evidence. Then, for each of
// the life, head and heart lines, the best route through that evidence inside a
// corridor where the line is known to lie is traced, and kept only if the
// evidence along most of it is real and continuous. A line that is not clearly
// there is reported as not found; it is never filled in from the corridor.
//
// The fate and sun lines are not looked for. They are faint, they vary most
// from hand to hand, and in a photograph they are too easily confused with
// the other creases of the palm to name with a straight face.
// =============================================================================

enum FoundLineKind { life, head, heart }

/// One line traced from the picture.
class FoundLine {
  const FoundLine({
    required this.kind,
    required this.box,
    required this.image,
    required this.cover,
  });

  final FoundLineKind kind;

  /// Seven points along the line in the palm box (0 to 1, thumb on the left),
  /// in the direction the engine reads each line: life from the web of the
  /// thumb down to the wrist, head from the thumb side across, heart from the
  /// little-finger side across.
  final List<Pt> box;

  /// The same points in the picture, in pixels, for drawing on the photograph.
  final List<Pt> image;

  /// Share of the traced route that sits on real, continuous crease evidence,
  /// 0 to 1. Only lines above the acceptance bar are returned at all.
  final double cover;
}

class CreaseResult {
  const CreaseResult({
    required this.lines,
    required this.tried,
    required this.pixelsPerBoxWidth,
    required this.usable,
  });

  /// The lines that were clearly there.
  final Map<FoundLineKind, FoundLine> lines;

  /// Every line that was looked for, with the best evidence share found,
  /// whether or not it cleared the bar. For saying "faint" honestly.
  final Map<FoundLineKind, double> tried;

  /// How many picture pixels the palm box was wide. Small means the creases
  /// were never going to show.
  final double pixelsPerBoxWidth;

  /// False when the picture was too small or too empty for the search to mean
  /// anything.
  final bool usable;
}

class _Spec {
  const _Spec(this.kind, this.prior, this.radius, this.needs);

  final FoundLineKind kind;
  final List<Pt> prior;
  final double radius;
  final double needs;
}

// Where each line lies in the palm box, with the corridor it is looked for in
// and the share of its route that must sit on real evidence.
const List<_Spec> _specs = <_Spec>[
  _Spec(FoundLineKind.life, <Pt>[
    Pt(0.36, 0.33),
    Pt(0.33, 0.50),
    Pt(0.37, 0.70),
    Pt(0.45, 0.90),
  ], 0.14, 0.80),
  _Spec(FoundLineKind.heart, <Pt>[
    Pt(0.86, 0.36),
    Pt(0.70, 0.32),
    Pt(0.52, 0.30),
    Pt(0.38, 0.32),
  ], 0.08, 0.70),
  _Spec(FoundLineKind.head, <Pt>[
    Pt(0.34, 0.40),
    Pt(0.50, 0.46),
    Pt(0.66, 0.52),
    Pt(0.78, 0.56),
  ], 0.11, 0.70),
];

const int _w = 320;
const int _h = 400;

/// The least fine detail a palm must show for a search to mean anything: the
/// 95th percentile of the crease response, in units of the picture's own
/// brightness. Real palms photographed on phones sit between 0.011 and 0.11 on
/// the photographs this was checked against; a smooth, flat or very soft
/// picture sits near 0.003. Below this the evidence is noise, and the finder
/// says so instead of ranking the noise.
const double _detailFloor = 0.006;

/// Looks for the great lines on a palm. [landmarks] are the 21 points of the
/// hand in [frame]; [thumbOnLeft] says which way to turn the picture into the
/// palm box.
CreaseResult findCreases(
  PalmFrame frame,
  List<Pt> landmarks, {
  required bool thumbOnLeft,
  Map<String, double>? debug,
}) {
  final PalmMap map = PalmMap.fit(landmarks, mirrored: !thumbOnLeft);
  final double scale = map.pixelsPerBoxWidth;
  if (scale < 150) {
    return CreaseResult(
      lines: const <FoundLineKind, FoundLine>{},
      tried: const <FoundLineKind, double>{},
      pixelsPerBoxWidth: scale,
      usable: false,
    );
  }
  final BoxPatch patch = map.sample(frame, width: _w, height: _h);

  // The part of the box that is palm, pulled in from its edge, so the edge of
  // the hand against the background is never mistaken for a crease.
  final Uint8List palm = _palmMask(map, landmarks);
  final Uint8List inner = _erode(palm, _w, _h, 6);
  int innerCount = 0;
  for (final int v in inner) {
    innerCount += v;
  }
  if (innerCount < 8000) {
    return CreaseResult(
      lines: const <FoundLineKind, FoundLine>{},
      tried: const <FoundLineKind, double>{},
      pixelsPerBoxWidth: scale,
      usable: false,
    );
  }

  final Float32List ridge = _ridge(patch.green, <double>[2.0, 3.0]);
  for (int i = 0; i < ridge.length; i++) {
    if (inner[i] == 0) ridge[i] = 0;
  }
  final List<double> values = <double>[
    for (int i = 0; i < ridge.length; i++)
      if (inner[i] != 0) ridge[i],
  ]..sort();
  double pct(double p) => values[((values.length - 1) * p).round()];
  final double hi = pct(0.95);
  final double lo = pct(0.85);
  final double top = pct(0.99);
  if (hi < _detailFloor) {
    if (debug != null) debug['p95'] = hi;
    return CreaseResult(
      lines: const <FoundLineKind, FoundLine>{},
      tried: const <FoundLineKind, double>{},
      pixelsPerBoxWidth: scale,
      usable: false,
    );
  }
  if (debug != null) {
    debug['p85'] = lo;
    debug['p95'] = hi;
    debug['p99'] = top;
    debug['p50'] = pct(0.5);
  }
  if (top <= 1e-6) {
    return CreaseResult(
      lines: const <FoundLineKind, FoundLine>{},
      tried: const <FoundLineKind, double>{},
      pixelsPerBoxWidth: scale,
      usable: false,
    );
  }

  final Uint8List evidence = _evidence(ridge, hi, lo);
  final Uint8List fat = _dilate(evidence, _w, _h, 2);
  final Uint8List taken = Uint8List(_w * _h);

  final Map<FoundLineKind, FoundLine> found = <FoundLineKind, FoundLine>{};
  final Map<FoundLineKind, double> tried = <FoundLineKind, double>{};
  for (final _Spec spec in _specs) {
    final Float32List score = Float32List(_w * _h);
    for (int i = 0; i < score.length; i++) {
      if (taken[i] != 0) continue;
      score[i] = math.min(1.0, ridge[i] / top) * 0.6 + fat[i] * 0.8;
    }
    final List<Pt> route = _route(score, spec);
    int covered = 0, within = 0;
    for (final Pt p in route) {
      final int x = p.x.round().clamp(0, _w - 1);
      final int y = p.y.round().clamp(0, _h - 1);
      if (fat[y * _w + x] != 0) covered++;
      if (inner[y * _w + x] != 0) within++;
    }
    final double cover = covered / route.length;
    final double inside = within / route.length;
    tried[spec.kind] = cover;
    // With little fine detail on the palm there is little to tell a crease
    // from the grain, so the bar goes up.
    final double needed = spec.needs + (hi < 0.015 ? 0.10 : 0);
    if (cover < needed || inside < 0.7) continue;

    // Keep the same crease from being called two lines.
    final int skip = spec.kind == FoundLineKind.life
        ? (route.length * 0.2).round()
        : 0;
    _stamp(taken, route.sublist(skip), 6);

    final List<Pt> boxPts = _evenly(route, 7)
        .map((Pt p) => Pt(p.x / _w, p.y / _h))
        .toList();
    found[spec.kind] = FoundLine(
      kind: spec.kind,
      box: boxPts,
      image: boxPts.map((Pt p) => map.toImage(p.x, p.y)).toList(),
      cover: cover,
    );
  }
  return CreaseResult(
    lines: found,
    tried: tried,
    pixelsPerBoxWidth: scale,
    usable: true,
  );
}

// -----------------------------------------------------------------------------
// The palm region.

Uint8List _palmMask(PalmMap map, List<Pt> lm) {
  final List<Pt> hull = _hull(<Pt>[
    for (final int j in const <int>[
      Joint.wrist,
      Joint.thumbCmc,
      Joint.thumbMcp,
      Joint.indexMcp,
      Joint.middleMcp,
      Joint.ringMcp,
      Joint.pinkyMcp,
    ])
      () {
        final Pt b = map.toBox(lm[j]);
        return Pt(b.x * _w, b.y * _h);
      }(),
  ]);
  final Uint8List mask = Uint8List(_w * _h);
  for (int y = 0; y < _h; y++) {
    for (int x = 0; x < _w; x++) {
      if (_insideConvex(hull, x + 0.5, y + 0.5)) mask[y * _w + x] = 1;
    }
  }
  return mask;
}

List<Pt> _hull(List<Pt> points) {
  final List<Pt> p = List<Pt>.of(points)
    ..sort((Pt a, Pt b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  double cross(Pt o, Pt a, Pt b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final List<Pt> lower = <Pt>[];
  for (final Pt q in p) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  final List<Pt> upper = <Pt>[];
  for (final Pt q in p.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  lower.removeLast();
  upper.removeLast();
  return <Pt>[...lower, ...upper];
}

bool _insideConvex(List<Pt> hull, double x, double y) {
  bool sign = false;
  bool seen = false;
  for (int i = 0; i < hull.length; i++) {
    final Pt a = hull[i];
    final Pt b = hull[(i + 1) % hull.length];
    final double c = (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x);
    if (c == 0) continue;
    if (!seen) {
      sign = c > 0;
      seen = true;
    } else if ((c > 0) != sign) {
      return false;
    }
  }
  return seen;
}

Uint8List _erode(Uint8List m, int w, int h, int r) {
  // A pixel survives when its whole (2r+1) square is set; integral image.
  final Int32List sat = Int32List((w + 1) * (h + 1));
  for (int y = 0; y < h; y++) {
    int row = 0;
    for (int x = 0; x < w; x++) {
      row += m[y * w + x];
      sat[(y + 1) * (w + 1) + x + 1] = sat[y * (w + 1) + x + 1] + row;
    }
  }
  final Uint8List out = Uint8List(w * h);
  final int side = 2 * r + 1;
  for (int y = r; y < h - r; y++) {
    for (int x = r; x < w - r; x++) {
      final int x0 = x - r, y0 = y - r, x1 = x + r + 1, y1 = y + r + 1;
      final int s =
          sat[y1 * (w + 1) + x1] -
          sat[y0 * (w + 1) + x1] -
          sat[y1 * (w + 1) + x0] +
          sat[y0 * (w + 1) + x0];
      if (s == side * side) out[y * w + x] = 1;
    }
  }
  return out;
}

Uint8List _dilate(Uint8List m, int w, int h, int r) {
  final Int32List sat = Int32List((w + 1) * (h + 1));
  for (int y = 0; y < h; y++) {
    int row = 0;
    for (int x = 0; x < w; x++) {
      row += m[y * w + x];
      sat[(y + 1) * (w + 1) + x + 1] = sat[y * (w + 1) + x + 1] + row;
    }
  }
  final Uint8List out = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int x0 = math.max(0, x - r), y0 = math.max(0, y - r);
      final int x1 = math.min(w, x + r + 1), y1 = math.min(h, y + r + 1);
      final int s =
          sat[y1 * (w + 1) + x1] -
          sat[y0 * (w + 1) + x1] -
          sat[y1 * (w + 1) + x0] +
          sat[y0 * (w + 1) + x0];
      if (s > 0) out[y * w + x] = 1;
    }
  }
  return out;
}

// -----------------------------------------------------------------------------
// Dark thin creases: the largest curvature across a line, summed over two
// widths, with round dark spots suppressed.

Float32List _ridge(Float32List green, List<double> sigmas) {
  // Even out the light: divide by a very smooth copy of the picture.
  final Float32List background = _smoothCoarse(green);
  final Float32List n = Float32List(green.length);
  for (int i = 0; i < n.length; i++) {
    n[i] = green[i] / (background[i] + 1e-3);
  }
  final Float32List best = Float32List(n.length);
  for (final double sigma in sigmas) {
    final Float32List b = _gaussian(n, _w, _h, sigma);
    for (int y = 1; y < _h - 1; y++) {
      for (int x = 1; x < _w - 1; x++) {
        final int i = y * _w + x;
        final double c = b[i];
        final double lxx = b[i - 1] - 2 * c + b[i + 1];
        final double lyy = b[i - _w] - 2 * c + b[i + _w];
        final double lxy =
            (b[i + _w + 1] - b[i + _w - 1] - b[i - _w + 1] + b[i - _w - 1]) / 4;
        final double mean = (lxx + lyy) / 2;
        final double tmp = math.sqrt(
          math.pow((lxx - lyy) / 2, 2) + lxy * lxy,
        );
        final double l1 = mean + tmp;
        final double l2 = mean - tmp;
        if (l1 <= 0) continue;
        final double blob = math.max(l2, 0) / (l1 + 1e-6);
        final double r = l1 * sigma * sigma * math.exp(-blob * blob / 0.32);
        if (r > best[i]) best[i] = r;
      }
    }
  }
  return best;
}

Float32List _smoothCoarse(Float32List g) {
  // Quarter-size copy, blurred, then bilinearly brought back up.
  const int f = 4;
  final int cw = _w ~/ f, ch = _h ~/ f;
  final Float32List small = Float32List(cw * ch);
  for (int y = 0; y < ch; y++) {
    for (int x = 0; x < cw; x++) {
      double s = 0;
      for (int dy = 0; dy < f; dy++) {
        for (int dx = 0; dx < f; dx++) {
          s += g[(y * f + dy) * _w + x * f + dx];
        }
      }
      small[y * cw + x] = s / (f * f);
    }
  }
  final Float32List blurred = _gaussian(small, cw, ch, 3.0);
  final Float32List out = Float32List(g.length);
  for (int y = 0; y < _h; y++) {
    final double fy = ((y + 0.5) / f - 0.5).clamp(0.0, ch - 1.0);
    final int y0 = fy.floor();
    final int y1 = math.min(y0 + 1, ch - 1);
    final double ty = fy - y0;
    for (int x = 0; x < _w; x++) {
      final double fx = ((x + 0.5) / f - 0.5).clamp(0.0, cw - 1.0);
      final int x0 = fx.floor();
      final int x1 = math.min(x0 + 1, cw - 1);
      final double tx = fx - x0;
      final double top = blurred[y0 * cw + x0] * (1 - tx) + blurred[y0 * cw + x1] * tx;
      final double bottom =
          blurred[y1 * cw + x0] * (1 - tx) + blurred[y1 * cw + x1] * tx;
      out[y * _w + x] = top * (1 - ty) + bottom * ty;
    }
  }
  return out;
}

Float32List _gaussian(Float32List src, int w, int h, double sigma) {
  final int r = (sigma * 3).ceil();
  final Float32List k = Float32List(2 * r + 1);
  double sum = 0;
  for (int i = -r; i <= r; i++) {
    k[i + r] = math.exp(-(i * i) / (2 * sigma * sigma));
    sum += k[i + r];
  }
  for (int i = 0; i < k.length; i++) {
    k[i] /= sum;
  }
  final Float32List tmp = Float32List(src.length);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double s = 0;
      for (int i = -r; i <= r; i++) {
        final int xx = (x + i).clamp(0, w - 1);
        s += src[y * w + xx] * k[i + r];
      }
      tmp[y * w + x] = s;
    }
  }
  final Float32List out = Float32List(src.length);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double s = 0;
      for (int i = -r; i <= r; i++) {
        final int yy = (y + i).clamp(0, h - 1);
        s += tmp[yy * w + x] * k[i + r];
      }
      out[y * w + x] = s;
    }
  }
  return out;
}

// -----------------------------------------------------------------------------
// Evidence: creases that run on. Strong pixels (top 5% of the palm) seed, weak
// ones (top 15%) extend, and only chains of a real length survive.

Uint8List _evidence(Float32List ridge, double hi, double lo) {
  final Uint8List weak = Uint8List(ridge.length);
  for (int i = 0; i < ridge.length; i++) {
    if (ridge[i] > lo) weak[i] = 1;
  }
  final Uint8List joined = _dilate(weak, _w, _h, 1);
  final Int32List label = Int32List(ridge.length);
  final Uint8List keep = Uint8List(ridge.length);
  final List<int> stack = <int>[];
  int next = 0;
  for (int start = 0; start < joined.length; start++) {
    if (joined[start] == 0 || label[start] != 0) continue;
    next++;
    final List<int> members = <int>[];
    bool strong = false;
    stack.add(start);
    label[start] = next;
    while (stack.isNotEmpty) {
      final int i = stack.removeLast();
      members.add(i);
      if (ridge[i] > hi) strong = true;
      final int x = i % _w, y = i ~/ _w;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final int xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= _w || yy >= _h) continue;
          final int j = yy * _w + xx;
          if (joined[j] != 0 && label[j] == 0) {
            label[j] = next;
            stack.add(j);
          }
        }
      }
    }
    if (strong && members.length >= 80) {
      for (final int i in members) {
        if (weak[i] != 0) keep[i] = 1;
      }
    }
  }
  return keep;
}

// -----------------------------------------------------------------------------
// Tracing: a trellis along the expected line, one station every four pixels,
// with offsets across it; the best route is the one that sits on the most
// evidence without lurching sideways.

List<Pt> _resample(List<Pt> poly, double step) {
  final List<Pt> p = <Pt>[for (final Pt q in poly) Pt(q.x * _w, q.y * _h)];
  final List<double> cum = <double>[0];
  for (int i = 1; i < p.length; i++) {
    cum.add(cum.last + p[i - 1].distanceTo(p[i]));
  }
  final int n = (cum.last / step).floor() + 1;
  final List<Pt> out = <Pt>[];
  int seg = 0;
  for (int i = 0; i < n; i++) {
    final double t = i * step;
    while (seg < p.length - 2 && cum[seg + 1] < t) {
      seg++;
    }
    final double span = cum[seg + 1] - cum[seg];
    final double f = span <= 0 ? 0 : ((t - cum[seg]) / span).clamp(0.0, 1.0);
    out.add(
      Pt(
        p[seg].x + (p[seg + 1].x - p[seg].x) * f,
        p[seg].y + (p[seg + 1].y - p[seg].y) * f,
      ),
    );
  }
  // A light smoothing so the corridor does not carry the polyline's corners.
  final List<Pt> smooth = List<Pt>.of(out);
  for (int i = 0; i < out.length; i++) {
    double sx = 0, sy = 0;
    int c = 0;
    for (int d = -2; d <= 2; d++) {
      final int j = (i + d).clamp(0, out.length - 1);
      sx += out[j].x;
      sy += out[j].y;
      c++;
    }
    smooth[i] = Pt(sx / c, sy / c);
  }
  return smooth;
}

List<Pt> _route(Float32List score, _Spec spec) {
  final List<Pt> stations = _resample(spec.prior, 4);
  final int k = stations.length;
  final int radius = (spec.radius * _w).round();
  const int stepPx = 2;
  final int m = (radius ~/ stepPx) * 2 + 1;
  final int mid = m ~/ 2;

  // Unit normals along the corridor.
  final List<Pt> normal = <Pt>[
    for (int i = 0; i < k; i++)
      () {
        final Pt a = stations[math.max(0, i - 1)];
        final Pt b = stations[math.min(k - 1, i + 1)];
        double tx = b.x - a.x, ty = b.y - a.y;
        final double len = math.sqrt(tx * tx + ty * ty);
        if (len == 0) return const Pt(0, 1);
        tx /= len;
        ty /= len;
        return Pt(-ty, tx);
      }(),
  ];

  double valueAt(int i, int j) {
    final double off = (j - mid) * stepPx.toDouble();
    final int x = (stations[i].x + normal[i].x * off).round();
    final int y = (stations[i].y + normal[i].y * off).round();
    if (x < 0 || y < 0 || x >= _w || y >= _h) return -0.2;
    return score[y * _w + x];
  }

  final Float32List total = Float32List(k * m);
  final Int32List back = Int32List(k * m);
  for (int j = 0; j < m; j++) {
    total[j] = valueAt(0, j);
  }
  for (int i = 1; i < k; i++) {
    for (int j = 0; j < m; j++) {
      int bestJ = j;
      double best = -1e9;
      for (int d = -1; d <= 1; d++) {
        final int jj = j + d;
        if (jj < 0 || jj >= m) continue;
        final double s = total[(i - 1) * m + jj] - (d == 0 ? 0 : 0.01);
        if (s > best) {
          best = s;
          bestJ = jj;
        }
      }
      back[i * m + j] = bestJ;
      total[i * m + j] = best + valueAt(i, j);
    }
  }
  int j = 0;
  double top = -1e9;
  for (int jj = 0; jj < m; jj++) {
    if (total[(k - 1) * m + jj] > top) {
      top = total[(k - 1) * m + jj];
      j = jj;
    }
  }
  final List<Pt> route = List<Pt>.filled(k, const Pt(0, 0));
  for (int i = k - 1; i >= 0; i--) {
    final double off = (j - mid) * stepPx.toDouble();
    route[i] = Pt(
      stations[i].x + normal[i].x * off,
      stations[i].y + normal[i].y * off,
    );
    j = back[i * m + j];
  }
  return route;
}

void _stamp(Uint8List mask, List<Pt> route, int r) {
  for (final Pt p in route) {
    final int cx = p.x.round(), cy = p.y.round();
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final int x = cx + dx, y = cy + dy;
        if (x < 0 || y < 0 || x >= _w || y >= _h) continue;
        mask[y * _w + x] = 1;
      }
    }
  }
}

List<Pt> _evenly(List<Pt> route, int count) {
  final List<double> cum = <double>[0];
  for (int i = 1; i < route.length; i++) {
    cum.add(cum.last + route[i - 1].distanceTo(route[i]));
  }
  final List<Pt> out = <Pt>[];
  int seg = 0;
  for (int n = 0; n < count; n++) {
    final double t = cum.last * n / (count - 1);
    while (seg < route.length - 2 && cum[seg + 1] < t) {
      seg++;
    }
    final double span = cum[seg + 1] - cum[seg];
    final double f = span <= 0 ? 0 : ((t - cum[seg]) / span).clamp(0.0, 1.0);
    out.add(
      Pt(
        route[seg].x + (route[seg + 1].x - route[seg].x) * f,
        route[seg].y + (route[seg + 1].y - route[seg].y) * f,
      ),
    );
  }
  return out;
}
