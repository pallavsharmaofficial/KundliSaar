import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// How loudly the kundli shows through behind a screen.
///
/// [hero] is for the home screen, where nothing competes with the drawing and
/// it can be seen for what it is. [reading] is for every screen that carries
/// a reading: the same drawing, smaller, quieter and pushed into a corner, so
/// it is felt as a paper rather than read as a picture.
enum GroundWeight { hero, reading }

/// The page every screen sits on: the ground colour, a warm glow at the top,
/// and the north Indian kundli (the square, both diagonals and the inner
/// diamond) drawn very faintly across it.
///
/// Everything is painted with a [CustomPainter], so it scales to any screen
/// and takes any theme; there is no image anywhere. It is one cached layer
/// behind the page: the page scrolls above it, and the painter repaints only
/// when the size, the weight or a colour changes, never on scroll.
///
/// The colours are passed in rather than read from the theme so this file
/// depends on nothing but Flutter. `lib/core/theme.dart` is what decides them.
class KundliGround extends StatelessWidget {
  const KundliGround({
    super.key,
    required this.child,
    required this.ground,
    required this.glow,
    required this.line,
    this.lineAlpha = 0.08,
    this.weight = GroundWeight.reading,
  });

  final Widget child;

  /// The flat colour of the page.
  final Color ground;

  /// The lighter, warmer colour the page glows towards at the top.
  final Color glow;

  /// The colour of the chart's lines, before [lineAlpha] is applied.
  final Color line;

  /// How opaque the lines are on a [GroundWeight.hero] ground. The reading
  /// ground is a fixed fraction of it.
  final double lineAlpha;

  final GroundWeight weight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                painter: KundliGroundPainter(
                  ground: ground,
                  glow: glow,
                  line: line,
                  lineAlpha: lineAlpha,
                  weight: weight,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Paints [KundliGround]. Public so a test can paint it without a widget tree.
class KundliGroundPainter extends CustomPainter {
  const KundliGroundPainter({
    required this.ground,
    required this.glow,
    required this.line,
    required this.lineAlpha,
    required this.weight,
  });

  final Color ground;
  final Color glow;
  final Color line;
  final double lineAlpha;
  final GroundWeight weight;

  /// The reading ground is this fraction as strong as the hero one.
  static const double readingStrength = 0.62;

  /// How many times the ground has been painted. For tests.
  @visibleForTesting
  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = ground);

    // A pool of warm light at the top right, where the eye lands first.
    final double reach = math.max(size.width, size.height * 0.5);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.82, -size.height * 0.04),
          reach * 1.15,
          <Color>[glow, glow.withValues(alpha: 0)],
        ),
    );

    final _Geometry geometry = _Geometry.of(size, weight);
    final double strength = weight == GroundWeight.hero ? 1 : readingStrength;
    final Color lineColor = line.withValues(alpha: lineAlpha * strength);

    // The lines fade out towards the bottom of the screen, so the drawing
    // is a feature of the top of the page and never sits behind the text
    // the reader is working through further down. A gradient on the paint
    // does this; it costs nothing like a masked layer.
    final double fadeEnd = size.height * geometry.fadeEnd;
    final Paint lines = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, fadeEnd), <Color>[
        lineColor,
        lineColor.withValues(alpha: 0),
      ]);
    canvas.drawPath(geometry.major, lines);
    if (geometry.minor != null) {
      final Paint fine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.strokeWidth * 0.8
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, fadeEnd), <Color>[
          lineColor.withValues(alpha: lineColor.a * 0.8),
          lineColor.withValues(alpha: 0),
        ]);
      canvas.drawPath(geometry.minor!, fine);
    }

    // The foot-of-the-page chart, hero only, drawn at a steady strength.
    if (geometry.foot != null) {
      canvas.drawPath(
        geometry.foot!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = lineColor.withValues(alpha: lineColor.a * 0.7),
      );
    }
  }

  /// How many screen sizes have their paths kept. For tests.
  @visibleForTesting
  static int get cachedGeometries => _Geometry._cache.length;

  /// Forgets the kept paths. For tests.
  @visibleForTesting
  static void clearGeometryCache() => _Geometry._cache.clear();

  @override
  bool shouldRepaint(covariant KundliGroundPainter old) =>
      old.ground != ground ||
      old.glow != glow ||
      old.line != line ||
      old.lineAlpha != lineAlpha ||
      old.weight != weight;
}

