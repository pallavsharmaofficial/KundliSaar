import 'dart:math' as math;
import 'dart:typed_data';

import 'ot_font.dart';

/// What one code of the embedded font draws: one or more glyphs of the source
/// font, each shifted to where the shaper put it. A single unshifted glyph is
/// copied as it is; anything else becomes a TrueType composite glyph, so the
/// PDF needs no positioning operators and every viewer draws the same thing.
class SubsetGlyph {
  const SubsetGlyph(this.parts, this.advance);

  /// (source glyph id, dx, dy) in font units.
  final List<(int, int, int)> parts;
  final int advance;
}

/// Builds the TrueType file that goes into the PDF: glyph 0 is .notdef, glyph
/// n is [glyphs] `[n - 1]`, and the source glyphs that composites use follow.
/// Hinting is dropped, which is why no cvt, fpgm or prep table is written.
Uint8List buildSubsetFont(OtFont font, List<SubsetGlyph> glyphs) {
  final _Builder b = _Builder(font);
  return b.build(glyphs);
}

class _Builder {
  _Builder(this.font);

  final OtFont font;

  final List<Uint8List> _glyphData = <Uint8List>[];
  final List<int> _advances = <int>[];
  final List<int> _lsbs = <int>[];
  final Map<int, int> _componentIndex = <int, int>{};

  static int _align4(int n) => (n + 3) & ~3;

  Uint8List build(List<SubsetGlyph> glyphs) {
    // Glyph 0 and one glyph per code.
    _add(_stripped(0), font.advance(0), _lsbOf(0));
    final List<int> pendingFix = <int>[];
    for (final SubsetGlyph g in glyphs) {
      if (g.parts.length == 1 &&
          g.parts.first.$2 == 0 &&
          g.parts.first.$3 == 0) {
        final int src = g.parts.first.$1;
        final int at = _glyphData.length;
        _add(Uint8List(0), g.advance, _lsbOf(src));
        pendingFix.add(at);
        _simpleSource[at] = src;
      } else {
        final int at = _glyphData.length;
        _add(Uint8List(0), g.advance, 0);
        pendingFix.add(at);
        _compositeSource[at] = g.parts;
      }
    }
    // Now that every code has an index, fill their outlines, creating the
    // component glyphs they need after them.
    for (final int at in pendingFix) {
      final int? src = _simpleSource[at];
      if (src != null) {
        final Uint8List data = _stripped(src);
        _glyphData[at] = data;
        _lsbs[at] = _lsbOfData(data, src);
      } else {
        final List<(int, int, int)> parts = _compositeSource[at]!;
        _glyphData[at] = _composite(parts);
        _lsbs[at] = _boxOf(_glyphData[at])?.$1 ?? 0;
      }
    }
    return _write();
  }

  final Map<int, int> _simpleSource = <int, int>{};
  final Map<int, List<(int, int, int)>> _compositeSource =
      <int, List<(int, int, int)>>{};

  int _lsbOf(int gid) => font.leftSideBearing(gid);

  int _lsbOfData(Uint8List data, int gid) =>
      _boxOf(data)?.$1 ?? font.leftSideBearing(gid);

  int _add(Uint8List data, int advance, int lsb) {
    _glyphData.add(data);
    _advances.add(advance);
    _lsbs.add(lsb);
    return _glyphData.length - 1;
  }

  (int, int, int, int)? _boxOf(Uint8List data) {
    if (data.length < 10) return null;
    final ByteData d = ByteData.sublistView(data);
    return (d.getInt16(2), d.getInt16(4), d.getInt16(6), d.getInt16(8));
  }

  /// Index of source glyph [gid] as a component of another glyph.
  int _component(int gid) {
    final int? have = _componentIndex[gid];
    if (have != null) return have;
    final int at = _add(Uint8List(0), font.advance(gid), _lsbOf(gid));
    _componentIndex[gid] = at;
    _glyphData[at] = _stripped(gid);
    return at;
  }

