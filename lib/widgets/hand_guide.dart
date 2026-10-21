import 'package:flutter/material.dart';

import '../palm/capture_flow.dart';
import '../palm/guidance.dart';
import '../palm/palm_types.dart';

/// The outline of an open palm, fingers up, drawn over the camera so the person
/// can see where to put their hand and about how big it should look.
class HandGuidePainter extends CustomPainter {
  HandGuidePainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = colour;
    // The guide covers about 70% of the width and 62% of the height, which is
    // what a hand at the right distance covers.
    final double w = size.width * 0.70;
    final double h = size.height * 0.62;
    final double left = (size.width - w) / 2;
    final double top = size.height * 0.20;

    final Rect palm = Rect.fromLTWH(left + w * 0.08, top + h * 0.46, w * 0.84, h * 0.54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(palm, Radius.circular(w * 0.16)),
      line,
    );
    // Four fingers, the middle tallest.
    const List<double> tops = <double>[0.12, 0.0, 0.07, 0.20];
    for (int i = 0; i < 4; i++) {
      final double fx = left + w * (0.10 + i * 0.2);
      final Rect finger = Rect.fromLTWH(
        fx,
        top + h * tops[i],
        w * 0.17,
        h * (0.52 - tops[i]),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(finger, Radius.circular(w * 0.085)),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HandGuidePainter old) => old.colour != colour;
}

const List<(int, int)> _bones = <(int, int)>[
  (0, 1), (1, 2), (2, 3), (3, 4),
  (0, 5), (5, 6), (6, 7), (7, 8),
  (5, 9), (9, 10), (10, 11), (11, 12),
  (9, 13), (13, 14), (14, 15), (15, 16),
  (13, 17), (17, 18), (18, 19), (19, 20),
  (0, 17),
];

/// The 21 points the camera has found on the hand, drawn lightly so the person
/// can see that the app has found their hand and is following it.
class HandSkeletonPainter extends CustomPainter {
  HandSkeletonPainter({required this.hand, required this.colour});

  final HandObservation? hand;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final HandObservation? h = hand;
    if (h == null) return;
    Offset at(Pt p) => Offset(
      p.x / h.frameWidth * size.width,
      p.y / h.frameHeight * size.height,
    );
    final Paint bone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = colour.withValues(alpha: 0.7);
    for (final (int a, int b) in _bones) {
      canvas.drawLine(at(h.points[a]), at(h.points[b]), bone);
    }
    final Paint dot = Paint()..color = colour;
    for (final Pt p in h.points) {
      canvas.drawCircle(at(p), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant HandSkeletonPainter old) =>
      old.hand != hand || old.colour != colour;
}

IconData guidanceIcon(Guidance g) {
  switch (g) {
    case Guidance.noHand:
      return Icons.back_hand_outlined;
    case Guidance.tooDark:
      return Icons.light_mode_outlined;
    case Guidance.tooBright:
      return Icons.wb_sunny_outlined;
    case Guidance.tooFar:
      return Icons.zoom_in;
    case Guidance.tooClose:
      return Icons.zoom_out;
    case Guidance.partlyOut:
      return Icons.crop_free;
    case Guidance.showPalm:
      return Icons.flip_camera_android_outlined;
    case Guidance.openFingers:
      return Icons.pan_tool_outlined;
    case Guidance.holdSteady:
      return Icons.pause_circle_outline;
    case Guidance.blurry:
      return Icons.blur_on;
    case Guidance.ready:
      return Icons.check_circle_outline;
  }
}

/// What the camera screen says, one short line at a time.
String statusLine(CaptureStatus status, bool hindi) {
  switch (status.phase) {
    case CapturePhase.counting:
      return hindi
          ? 'हाथ ऐसे ही रखिए… ${status.digit}'
          : 'Hold still… ${status.digit}';
    case CapturePhase.captured:
      return hindi ? 'हो गया' : 'Got it';
    case CapturePhase.aiming:
    case CapturePhase.steadying:
      return guidanceText[status.guidance]!.of(hindi);
  }
}

/// The line that tells the person what to do next, with its icon. A live
/// region, so a screen reader speaks each change.
class GuidanceBanner extends StatelessWidget {
  const GuidanceBanner({super.key, required this.status, required this.hindi});

  final CaptureStatus status;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool good =
        status.phase != CapturePhase.aiming ||
        status.guidance == Guidance.ready;
    final Color tint = good ? const Color(0xFF2E7D32) : theme.colorScheme.primary;
    final String text = statusLine(status, hindi);
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                status.phase == CapturePhase.aiming
                    ? guidanceIcon(status.guidance)
                    : Icons.check_circle_outline,
                color: tint,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  key: const ValueKey<String>('guidance-text'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big 3, 2, 1 over the guide, and the ring that fills while the hand is
/// being checked for steadiness.
class CountdownBadge extends StatelessWidget {
  const CountdownBadge({super.key, required this.status});

  final CaptureStatus status;

  @override
  Widget build(BuildContext context) {
    final int? digit = status.digit;
    if (status.phase == CapturePhase.steadying) {
      return SizedBox(
        width: 72,
        height: 72,
        child: CircularProgressIndicator(
          key: const ValueKey<String>('steady-ring'),
          value: status.progress,
          strokeWidth: 6,
          color: const Color(0xFF2E7D32),
          backgroundColor: Colors.white24,
        ),
      );
    }
    if (status.phase != CapturePhase.counting || digit == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xAA000000),
        shape: BoxShape.circle,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (Widget child, Animation<double> a) =>
            ScaleTransition(scale: a, child: child),
        child: Text(
          '$digit',
          key: ValueKey<int>(digit),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
