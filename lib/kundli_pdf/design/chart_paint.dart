import 'dart:math' as math;

import 'package:pdf/pdf.dart';

import 'palette.dart';

/// What goes into one house of a chart.
class HouseBox {
  const HouseBox({
    required this.house,
    required this.sign,
    required this.labels,
    this.isLagna = false,
  });

  /// 1 to 12, counted from the lagna.
  final int house;

  /// Zero-based sign index.
  final int sign;
  final List<String> labels;
  final bool isLagna;
}

/// The charts, drawn as vector lines in plain black ink so that they print as
/// well in black and white as in colour.
class ChartPaint {
  const ChartPaint._();

  static double _width(PdfFont font, String text, double size) =>
      font.stringMetrics(text).advanceWidth * size;

  /// Draws [text] centred on [cx], with its middle at height [cy].
  static void centred(
    PdfGraphics g,
    PdfFont font,
    String text,
    double cx,
    double cy,
    double size, {
    PdfColor color = Pal.ink,
  }) {
    if (text.isEmpty) return;
    g.setFillColor(color);
    g.drawString(
      font,
      size,
      text,
      cx - _width(font, text, size) / 2,
      cy - size * 0.28,
    );
  }

  /// Draws a block of rows centred on a point; rows are packed [perRow] to a
  /// line, widest first fits are not attempted: charts keep their labels short.
  static void block(
    PdfGraphics g,
    PdfFont font,
    List<String> labels,
    double cx,
    double cy,
    double size, {
    int perRow = 2,
    PdfColor color = Pal.ink,
    double leading = 1.18,
    double maxWidth = double.infinity,
  }) {
    if (labels.isEmpty) return;
    // Crowded houses (four or five grahas in one) shrink to fit their box.
    final int per = labels.length > 4 ? 3 : perRow;
    final List<String> rows = <String>[];
    for (int i = 0; i < labels.length; i += per) {
      rows.add(labels.sublist(i, math.min(i + per, labels.length)).join('  '));
    }
    double fitted = size;
    double widest = 0;
    for (final String row in rows) {
      widest = math.max(widest, _width(font, row, size));
    }
    if (widest > maxWidth) fitted = size * math.max(0.6, maxWidth / widest);
    final double rowHeight = fitted * leading;
    final double top = cy + (rows.length - 1) * rowHeight / 2;
    for (int r = 0; r < rows.length; r++) {
      centred(g, font, rows[r], cx, top - r * rowHeight, fitted, color: color);
    }
  }

  static void _stroke(PdfGraphics g, double width, {PdfColor color = Pal.ink}) {
    g.setStrokeColor(color);
    g.setLineWidth(width);
  }

  // -------------------------------------------------------------------------
  // North Indian
  // -------------------------------------------------------------------------

  /// Centres of the twelve houses in the North Indian chart, as fractions of
  /// the square measured from the top left.
  static const List<(double, double)> _northCentre = <(double, double)>[
    (0.50, 0.25),
    (0.25, 0.105),
    (0.115, 0.25),
    (0.25, 0.50),
    (0.115, 0.75),
    (0.25, 0.895),
    (0.50, 0.75),
    (0.75, 0.895),
    (0.885, 0.75),
    (0.75, 0.50),
    (0.885, 0.25),
    (0.75, 0.105),
  ];

  /// Where each house's sign number sits: towards the middle of the chart.
  static const List<(double, double)> _northNumber = <(double, double)>[
    (0.50, 0.405),
    (0.25, 0.195),
    (0.195, 0.25),
    (0.405, 0.50),
    (0.195, 0.75),
    (0.25, 0.805),
    (0.50, 0.595),
    (0.75, 0.805),
    (0.805, 0.75),
    (0.595, 0.50),
    (0.805, 0.25),
    (0.75, 0.195),
  ];

  /// How much of the chart's width a house's labels may take, by house: the
  /// kites in the middle of each side are wide, the corner triangles narrow.
  static double _northRoom(int house) {
    if (house % 3 == 1) return 0.34;
    return const <int>{3, 5, 9, 11}.contains(house) ? 0.185 : 0.25;
  }

