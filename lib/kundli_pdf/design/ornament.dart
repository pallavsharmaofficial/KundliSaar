import 'dart:math' as math;

import 'package:pdf/pdf.dart';

import 'palette.dart';

/// Everything decorative on the page, drawn in code as plain vector paths:
/// a guilloche border, corner rosettes, a lotus-petal ring and the kundli
/// square itself, which is the one motif the whole book is built around.
/// Nothing here is traced or copied from anywhere; it is arithmetic.
///
/// The same drawing serves two jobs. On the first and last page it is the
/// whole background. On every page between, [paintWatermark] draws the same
/// border and the same emblem so faintly that text sits on top of it without
/// noticing.
class Ornament {
  const Ornament._();

  // -------------------------------------------------------------------------
  // Small helpers
  // -------------------------------------------------------------------------

  static (double, double) _pol(double cx, double cy, double r, double a) =>
      (cx + r * math.cos(a), cy + r * math.sin(a));

  static void _poly(
    PdfGraphics g,
    List<(double, double)> pts, {
    bool close = false,
  }) {
    if (pts.isEmpty) return;
    g.moveTo(pts.first.$1, pts.first.$2);
    for (int i = 1; i < pts.length; i++) {
      g.lineTo(pts[i].$1, pts[i].$2);
    }
    if (close) g.closePath();
  }

  /// When set, translucency is done by mixing the colour into [Pal.parchment]
  /// instead of with a graphics state. The watermark is stored once as a form
  /// object that every page draws, and a form has no state resources of its
  /// own, so it is drawn in flat colours that look the same on the page.
  static bool flat = false;

  static PdfColor _mixed(PdfColor c, double opacity) => PdfColor(
    Pal.parchment.red + (c.red - Pal.parchment.red) * opacity,
    Pal.parchment.green + (c.green - Pal.parchment.green) * opacity,
    Pal.parchment.blue + (c.blue - Pal.parchment.blue) * opacity,
  );

