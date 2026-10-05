import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/jyotish/nakshatra.dart';

/// Stylised star patterns for the 27 nakshatras, one per mansion.
///
/// These are drawn from each nakshatra's own symbol rather than from the sky:
/// Ashwini's horse head, Bharani's yoni, Rohini's cart. Coordinates are
/// normalised to a unit box, and the pairs say which stars to join.
class _Pattern {
  const _Pattern(this.stars, this.links);

  final List<Offset> stars;
  final List<List<int>> links;
}

const List<_Pattern> _patterns = <_Pattern>[
  // Ashwini: a horse's head
  _Pattern(
    <Offset>[
      Offset(0.25, 0.65),
      Offset(0.40, 0.35),
      Offset(0.62, 0.28),
      Offset(0.78, 0.45),
      Offset(0.60, 0.70),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
      <int>[4, 0],
    ],
  ),
  // Bharani: the yoni, three stars in a triangle
  _Pattern(
    <Offset>[Offset(0.30, 0.30), Offset(0.70, 0.30), Offset(0.50, 0.75)],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 0],
    ],
  ),
  // Krittika: the flame, six stars of the Pleiades
  _Pattern(
    <Offset>[
      Offset(0.35, 0.70),
      Offset(0.45, 0.50),
      Offset(0.40, 0.30),
      Offset(0.58, 0.25),
      Offset(0.65, 0.45),
      Offset(0.55, 0.62),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
      <int>[4, 5],
      <int>[5, 1],
    ],
  ),
  // Rohini: the cart
  _Pattern(
    <Offset>[
      Offset(0.25, 0.40),
      Offset(0.70, 0.35),
      Offset(0.75, 0.62),
      Offset(0.30, 0.68),
      Offset(0.50, 0.22),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 0],
      <int>[0, 4],
      <int>[1, 4],
    ],
  ),
  // Mrigashira: a deer's head
  _Pattern(
    <Offset>[
      Offset(0.30, 0.55),
      Offset(0.50, 0.42),
      Offset(0.70, 0.52),
      Offset(0.42, 0.25),
      Offset(0.60, 0.24),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[1, 3],
      <int>[1, 4],
    ],
  ),
  // Ardra: a single teardrop
  _Pattern(
    <Offset>[
      Offset(0.50, 0.30),
      Offset(0.42, 0.52),
      Offset(0.50, 0.70),
      Offset(0.58, 0.52),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 0],
    ],
  ),
  // Punarvasu: a quiver of arrows
  _Pattern(
    <Offset>[
      Offset(0.28, 0.68),
      Offset(0.42, 0.44),
      Offset(0.58, 0.32),
      Offset(0.74, 0.30),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
    ],
  ),
  // Pushya: the cow's udder, a flower of four
  _Pattern(
    <Offset>[
      Offset(0.50, 0.28),
      Offset(0.72, 0.50),
      Offset(0.50, 0.72),
      Offset(0.28, 0.50),
      Offset(0.50, 0.50),
    ],
    <List<int>>[
      <int>[0, 4],
      <int>[1, 4],
      <int>[2, 4],
      <int>[3, 4],
    ],
  ),
  // Ashlesha: a coiled serpent
  _Pattern(
    <Offset>[
      Offset(0.25, 0.60),
      Offset(0.38, 0.42),
      Offset(0.56, 0.38),
      Offset(0.68, 0.52),
      Offset(0.60, 0.68),
      Offset(0.44, 0.64),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
      <int>[4, 5],
    ],
  ),
  // Magha: a throne
  _Pattern(
    <Offset>[
      Offset(0.32, 0.72),
      Offset(0.32, 0.42),
      Offset(0.50, 0.28),
      Offset(0.68, 0.42),
      Offset(0.68, 0.72),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
      <int>[1, 3],
    ],
  ),
  // Purva Phalguni: the front legs of a bed
  _Pattern(
    <Offset>[
      Offset(0.34, 0.30),
      Offset(0.66, 0.30),
      Offset(0.34, 0.68),
      Offset(0.66, 0.68),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 3],
    ],
  ),
  // Uttara Phalguni: the back legs of a bed
  _Pattern(
    <Offset>[
      Offset(0.34, 0.32),
      Offset(0.66, 0.32),
      Offset(0.34, 0.70),
      Offset(0.66, 0.70),
    ],
    <List<int>>[
      <int>[2, 3],
      <int>[0, 2],
      <int>[1, 3],
    ],
  ),
  // Hasta: an open hand, five fingers
  _Pattern(
    <Offset>[
      Offset(0.50, 0.72),
      Offset(0.28, 0.48),
      Offset(0.40, 0.30),
      Offset(0.56, 0.26),
      Offset(0.70, 0.36),
      Offset(0.74, 0.56),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[0, 2],
      <int>[0, 3],
      <int>[0, 4],
      <int>[0, 5],
    ],
  ),
  // Chitra: one bright jewel
  _Pattern(
    <Offset>[
      Offset(0.50, 0.50),
      Offset(0.50, 0.26),
      Offset(0.74, 0.50),
      Offset(0.50, 0.74),
      Offset(0.26, 0.50),
    ],
    <List<int>>[
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
      <int>[4, 1],
    ],
  ),
  // Swati: a shoot bending in the wind
  _Pattern(
    <Offset>[
      Offset(0.34, 0.74),
      Offset(0.42, 0.56),
      Offset(0.52, 0.42),
      Offset(0.68, 0.32),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
    ],
  ),
  // Vishakha: a triumphal arch
  _Pattern(
    <Offset>[
      Offset(0.28, 0.72),
      Offset(0.32, 0.42),
      Offset(0.50, 0.28),
      Offset(0.68, 0.42),
      Offset(0.72, 0.72),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
    ],
  ),
  // Anuradha: a lotus
  _Pattern(
    <Offset>[
      Offset(0.50, 0.46),
      Offset(0.32, 0.38),
      Offset(0.50, 0.26),
      Offset(0.68, 0.38),
      Offset(0.40, 0.66),
      Offset(0.60, 0.66),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[0, 2],
      <int>[0, 3],
      <int>[0, 4],
      <int>[0, 5],
    ],
  ),
  // Jyeshtha: an earring
  _Pattern(
    <Offset>[
      Offset(0.50, 0.26),
      Offset(0.38, 0.46),
      Offset(0.50, 0.68),
      Offset(0.62, 0.46),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 0],
    ],
  ),
  // Mula: a bunch of roots
  _Pattern(
    <Offset>[
      Offset(0.50, 0.26),
      Offset(0.38, 0.48),
      Offset(0.50, 0.48),
      Offset(0.62, 0.48),
      Offset(0.32, 0.72),
      Offset(0.68, 0.72),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[0, 2],
      <int>[0, 3],
      <int>[1, 4],
      <int>[3, 5],
    ],
  ),
  // Purva Ashadha: a winnowing basket
  _Pattern(
    <Offset>[
      Offset(0.30, 0.38),
      Offset(0.70, 0.38),
      Offset(0.60, 0.70),
      Offset(0.40, 0.70),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 0],
    ],
  ),
  // Uttara Ashadha: an elephant's tusk
  _Pattern(
    <Offset>[
      Offset(0.28, 0.66),
      Offset(0.44, 0.50),
      Offset(0.62, 0.40),
      Offset(0.76, 0.36),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
    ],
  ),
  // Shravana: three footprints
  _Pattern(
    <Offset>[Offset(0.32, 0.62), Offset(0.50, 0.46), Offset(0.68, 0.32)],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
    ],
  ),
  // Dhanishta: a drum
  _Pattern(
    <Offset>[
      Offset(0.34, 0.34),
      Offset(0.66, 0.34),
      Offset(0.66, 0.66),
      Offset(0.34, 0.66),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 0],
      <int>[0, 2],
      <int>[1, 3],
    ],
  ),
  // Shatabhisha: a circle of a hundred
  _Pattern(
    <Offset>[
      Offset(0.50, 0.26),
      Offset(0.67, 0.36),
      Offset(0.74, 0.54),
      Offset(0.62, 0.70),
      Offset(0.42, 0.72),
      Offset(0.28, 0.58),
      Offset(0.30, 0.38),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 4],
      <int>[4, 5],
      <int>[5, 6],
      <int>[6, 0],
    ],
  ),
  // Purva Bhadrapada: the front of a cot
  _Pattern(
    <Offset>[Offset(0.34, 0.30), Offset(0.66, 0.30), Offset(0.34, 0.66)],
    <List<int>>[
      <int>[0, 1],
      <int>[0, 2],
    ],
  ),
  // Uttara Bhadrapada: the back of a cot
  _Pattern(
    <Offset>[Offset(0.34, 0.34), Offset(0.66, 0.34), Offset(0.66, 0.70)],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
    ],
  ),
  // Revati: a fish
  _Pattern(
    <Offset>[
      Offset(0.28, 0.50),
      Offset(0.46, 0.36),
      Offset(0.66, 0.50),
      Offset(0.46, 0.64),
      Offset(0.78, 0.38),
      Offset(0.78, 0.62),
    ],
    <List<int>>[
      <int>[0, 1],
      <int>[1, 2],
      <int>[2, 3],
      <int>[3, 0],
      <int>[2, 4],
      <int>[2, 5],
      <int>[4, 5],
    ],
  ),
];

