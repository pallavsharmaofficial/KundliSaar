import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kundlisaar/palm/crease_finder.dart';
import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/palm_map.dart';
import 'package:kundlisaar/palm/palm_types.dart';

/// A flat, open hand made from proportions, for tests that need a hand of a
/// known shape without a photograph of one.
///
/// Built upright with the wrist at the origin, then turned, moved and put in a
/// frame. [widthRatio] is knuckle span over palm length and [fingerRatio] the
/// middle finger over palm length: the two numbers the hand type is read from.
HandObservation syntheticHand({
  int frameWidth = 720,
  int frameHeight = 1280,
  double centreX = 360,
  double centreY = 640,

  /// Wrist to middle fingertip, in pixels.
  double handLength = 760,
  double widthRatio = 0.66,
  double fingerRatio = 0.90,
  double rotationDegrees = 0,
  bool thumbLeft = true,

  /// Defaults to the hand a palm with this thumb would be: a left hand when the
  /// thumb is on the left.
  double? rightProbability,
  double curl = 0,
  FrameLook look = const FrameLook(palmBrightness: 0.55, sharpness: 0.12),
  int timeMs = 0,
}) {
  final double palm = handLength / (1 + fingerRatio);
  final double finger = palm * fingerRatio;
  final double span = palm * widthRatio;
  final double a = math.sqrt(span * span - math.pow(0.1 * palm, 2)) / 2;

  // Local points, x right, y down, wrist at the origin, fingers up.
  final List<Pt> local = List<Pt>.filled(Joint.count, const Pt(0, 0));
  local[Joint.wrist] = const Pt(0, 0);
  local[Joint.indexMcp] = Pt(-a, -0.95 * palm);
  local[Joint.middleMcp] = Pt(-0.15 * a, -1.0 * palm);
  local[Joint.ringMcp] = Pt(0.45 * a, -0.95 * palm);
  local[Joint.pinkyMcp] = Pt(a, -0.85 * palm);
  const List<double> reach = <double>[0.88, 1.0, 0.92, 0.72];
  const List<double> splay = <double>[-0.10, -0.02, 0.06, 0.14];
  for (int i = 0; i < 4; i++) {
    final Pt mcp = local[Joint.fingers[i].$1];
    final double len = finger * reach[i] * (1 - 1.15 * curl);
    for (int k = 1; k <= 3; k++) {
      final double f = k / 3;
      local[Joint.fingers[i].$1 + k] = Pt(
        mcp.x + splay[i] * len * f,
        mcp.y - len * f,
      );
    }
  }
  local[Joint.thumbCmc] = Pt(-0.45 * span, -0.15 * palm);
  local[Joint.thumbMcp] = Pt(-0.78 * span, -0.42 * palm);
  local[Joint.thumbIp] = Pt(-0.95 * span, -0.60 * palm);
  local[Joint.thumbTip] = Pt(-1.08 * span, -0.76 * palm);

  final double c = math.cos(rotationDegrees * math.pi / 180);
  final double s = math.sin(rotationDegrees * math.pi / 180);
  final List<Pt> turned = <Pt>[
    for (final Pt p in local)
      () {
        final double x = thumbLeft ? p.x : -p.x;
        return Pt(x * c - p.y * s, x * s + p.y * c);
      }(),
  ];
  double minX = double.infinity, maxX = -double.infinity;
  double minY = double.infinity, maxY = -double.infinity;
  for (final Pt p in turned) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  final double dx = centreX - (minX + maxX) / 2;
  final double dy = centreY - (minY + maxY) / 2;
  return HandObservation(
    points: <Pt>[for (final Pt p in turned) Pt(p.x + dx, p.y + dy)],
    depth: List<double>.filled(Joint.count, 0),
    presence: 0.99,
    rightProbability: rightProbability ?? (thumbLeft ? 0.08 : 0.92),
    frameWidth: frameWidth,
    frameHeight: frameHeight,
    look: look,
    timeMs: timeMs,
  );
}

/// Where each great line runs on the synthetic palms, in the palm box.
const Map<FoundLineKind, List<Pt>> drawnLines = <FoundLineKind, List<Pt>>{
  FoundLineKind.life: <Pt>[
    Pt(0.37, 0.33),
    Pt(0.31, 0.50),
    Pt(0.33, 0.68),
    Pt(0.42, 0.88),
  ],
  FoundLineKind.head: <Pt>[
    Pt(0.34, 0.41),
    Pt(0.50, 0.46),
    Pt(0.66, 0.52),
    Pt(0.78, 0.56),
  ],
  FoundLineKind.heart: <Pt>[
    Pt(0.85, 0.35),
    Pt(0.70, 0.31),
    Pt(0.52, 0.30),
    Pt(0.40, 0.32),
  ],
};

class SyntheticPalm {
  SyntheticPalm(this.frame, this.landmarks, this.map);