  static void _ink(
    PdfGraphics g,
    PdfColor color,
    double width, {
    double opacity = 1,
  }) {
    g.setLineWidth(width);
    if (flat && opacity < 1) {
      g.setStrokeColor(_mixed(color, opacity));
      g.setFillColor(_mixed(color, opacity));
      return;
    }
    g.setStrokeColor(color);
    if (opacity < 1) {
      g.setGraphicState(
        PdfGraphicState(strokeOpacity: opacity, opacity: opacity),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Motifs
  // -------------------------------------------------------------------------

  /// An engine-turned rosette: layered epitrochoids with [lobes] loops.
  static void rosette(
    PdfGraphics g,
    double cx,
    double cy,
    double radius, {
    int lobes = 12,
    int layers = 4,
    double opacity = 1,
    PdfColor color = Pal.maroon,
    double width = 0.35,
  }) {
    _ink(g, color, width, opacity: opacity);
    for (int l = 0; l < layers; l++) {
      final double d = radius * (0.10 + 0.20 * l / math.max(1, layers - 1));
      final double rr = (radius - d) / (lobes - 1);
      final List<(double, double)> pts = <(double, double)>[];
      const int steps = 360;
      for (int i = 0; i <= steps; i++) {
        final double t = 2 * math.pi * i / steps;
        pts.add((
          cx + rr * (lobes - 1) * math.cos(t) + d * math.cos((lobes - 1) * t),
          cy + rr * (lobes - 1) * math.sin(t) - d * math.sin((lobes - 1) * t),
        ));
      }
      _poly(g, pts, close: true);
      g.strokePath();
    }
    g.drawEllipse(cx, cy, radius, radius);
    g.strokePath();
  }

  /// A ring of [petals] almond petals between two radii.
  static void petalRing(
    PdfGraphics g,
    double cx,
    double cy,
    double inner,
    double outer, {
    int petals = 16,
    double spread = 0.8,
    double phase = 0,
  }) {
    final double len = outer - inner;
    for (int k = 0; k < petals; k++) {
      final double a = phase + 2 * math.pi * k / petals;
      final double w = math.pi / petals * spread;
      (double, double) at(double along, double side) =>
          _pol(cx, cy, inner + len * along, a + side);
      final (double, double) b = at(0, 0);
      final (double, double) t = at(1, 0);
      g.moveTo(b.$1, b.$2);
      final (double, double) l1 = at(
        0.12,
        -w * 1.9 * inner / (inner + len * 0.12),
      );
      final (double, double) l2 = at(0.70, -w * 1.25);
      g.curveTo(l1.$1, l1.$2, l2.$1, l2.$2, t.$1, t.$2);
      final (double, double) r1 = at(0.70, w * 1.25);
      final (double, double) r2 = at(
        0.12,
        w * 1.9 * inner / (inner + len * 0.12),
      );
      g.curveTo(r1.$1, r1.$2, r2.$1, r2.$2, b.$1, b.$2);
      g.closePath();
    }
  }

  /// The kundli square: outline, both diagonals and the diamond joining the
  /// midpoints, as it stands in the North Indian chart.
  static void kundliSquare(
    PdfGraphics g,
    double cx,
    double cy,
    double half, {
    double rotation = 0,
  }) {
    (double, double) at(double x, double y) {
      final double c = math.cos(rotation);
      final double s = math.sin(rotation);
      return (cx + x * c - y * s, cy + x * s + y * c);
    }

    final List<(double, double)> corners = <(double, double)>[
      at(-half, -half),
      at(half, -half),
      at(half, half),
      at(-half, half),
    ];
    _poly(g, corners, close: true);
    g.strokePath();
    _poly(g, <(double, double)>[corners[0], corners[2]]);
    g.strokePath();
    _poly(g, <(double, double)>[corners[1], corners[3]]);
    g.strokePath();
    _poly(g, <(double, double)>[
      at(0, -half),
      at(half, 0),
      at(0, half),
      at(-half, 0),
    ], close: true);
    g.strokePath();
  }

  /// The emblem: two kundli squares turned against each other inside rings
  /// and a lotus of petals, with a rosette at the heart.
  static void emblem(
    PdfGraphics g,
    double cx,
    double cy,
    double radius, {
    double opacity = 1,
    PdfColor main = Pal.maroon,
    PdfColor accent = Pal.gold,
  }) {
    // Outer lotus.
    _ink(g, accent, 0.7, opacity: opacity);
    petalRing(g, cx, cy, radius * 0.80, radius, petals: 24, spread: 0.9);
    g.strokePath();
    _ink(g, main, 0.5, opacity: opacity);
    petalRing(
      g,
      cx,
      cy,
      radius * 0.80,
      radius * 0.93,
      petals: 24,
      spread: 0.55,
      phase: math.pi / 24,
    );
    g.strokePath();

    // Rings.
    _ink(g, main, 0.9, opacity: opacity);
    g.drawEllipse(cx, cy, radius * 0.78, radius * 0.78);
    g.strokePath();
    _ink(g, accent, 0.5, opacity: opacity);
    g.drawEllipse(cx, cy, radius * 0.74, radius * 0.74);
    g.strokePath();

    // The squares.
    final double half = radius * 0.52;
    _ink(g, main, 1.0, opacity: opacity);
    kundliSquare(g, cx, cy, half);
    _ink(g, accent, 0.8, opacity: opacity);
    kundliSquare(g, cx, cy, half, rotation: math.pi / 4);

    // Inner lotus and heart.
    _ink(g, main, 0.6, opacity: opacity);
    petalRing(
      g,
      cx,
      cy,
      radius * 0.17,
      radius * 0.40,
      petals: 12,
      spread: 0.85,
      phase: math.pi / 12,
    );
    g.strokePath();
    rosette(
      g,
      cx,
      cy,
      radius * 0.16,
      lobes: 9,
      layers: 3,
      opacity: opacity,
      color: main,
      width: 0.4,
    );
  }

  /// A braid of sine waves along a horizontal strip of height [h].
  static void guillocheStrip(
    PdfGraphics g,
    double x,
    double y,
    double length,
    double h, {
    bool vertical = false,
    int strands = 4,
    double wavelength = 18,
    double opacity = 1,
    PdfColor color = Pal.gold,
    double width = 0.45,
  }) {
    _ink(g, color, width, opacity: opacity);
    final double amp = h / 2 - 1.2;
    for (int s = 0; s < strands; s++) {
      final double phase = 2 * math.pi * s / strands;
      final List<(double, double)> pts = <(double, double)>[];
      for (double u = 0; u <= length; u += 0.9) {
        final double v =
            h / 2 + amp * math.sin(2 * math.pi * u / wavelength + phase);
        pts.add(vertical ? (x + v, y + u) : (x + u, y + v));
      }
      _poly(g, pts);
      g.strokePath();
    }
    // A slower pair across them gives the woven look.
    for (int s = 0; s < 2; s++) {
      final List<(double, double)> pts = <(double, double)>[];
      for (double u = 0; u <= length; u += 1.2) {
        final double v =
            h / 2 +
            amp *
                0.75 *
                math.sin(2 * math.pi * u / (wavelength * 3) + s * math.pi);
        pts.add(vertical ? (x + v, y + u) : (x + u, y + v));
      }
      _poly(g, pts);
      g.strokePath();
    }
  }

  /// A small corner piece: a framed square holding a rosette and a star.
  static void cornerPiece(
    PdfGraphics g,
    double x,
    double y,
    double size, {
    double opacity = 1,
    bool filled = true,
  }) {
    if (filled) {
      g.setFillColor(Pal.parchment);
      if (opacity < 1 && !flat) {
        g.setGraphicState(PdfGraphicState(opacity: opacity));
      }
      g.drawRect(x, y, size, size);
      g.fillPath();
    }
    _ink(g, Pal.maroon, 1.1, opacity: opacity);
    g.drawRect(x, y, size, size);
    g.strokePath();
    _ink(g, Pal.gold, 0.6, opacity: opacity);
    g.drawRect(x + 3, y + 3, size - 6, size - 6);
    g.strokePath();
    final double cx = x + size / 2;
    final double cy = y + size / 2;
    rosette(
      g,
      cx,
      cy,
      size * 0.36,
      lobes: 8,
      layers: 3,
      opacity: opacity,
      color: Pal.maroon,
    );
    _ink(g, Pal.gold, 0.5, opacity: opacity);
    kundliSquare(g, cx, cy, size * 0.17, rotation: math.pi / 4);
  }

  /// A row of small lotus buds along a baseline.
  static void budRow(
    PdfGraphics g,
    double x0,
    double x1,
    double y, {
    double size = 9,
    double step = 22,
    double opacity = 1,
  }) {
    _ink(g, Pal.maroon, 0.6, opacity: opacity);
    for (double x = x0; x <= x1; x += step) {
      petalRing(
        g,
        x,
        y,
        size * 0.15,
        size,
        petals: 5,
        spread: 0.7,
        phase: math.pi / 2 - 2 * math.pi / 10 * 2,
      );
      g.strokePath();
    }
  }

  /// A short divider: a line with a small diamond in the middle.
  static void divider(
    PdfGraphics g,
    double cx,
    double y,
    double halfLength, {
    double opacity = 1,
  }) {
    _ink(g, Pal.gold, 0.7, opacity: opacity);
    g.moveTo(cx - halfLength, y);
    g.lineTo(cx - 7, y);
    g.moveTo(cx + 7, y);
    g.lineTo(cx + halfLength, y);
    g.strokePath();
    _poly(g, <(double, double)>[
      (cx, y + 4),
      (cx + 4, y),
      (cx, y - 4),
      (cx - 4, y),
    ], close: true);
    g.setFillColor(Pal.maroon);
    if (opacity < 1 && !flat) {
      g.setGraphicState(PdfGraphicState(opacity: opacity));
    }
    g.fillPath();
  }

  // -------------------------------------------------------------------------
  // The two pages
  // -------------------------------------------------------------------------

  /// The first and last page: the full ornament. [emblemY] is the height of
  /// the emblem's centre from the bottom of the page.
  static void paintFull(
    PdfGraphics g,
    double w,
    double h, {
    required double emblemY,
    double emblemRadius = 118,
  }) {
    g.saveContext();
    // Ground, with a deeper margin the frame sits in.
    g.setFillColor(Pal.parchmentDeep);
    g.drawRect(0, 0, w, h);
    g.fillPath();
    g.setFillColor(Pal.parchment);
    g.drawRect(14, 14, w - 28, h - 28);
    g.fillPath();

    // Frame lines.
    _ink(g, Pal.maroon, 2.6);
    g.drawRect(14, 14, w - 28, h - 28);
    g.strokePath();
    _ink(g, Pal.gold, 1.0);
    g.drawRect(20, 20, w - 40, h - 40);
    g.strokePath();
    _ink(g, Pal.gold, 0.8);
    g.drawRect(50, 50, w - 100, h - 100);
    g.strokePath();
    _ink(g, Pal.maroon, 1.2);
    g.drawRect(54, 54, w - 108, h - 108);
    g.strokePath();

    // The braid between the two pairs of lines.
    const double corner = 52;
    guillocheStrip(
      g,
      62 - 8,
      26,
      w - 2 * 62 + 16,
      20,
      strands: 4,
      wavelength: 20,
    );
    guillocheStrip(
      g,
      62 - 8,
      h - 46,
      w - 2 * 62 + 16,
      20,
      strands: 4,
      wavelength: 20,
    );
    guillocheStrip(
      g,
      26,
      62 - 8,
      h - 2 * 62 + 16,
      20,
      vertical: true,
      strands: 4,
      wavelength: 20,
    );
    guillocheStrip(
      g,
      w - 46,
      62 - 8,
      h - 2 * 62 + 16,
      20,
      vertical: true,
      strands: 4,
      wavelength: 20,
    );

    // Corners sit over the ends of the braid.
    cornerPiece(g, 17, 17, corner + 2);
    cornerPiece(g, w - 17 - corner - 2, 17, corner + 2);
    cornerPiece(g, 17, h - 17 - corner - 2, corner + 2);
    cornerPiece(g, w - 17 - corner - 2, h - 17 - corner - 2, corner + 2);

    // The emblem and the rule of buds under the page's heading area.
    emblem(g, w / 2, emblemY, emblemRadius);
    budRow(g, 96, w - 96, 78, size: 8, step: 20, opacity: 0.9);
    budRow(g, 96, w - 96, h - 78, size: 8, step: 20, opacity: 0.9);
    g.restoreContext();
  }

  /// A middle page: the same border and the same emblem, only fainter.
  static void paintWatermark(PdfGraphics g, double w, double h) {
    flat = true;
    g.saveContext();
    g.setFillColor(Pal.parchment);
    g.drawRect(0, 0, w, h);
    g.fillPath();

    _ink(g, Pal.maroon, 0.8, opacity: 0.22);
    g.drawRect(22, 22, w - 44, h - 44);
    g.strokePath();
    _ink(g, Pal.gold, 0.6, opacity: 0.30);
    g.drawRect(27, 27, w - 54, h - 54);
    g.strokePath();

    const double band = 8;
    guillocheStrip(
      g,
      40,
      31.5,
      w - 80,
      band,
      strands: 3,
      wavelength: 14,
      opacity: 0.30,
      width: 0.3,
    );
    guillocheStrip(
      g,
      40,
      h - 39.5,
      w - 80,
      band,
      strands: 3,
      wavelength: 14,
      opacity: 0.30,
      width: 0.3,
    );
    guillocheStrip(
      g,
      31.5,
      40,
      h - 80,
      band,
      vertical: true,
      strands: 3,
      wavelength: 14,
      opacity: 0.30,
      width: 0.3,
    );
    guillocheStrip(
      g,
      w - 39.5,
      40,
      h - 80,
      band,
      vertical: true,
      strands: 3,
      wavelength: 14,
      opacity: 0.30,
      width: 0.3,
    );

    for (final (double, double) c in <(double, double)>[
      (22.0, 22.0),
      (w - 22.0 - 24, 22.0),
      (22.0, h - 22.0 - 24),
      (w - 22.0 - 24, h - 22.0 - 24),
    ]) {
      cornerPiece(g, c.$1, c.$2, 24, opacity: 0.30, filled: false);
    }

    emblem(g, w / 2, h / 2 + 8, 205, opacity: 0.075);
    g.restoreContext();
    flat = false;
  }
}
