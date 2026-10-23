import 'dart:math' as math;
import 'dart:typed_data';

import 'frame.dart';
import 'palm_types.dart';

/// The app's palm box, 0 to 1 across and down, the same box the hand tracer
/// draws on and the hastrekha engine reads in, laid over a real hand.
///
/// The box is thumb on the left, fingers at the top. It is anchored to the
/// wrist and the four knuckles, which sit over the Jupiter, Saturn, Sun and
/// Mercury mounts the engine places. A right palm shows its thumb on the right,
/// so its picture is mirrored into the box; the lines then read the same way
/// on either hand.
class PalmMap {
  PalmMap._(this._ax, this._ay, this.mirrored);

  /// Where the wrist and knuckles sit in the box. The mount positions are the
  /// engine's own (see mountCentres in hastrekha.dart).
  static const Map<int, (double, double)> anchors = <int, (double, double)>{
    Joint.wrist: (0.52, 0.96),
    Joint.indexMcp: (0.33, 0.23),
    Joint.middleMcp: (0.50, 0.19),
    Joint.ringMcp: (0.66, 0.21),
    Joint.pinkyMcp: (0.80, 0.27),
  };

  /// Fit with least squares: image x and y are each an affine function of the
  /// box position.
  factory PalmMap.fit(List<Pt> points, {required bool mirrored}) {
    final List<List<double>> rows = <List<double>>[];
    final List<double> bx = <double>[];
    final List<double> by = <double>[];
    anchors.forEach((int joint, (double, double) a) {
      final double u = mirrored ? 1 - a.$1 : a.$1;
      rows.add(<double>[u, a.$2, 1]);
      bx.add(points[joint].x);
      by.add(points[joint].y);
    });
    return PalmMap._(_lstsq(rows, bx), _lstsq(rows, by), mirrored);
  }

  final List<double> _ax;
  final List<double> _ay;
  final bool mirrored;

  /// Where a point of the box falls in the picture.
  Pt toImage(double u, double v) {
    final double w = mirrored ? 1 - u : u;
    return Pt(
      _ax[0] * w + _ax[1] * v + _ax[2],
      _ay[0] * w + _ay[1] * v + _ay[2],
    );
  }

  /// How many picture pixels one box width covers.
  double get pixelsPerBoxWidth => math.sqrt(_ax[0] * _ax[0] + _ay[0] * _ay[0]);
  double get pixelsPerBoxHeight => math.sqrt(_ax[1] * _ax[1] + _ay[1] * _ay[1]);

  /// A point of the picture in the box.
  Pt toBox(Pt p) {
    final double det = _ax[0] * _ay[1] - _ax[1] * _ay[0];
    final double dx = p.x - _ax[2];
    final double dy = p.y - _ay[2];
    final double w = (_ay[1] * dx - _ax[1] * dy) / det;
    final double v = (-_ay[0] * dx + _ax[0] * dy) / det;
    return Pt(mirrored ? 1 - w : w, v);
  }

  /// The picture sampled into a box [width] by [height]. Creases are read
  /// from the green channel, where skin creases show best; red and blue are
  /// kept to tell skin from background. Pixels that fall outside the picture are
  /// zero and flagged in [outside].
  BoxPatch sample(PalmFrame frame, {required int width, required int height}) {
    final Float32List g = Float32List(width * height);
    final Float32List r = Float32List(width * height);
    final Float32List b = Float32List(width * height);
    final Uint8List outside = Uint8List(width * height);
    final Float32List rgb = Float32List(3);
    for (int j = 0; j < height; j++) {
      final double v = (j + 0.5) / height;
      for (int i = 0; i < width; i++) {
        final double u = (i + 0.5) / width;
        final Pt p = toImage(u, v);
        final double fx = p.x - 0.5;
        final double fy = p.y - 0.5;
        if (fx < 0 || fy < 0 || fx > frame.width - 1 || fy > frame.height - 1) {
          outside[j * width + i] = 1;
          continue;
        }
        frame.rgbAt(fx, fy, rgb, 0);
        r[j * width + i] = rgb[0];
        g[j * width + i] = rgb[1];
        b[j * width + i] = rgb[2];
      }
    }
    return BoxPatch(width, height, g, outside, red: r, blue: b);
  }
}

class BoxPatch {
  BoxPatch(
    this.width,
    this.height,
    this.green,
    this.outside, {
    Float32List? red,
    Float32List? blue,
  }) : red = red ?? green,
       blue = blue ?? green;

  final int width;
  final int height;
  final Float32List green;

  /// The other two channels, for telling skin from what is behind the hand.
  final Float32List red;
  final Float32List blue;

  /// 1 where the box point fell outside the picture.
  final Uint8List outside;
}

List<double> _lstsq(List<List<double>> a, List<double> b) {
  // Normal equations for three unknowns.
  final List<List<double>> m = List<List<double>>.generate(
    3,
    (_) => List<double>.filled(4, 0),
  );
  for (int r = 0; r < a.length; r++) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        m[i][j] += a[r][i] * a[r][j];
      }
      m[i][3] += a[r][i] * b[r];
    }
  }
  for (int c = 0; c < 3; c++) {
    int pivot = c;
    for (int r = c + 1; r < 3; r++) {
      if (m[r][c].abs() > m[pivot][c].abs()) pivot = r;
    }
    final List<double> t = m[c];
    m[c] = m[pivot];
    m[pivot] = t;
    for (int r = 0; r < 3; r++) {
      if (r == c) continue;
      final double f = m[r][c] / m[c][c];
      for (int k = c; k < 4; k++) {
        m[r][k] -= f * m[c][k];
      }
    }
  }
  return <double>[m[0][3] / m[0][0], m[1][3] / m[1][1], m[2][3] / m[2][2]];
}
