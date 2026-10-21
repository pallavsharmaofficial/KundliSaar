import 'dart:math' as math;

/// A point in the upright camera picture, in pixels, y growing downward.
class Pt {
  const Pt(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(Pt other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));

  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt scaled(double k) => Pt(x * k, y * k);

  @override
  String toString() => 'Pt(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// The 21 points the hand model reports, named once so nothing else needs the
/// numbers.
class Joint {
  static const int wrist = 0;
  static const int thumbCmc = 1;
  static const int thumbMcp = 2;
  static const int thumbIp = 3;
  static const int thumbTip = 4;
  static const int indexMcp = 5;
  static const int indexPip = 6;
  static const int indexDip = 7;
  static const int indexTip = 8;
  static const int middleMcp = 9;
  static const int middlePip = 10;
  static const int middleDip = 11;
  static const int middleTip = 12;
  static const int ringMcp = 13;
  static const int ringPip = 14;
  static const int ringDip = 15;
  static const int ringTip = 16;
  static const int pinkyMcp = 17;
  static const int pinkyPip = 18;
  static const int pinkyDip = 19;
  static const int pinkyTip = 20;
  static const int count = 21;

  /// Knuckle and tip of each of the four fingers, index to little.
  static const List<(int, int)> fingers = <(int, int)>[
    (indexMcp, indexTip),
    (middleMcp, middleTip),
    (ringMcp, ringTip),
    (pinkyMcp, pinkyTip),
  ];
}

enum HandSide { left, right }

/// What the picture looks like around the hand, worked out while the model's
/// own input was being prepared so it costs nothing extra.
class FrameLook {
  const FrameLook({
    this.palmBrightness = 0.5,
    this.clipped = 0,
    this.crushed = 0,
    this.sharpness = 1,
    this.frameBrightness = 0.5,
  });

  /// Mean brightness of the palm, 0 to 1.
  final double palmBrightness;

  /// Share of the palm that is blown out to white.
  final double clipped;

  /// Share of the palm that is black.
  final double crushed;

  /// How much fine detail there is on the palm, relative to a sharp, evenly
  /// lit one. About 1 is crisp; well under 0.3 is out of focus or blurred.
  final double sharpness;

  /// Mean brightness of the whole picture.
  final double frameBrightness;
}

/// One look at the hand. Everything the guidance and the measurement need.
class HandObservation {
  const HandObservation({
    required this.points,
    required this.depth,
    required this.presence,
    required this.rightProbability,
    required this.frameWidth,
    required this.frameHeight,
    this.world,
    this.look = const FrameLook(),
    this.timeMs = 0,
  });

  /// 21 points, in pixels of the upright frame.
  final List<Pt> points;

  /// The model's relative depth for each point, in the same pixel units. Smaller
  /// is nearer the camera. A guess from one picture, used only as a hint.
  final List<double> depth;

  /// 21 points in metres, centred on the hand, camera axes. Used only to judge
  /// how far the palm is turned from the camera.
  final List<List<double>>? world;

  /// How sure the model is that a hand is there, 0 to 1.
  final double presence;

  /// Probability that this is a right hand, already corrected for the camera
  /// not mirroring the picture. 0.5 means the model could not tell.
  final double rightProbability;

  final int frameWidth;
  final int frameHeight;
  final FrameLook look;

  /// Milliseconds on whatever clock the caller keeps; only differences count.
  final int timeMs;

  Pt operator [](int joint) => points[joint];

  /// Confidence in left versus right, 0 (a coin toss) to 1.
  double get sideConfidence => (rightProbability - 0.5).abs() * 2;

  HandSide get likelySide =>
      rightProbability >= 0.5 ? HandSide.right : HandSide.left;
}
