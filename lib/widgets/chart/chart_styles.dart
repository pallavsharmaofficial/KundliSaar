import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/astro/ephemeris.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/graha_data.dart';

/// The three ways the app can draw the same chart.
enum ChartStyle { north, south, wheel }

/// What a single house holds, in drawing terms.
class HouseContents {
  const HouseContents({
    required this.house,
    required this.signIndex,
    required this.grahas,
    required this.isLagna,
  });

  final int house;
  final int signIndex;
  final List<PlacedGraha> grahas;
  final bool isLagna;
}

List<HouseContents> houseContents(
  Kundli kundli, {
  Map<Graha, int>? overrideSigns,
  int? overrideLagna,
}) {
  final int lagnaSign = overrideLagna ?? kundli.lagnaRashi.index;
  final Map<int, List<PlacedGraha>> bySign = <int, List<PlacedGraha>>{};
  for (final PlacedGraha graha in kundli.grahas.values) {
    final int sign = overrideSigns != null
        ? overrideSigns[graha.graha]!
        : graha.rashi.index;
    bySign.putIfAbsent(sign, () => <PlacedGraha>[]).add(graha);
  }
  return <HouseContents>[
    for (int house = 1; house <= 12; house++)
      HouseContents(
        house: house,
        signIndex: (lagnaSign + house - 1) % 12,
        grahas: bySign[(lagnaSign + house - 1) % 12] ?? const <PlacedGraha>[],
        isLagna: house == 1,
      ),
  ];
}

/// Short label for a graha inside a chart cell.
String grahaGlyph(Graha graha, {required bool hindi}) {
  final GrahaInfo info = grahaInfo(graha);
  if (hindi) {
    return info.hindi.substring(0, info.hindi.length >= 2 ? 2 : 1);
  }
  const Map<Graha, String> short = <Graha, String>{
    Graha.sun: 'Su',
    Graha.moon: 'Mo',
    Graha.mars: 'Ma',
    Graha.mercury: 'Me',
    Graha.jupiter: 'Ju',
    Graha.venus: 'Ve',
    Graha.saturn: 'Sa',
    Graha.rahu: 'Ra',
    Graha.ketu: 'Ke',
  };
  return short[graha]!;
}

String rashiNumber(int signIndex) => (signIndex + 1).toString();

/// Draws the chart in the chosen style. The three styles differ only in the
/// drawing: the same placements go into all of them.
class KundliChartPainter extends CustomPainter {
  KundliChartPainter({
    required this.houses,
    required this.style,
    required this.lineColor,
    required this.textColor,
    required this.accentColor,
    required this.hindi,
    this.highlightHouse,
  });