/// The chart as paths for one screen size. Building them is cheap but they
/// are the same on every repaint, so they are kept.
class _Geometry {
  const _Geometry({
    required this.major,
    required this.minor,
    required this.foot,
    required this.strokeWidth,
    required this.fadeEnd,
  });

  final Path major;
  final Path? minor;
  final Path? foot;
  final double strokeWidth;

  /// Where, as a fraction of the screen height, the lines have faded away.
  final double fadeEnd;

  static final LinkedHashMap<(int, int, GroundWeight), _Geometry> _cache =
      LinkedHashMap<(int, int, GroundWeight), _Geometry>();

  static _Geometry of(Size size, GroundWeight weight) {
    final (int, int, GroundWeight) key = (
      size.width.round(),
      size.height.round(),
      weight,
    );
    final _Geometry? hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // most recently used goes last
      return hit;
    }
    final _Geometry built = _build(size, weight);
    _cache[key] = built;
    while (_cache.length > 6) {
      _cache.remove(_cache.keys.first);
    }
    return built;
  }

  static _Geometry _build(Size size, GroundWeight weight) {
    final double w = size.width;
    final double h = size.height;
    // On a very wide window (the web build) the chart is sized by the height
    // too, so it does not swell to fill a desktop screen.
    final double unit = math.min(w, h * 0.75);

    if (weight == GroundWeight.hero) {
      final Offset a = Offset(w * 0.82, unit * 0.18);
      final double sideA = unit * 1.18;
      final Path major = _chart(a, sideA);
      final Path minor = _innerChart(a, sideA);
      final Path foot = _chart(Offset(w * 0.04, h * 0.86), unit * 0.62);
      return _Geometry(
        major: major,
        minor: minor,
        foot: foot,
        strokeWidth: 1.2,
        fadeEnd: 0.62,
      );
    }
    final Offset a = Offset(w * 0.96, unit * 0.06);
    final double side = unit * 0.92;
    return _Geometry(
      major: _chart(a, side),
      minor: _innerChart(a, side),
      foot: null,
      strokeWidth: 1.0,
      fadeEnd: 0.46,
    );
  }

  /// The north Indian chart: the square, both diagonals, and the diamond
  /// joining the midpoints of the sides.
  static Path _chart(Offset centre, double side) {
    final double half = side / 2;
    final Rect r = Rect.fromCenter(center: centre, width: side, height: side);
    return Path()
      ..addRect(r)
      ..moveTo(r.left, r.top)
      ..lineTo(r.right, r.bottom)
      ..moveTo(r.right, r.top)
      ..lineTo(r.left, r.bottom)
      ..moveTo(centre.dx, centre.dy - half)
      ..lineTo(centre.dx + half, centre.dy)
      ..lineTo(centre.dx, centre.dy + half)
      ..lineTo(centre.dx - half, centre.dy)
      ..close();
  }

  /// The chart again inside the diamond: the diamond is itself a square, so
  /// it has diagonals (the horizontal and vertical through the centre) and
  /// its own inner diamond (the upright square a quarter of the way in).
  static Path _innerChart(Offset centre, double side) {
    final double half = side / 2;
    final double q = side / 4;
    return Path()
      ..moveTo(centre.dx - half, centre.dy)
      ..lineTo(centre.dx + half, centre.dy)
      ..moveTo(centre.dx, centre.dy - half)
      ..lineTo(centre.dx, centre.dy + half)
      ..addRect(Rect.fromCenter(center: centre, width: half, height: half))
      ..moveTo(centre.dx, centre.dy - q)
      ..lineTo(centre.dx + q, centre.dy)
      ..lineTo(centre.dx, centre.dy + q)
      ..lineTo(centre.dx - q, centre.dy)
      ..close();
  }
}
