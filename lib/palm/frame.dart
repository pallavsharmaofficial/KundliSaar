import 'dart:math' as math;
import 'dart:typed_data';

/// A camera picture, already turned the right way up, that the hand pipeline
/// reads from.
///
/// Nothing here converts a whole frame: the models only ever want a few
/// thousand samples of it, so a frame is asked for one point at a time. That
/// keeps a cheap phone from spending its budget turning a 720p YUV buffer
/// into pixels nobody looks at.
abstract class PalmFrame {
  /// Size once upright, in pixels.
  int get width;
  int get height;

  /// Brightness, 0 to 1, at a point in pixels. Points outside the frame read
  /// as the nearest edge.
  double lumaAt(double x, double y);

  /// Writes red, green and blue, 0 to 1, to [out] at [offset].
  void rgbAt(double x, double y, Float32List out, int offset);
}

/// How many quarter turns, clockwise, take the sensor's picture to upright.
/// On a phone held upright the back camera's sensor sits at 90.
enum Turn { none, quarter, half, threeQuarters }

Turn turnFromDegrees(int degrees) {
  switch (((degrees % 360) + 360) % 360) {
    case 90:
      return Turn.quarter;
    case 180:
      return Turn.half;
    case 270:
      return Turn.threeQuarters;
    default:
      return Turn.none;
  }
}

/// Maps a point of the upright picture back to the sensor's own pixel grid.
class _Upright {
  _Upright(this.rawWidth, this.rawHeight, this.turn)
    : width = (turn == Turn.quarter || turn == Turn.threeQuarters)
          ? rawHeight
          : rawWidth,
      height = (turn == Turn.quarter || turn == Turn.threeQuarters)
          ? rawWidth
          : rawHeight;

  final int rawWidth;
  final int rawHeight;
  final Turn turn;
  final int width;
  final int height;

  /// Sensor x for an upright point, as a double so bilinear reads work.
  double rawX(double x, double y) {
    switch (turn) {
      case Turn.none:
        return x;
      case Turn.quarter:
        return y;
      case Turn.half:
        return rawWidth - 1 - x;
      case Turn.threeQuarters:
        return rawWidth - 1 - y;
    }
  }

  double rawY(double x, double y) {
    switch (turn) {
      case Turn.none:
        return y;
      case Turn.quarter:
        return rawHeight - 1 - x;
      case Turn.half:
        return rawHeight - 1 - y;
      case Turn.threeQuarters:
        return x;
    }
  }
}

double _clampTo(double v, double max) => v < 0 ? 0 : (v > max ? max : v);

/// Plain RGBA, which is what a decoded photograph and the tests give.
class RgbaFrame extends PalmFrame {
  RgbaFrame(this.bytes, this.width, this.height);

  final Uint8List bytes;
  @override
  final int width;
  @override
  final int height;

  @override
  double lumaAt(double x, double y) {
    final Float32List rgb = Float32List(3);
    rgbAt(x, y, rgb, 0);
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
  }

  @override
  void rgbAt(double x, double y, Float32List out, int offset) {
    final double fx = _clampTo(x, width - 1.0);
    final double fy = _clampTo(y, height - 1.0);
    final int x0 = fx.floor();
    final int y0 = fy.floor();
    final int x1 = math.min(x0 + 1, width - 1);
    final int y1 = math.min(y0 + 1, height - 1);
    final double tx = fx - x0;
    final double ty = fy - y0;
    for (int c = 0; c < 3; c++) {
      final double top =
          bytes[(y0 * width + x0) * 4 + c] * (1 - tx) +
          bytes[(y0 * width + x1) * 4 + c] * tx;
      final double bottom =
          bytes[(y1 * width + x0) * 4 + c] * (1 - tx) +
          bytes[(y1 * width + x1) * 4 + c] * tx;
      out[offset + c] = (top * (1 - ty) + bottom * ty) / 255.0;
    }
  }
}

