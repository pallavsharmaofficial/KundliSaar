import 'dart:math' as math;

import 'palm_types.dart';

/// Which side of the hand faces the camera.
enum Facing { palm, back, unclear }

/// Everything the guidance and the reading need to know about where the hand
/// is and what shape it has, worked out from the 21 points alone.
class HandGeometry {
  HandGeometry._({
    required this.fill,
    required this.fillX,
    required this.fillY,
    required this.edgeMargin,
    required this.centre,
    required this.knuckleSpan,
    required this.palmLength,
    required this.fingerLength,
    required this.minExtension,
    required this.thumbOnLeft,
    required this.facing,
    required this.angleDegrees,
  });

  factory HandGeometry.of(HandObservation o) {
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final Pt p in o.points) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final double w = o.frameWidth.toDouble();
    final double h = o.frameHeight.toDouble();
    final double fillX = (maxX - minX) / w;
    final double fillY = (maxY - minY) / h;
    // How far the nearest point sits from the nearest edge, as a share of the
    // short side. Negative when a point is outside the frame.
    final double edge = math.min(
      math.min(minX, w - maxX),
      math.min(minY, h - maxY),
    );
    final double edgeMargin = edge / math.min(w, h);

    double extension = double.infinity;
    for (final (int mcp, int tip) in Joint.fingers) {
      final double knuckle = o[Joint.wrist].distanceTo(o[mcp]);
      if (knuckle <= 0) continue;
      extension = math.min(extension, o[Joint.wrist].distanceTo(o[tip]) / knuckle);
    }

    final Pt a = o[Joint.indexMcp] - o[Joint.wrist];
    final Pt b = o[Joint.pinkyMcp] - o[Joint.wrist];
    // Positive when, with the fingers up, the index finger is left of the
    // little finger: the thumb is on the left of the picture.
    final double cross = a.x * b.y - a.y * b.x;
    final bool thumbLeft = cross > 0;

    // The network tells a left hand from a right one. A left palm and a right
    // back look alike in outline (thumb on the same side); the network's own
    // answer is what tells them apart.
    final double rightP = o.rightProbability;
    final bool saysLeft = rightP < 0.5;
    Facing facing;
    if (o.sideConfidence < 0.5) {
      facing = Facing.unclear;
    } else {
      final bool palm = thumbLeft == saysLeft;
      facing = palm ? Facing.palm : Facing.back;
    }

    final Pt axis = o[Joint.middleMcp] - o[Joint.wrist];
    return HandGeometry._(
      fill: math.max(fillX, fillY),
      fillX: fillX,
      fillY: fillY,
      edgeMargin: edgeMargin,
      centre: Pt((minX + maxX) / 2, (minY + maxY) / 2),
      knuckleSpan: o[Joint.indexMcp].distanceTo(o[Joint.pinkyMcp]),
      palmLength: o[Joint.wrist].distanceTo(o[Joint.middleMcp]),
      fingerLength: o[Joint.middleMcp].distanceTo(o[Joint.middleTip]),
      minExtension: extension.isFinite ? extension : 0,
      thumbOnLeft: thumbLeft,
      facing: facing,
      angleDegrees:
          math.atan2(axis.x, -axis.y) * 180 / math.pi, // 0 = fingers up
    );
  }

  /// How much of the frame the hand covers along its tightest axis, 0 to 1.
  final double fill;
  final double fillX;
  final double fillY;

  /// Distance from the edge of the picture to the nearest of the 21 points, as
  /// a share of the short side; below zero means part of the hand is outside.
  final double edgeMargin;

  /// Middle of the box around the hand, in pixels.
  final Pt centre;

  /// Index knuckle to little-finger knuckle.
  final double knuckleSpan;

  /// Wrist to the middle knuckle.
  final double palmLength;

  /// Middle knuckle to the middle fingertip.
  final double fingerLength;

  /// The least, over the four fingers, of fingertip-to-wrist over
  /// knuckle-to-wrist. A flat hand is near 1.7; a fist is near 1.1.
  final double minExtension;

  /// With the fingers up, the thumb sits on the left of the picture.
  final bool thumbOnLeft;
  final Facing facing;

  /// How far the hand is turned in the picture's plane, degrees. 0 is fingers
  /// straight up.
  final double angleDegrees;

  bool get partlyOutside => edgeMargin < 0.005;

  /// The hand, if the palm faces the camera: the thumb on the left of an
  /// upright left palm, on the right of a right one.
  HandSide get palmSide => thumbOnLeft ? HandSide.left : HandSide.right;

  /// Knuckle span over palm length. The measure the hand type is read from.
  double get widthRatio => palmLength <= 0 ? 0 : knuckleSpan / palmLength;

  /// Finger length over palm length.
  double get fingerRatio => palmLength <= 0 ? 0 : fingerLength / palmLength;
}