  /// A source glyph without its hinting instructions. Composite sources have
  /// their component references re-pointed into the new glyph order.
  Uint8List _stripped(int gid) {
    final Uint8List src = font.glyphData(gid);
    if (src.length < 10) return Uint8List(0);
    final ByteData d = ByteData.sublistView(src);
    final int contours = d.getInt16(0);
    if (contours >= 0) {
      final int endPtsEnd = 10 + contours * 2;
      if (contours == 0) return Uint8List.fromList(src.sublist(0, 10));
      final int instrLen = d.getUint16(endPtsEnd);
      final int points = d.getUint16(10 + (contours - 1) * 2) + 1;
      final Uint8List rest = Uint8List.sublistView(
        src,
        endPtsEnd + 2 + instrLen,
      );
      final BytesBuilder out = BytesBuilder();
      out.add(src.sublist(0, endPtsEnd));
      out.add(<int>[0, 0]);
      out.add(rest.sublist(0, _outlineBytes(rest, points)));
      return _padded(out.toBytes());
    }
    // Composite.
    final BytesBuilder out = BytesBuilder();
    out.add(src.sublist(0, 10));
    int p = 10;
    int flags;
    do {
      flags = d.getUint16(p);
      final int comp = d.getUint16(p + 2);
      final int newIndex = _component(comp);
      int len = 4 + ((flags & 0x1) != 0 ? 4 : 2);
      if ((flags & 0x8) != 0) {
        len += 2;
      } else if ((flags & 0x40) != 0) {
        len += 4;
      } else if ((flags & 0x80) != 0) {
        len += 8;
      }
      final Uint8List piece = Uint8List.fromList(src.sublist(p, p + len));
      final ByteData pd = ByteData.sublistView(piece);
      pd.setUint16(0, flags & ~0x100);
      pd.setUint16(2, newIndex);
      out.add(piece);
      p += len;
    } while ((flags & 0x20) != 0);
    return _padded(out.toBytes());
  }

  /// How many bytes the flags and coordinates of a simple glyph take, so that
  /// the padding the source file put after them is not carried along.
  int _outlineBytes(Uint8List b, int points) {
    int p = 0;
    int xBytes = 0;
    int yBytes = 0;
    int read = 0;
    while (read < points && p < b.length) {
      final int flag = b[p++];
      int repeat = 1;
      if ((flag & 0x08) != 0 && p < b.length) repeat += b[p++];
      for (int i = 0; i < repeat && read < points; i++, read++) {
        xBytes += (flag & 0x02) != 0 ? 1 : ((flag & 0x10) != 0 ? 0 : 2);
        yBytes += (flag & 0x04) != 0 ? 1 : ((flag & 0x20) != 0 ? 0 : 2);
      }
    }
    return math.min(b.length, p + xBytes + yBytes);
  }

  Uint8List _padded(Uint8List b) {
    final int n = _align4(b.length);
    if (n == b.length) return b;
    final Uint8List r = Uint8List(n);
    r.setAll(0, b);
    return r;
  }

  /// A composite glyph made of [parts] placed at their offsets.
  Uint8List _composite(List<(int, int, int)> parts) {
    int xMin = 1 << 30, yMin = 1 << 30, xMax = -(1 << 30), yMax = -(1 << 30);
    final BytesBuilder body = BytesBuilder();
    for (int i = 0; i < parts.length; i++) {
      final (int gid, int dx, int dy) = parts[i];
      final (int, int, int, int)? box = font.glyphBox(gid);
      if (box != null) {
        xMin = math.min(xMin, box.$1 + dx);
        yMin = math.min(yMin, box.$2 + dy);
        xMax = math.max(xMax, box.$3 + dx);
        yMax = math.max(yMax, box.$4 + dy);
      }
      final int index = _component(gid);
      final bool more = i < parts.length - 1;
      // ARG_1_AND_2_ARE_WORDS | ARGS_ARE_XY_VALUES | MORE_COMPONENTS
      final int flags = 0x1 | 0x2 | (more ? 0x20 : 0);
      final ByteData piece = ByteData(8);
      piece.setUint16(0, flags);
      piece.setUint16(2, index);
      piece.setInt16(4, dx);
      piece.setInt16(6, dy);
      body.add(piece.buffer.asUint8List());
    }
    if (xMin > xMax) {
      xMin = yMin = xMax = yMax = 0;
    }
    final ByteData head = ByteData(10);
    head.setInt16(0, -1);
    head.setInt16(2, xMin);
    head.setInt16(4, yMin);
    head.setInt16(6, xMax);
    head.setInt16(8, yMax);
    final BytesBuilder out = BytesBuilder();
    out.add(head.buffer.asUint8List());
    out.add(body.toBytes());
    return _padded(out.toBytes());
  }

  // -------------------------------------------------------------------------
  // Writing the file
  // -------------------------------------------------------------------------

