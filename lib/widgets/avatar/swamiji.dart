import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What the avatar is doing. The mood changes the posture, the eyes and the
/// aura, which is how a listener knows whether the app is waiting for them,
/// working, or talking.
enum SwamijiMood { idle, listening, thinking, speaking, blessing }

/// A seated swamiji, drawn entirely in code.
///
/// Nothing here is a photograph or a likeness of any living teacher: it is a
/// figure in the way a temple mural is a figure. Drawing it rather than
/// shipping an animation file keeps it a few kilobytes, lets it take the app's
/// colours, and means it works with the network off.
class SwamijiAvatar extends StatefulWidget {
  const SwamijiAvatar({
    super.key,
    this.mood = SwamijiMood.idle,
    this.size = 180,
    this.level = 0,
  });

  final SwamijiMood mood;
  final double size;

  /// Loudness of the voice right now, 0 to 1, used to move the mouth.
  final double level;

  @override
  State<SwamijiAvatar> createState() => _SwamijiAvatarState();
}

class _SwamijiAvatarState extends State<SwamijiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => SizedBox(
        width: widget.size,
        height: widget.size * 1.12,
        child: CustomPaint(
          painter: _SwamijiPainter(
            time: _controller.value,
            mood: widget.mood,
            level: widget.level,
            accent: scheme.primary,
            onSurface: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SwamijiPainter extends CustomPainter {
  _SwamijiPainter({
    required this.time,
    required this.mood,
    required this.level,
    required this.accent,
    required this.onSurface,
  });

  final double time;
  final SwamijiMood mood;
  final double level;
  final Color accent;
  final Color onSurface;

  static const Color _skin = Color(0xFFD7A06B);
  static const Color _skinShade = Color(0xFFB9834F);
  static const Color _robe = Color(0xFFE2762B);
  static const Color _robeShade = Color(0xFFC25A17);
  static const Color _hair = Color(0xFFF3EDE4);
  static const Color _hairShade = Color(0xFFD8CEC0);
  static const Color _bead = Color(0xFF6B4423);
  static const Color _ash = Color(0xFFF7F2E7);
  static const Color _sindoor = Color(0xFFC1272D);

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.width / 200;
    final Offset origin = Offset(size.width / 2, size.height);

    // One slow breath, in and out.
    final double breath = math.sin(time * 2 * math.pi) * 0.5 + 0.5;
    final double lift = breath * 1.6 * unit;

    void at(void Function(Canvas) draw) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(unit, unit);
      draw(canvas);
      canvas.restore();
    }

    at((Canvas c) => _paintAura(c, breath));
    at((Canvas c) => _paintAsana(c));
    at((Canvas c) => _paintBody(c, lift / unit));
    at((Canvas c) => _paintHead(c, lift / unit));
  }

  /// The glow behind the figure, quicker when he is listening.
  void _paintAura(Canvas canvas, double breath) {
    final double pulse = switch (mood) {
      SwamijiMood.listening => 0.5 + 0.5 * math.sin(time * 2 * math.pi * 3),
      SwamijiMood.speaking => 0.4 + 0.6 * level,
      _ => breath,
    };
    canvas.drawCircle(
      const Offset(0, -118),
      62 + 8 * pulse,
      Paint()
        ..color = accent.withValues(alpha: 0.10 + 0.10 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // A halo, the way it is painted behind a seated figure.
    canvas.drawCircle(
      const Offset(0, -124),
      44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.35 + 0.25 * pulse),
    );
  }

  /// The lotus seat.
  void _paintAsana(Canvas canvas) {
    final Paint petal = Paint()..color = _robeShade.withValues(alpha: 0.9);
    for (int i = -3; i <= 3; i++) {
      final Path path = Path()
        ..moveTo(i * 16.0, -6)
        ..quadraticBezierTo(i * 16.0 - 11, -18, i * 16.0, -26)
        ..quadraticBezierTo(i * 16.0 + 11, -18, i * 16.0, -6)
        ..close();
      canvas.drawPath(path, petal);
    }
    canvas.drawOval(
      const Rect.fromLTRB(-78, -16, 78, 4),
      Paint()..color = _robe.withValues(alpha: 0.95),
    );
  }

  void _paintBody(Canvas canvas, double lift) {
    canvas.save();
    canvas.translate(0, -lift);

    // Crossed legs under the robe.
    final Path legs = Path()
      ..moveTo(-64, -14)
      ..quadraticBezierTo(-40, -40, 0, -40)
      ..quadraticBezierTo(40, -40, 64, -14)
      ..quadraticBezierTo(0, 0, -64, -14)
      ..close();
    canvas.drawPath(legs, Paint()..color = _robe);

    // Torso, widening into the shoulders.
    final Path torso = Path()
      ..moveTo(-30, -36)
      ..quadraticBezierTo(-44, -78, -38, -104)
      ..quadraticBezierTo(0, -118, 38, -104)
      ..quadraticBezierTo(44, -78, 30, -36)
      ..close();
    canvas.drawPath(torso, Paint()..color = _robe);

    // The upper cloth falling over one shoulder.
    final Path shawl = Path()
      ..moveTo(-38, -104)
      ..quadraticBezierTo(-10, -96, 12, -70)
      ..quadraticBezierTo(22, -52, 18, -36)
      ..lineTo(-24, -36)
      ..quadraticBezierTo(-36, -70, -38, -104)
      ..close();
    canvas.drawPath(shawl, Paint()..color = _robeShade);

    // Bare chest and the rudraksha mala.
    canvas.drawPath(
      Path()
        ..moveTo(-16, -104)
        ..quadraticBezierTo(0, -96, 16, -104)
        ..quadraticBezierTo(14, -82, 0, -74)
        ..quadraticBezierTo(-14, -82, -16, -104)
        ..close(),
      Paint()..color = _skin,
    );
    for (int i = 0; i <= 14; i++) {
      final double t = i / 14;
      final double x = -22 + 44 * t;
      final double y = -104 + 26 * math.sin(math.pi * t);
      canvas.drawCircle(Offset(x, y), 2.1, Paint()..color = _bead);
    }

    _paintArms(canvas);
    canvas.restore();
  }

  void _paintArms(Canvas canvas) {
    final Paint skin = Paint()..color = _skin;
    final Paint shade = Paint()..color = _skinShade;

    if (mood == SwamijiMood.blessing) {
      // The right hand raised in abhaya mudra: the gesture of do not fear.
      final Path arm = Path()
        ..moveTo(32, -98)
        ..quadraticBezierTo(56, -92, 56, -118)
        ..quadraticBezierTo(56, -132, 48, -136)
        ..quadraticBezierTo(38, -128, 36, -112)
        ..quadraticBezierTo(34, -102, 26, -94)
        ..close();
      canvas.drawPath(arm, skin);
      canvas.drawCircle(const Offset(50, -140), 9, skin);
      for (int i = 0; i < 4; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(44 + i * 3.2, -152, 2.4, 10),
            const Radius.circular(1.2),
          ),
          skin,
        );
      }
    } else {
      // Both hands resting on the knees in chin mudra.
      final Path left = Path()
        ..moveTo(-32, -98)
        ..quadraticBezierTo(-54, -78, -52, -48)
        ..quadraticBezierTo(-44, -42, -36, -48)
        ..quadraticBezierTo(-36, -74, -24, -92)
        ..close();
      final Path right = Path()
        ..moveTo(32, -98)
        ..quadraticBezierTo(54, -78, 52, -48)
        ..quadraticBezierTo(44, -42, 36, -48)
        ..quadraticBezierTo(36, -74, 24, -92)
        ..close();
      canvas.drawPath(left, skin);
      canvas.drawPath(right, skin);
      canvas.drawCircle(const Offset(-46, -44), 7.5, skin);
      canvas.drawCircle(const Offset(46, -44), 7.5, skin);
      // Thumb meeting forefinger.
      canvas.drawCircle(const Offset(-49, -49), 3.0, shade);
      canvas.drawCircle(const Offset(49, -49), 3.0, shade);
    }

    if (mood == SwamijiMood.thinking) {
      // The mala turning, one bead at a time.
      final double turn = (time * 8) % 1;
      canvas.drawCircle(
        Offset(46 - 4 * turn, -44 - 6 * turn),
        2.6,
        Paint()..color = _bead,
      );
    }
  }

  void _paintHead(Canvas canvas, double lift) {
    canvas.save();
    canvas.translate(0, -lift);
    // A small tilt when he is listening.
    final double tilt = mood == SwamijiMood.listening ? 0.06 : 0.0;
    canvas.translate(0, -124);
    canvas.rotate(tilt);

    // Neck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, 14, 22, 20),
        const Radius.circular(8),
      ),
      Paint()..color = _skinShade,
    );

    // Face.
    canvas.drawOval(
      const Rect.fromLTRB(-30, -34, 30, 26),
      Paint()..color = _skin,
    );

    // Ears.
    canvas.drawOval(
      const Rect.fromLTRB(-35, -10, -27, 8),
      Paint()..color = _skin,
    );
    canvas.drawOval(
      const Rect.fromLTRB(27, -10, 35, 8),
      Paint()..color = _skin,
    );

    // The jata, hair tied in a knot above the head.
    canvas.drawPath(
      Path()
        ..moveTo(-30, -16)
        ..quadraticBezierTo(-34, -44, 0, -46)
        ..quadraticBezierTo(34, -44, 30, -16)
        ..quadraticBezierTo(18, -34, 0, -34)
        ..quadraticBezierTo(-18, -34, -30, -16)
        ..close(),
      Paint()..color = _hair,
    );
    canvas.drawCircle(const Offset(0, -50), 11, Paint()..color = _hair);
    canvas.drawCircle(
      const Offset(0, -50),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _hairShade,
    );

    // Urdhva pundra, the upright mark on the forehead.
    canvas.drawPath(
      Path()
        ..moveTo(-5, -26)
        ..lineTo(-2.4, -8)
        ..lineTo(2.4, -8)
        ..lineTo(5, -26)
        ..quadraticBezierTo(0, -22, -5, -26)
        ..close(),
      Paint()..color = _ash,
    );
    canvas.drawCircle(const Offset(0, -9), 2.2, Paint()..color = _sindoor);

    _paintFace(canvas);

    // The beard, long and white.
    canvas.drawPath(
      Path()
        ..moveTo(-26, 2)
        ..quadraticBezierTo(-24, 30, 0, 46)
        ..quadraticBezierTo(24, 30, 26, 2)
        ..quadraticBezierTo(14, 18, 0, 18)
        ..quadraticBezierTo(-14, 18, -26, 2)
        ..close(),
      Paint()..color = _hair,
    );

    canvas.restore();
  }

  void _paintFace(Canvas canvas) {
    final Paint brow = Paint()
      ..color = _hairShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTRB(-20, -14, -4, -2),
      math.pi,
      math.pi,
      false,
      brow,
    );
    canvas.drawArc(
      const Rect.fromLTRB(4, -14, 20, -2),
      math.pi,
      math.pi,
      false,
      brow,
    );

    // Eyes. They close when he is thinking, and blink on their own otherwise.
    final double blinkPhase = (time * 6) % 1;
    final bool blinking = blinkPhase > 0.94;
    final bool closed = mood == SwamijiMood.thinking || blinking;
    final Paint eyeWhite = Paint()..color = const Color(0xFFFBF7F0);
    final Paint pupil = Paint()..color = const Color(0xFF3A2A1C);
    final Paint lid = Paint()
      ..color = _skinShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final double side in <double>[-1, 1]) {
      final Offset centre = Offset(12.5 * side, -1);
      if (closed) {
        canvas.drawLine(
          centre + const Offset(-6, 0),
          centre + const Offset(6, 0),
          lid,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: centre, width: 14, height: 7.5),
          eyeWhite,
        );
        // The gaze drifts a little while he listens.
        final double look = mood == SwamijiMood.listening
            ? math.sin(time * 2 * math.pi * 1.5) * 1.6
            : 0;
        canvas.drawCircle(centre + Offset(look, 0), 2.6, pupil);
      }
    }

    // Mouth. It moves with the voice while speaking.
    final double open = mood == SwamijiMood.speaking
        ? (0.25 + 0.75 * level) *
              (0.55 + 0.45 * math.sin(time * 2 * math.pi * 9))
        : 0;
    if (open > 0.05) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, 13),
          width: 13,
          height: 3 + 7 * open,
        ),
        Paint()..color = const Color(0xFF7A3B2E),
      );
    } else {
      canvas.drawArc(
        const Rect.fromLTRB(-9, 7, 9, 17),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        Paint()
          ..color = const Color(0xFF8B4A3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SwamijiPainter old) =>
      old.time != time || old.mood != mood || old.level != level;
}

/// The avatar with a line of speech beside it, as it appears on the Ask screen.
class SwamijiPanel extends StatelessWidget {
  const SwamijiPanel({
    super.key,
    required this.mood,
    required this.caption,
    this.level = 0,
    this.onTap,
  });

  final SwamijiMood mood;
  final String caption;
  final double level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SwamijiAvatar(mood: mood, size: 112, level: level),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(caption, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