  final PalmFrame frame;
  final List<Pt> landmarks;
  final PalmMap map;
}

/// A picture of a palm: a skin colour with an uneven light across it, a little
/// grain, and dark creases drawn where the great lines run.
///
/// [creaseDepth] is how much darker a crease is than the skin around it
/// (0.25 is a clear crease; 0.04 is barely there). [blur] is a box blur in
/// pixels, to make the picture soft.
SyntheticPalm syntheticPalm({
  Set<FoundLineKind> lines = const <FoundLineKind>{
    FoundLineKind.life,
    FoundLineKind.head,
    FoundLineKind.heart,
  },
  List<int> skin = const <int>[224, 172, 140],
  double creaseDepth = 0.28,
  int blur = 0,
  double grain = 0.03,
  bool thumbLeft = true,
  int seed = 7,
}) {
  const int w = 900, h = 1100;
  const double x0 = 190, y0 = 120, sx = 520, sy = 650;
  Pt imagePoint(double u, double v) =>
      Pt(x0 + sx * (thumbLeft ? u : 1 - u), y0 + sy * v);

  // Landmarks, with the knuckles and wrist where the palm box expects them and
  // the thumb's two base joints where a thumb would be.
  final List<Pt> lm = List<Pt>.filled(Joint.count, const Pt(0, 0));
  PalmMap.anchors.forEach((int j, (double, double) a) {
    lm[j] = imagePoint(a.$1, a.$2);
  });
  lm[Joint.thumbCmc] = imagePoint(0.26, 0.82);
  lm[Joint.thumbMcp] = imagePoint(0.08, 0.62);
  lm[Joint.thumbIp] = imagePoint(-0.02, 0.45);
  lm[Joint.thumbTip] = imagePoint(-0.08, 0.30);
  for (final (int mcp, int tip) in Joint.fingers) {
    for (int k = 1; k <= 3; k++) {
      final Pt m = lm[mcp];
      lm[mcp + k] = Pt(m.x, m.y - sy * 0.5 * k / 3);
    }
    lm[tip] = Pt(lm[mcp].x, lm[mcp].y - sy * 0.5);
  }

  // Segments of every crease, in pixels.
  final List<(Pt, Pt)> segments = <(Pt, Pt)>[];
  for (final FoundLineKind k in lines) {
    final List<Pt> poly = drawnLines[k]!;
    for (int i = 1; i < poly.length; i++) {
      segments.add((
        imagePoint(poly[i - 1].x, poly[i - 1].y),
        imagePoint(poly[i].x, poly[i].y),
      ));
    }
  }

  final math.Random rng = math.Random(seed);
  final Uint8List rgba = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double d = 1e9;
      for (final (Pt, Pt) seg in segments) {
        d = math.min(d, _distanceToSegment(x.toDouble(), y.toDouble(), seg.$1, seg.$2));
      }
      final double crease = d > 12 ? 0 : creaseDepth * math.exp(-d * d / (2 * 2.2 * 2.2));
      // The light falls off across the palm, as it does under a window.
      final double light = 0.82 + 0.18 * (x / w) + 0.08 * (1 - y / h);
      final double noise = 1 + grain * (rng.nextDouble() * 2 - 1);
      final double factor = light * (1 - crease) * noise;
      final int o = (y * w + x) * 4;
      for (int c = 0; c < 3; c++) {
        rgba[o + c] = (skin[c] * factor).round().clamp(0, 255);
      }
      rgba[o + 3] = 255;
    }
  }
  Uint8List out = rgba;
  if (blur > 0) out = _boxBlur(rgba, w, h, blur);
  return SyntheticPalm(
    RgbaFrame(out, w, h),
    lm,
    PalmMap.fit(lm, mirrored: !thumbLeft),
  );
}

double _distanceToSegment(double px, double py, Pt a, Pt b) {
  final double dx = b.x - a.x, dy = b.y - a.y;
  final double len2 = dx * dx + dy * dy;
  final double t = len2 == 0
      ? 0
      : (((px - a.x) * dx + (py - a.y) * dy) / len2).clamp(0.0, 1.0);
  final double cx = a.x + t * dx, cy = a.y + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

Uint8List _boxBlur(Uint8List src, int w, int h, int r) {
  Uint8List pass(Uint8List s, bool horizontal) {
    final Uint8List o = Uint8List(s.length);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        for (int c = 0; c < 3; c++) {
          int sum = 0, n = 0;
          for (int k = -r; k <= r; k++) {
            final int xx = horizontal ? x + k : x;
            final int yy = horizontal ? y : y + k;
            if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
            sum += s[(yy * w + xx) * 4 + c];
            n++;
          }
          o[(y * w + x) * 4 + c] = sum ~/ n;
        }
        o[(y * w + x) * 4 + 3] = 255;
      }
    }
    return o;
  }

  return pass(pass(src, true), false);
}
