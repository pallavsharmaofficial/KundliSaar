import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A temple-door arch, used to frame the top of a reading the way a torana
/// frames a shrine: a run of small arches in marigold over the headline.
class ToranaHeader extends StatelessWidget {
  const ToranaHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KundliTones tones = KundliTones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CustomPaint(
            size: const Size(double.infinity, 20),
            painter: _ToranaPainter(
              arch: tones.accent,
              bead: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.headlineMedium),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(color: tones.softInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToranaPainter extends CustomPainter {
  _ToranaPainter({required this.arch, required this.bead});

  final Color arch;
  final Color bead;

  @override
  void paint(Canvas canvas, Size size) {
    // About one arch to every 36 dp, so the pattern keeps its proportions on
    // a phone and on a desktop window alike.
    final int arches = (size.width / 36).round().clamp(6, 24);
    final double width = size.width / arches;
    final Paint stroke = Paint()
      ..color = arch
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final Path path = Path()..moveTo(0, size.height - 2);
    for (int i = 0; i < arches; i++) {
      path.arcToPoint(
        Offset((i + 1) * width, size.height - 2),
        radius: Radius.circular(width * 0.62),
        clockwise: true,
      );
    }
    canvas.drawPath(path, stroke);
    final Paint dot = Paint()..color = bead;
    for (int i = 0; i <= arches; i++) {
      canvas.drawCircle(Offset(i * width, size.height - 2), 2.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ToranaPainter old) =>
      old.arch != arch || old.bead != bead;
}

/// A bordered panel, the app's standard container for a block of reading.
///
/// It is the theme's [Card]: ivory on the parchment ground, a warm edge and a
/// soft shadow, so it reads as raised rather than outlined. A title, when
/// given, is marked with the chart's diamond in marigold.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KundliTones tones = KundliTones.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null)
              Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: DiamondMark(color: tones.accent),
                  ),
                  Expanded(
                    child: Text(title!, style: theme.textTheme.titleMedium),
                  ),
                  ?trailing,
                ],
              ),
            if (title != null) const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// The small square-on-its-corner that stands for the chart's inner diamond.
/// It heads a panel's title and ends an ornamental rule.
class DiamondMark extends StatelessWidget {
  const DiamondMark({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _DiamondPainter(color)),
  );
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(h, 0)
        ..lineTo(size.width, h)
        ..lineTo(h, size.height)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter old) => old.color != color;
}

/// Label and value on one line, the app's unit of a fact.
class FactRow extends StatelessWidget {
  const FactRow(this.label, this.value, {super.key, this.emphasise = false});

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KundliTones tones = KundliTones.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: tones.softInk),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: emphasise
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The line that travels with every reading, set under a short rule that
/// ends in the chart's diamond so it reads as a footer rather than as more
/// of the reading.
class DisclaimerNote extends StatelessWidget {
  const DisclaimerNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KundliTones tones = KundliTones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DiamondMark(color: tones.accent, size: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 18,
                  color: tones.softInk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    height: 1.6,
                    color: tones.softInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small mark of the kundli itself, for an empty state: the square, both
/// diagonals and the inner diamond, with the diamond lit. (It was a mandala;
/// the app's motif is the chart, so the mark is too.)
class MandalaMark extends StatelessWidget {
  const MandalaMark({super.key, this.size = 96, this.opacity = 1});

  final double size;

  /// 1 is the full mark; lower fades it for use as a quiet backdrop.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final KundliTones tones = KundliTones.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KundliMarkPainter(
          line: tones.glyph.withValues(alpha: 0.85 * opacity),
          lit: tones.glyphAccent.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _KundliMarkPainter extends CustomPainter {
  _KundliMarkPainter({required this.line, required this.lit});

  final Color line;
  final Color lit;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double pad = s * 0.08;
    final Rect r = Rect.fromLTWH(pad, pad, s - pad * 2, s - pad * 2);
    final Offset c = r.center;
    final Path diamond = Path()
      ..moveTo(c.dx, r.top)
      ..lineTo(r.right, c.dy)
      ..lineTo(c.dx, r.bottom)
      ..lineTo(r.left, c.dy)
      ..close();
    // The lit diamond, inset so the lines round it.
    final Path lamp = Path()
      ..moveTo(c.dx, c.dy - r.height * 0.24)
      ..lineTo(c.dx + r.width * 0.24, c.dy)
      ..lineTo(c.dx, c.dy + r.height * 0.24)
      ..lineTo(c.dx - r.width * 0.24, c.dy)
      ..close();
    canvas.drawPath(lamp, Paint()..color = lit);
    final Paint stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.032)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.05)), stroke)
      ..drawPath(diamond, stroke);
    // The diagonals run corner to diamond, as they do in the chart.
    for (final (Offset a, Offset b) in <(Offset, Offset)>[
      (r.topLeft, Offset((r.left + c.dx) / 2, (r.top + c.dy) / 2)),
      (r.topRight, Offset((r.right + c.dx) / 2, (r.top + c.dy) / 2)),
      (r.bottomLeft, Offset((r.left + c.dx) / 2, (r.bottom + c.dy) / 2)),
      (r.bottomRight, Offset((r.right + c.dx) / 2, (r.bottom + c.dy) / 2)),
    ]) {
      canvas.drawLine(a, b, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _KundliMarkPainter old) =>
      old.line != line || old.lit != lit;
}
