import 'dart:typed_data';

import 'ot_layout.dart';

/// A TrueType-flavoured OpenType font, read just far enough to shape
/// Devanagari with its own GSUB and GPOS tables and to embed it in a PDF.
///
/// Nothing here depends on dart:io or dart:ui, so it runs unchanged on the
/// phone, in the browser and in the test VM.
class OtFont {
  OtFont(this.bytes) : data = ByteData.sublistView(bytes) {
    _readDirectory();
    _readHead();
    _readHhea();
    _readMaxp();
    _readHmtx();
    _readLoca();
    _readCmap();
    _readName();
    gdef = _table('GDEF') == null ? null : Gdef.parse(data, _table('GDEF')!.$1);
    gsub = _table('GSUB') == null
        ? null
        : LayoutTable.parse(data, _table('GSUB')!.$1, isGsub: true);
    gpos = _table('GPOS') == null
        ? null
        : LayoutTable.parse(data, _table('GPOS')!.$1, isGsub: false);
  }

  final Uint8List bytes;
  final ByteData data;

  final Map<String, (int, int)> _tables = <String, (int, int)>{};

  late final int unitsPerEm;
  late final int indexToLocFormat;
  late final int xMin, yMin, xMax, yMax;
  late final int ascender, descender, lineGap;
  late final int numGlyphs;
  late final int _numHMetrics;
  late final List<int> _advances;
  late final List<int> _lsb;
  late final List<int> _loca;
  final Map<int, int> cmap = <int, int>{};
  String postScriptName = 'Font';
  String familyName = 'Font';

  Gdef? gdef;
  LayoutTable? gsub;
  LayoutTable? gpos;

  (int, int)? _table(String tag) => _tables[tag];

  bool hasTable(String tag) => _tables.containsKey(tag);

  Uint8List tableBytes(String tag) {
    final (int, int)? t = _tables[tag];
    if (t == null) return Uint8List(0);
    return Uint8List.sublistView(bytes, t.$1, t.$1 + t.$2);
  }

  void _readDirectory() {
    final int count = data.getUint16(4);
    for (int i = 0; i < count; i++) {
      final int at = 12 + i * 16;
      final String tag = String.fromCharCodes(bytes.sublist(at, at + 4));
      _tables[tag] = (data.getUint32(at + 8), data.getUint32(at + 12));
    }
  }

  void _readHead() {
    final int o = _table('head')!.$1;
    unitsPerEm = data.getUint16(o + 18);
    xMin = data.getInt16(o + 36);
    yMin = data.getInt16(o + 38);
    xMax = data.getInt16(o + 40);
    yMax = data.getInt16(o + 42);
    indexToLocFormat = data.getInt16(o + 50);
  }

  void _readHhea() {
    final int o = _table('hhea')!.$1;
    ascender = data.getInt16(o + 4);
    descender = data.getInt16(o + 6);
    lineGap = data.getInt16(o + 8);
    _numHMetrics = data.getUint16(o + 34);
  }

  void _readMaxp() {
    numGlyphs = data.getUint16(_table('maxp')!.$1 + 4);
  }

  void _readHmtx() {
    final int o = _table('hmtx')!.$1;
    _advances = List<int>.filled(numGlyphs, 0);
    _lsb = List<int>.filled(numGlyphs, 0);
    int last = 0;
    for (int g = 0; g < numGlyphs; g++) {
      if (g < _numHMetrics) {
        last = data.getUint16(o + g * 4);
        _advances[g] = last;
        _lsb[g] = data.getInt16(o + g * 4 + 2);
      } else {
        _advances[g] = last;
        _lsb[g] = data.getInt16(o + _numHMetrics * 4 + (g - _numHMetrics) * 2);
      }
    }
  }

  void _readLoca() {
    final int o = _table('loca')!.$1;
    _loca = List<int>.filled(numGlyphs + 1, 0);
    for (int i = 0; i <= numGlyphs; i++) {
      _loca[i] = indexToLocFormat == 0
          ? data.getUint16(o + i * 2) * 2
          : data.getUint32(o + i * 4);
    }
  }

