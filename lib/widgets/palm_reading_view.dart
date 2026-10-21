import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/jyotish/hastrekha.dart';
import '../l10n/app_localizations.dart';
import '../palm/crease_finder.dart';
import '../palm/palm_scan.dart';
import 'common.dart';

/// The reading itself, as panels: the hand type, then each line, then each
/// raised mount. Shared by the hand tracer and the camera, so a reading looks
/// the same whichever way it was made.
class PalmReadingPanels extends StatelessWidget {
  const PalmReadingPanels({
    super.key,
    required this.reading,
    required this.hindi,
  });

  final HastrekhaReading reading;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Panel(
          title: l.handType,
          child: Text(hindi ? reading.summaryHindi : reading.summary),
        ),
        for (final LineReading line in reading.lines)
          Panel(
            title: hindi ? lineNames[line.line]![1] : lineNames[line.line]![0],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(hindi ? line.readingHindi : line.reading),
                const SizedBox(height: 8),
                // What was measured, beneath the reading it produced, where a
                // long figure has room to wrap on a narrow phone.
                Text(
                  hindi ? line.measuredHindi : line.measured,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        for (final MountReading mount in reading.mounts)
          Panel(
            title: hindi
                ? mountNames[mount.mount]![1]
                : mountNames[mount.mount]![0],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(hindi ? mount.readingHindi : mount.reading),
                if (mount.chartAgreement != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    hindi ? mount.chartAgreementHindi! : mount.chartAgreement!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

const Map<FoundLineKind, Color> _lineColours = <FoundLineKind, Color>{
  FoundLineKind.life: Color(0xFFE53935),
  FoundLineKind.head: Color(0xFF43A047),
  FoundLineKind.heart: Color(0xFF1E88E5),
};

/// The photograph the reading was made from, with the lines the app found
/// drawn where it found them, so the person can see at a glance whether they
/// sit on their own lines. Held in memory; nothing is saved.
class PalmPhotoView extends StatelessWidget {
  const PalmPhotoView({
    super.key,
    required this.image,
    required this.lines,
    required this.previewScale,
    required this.hindi,
  });

  final ui.Image image;
  final Map<FoundLineKind, FoundLine> lines;
  final double previewScale;
  final bool hindi;

  static const Map<FoundLineKind, (String, String)> _names =
      <FoundLineKind, (String, String)>{
        FoundLineKind.life: ('Life', 'जीवन'),
        FoundLineKind.head: ('Head', 'मस्तिष्क'),
        FoundLineKind.heart: ('Heart', 'हृदय'),
      };

  @override
  Widget build(BuildContext context) {
    final double aspect = image.width / image.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: aspect,
            child: CustomPaint(
              painter: _PhotoPainter(image, lines, previewScale),
            ),
          ),
        ),
        if (lines.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: <Widget>[
              for (final FoundLineKind k in lines.keys)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(width: 14, height: 4, color: _lineColours[k]),
                    const SizedBox(width: 6),
                    Text(hindi ? _names[k]!.$2 : _names[k]!.$1),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.image, this.lines, this.scale);

  final ui.Image image;
  final Map<FoundLineKind, FoundLine> lines;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final double k = size.width / image.width;
    lines.forEach((FoundLineKind kind, FoundLine line) {
      final Path path = Path();
      for (int i = 0; i < line.image.length; i++) {
        final Offset o = Offset(
          line.image[i].x * scale * k,
          line.image[i].y * scale * k,
        );
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      final Color colour = _lineColours[kind]!;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colour,
      );
    });
  }

  @override
  bool shouldRepaint(covariant _PhotoPainter old) =>
      old.image != image || old.lines != lines || old.scale != scale;
}

/// A bulleted list of short statements, in either language.
class SayList extends StatelessWidget {
  const SayList({super.key, required this.items, required this.hindi});

  final List<Say> items;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Say s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 10),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(s.of(hindi), style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
