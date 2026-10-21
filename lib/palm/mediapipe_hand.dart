import 'dart:math' as math;
import 'dart:typed_data';

import 'palm_types.dart';

// =============================================================================
// The arithmetic around Google's MediaPipe hand models (Apache 2.0).
//
// Two networks work in turn. The palm detector looks at the whole picture, on
// a 192 square, and says roughly where a palm is and which way it points. The
// landmark model then looks at a 224 square cut out of the picture around that
// palm, turned so the fingers point up, and places 21 points on the hand. None
// of the cutting-out, turning and un-turning is inside the networks, so it is
// done here, following the published MediaPipe graph step for step.
// =============================================================================

const int detectorSize = 192;
const int landmarkSize = 224;

/// A square region of the picture, possibly turned, in pixels of the upright
/// frame. [rotation] is clockwise in radians, as the picture is drawn.
class RoiRect {
  const RoiRect({
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
    required this.rotation,
  });

  final double cx;
  final double cy;
  final double width;
  final double height;
  final double rotation;

  /// Where a point of the picture falls in the region's own unit square, the
  /// inverse of [toFrame].
  Pt fromFrame(Pt p) {
    final double c = math.cos(rotation);
    final double s = math.sin(rotation);
    final double dx = p.x - cx;
    final double dy = p.y - cy;
    return Pt((c * dx + s * dy) / width + 0.5, (-s * dx + c * dy) / height + 0.5);
  }

  /// Where a point of the region's own unit square (0..1, 0..1) falls in the
  /// picture.
  Pt toFrame(double u, double v) {
    final double c = math.cos(rotation);
    final double s = math.sin(rotation);
    final double dx = (u - 0.5) * width;
    final double dy = (v - 0.5) * height;
    return Pt(cx + c * dx - s * dy, cy + s * dx + c * dy);
  }
}

double normaliseRadians(double angle) {
  double a = angle;
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}

/// Anchor centres for the 192 px palm detector: strides 8, 16, 16, 16, which
/// gives a 24 by 24 grid with two anchors a cell and a 12 by 12 grid with six,
/// 2016 in all. The anchors are all the same size, so only the centres matter.
class PalmAnchors {
  PalmAnchors._(this.x, this.y);

  factory PalmAnchors() {
    final List<double> xs = <double>[];
    final List<double> ys = <double>[];
    void layer(int stride, int perCell) {
      final int cells = (detectorSize / stride).ceil();
      for (int row = 0; row < cells; row++) {
        for (int col = 0; col < cells; col++) {
          for (int k = 0; k < perCell; k++) {
            xs.add((col + 0.5) / cells);
            ys.add((row + 0.5) / cells);
          }
        }
      }
    }

    layer(8, 2);
    layer(16, 6);
    return PalmAnchors._(Float32List.fromList(xs), Float32List.fromList(ys));
  }

  final Float32List x;
  final Float32List y;
  int get length => x.length;
}

/// A palm the detector found, in the detector's own 0..1 square.
class PalmDetection {
  const PalmDetection({
    required this.score,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.keypoints,
  });

  final double score;
  final double cx;
  final double cy;
  final double w;
  final double h;

  /// Seven keypoints: wrist, then the bases of the fingers, as 0..1 pairs.
  final List<Pt> keypoints;
}

double _sigmoid(double v) {
  final double c = v < -100 ? -100 : (v > 100 ? 100 : v);
  return 1 / (1 + math.exp(-c));
}

/// Decodes the detector's raw outputs and merges the boxes that overlap the
/// best one, weighted by score, which is MediaPipe's own "weighted" suppression.
/// Returns the single best palm, or null when nothing clears [threshold].
PalmDetection? decodePalm({
  required Float32List regressors,
  required Float32List scores,
  required PalmAnchors anchors,
  double threshold = 0.5,
  double overlap = 0.3,
}) {
  final int n = anchors.length;
  final List<PalmDetection> found = <PalmDetection>[];
  for (int i = 0; i < n; i++) {
    final double score = _sigmoid(scores[i]);
    if (score < threshold) continue;
    final int o = i * 18;
    final double ax = anchors.x[i];
    final double ay = anchors.y[i];
    final double cx = regressors[o] / detectorSize + ax;
    final double cy = regressors[o + 1] / detectorSize + ay;
    final double w = regressors[o + 2] / detectorSize;
    final double h = regressors[o + 3] / detectorSize;
    final List<Pt> keypoints = <Pt>[
      for (int k = 0; k < 7; k++)
        Pt(
          regressors[o + 4 + k * 2] / detectorSize + ax,
          regressors[o + 5 + k * 2] / detectorSize + ay,
        ),
    ];
    found.add(
      PalmDetection(
        score: score,
        cx: cx,
        cy: cy,
        w: w,
        h: h,
        keypoints: keypoints,
      ),
    );
  }
  if (found.isEmpty) return null;
  found.sort((PalmDetection a, PalmDetection b) => b.score.compareTo(a.score));
  final PalmDetection best = found.first;

  double sumScore = 0;
  double cx = 0, cy = 0, w = 0, h = 0;
  final List<double> kx = List<double>.filled(7, 0);
  final List<double> ky = List<double>.filled(7, 0);
  for (final PalmDetection d in found) {
    if (_iou(best, d) < overlap) continue;
    sumScore += d.score;
    cx += d.cx * d.score;
    cy += d.cy * d.score;
    w += d.w * d.score;
    h += d.h * d.score;
    for (int k = 0; k < 7; k++) {
      kx[k] += d.keypoints[k].x * d.score;
      ky[k] += d.keypoints[k].y * d.score;
    }
  }
  return PalmDetection(
    score: best.score,
    cx: cx / sumScore,
    cy: cy / sumScore,
    w: w / sumScore,
    h: h / sumScore,
    keypoints: <Pt>[
      for (int k = 0; k < 7; k++) Pt(kx[k] / sumScore, ky[k] / sumScore),
    ],
  );
}