/// The loading state of the app: a nakshatra drawing itself star by star.
///
/// Waiting is unavoidable when a chart is being computed, so it is spent on
/// something worth looking at. The pattern walks the 27 mansions in order,
/// naming each one and its deity as it goes.
class NakshatraLoader extends StatefulWidget {
  const NakshatraLoader({
    super.key,
    this.message,
    this.startAt,
    this.size = 200,
    this.walk = true,
  });

  final String? message;

  /// Which mansion to draw first; otherwise it starts from Ashwini.
  final int? startAt;
  final double size;

  /// When false the loader stays on one nakshatra instead of walking the 27.
  final bool walk;

  @override
  State<NakshatraLoader> createState() => _NakshatraLoaderState();
}

class _NakshatraLoaderState extends State<NakshatraLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late int _index = widget.startAt ?? 0;
  double _previous = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  /// The Moon moves on to the next mansion when a cycle wraps.
  void _onTick() {
    if (!widget.walk) return;
    if (_controller.value < _previous) {
      setState(() => _index = (_index + 1) % 27);
    }
    _previous = _controller.value;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hindi = Localizations.localeOf(context).languageCode == 'hi';
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double progress = _controller.value;
        final NakshatraInfo nakshatra = nakshatraTable[_index % 27];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _NakshatraPainter(
                  pattern: _patterns[_index % 27],
                  progress: progress,
                  index: _index % 27,
                  starColor: theme.colorScheme.primary,
                  lineColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.35,
                  ),
                  ringColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hindi ? nakshatra.hindi : nakshatra.english,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              hindi ? nakshatra.deityHindi : nakshatra.deityEnglish,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (widget.message != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NakshatraPainter extends CustomPainter {
  _NakshatraPainter({
    required this.pattern,
    required this.progress,
    required this.index,
    required this.starColor,
    required this.lineColor,
    required this.ringColor,
  });

  final _Pattern pattern;
  final double progress;
  final int index;
  final Color starColor;
  final Color lineColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.width / 2;

    // The ring of 27 mansions, with the one being drawn lit.
    final Paint tick = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 27; i++) {
      final double angle = -math.pi / 2 + i * 2 * math.pi / 27;
      final Offset at =
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 6);
      final bool active = i == index;
      tick.color = active ? starColor : ringColor;
      canvas.drawCircle(at, active ? 3.4 : 1.6, tick);
    }

    // A slow sweep hand, like the Moon walking the mansions.
    final double sweep = -math.pi / 2 + (index + progress) * 2 * math.pi / 27;
    canvas.drawLine(
      centre,
      centre + Offset(math.cos(sweep), math.sin(sweep)) * (radius - 12),
      Paint()
        ..color = starColor.withValues(alpha: 0.25)
        ..strokeWidth = 1.2,
    );

    final double inner = radius * 0.74;
    Offset place(Offset unit) => Offset(
      centre.dx + (unit.dx - 0.5) * inner * 2,
      centre.dy + (unit.dy - 0.5) * inner * 2,
    );

    // Lines draw themselves in order, then the stars settle and twinkle.
    final double lineProgress = (progress / 0.7).clamp(0.0, 1.0);
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final double totalLinks = pattern.links.length.toDouble();
    for (int i = 0; i < pattern.links.length; i++) {
      final double share = (lineProgress * totalLinks - i).clamp(0.0, 1.0);
      if (share <= 0) break;
      final Offset a = place(pattern.stars[pattern.links[i][0]]);
      final Offset b = place(pattern.stars[pattern.links[i][1]]);
      canvas.drawLine(a, Offset.lerp(a, b, share)!, linePaint);
    }

    for (int i = 0; i < pattern.stars.length; i++) {
      final Offset at = place(pattern.stars[i]);
      final double twinkle =
          0.6 + 0.4 * math.sin(progress * 2 * math.pi * 2 + i * 1.3);
      final double appear = ((progress / 0.6) * pattern.stars.length - i).clamp(
        0.0,
        1.0,
      );
      if (appear <= 0) continue;
      canvas.drawCircle(
        at,
        2.0 + 2.6 * appear * twinkle,
        Paint()..color = starColor.withValues(alpha: 0.9 * appear),
      );
      canvas.drawCircle(
        at,
        6.0 + 4.0 * twinkle,
        Paint()
          ..color = starColor.withValues(alpha: 0.12 * appear)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NakshatraPainter old) =>
      old.progress != progress || old.index != index;
}

/// A full-screen version, for the first load of a heavy computation.
class NakshatraLoadingView extends StatelessWidget {
  const NakshatraLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: NakshatraLoader(message: message, size: 220),
    ),
  );
}
