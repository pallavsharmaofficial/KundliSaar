import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The app's own icons: one set, drawn in code on a 24 unit grid with a
/// single line weight, round caps and joins, and one small touch of colour
/// each.
///
/// They replace the Material glyphs where those said the wrong thing (a
/// sticking plaster for remedies, a birthday cake for the annual chart) and
/// they stand for the readings on the home screen so that the whole grid
/// shares a weight and a size. Plain interface icons (back, settings, search,
/// the microphone) stay Material: a chevron is a chevron.
enum KGlyph {
  /// The north Indian chart itself.
  kundli,

  /// Phaladesh: a dated timeline.
  phaladesh,

  /// Today's reading: the sun coming up over the horizon.
  rashifal,

  /// Sudarshan: the wheel.
  sudarshan,

  /// Ghat chakra: the chart's diamond with a warning in it.
  ghatChakra,

  /// Sarvatobhadra: the nine-square grid.
  sarvatobhadra,

  /// Shadbala: strengths as bars.
  strengths,

  /// Gochar: a planet moving round its orbit.
  transits,

  /// Varshphal: the sun returning to where it began.
  varshphal,

  /// Upay: a diya.
  remedies,

  /// Panchang: a calendar page with the moon.
  panchang,

  /// Muhurta: a clock.
  muhurta,

  /// Festivals: a lotus.
  festivals,

  /// Kundli milan: two rings joined.
  match,

  /// Namkaran: a name tag.
  namkaran,

  /// Hastrekha: an open palm with a line on it.
  hastrekha,

  /// Ank jyotish: the number sign.
  numerology,

  /// Prashna: a question.
  prashna,

  /// Learn: an open book.
  learn,
}