double _iou(PalmDetection a, PalmDetection b) {
  final double ax0 = a.cx - a.w / 2, ax1 = a.cx + a.w / 2;
  final double ay0 = a.cy - a.h / 2, ay1 = a.cy + a.h / 2;
  final double bx0 = b.cx - b.w / 2, bx1 = b.cx + b.w / 2;
  final double by0 = b.cy - b.h / 2, by1 = b.cy + b.h / 2;
  final double iw = math.max(0, math.min(ax1, bx1) - math.max(ax0, bx0));
  final double ih = math.max(0, math.min(ay1, by1) - math.max(ay0, by0));
  final double inter = iw * ih;
  final double union = a.w * a.h + b.w * b.h - inter;
  return union <= 0 ? 0 : inter / union;
}

/// The padding the detector's square input added around the picture.
class Letterbox {
  Letterbox(int frameW, int frameH)
    : scale = math.min(detectorSize / frameW, detectorSize / frameH),
      frameW = frameW,
      frameH = frameH {
    padX = (detectorSize - frameW * scale) / 2;
    padY = (detectorSize - frameH * scale) / 2;
  }

  final double scale;
  final int frameW;
  final int frameH;
  late final double padX;
  late final double padY;

  /// A point of the 0..1 detector square, in picture pixels.
  Pt toFrame(Pt p) => Pt(
    (p.x * detectorSize - padX) / scale,
    (p.y * detectorSize - padY) / scale,
  );

  /// A picture point, in the detector's 0..1 square (for the sampler).
  Pt fromFrame(double x, double y) =>
      Pt((x * scale + padX) / detectorSize, (y * scale + padY) / detectorSize);
}

/// The region the landmark model should look at, from a palm detection.
///
/// MediaPipe turns the hand to upright using the line from the wrist to the base
/// of the middle finger, moves the box up the hand by half its height, and
/// widens it to 2.6 times so the fingers are inside.
RoiRect roiFromPalm(PalmDetection d, Letterbox lb) {
  final Pt wrist = lb.toFrame(d.keypoints[0]);
  final Pt middle = lb.toFrame(d.keypoints[2]);
  final double rotation = normaliseRadians(
    math.pi / 2 - math.atan2(-(middle.y - wrist.y), middle.x - wrist.x),
  );
  final Pt centre = lb.toFrame(Pt(d.cx, d.cy));
  final double w = d.w * detectorSize / lb.scale;
  final double h = d.h * detectorSize / lb.scale;
  return _shiftAndScale(
    cx: centre.x,
    cy: centre.y,
    w: w,
    h: h,
    rotation: rotation,
    shiftY: -0.5,
    scale: 2.6,
  );
}

/// The region for the next frame, from where the hand was found in this one.
/// It is the box around all 21 points, turned by the wrist-to-middle-knuckle
/// line, widened to twice its size and moved up a tenth.
RoiRect roiFromLandmarks(List<Pt> pts) {
  double minX = double.infinity, minY = double.infinity;
  double maxX = -double.infinity, maxY = -double.infinity;
  for (final Pt p in pts) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final Pt wrist = pts[Joint.wrist];
  final Pt middle = pts[Joint.middleMcp];
  final double rotation = normaliseRadians(
    math.pi / 2 - math.atan2(-(middle.y - wrist.y), middle.x - wrist.x),
  );
  return _shiftAndScale(
    cx: (minX + maxX) / 2,
    cy: (minY + maxY) / 2,
    w: maxX - minX,
    h: maxY - minY,
    rotation: rotation,
    shiftY: -0.1,
    scale: 2.0,
  );
}

RoiRect _shiftAndScale({
  required double cx,
  required double cy,
  required double w,
  required double h,
  required double rotation,
  required double shiftY,
  required double scale,
}) {
  final double c = math.cos(rotation);
  final double s = math.sin(rotation);
  final double nx = cx + (-h * shiftY * s);
  final double ny = cy + (h * shiftY * c);
  final double side = math.max(w, h) * scale;
  return RoiRect(
    cx: nx,
    cy: ny,
    width: side,
    height: side,
    rotation: rotation,
  );
}

/// The landmark model's raw 63 numbers (x, y, z for 21 points, in the 224 px
/// of its input) put back on the picture.
List<Pt> projectLandmarks(Float32List raw, RoiRect roi) {
  return <Pt>[
    for (int i = 0; i < Joint.count; i++)
      roi.toFrame(
        raw[i * 3] / landmarkSize,
        raw[i * 3 + 1] / landmarkSize,
      ),
  ];
}

/// Depth for each point in picture pixels, from the model's own z (which is in
/// its input pixels and so scales with the box).
List<double> projectDepth(Float32List raw, RoiRect roi) => <double>[
  for (int i = 0; i < Joint.count; i++)
    raw[i * 3 + 2] / landmarkSize * roi.width,
];
