import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A temple-door arch, used to frame the top of a reading the way a torana
/// frames a shrine.
class ToranaHeader extends StatelessWidget {
  const ToranaHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CustomPaint(
            size: const Size(double.infinity, 26),
            painter: _ToranaPainter(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.headlineMedium),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToranaPainter extends CustomPainter {
  _ToranaPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final Path path = Path()..moveTo(0, size.height);
    const int arches = 9;
    final double width = size.width / arches;
    for (int i = 0; i < arches; i++) {
      path.arcToPoint(
        Offset((i + 1) * width, size.height),
        radius: Radius.circular(width * 0.62),
        clockwise: true,
      );
    }
    canvas.drawPath(path, paint);
    final Paint dot = Paint()..color = color.withValues(alpha: 0.5);
    for (int i = 0; i <= arches; i++) {
      canvas.drawCircle(Offset(i * width, size.height), 2.0, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ToranaPainter old) => old.color != color;
}

/// A bordered panel, the app's standard container for a block of reading.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(title!, style: theme.textTheme.titleMedium),
                  ),
                  ?trailing,
                ],
              ),
            if (title != null) const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
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

/// The line that travels with every reading.
class DisclaimerNote extends StatelessWidget {
  const DisclaimerNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.auto_stories_outlined,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small mandala used as a quiet background mark.
class MandalaMark extends StatelessWidget {
  const MandalaMark({super.key, this.size = 96, this.opacity = 0.12});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _MandalaPainter(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
      ),
    ),
  );
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (int ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(centre, size.width / 2 * ring / 3.2, paint);
    }
    for (int i = 0; i < 12; i++) {
      final double angle = i * math.pi / 6;
      canvas.drawLine(
        centre + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.16,
        centre + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.47,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter old) => old.color != color;
}