  static void north(
    PdfGraphics g,
    PdfFont font,
    double x,
    double y,
    double size,
    List<HouseBox> houses, {
    double labelSize = 0,
    int perRow = 2,
    String lagnaMark = 'ल',
    bool showSigns = true,
  }) {
    double px(double f) => x + f * size;
    double py(double f) => y + (1 - f) * size;
    final double ls = labelSize > 0 ? labelSize : size * 0.045;

    g.setFillColor(Pal.white);
    g.drawRect(x, y, size, size);
    g.fillPath();
    _stroke(g, 1.1);
    g.drawRect(x, y, size, size);
    g.strokePath();
    _stroke(g, 0.7);
    g.moveTo(px(0), py(0));
    g.lineTo(px(1), py(1));
    g.moveTo(px(1), py(0));
    g.lineTo(px(0), py(1));
    g.strokePath();
    g.moveTo(px(0.5), py(0));
    g.lineTo(px(1), py(0.5));
    g.lineTo(px(0.5), py(1));
    g.lineTo(px(0), py(0.5));
    g.closePath();
    g.strokePath();

    for (final HouseBox h in houses) {
      final (double, double) c = _northCentre[h.house - 1];
      final (double, double) n = _northNumber[h.house - 1];
      if (showSigns) {
        centred(
          g,
          font,
          '${h.sign + 1}',
          px(n.$1),
          py(n.$2),
          ls * 0.85,
          color: Pal.maroon,
        );
      }
      double cy = py(c.$2);
      if (h.isLagna && lagnaMark.isNotEmpty) {
        centred(
          g,
          font,
          lagnaMark,
          px(c.$1),
          py(c.$2) + ls * 1.5,
          ls * 0.95,
          color: Pal.maroon,
        );
        cy -= ls * 0.35;
      }
      block(
        g,
        font,
        h.labels,
        px(c.$1),
        cy,
        ls,
        perRow: perRow,
        maxWidth: size * _northRoom(h.house),
      );
    }
  }

  // -------------------------------------------------------------------------
  // South Indian
  // -------------------------------------------------------------------------

  static const List<List<int>> _southGrid = <List<int>>[
    <int>[11, 0, 1, 2],
    <int>[10, -1, -1, 3],
    <int>[9, -1, -1, 4],
    <int>[8, 7, 6, 5],
  ];

  static void south(
    PdfGraphics g,
    PdfFont font,
    double x,
    double y,
    double size,
    List<HouseBox> houses, {
    double labelSize = 0,
    int perRow = 2,
    List<String>? centreLines,
  }) {
    final double cell = size / 4;
    final double ls = labelSize > 0 ? labelSize : size * 0.047;
    g.setFillColor(Pal.white);
    g.drawRect(x, y, size, size);
    g.fillPath();
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        final int sign = _southGrid[row][col];
        if (sign < 0) continue;
        final double cx0 = x + col * cell;
        final double cy0 = y + (3 - row) * cell;
        _stroke(g, 0.8);
        g.drawRect(cx0, cy0, cell, cell);
        g.strokePath();
        final HouseBox h = houses.firstWhere((HouseBox b) => b.sign == sign);
        centred(
          g,
          font,
          '${sign + 1}',
          cx0 + cell * 0.17,
          cy0 + cell * 0.84,
          ls * 0.8,
          color: Pal.maroon,
        );
        if (h.isLagna) {
          _stroke(g, 0.9, color: Pal.maroon);
          g.moveTo(cx0, cy0 + cell);
          g.lineTo(cx0 + cell * 0.32, cy0 + cell * 0.68);
          g.strokePath();
          centred(
            g,
            font,
            'ल',
            cx0 + cell * 0.84,
            cy0 + cell * 0.84,
            ls * 0.9,
            color: Pal.maroon,
          );
        }
        block(
          g,
          font,
          h.labels,
          cx0 + cell / 2,
          cy0 + cell * 0.42,
          ls,
          perRow: perRow,
          maxWidth: cell * 0.9,
        );
      }
    }
    _stroke(g, 1.2);
    g.drawRect(x, y, size, size);
    g.strokePath();
    _stroke(g, 0.8);
    g.drawRect(x + cell, y + cell, cell * 2, cell * 2);
    g.strokePath();
    if (centreLines != null) {
      block(
        g,
        font,
        centreLines,
        x + size / 2,
        y + size / 2,
        ls * 1.05,
        perRow: 1,
        color: Pal.inkSoft,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Bars
  // -------------------------------------------------------------------------

  /// A horizontal bar of [value] out of [maximum], with a tick at [mark].
  static void bar(
    PdfGraphics g,
    double x,
    double y,
    double width,
    double height,
    double value,
    double maximum, {
    double? mark,
    PdfColor fill = Pal.inkSoft,
  }) {
    g.setFillColor(Pal.white);
    g.drawRect(x, y, width, height);
    g.fillPath();
    final double w = (value / maximum).clamp(0.0, 1.0) * width;
    g.setFillColor(fill);
    g.drawRect(x, y, w, height);
    g.fillPath();
    _stroke(g, 0.6);
    g.drawRect(x, y, width, height);
    g.strokePath();
    if (mark != null) {
      final double mx = x + (mark / maximum).clamp(0.0, 1.0) * width;
      _stroke(g, 1.4, color: Pal.maroon);
      g.moveTo(mx, y - 2);
      g.lineTo(mx, y + height + 2);
      g.strokePath();
    }
  }
}