/// One of the app's [KGlyph]s at a given size.
///
/// The line takes the ambient icon colour (so it follows a button's
/// foreground, an app bar's icon theme and so on) and the accent takes the
/// theme's glyph accent, unless either is given.
class KIcon extends StatelessWidget {
  const KIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.accent,
    this.semanticLabel,
  });

  final KGlyph glyph;
  final double size;
  final Color? color;
  final Color? accent;

  /// What a screen reader says. Icons beside a visible name leave it null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KundliTones tones = KundliTones.of(context);
    final IconThemeData icon = IconTheme.of(context);
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: semanticLabel == null,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _GlyphPainter(
            glyph,
            color ?? icon.color ?? tones.glyph,
            accent ?? tones.glyphAccent,
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color, this.accent);

  final KGlyph glyph;
  final Color color;
  final Color accent;

  /// Line weight on the 24 unit grid. At 24 dp this is Material's own
  /// outlined weight; it grows with the icon, which keeps the weight right
  /// at the 26 to 30 dp the home tiles use.
  static const double weight = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final _Geometry geometry = _Geometry.of(glyph);
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    if (geometry.accentFill != null) {
      canvas.drawPath(geometry.accentFill!, Paint()..color = accent);
    }
    if (geometry.accentLine != null) {
      canvas.drawPath(
        geometry.accentLine!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = weight
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = accent,
      );
    }
    if (geometry.line != null) {
      canvas.drawPath(
        geometry.line!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = weight
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
    if (geometry.solid != null) {
      canvas.drawPath(geometry.solid!, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.accent != accent;
}

/// A glyph's paths. They depend only on which glyph it is, so each is built
/// once and then shared by every icon of that kind on every frame.
class _Geometry {
  const _Geometry({this.line, this.accentFill, this.accentLine, this.solid});

  /// Stroked in the icon colour.
  final Path? line;

  /// Filled with the accent, under the line so the line sits on its edge.
  final Path? accentFill;

  /// Stroked in the accent.
  final Path? accentLine;

  /// Filled in the icon colour (a planet, a dot).
  final Path? solid;

  static final Map<KGlyph, _Geometry> _cache = <KGlyph, _Geometry>{};

  static _Geometry of(KGlyph glyph) =>
      _cache.putIfAbsent(glyph, () => _build(glyph));

  static _Geometry _build(KGlyph glyph) {
    switch (glyph) {
      case KGlyph.kundli:
        return _kundli();
      case KGlyph.phaladesh:
        return _phaladesh();
      case KGlyph.rashifal:
        return _rashifal();
      case KGlyph.sudarshan:
        return _sudarshan();
      case KGlyph.ghatChakra:
        return _ghatChakra();
      case KGlyph.sarvatobhadra:
        return _sarvatobhadra();
      case KGlyph.strengths:
        return _strengths();
      case KGlyph.transits:
        return _transits();
      case KGlyph.varshphal:
        return _varshphal();
      case KGlyph.remedies:
        return _remedies();
      case KGlyph.panchang:
        return _panchang();
      case KGlyph.muhurta:
        return _muhurta();
      case KGlyph.festivals:
        return _festivals();
      case KGlyph.match:
        return _match();
      case KGlyph.namkaran:
        return _namkaran();
      case KGlyph.hastrekha:
        return _hastrekha();
      case KGlyph.numerology:
        return _numerology();
      case KGlyph.prashna:
        return _prashna();
      case KGlyph.learn:
        return _learn();
    }
  }
}

// ---------------------------------------------------------------------------
// Drawing helpers. All coordinates are on the 24 unit grid.
// ---------------------------------------------------------------------------

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

Path _rrect(double l, double t, double r, double b, double radius) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path _lines(List<List<double>> segments) {
  final Path path = Path();
  for (final List<double> s in segments) {
    path
      ..moveTo(s[0], s[1])
      ..lineTo(s[2], s[3]);
  }
  return path;
}

Path _poly(List<double> xy, {bool close = false}) {
  final Path path = Path()..moveTo(xy[0], xy[1]);
  for (int i = 2; i < xy.length; i += 2) {
    path.lineTo(xy[i], xy[i + 1]);
  }
  if (close) path.close();
  return path;
}

Path _union(Iterable<Path> paths) {
  Path out = Path();
  for (final Path p in paths) {
    out = Path.combine(PathOperation.union, out, p);
  }
  return out;
}

// ---------------------------------------------------------------------------
// The glyphs.
// ---------------------------------------------------------------------------

/// The chart: the square, the diamond, and the four diagonals that run from
/// the corners to it. The diamond is filled with the accent.
_Geometry _kundli() {
  final Path line = _rrect(3.4, 3.4, 20.6, 20.6, 2.2)
    ..addPath(
      _poly(<double>[12, 3.4, 20.6, 12, 12, 20.6, 3.4, 12], close: true),
      Offset.zero,
    )
    ..addPath(
      _lines(<List<double>>[
        <double>[4.4, 4.4, 7.7, 7.7],
        <double>[19.6, 4.4, 16.3, 7.7],
        <double>[4.4, 19.6, 7.7, 16.3],
        <double>[19.6, 19.6, 16.3, 16.3],
      ]),
      Offset.zero,
    );
  final Path accent = _poly(<double>[
    12,
    7.2,
    16.8,
    12,
    12,
    16.8,
    7.2,
    12,
  ], close: true);
  return _Geometry(line: line, accentFill: accent);
}

/// A timeline: three dated moments down a line, the middle one the running one.
_Geometry _phaladesh() {
  final Path line =
      _lines(<List<double>>[
          <double>[6, 7.6, 6, 9.4],
          <double>[6, 14.6, 6, 16.4],
          <double>[11.2, 5.6, 20, 5.6],
          <double>[11.2, 12, 17, 12],
          <double>[11.2, 18.4, 19, 18.4],
        ])
        ..addPath(_circle(6, 5.6, 1.7), Offset.zero)
        ..addPath(_circle(6, 12, 2.5), Offset.zero)
        ..addPath(_circle(6, 18.4, 1.7), Offset.zero);
  return _Geometry(line: line, accentFill: _circle(6, 12, 2.5));
}

/// The sun coming up over the horizon.
_Geometry _rashifal() {
  const double cx = 12;
  const double cy = 16.8;
  const double r = 4.6;
  final Path sunFill = Path()
    ..moveTo(cx - r, cy)
    ..arcTo(
      Rect.fromCircle(center: const Offset(cx, cy), radius: r),
      math.pi,
      math.pi,
      false,
    )
    ..close();
  final Path line = Path()
    ..moveTo(cx - r, cy)
    ..arcTo(
      Rect.fromCircle(center: const Offset(cx, cy), radius: r),
      math.pi,
      math.pi,
      false,
    )
    ..moveTo(2.8, cy)
    ..lineTo(21.2, cy)
    ..moveTo(7.5, 20.6)
    ..lineTo(16.5, 20.6);
  // Rays at 200, 235, 270, 305 and 340 degrees from the centre.
  for (final double deg in <double>[205, 237.5, 270, 302.5, 335]) {
    final double a = deg * math.pi / 180;
    line
      ..moveTo(cx + math.cos(a) * 7.6, cy + math.sin(a) * 7.6)
      ..lineTo(cx + math.cos(a) * 9.8, cy + math.sin(a) * 9.8);
  }
  return _Geometry(line: line, accentFill: sunFill);
}

/// The wheel: an outer ring, a hub, and eight spokes.
_Geometry _sudarshan() {
  final Path line = _circle(12, 12, 9.2);
  for (int i = 0; i < 8; i++) {
    final double a = i * math.pi / 4 + math.pi / 8;
    line
      ..moveTo(12 + math.cos(a) * 4.2, 12 + math.sin(a) * 4.2)
      ..lineTo(12 + math.cos(a) * 9.2, 12 + math.sin(a) * 9.2);
  }
  return _Geometry(line: line, accentFill: _circle(12, 12, 2.7));
}

/// The chart's diamond with an exclamation mark in it.
_Geometry _ghatChakra() {
  final Path line =
      _poly(<double>[12, 2.6, 21.4, 12, 12, 21.4, 2.6, 12], close: true)
        ..moveTo(12, 8.2)
        ..lineTo(12, 12.6);
  return _Geometry(line: line, accentFill: _circle(12, 16.2, 1.25));
}

/// Nine squares, the middle one lit.
_Geometry _sarvatobhadra() {
  final Path line = _rrect(3.5, 3.5, 20.5, 20.5, 3)
    ..addPath(
      _lines(<List<double>>[
        <double>[9.17, 3.5, 9.17, 20.5],
        <double>[14.83, 3.5, 14.83, 20.5],
        <double>[3.5, 9.17, 20.5, 9.17],
        <double>[3.5, 14.83, 20.5, 14.83],
      ]),
      Offset.zero,
    );
  return _Geometry(
    line: line,
    accentFill: Path()..addRect(const Rect.fromLTRB(9.17, 9.17, 14.83, 14.83)),
  );
}

/// Three bars, the tallest lit.
_Geometry _strengths() {
  final Path line = _rrect(3.9, 13, 8.5, 20.4, 1.4)
    ..addPath(_rrect(9.75, 8.2, 14.35, 20.4, 1.4), Offset.zero)
    ..addPath(_rrect(15.6, 3.6, 20.2, 20.4, 1.4), Offset.zero);
  return _Geometry(line: line, accentFill: _rrect(15.6, 3.6, 20.2, 20.4, 1.4));
}

/// A planet on its orbit round the sun.
_Geometry _transits() {
  const double tilt = -26 * math.pi / 180;
  const double rx = 9.7;
  const double ry = 4.3;
  final Float64List m = Matrix4.identity()
      .multiplied(Matrix4.translationValues(12, 12, 0))
      .multiplied(Matrix4.rotationZ(tilt))
      .storage;
  final Path orbit = Path()
    ..addOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
    )
    ..close();
  final Path line = orbit.transform(m);
  const double t = -40 * math.pi / 180;
  final double px = rx * math.cos(t);
  final double py = ry * math.sin(t);
  final Offset planet = Offset(
    12 + px * math.cos(tilt) - py * math.sin(tilt),
    12 + px * math.sin(tilt) + py * math.cos(tilt),
  );
  return _Geometry(
    line: line,
    accentFill: _circle(12, 12, 2.5),
    solid: _circle(planet.dx, planet.dy, 1.9),
  );
}

/// The sun, and the ring it travels back round to where it began.
_Geometry _varshphal() {
  const double cx = 12;
  const double cy = 12;
  const double r = 8.6;
  const double start = -52 * math.pi / 180;
  const double sweep = 292 * math.pi / 180;
  final Path line = Path()
    ..addArc(
      Rect.fromCircle(center: const Offset(cx, cy), radius: r),
      start,
      sweep,
    );
  // The arrowhead at the end of the arc, pointing the way the ring turns.
  const double end = start + sweep;
  final Offset tip = Offset(cx + r * math.cos(end), cy + r * math.sin(end));
  final Offset forward = Offset(-math.sin(end), math.cos(end));
  final Offset outward = Offset(math.cos(end), math.sin(end));
  for (final double side in <double>[-1, 1]) {
    final Offset back = tip - forward * 3.1 + outward * (side * 2.4);
    line
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx, back.dy);
  }
  // The sun in the middle: a disc with short rays.
  final Path rays = Path();
  for (int i = 0; i < 8; i++) {
    final double a = i * math.pi / 4;
    rays
      ..moveTo(cx + math.cos(a) * 4.7, cy + math.sin(a) * 4.7)
      ..lineTo(cx + math.cos(a) * 5.7, cy + math.sin(a) * 5.7);
  }
  return _Geometry(
    line: line,
    accentFill: _circle(cx, cy, 2.9),
    accentLine: rays,
  );
}

/// A diya: the clay lamp and its flame.
_Geometry _remedies() {
  final Path bowl = Path()
    ..moveTo(3, 12.9)
    ..lineTo(21, 12.9)
    ..cubicTo(21, 17.6, 17, 20.6, 12, 20.6)
    ..cubicTo(7, 20.6, 3, 17.6, 3, 12.9)
    ..close();
  final Path foot = _lines(<List<double>>[
    <double>[8.6, 22.4, 15.4, 22.4],
  ]);
  final Path flame = Path()
    ..moveTo(12, 10.6)
    ..cubicTo(9.7, 9.1, 9.5, 6.2, 12, 2.8)
    ..cubicTo(14.5, 6.2, 14.3, 9.1, 12, 10.6)
    ..close();
  return _Geometry(line: bowl..addPath(foot, Offset.zero), accentFill: flame);
}

/// A calendar page with the moon on it.
_Geometry _panchang() {
  final Path line = _rrect(3.5, 5.2, 20.5, 20.8, 3)
    ..addPath(
      _lines(<List<double>>[
        <double>[3.5, 9.8, 20.5, 9.8],
        <double>[8.2, 3, 8.2, 7],
        <double>[15.8, 3, 15.8, 7],
      ]),
      Offset.zero,
    );
  final Path moon = Path.combine(
    PathOperation.difference,
    _circle(12, 15.4, 3.5),
    _circle(13.5, 14.5, 3.1),
  );
  return _Geometry(line: line, accentFill: moon);
}

/// A clock face, with a spark at its shoulder: the auspicious moment.
_Geometry _muhurta() {
  final Path line = _circle(11, 13, 8.2)
    ..addPath(_poly(<double>[11, 8.4, 11, 13, 14.2, 14.9]), Offset.zero);
  // A four-pointed star at the upper right.
  final Path star = Path()
    ..moveTo(19.2, 2.6)
    ..quadraticBezierTo(19.5, 4.5, 21.4, 4.8)
    ..quadraticBezierTo(19.5, 5.1, 19.2, 7)
    ..quadraticBezierTo(18.9, 5.1, 17, 4.8)
    ..quadraticBezierTo(18.9, 4.5, 19.2, 2.6)
    ..close();
  return _Geometry(line: line, accentFill: star);
}

/// A lotus: three petals over a ripple.
_Geometry _festivals() {
  final Path centre = Path()
    ..moveTo(12, 3.4)
    ..cubicTo(9.2, 7.4, 9.2, 12.8, 12, 16.4)
    ..cubicTo(14.8, 12.8, 14.8, 7.4, 12, 3.4)
    ..close();
  Path side(double sign) {
    double x(double v) => sign < 0 ? v : 24 - v;
    return Path()
      ..moveTo(x(12), 16.4)
      ..cubicTo(x(8), 16.2, x(4.9), 13.6, x(4.2), 9.4)
      ..cubicTo(x(8), 9.8, x(10.8), 12.4, x(12), 16.4)
      ..close();
  }

  final Path ripple = Path()
    ..moveTo(4.6, 19.4)
    ..cubicTo(8.6, 21.8, 15.4, 21.8, 19.4, 19.4);
  return _Geometry(
    line: Path()
      ..addPath(centre, Offset.zero)
      ..addPath(side(-1), Offset.zero)
      ..addPath(side(1), Offset.zero)
      ..addPath(ripple, Offset.zero),
    accentFill: centre,
  );
}

/// Two rings joined.
_Geometry _match() {
  final Path a = _circle(8.8, 12, 5.7);
  final Path b = _circle(15.2, 12, 5.7);
  return _Geometry(
    line: Path()
      ..addPath(a, Offset.zero)
      ..addPath(b, Offset.zero),
    accentFill: Path.combine(PathOperation.intersect, a, b),
  );
}

/// A name tag.
_Geometry _namkaran() {
  final Path tag = Path()
    ..moveTo(4.3, 7.6)
    ..quadraticBezierTo(4.3, 5.4, 6.5, 5.4)
    ..lineTo(13.3, 5.4)
    ..quadraticBezierTo(14.3, 5.4, 15, 6.1)
    ..lineTo(20.4, 11.2)
    ..quadraticBezierTo(21.2, 12, 20.4, 12.8)
    ..lineTo(15, 17.9)
    ..quadraticBezierTo(14.3, 18.6, 13.3, 18.6)
    ..lineTo(6.5, 18.6)
    ..quadraticBezierTo(4.3, 18.6, 4.3, 16.4)
    ..close();
  return _Geometry(line: tag, accentFill: _circle(8.4, 12, 1.7));
}

/// An open palm with a line across it.
_Geometry _hastrekha() {
  // Four fingers and the palm, joined into one outline; the thumb is a
  // rounded bar turned out from the palm.
  Path finger(double l, double top) => Path()
    ..addRRect(
      RRect.fromLTRBAndCorners(
        l,
        top,
        l + 3,
        13,
        topLeft: const Radius.circular(1.5),
        topRight: const Radius.circular(1.5),
      ),
    );
  final Path palm = Path()
    ..addRRect(
      RRect.fromLTRBAndCorners(
        7.4,
        10.5,
        19.4,
        21.6,
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
    );
  const double a = -38 * math.pi / 180;
  final Float64List m = Matrix4.identity()
      .multiplied(Matrix4.translationValues(5.6, 13.9, 0))
      .multiplied(Matrix4.rotationZ(a))
      .storage;
  final Path thumb =
      (Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 3, height: 8.4),
              const Radius.circular(1.5),
            ),
          ))
          .transform(m);
  final Path hand = _union(<Path>[
    finger(7.4, 5.6),
    finger(10.4, 3.4),
    finger(13.4, 4.4),
    finger(16.4, 7),
    palm,
    thumb,
  ]);
  hand
    ..moveTo(10.4, 7.4)
    ..lineTo(10.4, 11)
    ..moveTo(13.4, 6.2)
    ..lineTo(13.4, 11)
    ..moveTo(16.4, 8.4)
    ..lineTo(16.4, 11);
  final Path life = Path()
    ..moveTo(11.1, 15)
    ..cubicTo(11.4, 17, 12.4, 18.6, 14.4, 19.2);
  return _Geometry(line: hand, accentLine: life);
}

