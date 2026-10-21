import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/mediapipe_hand.dart';
import 'package:kundlisaar/palm/palm_types.dart';

import 'support/hands.dart';

void main() {
  group('the palm detector\'s anchors', () {
    test('there are 2016: 24 by 24 by two, and 12 by 12 by six', () {
      final PalmAnchors a = PalmAnchors();
      expect(a.length, 2016);
      expect(24 * 24 * 2 + 12 * 12 * 6, 2016);
    });

    test('they sit at cell centres, two to a cell then six', () {
      final PalmAnchors a = PalmAnchors();
      expect(a.x[0], closeTo(0.5 / 24, 1e-6));
      expect(a.y[0], closeTo(0.5 / 24, 1e-6));
      expect(a.x[1], a.x[0]);
      expect(a.x[2], closeTo(1.5 / 24, 1e-6));
      expect(a.x[1152], closeTo(0.5 / 12, 1e-6));
      expect(a.x[1152 + 6], closeTo(1.5 / 12, 1e-6));
      expect(a.x[2015], closeTo(11.5 / 12, 1e-6));
      expect(a.y[2015], closeTo(11.5 / 12, 1e-6));
    });
  });

  group('turned regions of the picture', () {
    test('a point goes into a region and comes back', () {
      const RoiRect roi = RoiRect(
        cx: 400,
        cy: 500,
        width: 300,
        height: 300,
        rotation: 0.6,
      );
      for (final (double, double) uv in <(double, double)>[
        (0, 0),
        (1, 0),
        (0.3, 0.8),
        (0.5, 0.5),
      ]) {
        final Pt p = roi.toFrame(uv.$1, uv.$2);
        final Pt back = roi.fromFrame(p);
        expect(back.x, closeTo(uv.$1, 1e-9));
        expect(back.y, closeTo(uv.$2, 1e-9));
      }
    });

    test('a region turned a quarter clockwise has its top on the right', () {
      const RoiRect roi = RoiRect(
        cx: 100,
        cy: 100,
        width: 100,
        height: 100,
        rotation: math.pi / 2,
      );
      final Pt top = roi.toFrame(0.5, 0);
      expect(top.x, closeTo(150, 1e-9));
      expect(top.y, closeTo(100, 1e-9));
    });

    test('the region after an upright hand is upright, and follows it when it turns', () {
      final double upright = roiFromLandmarks(syntheticHand().points).rotation;
      expect(upright.abs(), lessThan(0.1));
      final double turned = roiFromLandmarks(
        syntheticHand(rotationDegrees: 90, handLength: 560).points,
      ).rotation;
      expect(turned, closeTo(math.pi / 2, 0.1));
      final double upsideDown = roiFromLandmarks(
        syntheticHand(rotationDegrees: 180, handLength: 560).points,
      ).rotation.abs();
      expect(upsideDown, closeTo(math.pi, 0.1));
    });

    test('the region is wider than the hand, so the fingers are inside', () {
      final HandObservation h = syntheticHand(handLength: 600);
      final RoiRect roi = roiFromLandmarks(h.points);
      for (final Pt p in h.points) {
        final Pt q = roi.fromFrame(p);
        expect(q.x, inInclusiveRange(0, 1));
        expect(q.y, inInclusiveRange(0, 1));
      }
    });

    test('landmarks the model reports are put back where the region was', () {
      const RoiRect roi = RoiRect(
        cx: 300,
        cy: 400,
        width: 448,
        height: 448,
        rotation: 0.4,
      );
      final Float32List raw = Float32List(63);
      raw[0] = 112; // x in the model's 224
      raw[1] = 112; // y
      raw[2] = 0;
      final List<Pt> p = projectLandmarks(raw, roi);
      expect(p[0].x, closeTo(300, 1e-3));
      expect(p[0].y, closeTo(400, 1e-3));
    });
  });

  group('decoding the palm detector', () {
    Float32List regressors() => Float32List(2016 * 18);
    Float32List scores() => Float32List.fromList(
      List<double>.filled(2016, -10),
    );

    test('nothing above the threshold: no palm', () {
      expect(
        decodePalm(regressors: regressors(), scores: scores(), anchors: PalmAnchors()),
        isNull,
      );
    });

    test('one confident anchor gives a palm at its box', () {
      final Float32List r = regressors();
      final Float32List s = scores();
      final PalmAnchors anchors = PalmAnchors();
      const int i = 1200;
      s[i] = 5;
      r[i * 18] = 10; // x offset in 192 pixels
      r[i * 18 + 1] = -6;
      r[i * 18 + 2] = 48; // width
      r[i * 18 + 3] = 60; // height
      final PalmDetection d = decodePalm(
        regressors: r,
        scores: s,
        anchors: anchors,
      )!;
      expect(d.cx, closeTo(anchors.x[i] + 10 / 192, 1e-6));
      expect(d.cy, closeTo(anchors.y[i] - 6 / 192, 1e-6));
      expect(d.w, closeTo(48 / 192, 1e-6));
      expect(d.h, closeTo(60 / 192, 1e-6));
      expect(d.score, greaterThan(0.99));
      expect(d.keypoints, hasLength(7));
    });

    test('overlapping candidates are merged, not counted as two hands', () {
      final Float32List r = regressors();
      final Float32List s = scores();
      for (final int i in <int>[1200, 1201]) {
        s[i] = 4;
        r[i * 18 + 2] = 48;
        r[i * 18 + 3] = 48;
      }
      final PalmDetection? d = decodePalm(
        regressors: r,
        scores: s,
        anchors: PalmAnchors(),
      );
      expect(d, isNotNull);
      expect(d!.w, closeTo(48 / 192, 1e-6));
    });
  });

  group('the detector\'s square', () {
    test('a tall frame is padded at the sides, and points map both ways', () {
      final Letterbox lb = Letterbox(720, 1280);
      expect(lb.scale, closeTo(0.15, 1e-9));
      expect(lb.padX, closeTo(42, 1e-9));
      expect(lb.padY, closeTo(0, 1e-9));
      final Pt there = lb.fromFrame(360, 640);
      expect(there.x, closeTo(0.5, 1e-9));
      expect(there.y, closeTo(0.5, 1e-9));
      final Pt back = lb.toFrame(lb.fromFrame(100, 900));
      expect(back.x, closeTo(100, 1e-6));
      expect(back.y, closeTo(900, 1e-6));
    });

    test('a palm detection becomes a region that turns upright', () {
      final Letterbox lb = Letterbox(720, 1280);
      // Wrist below, middle knuckle above: the hand is upright, so no turn.
      final PalmDetection d = PalmDetection(
        score: 0.9,
        cx: 0.5,
        cy: 0.5,
        w: 0.3,
        h: 0.3,
        keypoints: <Pt>[
          const Pt(0.5, 0.7),
          const Pt(0.4, 0.4),
          const Pt(0.5, 0.35),
          const Pt(0.6, 0.4),
          const Pt(0.65, 0.45),
          const Pt(0.35, 0.55),
          const Pt(0.3, 0.5),
        ],
      );
      final RoiRect roi = roiFromPalm(d, lb);
      expect(roi.rotation.abs(), lessThan(0.05));
      expect(roi.width, greaterThan(d.w * 192 / lb.scale));
      // Shifted up the hand, toward the fingers.
      expect(roi.cy, lessThan(lb.toFrame(const Pt(0.5, 0.5)).y));
    });
  });
}