  final List<HouseContents> houses;
  final ChartStyle style;
  final Color lineColor;
  final Color textColor;
  final Color accentColor;
  final bool hindi;
  final int? highlightHouse;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    final Rect square = Rect.fromLTWH(
      (size.width - side) / 2,
      (size.height - side) / 2,
      side,
      side,
    );
    switch (style) {
      case ChartStyle.north:
        _paintNorth(canvas, square);
      case ChartStyle.south:
        _paintSouth(canvas, square);
      case ChartStyle.wheel:
        _paintWheel(canvas, square);
    }
  }

  Paint get _stroke => Paint()
    ..color = lineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  void _paintNorth(Canvas canvas, Rect r) {
    final double s = r.width;
    final Offset tl = r.topLeft;
    Offset p(double x, double y) => Offset(tl.dx + x * s, tl.dy + y * s);

    canvas.drawRect(r, _stroke);
    canvas.drawLine(p(0, 0), p(1, 1), _stroke);
    canvas.drawLine(p(1, 0), p(0, 1), _stroke);
    final Path rhombus = Path()
      ..moveTo(p(0.5, 0).dx, p(0.5, 0).dy)
      ..lineTo(p(1, 0.5).dx, p(1, 0.5).dy)
      ..lineTo(p(0.5, 1).dx, p(0.5, 1).dy)
      ..lineTo(p(0, 0.5).dx, p(0, 0.5).dy)
      ..close();
    canvas.drawPath(rhombus, _stroke);

    const List<List<double>> centres = <List<double>>[
      <double>[0.50, 0.26], // 1
      <double>[0.26, 0.12], // 2
      <double>[0.12, 0.26], // 3
      <double>[0.26, 0.50], // 4
      <double>[0.12, 0.74], // 5
      <double>[0.26, 0.88], // 6
      <double>[0.50, 0.74], // 7
      <double>[0.74, 0.88], // 8
      <double>[0.88, 0.74], // 9
      <double>[0.74, 0.50], // 10
      <double>[0.88, 0.26], // 11
      <double>[0.74, 0.12], // 12
    ];
    for (final HouseContents house in houses) {
      final List<double> c = centres[house.house - 1];
      _paintCell(canvas, p(c[0], c[1]), house, s, showSignNumber: true);
    }
  }

  void _paintSouth(Canvas canvas, Rect r) {
    final double cell = r.width / 4;
    // Signs are fixed in the South Indian grid, clockwise from Pisces at the
    // top left; the lagna is marked rather than moved.
    const List<List<int>> grid = <List<int>>[
      <int>[11, 0, 1, 2],
      <int>[10, -1, -1, 3],
      <int>[9, -1, -1, 4],
      <int>[8, 7, 6, 5],
    ];
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        final int sign = grid[row][col];
        if (sign < 0) continue;
        final Rect box = Rect.fromLTWH(
          r.left + col * cell,
          r.top + row * cell,
          cell,
          cell,
        );
        canvas.drawRect(box, _stroke);
        final HouseContents house = houses.firstWhere(
          (HouseContents h) => h.signIndex == sign,
        );
        if (house.isLagna) {
          final Paint fill = Paint()
            ..color = accentColor.withValues(alpha: 0.14)
            ..style = PaintingStyle.fill;
          canvas.drawRect(box, fill);
          canvas.drawLine(
            box.topLeft,
            box.topLeft + Offset(cell * 0.3, cell * 0.3),
            _stroke,
          );
        }
        _paintCell(canvas, box.center, house, r.width, showSignNumber: false);
      }
    }
    final Rect centre = Rect.fromLTWH(
      r.left + cell,
      r.top + cell,
      cell * 2,
      cell * 2,
    );
    canvas.drawRect(centre, _stroke);
  }

  void _paintWheel(Canvas canvas, Rect r) {
    final Offset centre = r.center;
    final double outer = r.width / 2;
    final double inner = outer * 0.58;
    canvas.drawCircle(centre, outer, _stroke);
    canvas.drawCircle(centre, inner, _stroke);
    for (int i = 0; i < 12; i++) {
      final double angle = _wheelAngle(i);
      canvas.drawLine(
        centre + Offset(math.cos(angle), math.sin(angle)) * inner,
        centre + Offset(math.cos(angle), math.sin(angle)) * outer,
        _stroke,
      );
    }
    for (final HouseContents house in houses) {
      final double angle = _wheelAngle(house.house - 1) + math.pi / 12;
      final Offset at =
          centre +
          Offset(math.cos(angle), math.sin(angle)) * ((outer + inner) / 2);
      _paintCell(canvas, at, house, r.width, showSignNumber: true);
    }
  }

  /// House 1 starts at the left, as the rising sign does on the horizon.
  double _wheelAngle(int index) => math.pi - index * math.pi / 6;

  void _paintCell(
    Canvas canvas,
    Offset centre,
    HouseContents house,
    double side, {
    required bool showSignNumber,
  }) {
    final double scale = side / 320;
    final List<TextSpan> spans = <TextSpan>[];
    if (showSignNumber) {
      spans.add(
        TextSpan(
          text: '${rashiNumber(house.signIndex)}\n',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.55),
            fontSize: 12 * scale,
            height: 1.2,
          ),
        ),
      );
    }
    if (house.isLagna && showSignNumber) {
      spans.add(
        TextSpan(
          text: hindi ? 'लग्न\n' : 'Lagna\n',
          style: TextStyle(
            color: accentColor,
            fontSize: 11 * scale,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      );
    }
    spans.add(
      TextSpan(
        text: house.grahas
            .map(
              (PlacedGraha g) =>
                  '${grahaGlyph(g.graha, hindi: hindi)}${g.isRetrograde ? 'ᴿ' : ''}',
            )
            .join('  '),
        style: TextStyle(
          color: textColor,
          fontSize: 14 * scale,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
    final TextPainter painter = TextPainter(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: side * 0.26);
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant KundliChartPainter old) =>
      old.houses != houses ||
      old.style != style ||
      old.hindi != hindi ||
      old.highlightHouse != highlightHouse ||
      old.lineColor != lineColor;
}

/// The chart as a widget, with the style switch handled by the caller.
class KundliChart extends StatelessWidget {
  const KundliChart({
    super.key,
    required this.kundli,
    required this.style,
    this.overrideSigns,
    this.overrideLagna,
    this.size = 320,
  });

  final Kundli kundli;
  final ChartStyle style;
  final Map<Graha, int>? overrideSigns;
  final int? overrideLagna;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hindi = Localizations.localeOf(context).languageCode == 'hi';
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: KundliChartPainter(
          houses: houseContents(
            kundli,
            overrideSigns: overrideSigns,
            overrideLagna: overrideLagna,
          ),
          style: style,
          lineColor: scheme.onSurface.withValues(alpha: 0.45),
          textColor: scheme.onSurface,
          accentColor: scheme.primary,
          hindi: hindi,
        ),
      ),
    );
  }
}