/// The number sign, with a dot in the middle.
_Geometry _numerology() {
  final Path line = _lines(<List<double>>[
    <double>[9.7, 4.2, 8.5, 19.8],
    <double>[16.1, 4.2, 14.9, 19.8],
    <double>[4.4, 9.3, 19.8, 9.3],
    <double>[4.2, 14.7, 19.6, 14.7],
  ]);
  return _Geometry(line: line, accentFill: _circle(12.3, 12, 1.5));
}

/// A question in a ring.
_Geometry _prashna() {
  final Path line = _circle(12, 12, 9.2)
    ..moveTo(9.3, 9.5)
    ..cubicTo(9.3, 7.8, 10.5, 6.9, 12.1, 6.9)
    ..cubicTo(13.7, 6.9, 14.9, 7.9, 14.9, 9.3)
    ..cubicTo(14.9, 11.3, 12, 11.5, 12, 13.8);
  return _Geometry(line: line, accentFill: _circle(12, 17.1, 1.25));
}

/// An open book.
_Geometry _learn() {
  final Path line = Path()
    ..moveTo(12, 6.8)
    ..cubicTo(10.2, 5.3, 7, 4.9, 3.6, 5.5)
    ..lineTo(3.6, 18.4)
    ..cubicTo(7, 17.8, 10.2, 18.2, 12, 19.8)
    ..cubicTo(13.8, 18.2, 17, 17.8, 20.4, 18.4)
    ..lineTo(20.4, 5.5)
    ..cubicTo(17, 4.9, 13.8, 5.3, 12, 6.8)
    ..moveTo(12, 6.8)
    ..lineTo(12, 19.8);
  final Path ribbon = _poly(<double>[
    15.2,
    5.1,
    18.4,
    5.4,
    18.4,
    11.6,
    16.8,
    10.2,
    15.2,
    11.6,
  ], close: true);
  return _Geometry(line: line, accentFill: ribbon);
}