  Uint8List _write() {
    final int n = _glyphData.length;

    // glyf and loca (long format).
    final BytesBuilder glyf = BytesBuilder();
    final ByteData loca = ByteData((n + 1) * 4);
    int offset = 0;
    for (int i = 0; i < n; i++) {
      loca.setUint32(i * 4, offset);
      glyf.add(_glyphData[i]);
      offset += _glyphData[i].length;
    }
    loca.setUint32(n * 4, offset);

    final ByteData hmtx = ByteData(n * 4);
    for (int i = 0; i < n; i++) {
      hmtx.setUint16(i * 4, _advances[i].clamp(0, 0xFFFF));
      hmtx.setInt16(i * 4 + 2, _lsbs[i].clamp(-32768, 32767));
    }

    Uint8List copyTable(String tag) => Uint8List.fromList(font.tableBytes(tag));

    final Uint8List head = copyTable('head');
    final ByteData hd = ByteData.sublistView(head);
    hd.setUint32(8, 0);
    hd.setInt16(50, 1); // indexToLocFormat: long

    final Uint8List hhea = copyTable('hhea');
    ByteData.sublistView(hhea).setUint16(34, n);

    final Uint8List maxp = copyTable('maxp');
    final ByteData md = ByteData.sublistView(maxp);
    md.setUint16(4, n);
    if (maxp.length >= 32) {
      // Composites here can hold several marks, so lift the declared limits.
      md.setUint16(10, math.max(md.getUint16(10), 4000));
      md.setUint16(12, math.max(md.getUint16(12), 400));
      md.setUint16(28, math.max(md.getUint16(28), 16));
      md.setUint16(30, math.max(md.getUint16(30), 4));
    }

    final Uint8List post = Uint8List(32);
    ByteData.sublistView(post).setUint32(0, 0x00030000);

    final Uint8List name = Uint8List(6);

    // A one-segment cmap, since some readers insist on finding one.
    final ByteData cmap = ByteData(36);
    cmap.setUint16(0, 0);
    cmap.setUint16(2, 1);
    cmap.setUint16(4, 3);
    cmap.setUint16(6, 1);
    cmap.setUint32(8, 12);
    cmap.setUint16(12, 4);
    cmap.setUint16(14, 24);
    cmap.setUint16(16, 0);
    cmap.setUint16(18, 2); // segCountX2
    cmap.setUint16(20, 2);
    cmap.setUint16(22, 0);
    cmap.setUint16(24, 0);
    cmap.setUint16(26, 0xFFFF); // endCode
    cmap.setUint16(28, 0); // reservedPad
    cmap.setUint16(30, 0xFFFF); // startCode
    cmap.setInt16(32, 1); // idDelta
    cmap.setUint16(34, 0); // idRangeOffset

    final Map<String, Uint8List> tables = <String, Uint8List>{
      'cmap': cmap.buffer.asUint8List(),
      'glyf': glyf.toBytes(),
      'head': head,
      'hhea': hhea,
      'hmtx': hmtx.buffer.asUint8List(),
      'loca': loca.buffer.asUint8List(),
      'maxp': maxp,
      'name': name,
      'post': post,
    };
    if (font.hasTable('OS/2')) tables['OS/2'] = copyTable('OS/2');

    final List<String> tags = tables.keys.toList()..sort();
    final int count = tags.length;
    int pow2 = 1;
    int log = 0;
    while (pow2 * 2 <= count) {
      pow2 *= 2;
      log++;
    }
    final ByteData dir = ByteData(12 + count * 16);
    dir.setUint32(0, 0x00010000);
    dir.setUint16(4, count);
    dir.setUint16(6, pow2 * 16);
    dir.setUint16(8, log);
    dir.setUint16(10, count * 16 - pow2 * 16);

    int pos = 12 + count * 16;
    int headAt = 0;
    final BytesBuilder body = BytesBuilder();
    for (int i = 0; i < count; i++) {
      final String tag = tags[i];
      final Uint8List data = tables[tag]!;
      final Uint8List padded = _padded(data);
      for (int k = 0; k < 4; k++) {
        dir.setUint8(12 + i * 16 + k, tag.codeUnitAt(k));
      }
      dir.setUint32(12 + i * 16 + 4, _checksum(padded));
      dir.setUint32(12 + i * 16 + 8, pos);
      dir.setUint32(12 + i * 16 + 12, data.length);
      if (tag == 'head') headAt = pos;
      body.add(padded);
      pos += padded.length;
    }
    final BytesBuilder file = BytesBuilder();
    file.add(dir.buffer.asUint8List());
    file.add(body.toBytes());
    final Uint8List out = file.toBytes();
    final int whole = _checksum(out);
    ByteData.sublistView(
      out,
    ).setUint32(headAt + 8, (0xB1B0AFBA - whole) & 0xFFFFFFFF);
    return out;
  }

  int _checksum(Uint8List data) {
    int sum = 0;
    final ByteData d = ByteData.sublistView(data);
    for (int i = 0; i + 4 <= data.length; i += 4) {
      sum = (sum + d.getUint32(i)) & 0xFFFFFFFF;
    }
    return sum;
  }
}
