import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../engine/jyotish/hastrekha.dart';

/// The palm the person traces on: an outline, the six lines with draggable
/// control points, and the mounts marked where they sit on a real hand.
class PalmCanvas extends StatefulWidget {
  const PalmCanvas({
    super.key,
    required this.trace,
    required this.active,
    required this.mounts,
    required this.onMoved,
    this.absent = const <PalmLine>{},
    this.photo,
  });

  final Map<PalmLine, List<PalmPoint>> trace;
  final PalmLine active;
  final Map<Mount, int> mounts;
  final Set<PalmLine> absent;
  final Uint8List? photo;
  final void Function(PalmLine line, int index, PalmPoint point) onMoved;

  @override
  State<PalmCanvas> createState() => _PalmCanvasState();
}

class _PalmCanvasState extends State<PalmCanvas> {
  int? _dragging;

  void _grab(Offset local, Size size) {
    final List<PalmPoint> points = widget.trace[widget.active]!;
    double best = 32;
    int? index;
    for (int i = 0; i < points.length; i++) {
      final Offset at = Offset(
        points[i].x * size.width,
        points[i].y * size.height,
      );
      final double distance = (at - local).distance;
      if (distance < best) {
        best = distance;
        index = i;
      }
    }
    _dragging = index;
  }

  void _move(Offset local, Size size) {
    final int? index = _dragging;
    if (index == null) return;
    widget.onMoved(
      widget.active,
      index,
      PalmPoint(
        (local.dx / size.width).clamp(0.02, 0.98),
        (local.dy / size.height).clamp(0.02, 0.98),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final Size size = Size(width, width * 1.25);
        return GestureDetector(
          onPanStart: (DragStartDetails details) =>
              _grab(details.localPosition, size),
          onPanUpdate: (DragUpdateDetails details) =>
              _move(details.localPosition, size),
          onPanEnd: (_) => _dragging = null,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (widget.photo != null)
                  Opacity(
                    opacity: 0.55,
                    child: Image.memory(widget.photo!, fit: BoxFit.cover),
                  ),
                CustomPaint(
                  painter: _PalmPainter(
                    trace: widget.trace,
                    active: widget.active,
                    mounts: widget.mounts,
                    absent: widget.absent,
                    outline: scheme.onSurface.withValues(alpha: 0.35),
                    inactive: scheme.onSurface.withValues(alpha: 0.30),
                    accent: scheme.primary,
                    hasPhoto: widget.photo != null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PalmPainter extends CustomPainter {
  _PalmPainter({
    required this.trace,
    required this.active,
    required this.mounts,
    required this.absent,
    required this.outline,
    required this.inactive,
    required this.accent,
    required this.hasPhoto,
  });

  final Map<PalmLine, List<PalmPoint>> trace;
  final PalmLine active;
  final Map<Mount, int> mounts;
  final Set<PalmLine> absent;
  final Color outline;
  final Color inactive;
  final Color accent;
  final bool hasPhoto;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(PalmPoint p) => Offset(p.x * size.width, p.y * size.height);

    if (!hasPhoto) _paintHand(canvas, size);

    // Mounts, drawn where they sit on the hand.
    mounts.forEach((Mount mount, int prominence) {
      final Offset centre = at(mountCentres[mount]!);
      canvas.drawCircle(
        centre,
        prominence == 2 ? 13 : 8,
        Paint()
          ..color = prominence == 2
              ? accent.withValues(alpha: 0.22)
              : outline.withValues(alpha: 0.12),
      );
      if (prominence == 2) {
        canvas.drawCircle(
          centre,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = accent.withValues(alpha: 0.6),
        );
      }
    });

    // Lines: a smooth curve through the control points.
    for (final MapEntry<PalmLine, List<PalmPoint>> entry in trace.entries) {
      if (absent.contains(entry.key)) continue;
      final bool isActive = entry.key == active;
      final List<Offset> points = entry.value.map(at).toList();
      final Path path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final Offset previous = points[i - 1];
        final Offset current = points[i];
        final Offset control = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        path.quadraticBezierTo(
          previous.dx,
          previous.dy,
          control.dx,
          control.dy,
        );
      }
      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 3.2 : 1.8
          ..strokeCap = StrokeCap.round
          ..color = isActive ? accent : inactive,
      );
      if (isActive) {
        for (final Offset point in points) {
          canvas.drawCircle(
            point,
            7,
            Paint()..color = accent.withValues(alpha: 0.9),
          );
          canvas.drawCircle(point, 3, Paint()..color = Colors.white);
        }
      }
    }
  }

  /// A plain outline of a right palm, fingers at the top, thumb to the left.
  void _paintHand(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = outline;
    double x(double v) => v * size.width;
    double y(double v) => v * size.height;

    final Path palm = Path()
      ..moveTo(x(0.20), y(0.52))
      ..quadraticBezierTo(x(0.14), y(0.76), x(0.34), y(0.94))
      ..quadraticBezierTo(x(0.54), y(1.02), x(0.74), y(0.92))
      ..quadraticBezierTo(x(0.92), y(0.76), x(0.90), y(0.46))
      ..quadraticBezierTo(x(0.86), y(0.24), x(0.78), y(0.20))
      ..quadraticBezierTo(x(0.60), y(0.12), x(0.40), y(0.18))
      ..quadraticBezierTo(x(0.24), y(0.26), x(0.20), y(0.52))
      ..close();
    canvas.drawPath(palm, paint);

    // Four fingers and a thumb, suggested rather than drawn in full.
    for (final (double left, double top) in <(double, double)>[
      (0.36, 0.17),
      (0.52, 0.13),
      (0.67, 0.15),
      (0.80, 0.21),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x(left) - 10, y(top) - y(0.12), 20, y(0.13)),
          const Radius.circular(10),
        ),
        paint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(0.13), y(0.50), 20, y(0.16)),
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PalmPainter old) =>
      old.active != active ||
      old.trace != trace ||
      old.mounts != mounts ||
      old.absent != absent ||
      old.hasPhoto != hasPhoto;
}
