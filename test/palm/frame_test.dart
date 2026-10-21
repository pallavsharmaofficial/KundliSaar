import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/hand_tracker.dart';

/// A 4 by 2 sensor picture whose luma is its own index, so where a point lands
/// after turning is readable.
Yuv420Frame yuv(Turn turn) {
  final Uint8List y = Uint8List.fromList(<int>[10, 20, 30, 40, 50, 60, 70, 80]);
  final Uint8List chroma = Uint8List.fromList(<int>[128, 128, 128, 128]);
  return Yuv420Frame(
    y: y,
    u: chroma,
    v: chroma,
    rawWidth: 4,
    rawHeight: 2,
    yRowStride: 4,
    uvRowStride: 2,
    uvPixelStride: 1,
    turn: turn,
  );
}

int luma(PalmFrame f, int x, int y) => (f.lumaAt(x.toDouble(), y.toDouble()) * 255).round();

void main() {
  group('turning a sensor picture upright', () {
    test('not turned', () {
      final PalmFrame f = yuv(Turn.none);
      expect((f.width, f.height), (4, 2));
      expect(luma(f, 0, 0), 10);
      expect(luma(f, 3, 1), 80);
    });

    test('a quarter turn clockwise: the sensor\'s bottom-left becomes the top-left', () {
      final PalmFrame f = yuv(Turn.quarter);
      expect((f.width, f.height), (2, 4));
      expect(luma(f, 0, 0), 50);
      expect(luma(f, 1, 0), 10);
      expect(luma(f, 0, 3), 80);
      expect(luma(f, 1, 3), 40);
    });

    test('a half turn', () {
      final PalmFrame f = yuv(Turn.half);
      expect((f.width, f.height), (4, 2));
      expect(luma(f, 0, 0), 80);
      expect(luma(f, 3, 1), 10);
    });

    test('three quarters', () {
      final PalmFrame f = yuv(Turn.threeQuarters);
      expect((f.width, f.height), (2, 4));
      expect(luma(f, 0, 0), 40);
      expect(luma(f, 1, 0), 80);
      expect(luma(f, 0, 3), 10);
    });

    test('degrees are put into quarter turns, however they are written', () {
      expect(turnFromDegrees(90), Turn.quarter);
      expect(turnFromDegrees(450), Turn.quarter);
      expect(turnFromDegrees(-90), Turn.threeQuarters);
      expect(turnFromDegrees(180), Turn.half);
      expect(turnFromDegrees(0), Turn.none);
      expect(turnFromDegrees(45), Turn.none);
    });
  });

  group('colour', () {
    test('neutral chroma gives grey', () {
      final Float32List rgb = Float32List(3);
      yuv(Turn.none).rgbAt(1, 0, rgb, 0);
      expect(rgb[0], closeTo(20 / 255, 1e-3));
      expect(rgb[1], closeTo(20 / 255, 1e-3));
      expect(rgb[2], closeTo(20 / 255, 1e-3));
    });

    test('BGRA is read blue first', () {
      final Bgra8888Frame f = Bgra8888Frame(
        bytes: Uint8List.fromList(<int>[255, 0, 0, 255]), // blue pixel
        rawWidth: 1,
        rawHeight: 1,
        rowStride: 4,
      );
      final Float32List rgb = Float32List(3);
      f.rgbAt(0, 0, rgb, 0);
      expect(rgb[0], 0);
      expect(rgb[1], 0);
      expect(rgb[2], 1);
    });

    test('RGBA is read red first, and a point between pixels is blended', () {
      final RgbaFrame f = RgbaFrame(
        Uint8List.fromList(<int>[0, 0, 0, 255, 255, 255, 255, 255]),
        2,
        1,
      );
      final Float32List rgb = Float32List(3);
      f.rgbAt(0.5, 0, rgb, 0);
      expect(rgb[0], closeTo(0.5, 1e-6));
    });
  });

  test('a camera frame becomes the right kind of picture', () {
    final CameraFrame c = CameraFrame(
      format: FrameFormat.yuv420,
      width: 4,
      height: 2,
      rotationDegrees: 90,
      planes: <FramePlane>[
        FramePlane(Uint8List(8), 4),
        FramePlane(Uint8List(2), 2, 1),
        FramePlane(Uint8List(2), 2, 1),
      ],
    );
    final PalmFrame f = c.toPalmFrame();
    expect((f.width, f.height), (2, 4));
  });
}