/// Android's YUV_420_888: a full-size luma plane and two quarter-size chroma
/// planes that may be interleaved, which is what the pixel stride is for.
class Yuv420Frame extends PalmFrame {
  Yuv420Frame({
    required this.y,
    required this.u,
    required this.v,
    required int rawWidth,
    required int rawHeight,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    Turn turn = Turn.none,
  }) : _map = _Upright(rawWidth, rawHeight, turn);

  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final _Upright _map;

  @override
  int get width => _map.width;
  @override
  int get height => _map.height;

  double _luma(double rx, double ry) {
    final double fx = _clampTo(rx, _map.rawWidth - 1.0);
    final double fy = _clampTo(ry, _map.rawHeight - 1.0);
    final int x0 = fx.floor();
    final int y0 = fy.floor();
    final int x1 = math.min(x0 + 1, _map.rawWidth - 1);
    final int y1 = math.min(y0 + 1, _map.rawHeight - 1);
    final double tx = fx - x0;
    final double ty = fy - y0;
    final double top =
        y[y0 * yRowStride + x0] * (1 - tx) + y[y0 * yRowStride + x1] * tx;
    final double bottom =
        y[y1 * yRowStride + x0] * (1 - tx) + y[y1 * yRowStride + x1] * tx;
    return top * (1 - ty) + bottom * ty;
  }

  @override
  double lumaAt(double x, double yy) =>
      _luma(_map.rawX(x, yy), _map.rawY(x, yy)) / 255.0;

  @override
  void rgbAt(double x, double yy, Float32List out, int offset) {
    final double rx = _map.rawX(x, yy);
    final double ry = _map.rawY(x, yy);
    final double luma = _luma(rx, ry);
    final int cx = _clampTo(rx, _map.rawWidth - 1.0).toInt() >> 1;
    final int cy = _clampTo(ry, _map.rawHeight - 1.0).toInt() >> 1;
    final int index = cy * uvRowStride + cx * uvPixelStride;
    final double cb = u[index] - 128.0;
    final double cr = v[index] - 128.0;
    out[offset] = _unit((luma + 1.402 * cr) / 255.0);
    out[offset + 1] = _unit((luma - 0.344136 * cb - 0.714136 * cr) / 255.0);
    out[offset + 2] = _unit((luma + 1.772 * cb) / 255.0);
  }
}

/// iOS's BGRA8888, one interleaved plane.
class Bgra8888Frame extends PalmFrame {
  Bgra8888Frame({
    required this.bytes,
    required int rawWidth,
    required int rawHeight,
    required this.rowStride,
    Turn turn = Turn.none,
  }) : _map = _Upright(rawWidth, rawHeight, turn);

  final Uint8List bytes;
  final int rowStride;
  final _Upright _map;

  @override
  int get width => _map.width;
  @override
  int get height => _map.height;

  @override
  double lumaAt(double x, double y) {
    final Float32List rgb = Float32List(3);
    rgbAt(x, y, rgb, 0);
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
  }

  @override
  void rgbAt(double x, double y, Float32List out, int offset) {
    final double fx = _clampTo(_map.rawX(x, y), _map.rawWidth - 1.0);
    final double fy = _clampTo(_map.rawY(x, y), _map.rawHeight - 1.0);
    final int x0 = fx.floor();
    final int y0 = fy.floor();
    final int x1 = math.min(x0 + 1, _map.rawWidth - 1);
    final int y1 = math.min(y0 + 1, _map.rawHeight - 1);
    final double tx = fx - x0;
    final double ty = fy - y0;
    // Byte order in the buffer is blue, green, red, alpha.
    for (int c = 0; c < 3; c++) {
      final int channel = 2 - c;
      final double top =
          bytes[y0 * rowStride + x0 * 4 + channel] * (1 - tx) +
          bytes[y0 * rowStride + x1 * 4 + channel] * tx;
      final double bottom =
          bytes[y1 * rowStride + x0 * 4 + channel] * (1 - tx) +
          bytes[y1 * rowStride + x1 * 4 + channel] * tx;
      out[offset + c] = (top * (1 - ty) + bottom * ty) / 255.0;
    }
  }
}

double _unit(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