  void _readCmap() {
    final int o = _table('cmap')!.$1;
    final int n = data.getUint16(o + 2);
    int? best;
    int bestScore = -1;
    for (int i = 0; i < n; i++) {
      final int platform = data.getUint16(o + 4 + i * 8);
      final int encoding = data.getUint16(o + 6 + i * 8);
      final int offset = data.getUint32(o + 8 + i * 8);
      final int format = data.getUint16(o + offset);
      int score = -1;
      if (platform == 3 && encoding == 10 && format == 12) score = 4;
      if (platform == 0 && format == 12) score = 3;
      if (platform == 3 && encoding == 1 && format == 4) score = 2;
      if (platform == 0 && format == 4) score = 1;
      if (score > bestScore) {
        bestScore = score;
        best = o + offset;
      }
    }
    if (best == null) return;
    final int format = data.getUint16(best);
    if (format == 4) {
      final int segX2 = data.getUint16(best + 6);
      final int seg = segX2 ~/ 2;
      final int endCodes = best + 14;
      final int startCodes = endCodes + segX2 + 2;
      final int deltas = startCodes + segX2;
      final int rangeOffsets = deltas + segX2;
      for (int s = 0; s < seg; s++) {
        final int end = data.getUint16(endCodes + s * 2);
        final int start = data.getUint16(startCodes + s * 2);
        final int delta = data.getInt16(deltas + s * 2);
        final int rangeOffset = data.getUint16(rangeOffsets + s * 2);
        if (start == 0xFFFF) continue;
        for (int c = start; c <= end; c++) {
          int g;
          if (rangeOffset == 0) {
            g = (c + delta) & 0xFFFF;
          } else {
            final int at = rangeOffsets + s * 2 + rangeOffset + (c - start) * 2;
            if (at + 2 > bytes.length) continue;
            g = data.getUint16(at);
            if (g != 0) g = (g + delta) & 0xFFFF;
          }
          if (g != 0) cmap[c] = g;
        }
      }
    } else if (format == 12) {
      final int groups = data.getUint32(best + 12);
      for (int i = 0; i < groups; i++) {
        final int at = best + 16 + i * 12;
        final int start = data.getUint32(at);
        final int end = data.getUint32(at + 4);
        final int g0 = data.getUint32(at + 8);
        for (int c = start; c <= end; c++) {
          cmap[c] = g0 + (c - start);
        }
      }
    }
  }

  void _readName() {
    final (int, int)? t = _table('name');
    if (t == null) return;
    final int o = t.$1;
    final int count = data.getUint16(o + 2);
    final int strings = o + data.getUint16(o + 4);
    String? family;
    String? ps;
    for (int i = 0; i < count; i++) {
      final int at = o + 6 + i * 12;
      final int platform = data.getUint16(at);
      final int nameId = data.getUint16(at + 6);
      final int length = data.getUint16(at + 8);
      final int offset = data.getUint16(at + 10);
      if (nameId != 1 && nameId != 6) continue;
      String text;
      if (platform == 3 || platform == 0) {
        final StringBuffer b = StringBuffer();
        for (int k = 0; k < length; k += 2) {
          b.writeCharCode(data.getUint16(strings + offset + k));
        }
        text = b.toString();
      } else {
        text = String.fromCharCodes(
          bytes.sublist(strings + offset, strings + offset + length),
        );
      }
      if (nameId == 1) family ??= text;
      if (nameId == 6) ps ??= text;
    }
    if (family != null) familyName = family;
    if (ps != null) {
      postScriptName = ps.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    }
  }

  /// Advance width of a glyph in font units.
  int advance(int gid) => gid < 0 || gid >= numGlyphs ? 0 : _advances[gid];

  int leftSideBearing(int gid) => _lsb[gid];

  /// The raw outline record of a glyph, empty for blank glyphs.
  Uint8List glyphData(int gid) {
    final int glyf = _table('glyf')!.$1;
    final int from = _loca[gid];
    final int to = _loca[gid + 1];
    if (to <= from) return Uint8List(0);
    return Uint8List.sublistView(bytes, glyf + from, glyf + to);
  }

  /// Glyph bounding box from its outline header, or null for a blank glyph.
  (int, int, int, int)? glyphBox(int gid) {
    final Uint8List g = glyphData(gid);
    if (g.length < 10) return null;
    final ByteData d = ByteData.sublistView(g);
    return (d.getInt16(2), d.getInt16(4), d.getInt16(6), d.getInt16(8));
  }

  bool hasGlyphFor(int codePoint) => cmap.containsKey(codePoint);
}
