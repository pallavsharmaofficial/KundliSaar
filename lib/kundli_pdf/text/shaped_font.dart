// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/array.dart';
import 'package:pdf/src/pdf/format/base.dart';
import 'package:pdf/src/pdf/format/dict.dart';
import 'package:pdf/src/pdf/format/num.dart';
import 'package:pdf/src/pdf/format/string.dart';
import 'package:pdf/src/pdf/obj/object.dart';
import 'package:pdf/src/pdf/obj/object_stream.dart';
import 'package:pdf/widgets.dart' as pw;

import 'devanagari_shaper.dart';
import 'ot_font.dart';
import 'subset_ttf.dart';

/// One code of the font embedded in the PDF.
class _Code {
  _Code(this.parts, this.advance, this.text);
  final List<(int, int, int)> parts;
  final int advance;
  final String text;
}

/// A font that has been read and can shape: shared by every document.
class ShapedFace {
  ShapedFace(Uint8List bytes, {this.lineAscent = 1.0, this.lineDescent = -0.42})
    : font = OtFont(bytes) {
    shaper = DevanagariShaper(font);
  }

  final OtFont font;
  late final DevanagariShaper shaper;

  /// How tall a line of this font is taken to be when text is laid out,
  /// independent of the font's own (very generous) ascent and descent.
  final double lineAscent;
  final double lineDescent;
}

/// The font as the PDF writer sees it. It draws text through the shaper:
/// every word is shaped into syllables, each syllable becomes one code of the
/// embedded font, and the codes are written as a CID-keyed TrueType font with
/// a ToUnicode map, so the text can still be searched and copied.
class ShapedPdfFont extends PdfFont {
  ShapedPdfFont(PdfDocument document, this.face)
    : super.create(document, subtype: '/Type0') {
    file = PdfObjectStream(document, isBinary: true);
    toUnicode = PdfObjectStream(document);
    widths = PdfObject<PdfArray>(document, params: PdfArray());
    descriptor = PdfObject<PdfDict>(document, params: PdfDict());
    descendant = PdfObject<PdfDict>(document, params: PdfDict());
    _codes.add(
      _Code(const <(int, int, int)>[(0, 0, 0)], face.font.advance(0), ''),
    );
  }

  final ShapedFace face;

  late final PdfObjectStream file;
  late final PdfObjectStream toUnicode;
  late final PdfObject<PdfArray> widths;
  late final PdfObject<PdfDict> descriptor;
  late final PdfObject<PdfDict> descendant;

  final List<_Code> _codes = <_Code>[];
  final Map<String, int> _byKey = <String, int>{};
  final Map<String, List<int>> _encoded = <String, List<int>>{};

  /// Code points the font has no glyph for. Tests read this.
  final Set<int> missing = <int>{};

  /// Every string that was drawn, for the checks that read what the PDF says.
  final List<String> drawn = <String>[];
  bool recordDrawn = false;

  OtFont get font => face.font;

  int _codeFor(
    String key,
    List<(int, int, int)> parts,
    int advance,
    String text,
  ) {
    final int? have = _byKey[key];
    if (have != null) return have;
    _codes.add(_Code(parts, advance, text));
    return _byKey[key] = _codes.length - 1;
  }

  /// The codes for [text], in drawing order.
  List<int> encode(String text) {
    final List<int>? hit = _encoded[text];
    if (hit != null) return hit;
    final List<int> out = <int>[];
    final StringBuffer run = StringBuffer();

    void flushRun() {
      if (run.isEmpty) return;
      for (final ShapedCluster c in face.shaper.shape(run.toString())) {
        if (c.isSimple) {
          out.add(
            _codeFor(
              'g${c.glyphs.first.gid}',
              <(int, int, int)>[(c.glyphs.first.gid, 0, 0)],
              c.advance,
              c.text,
            ),
          );
        } else {
          final String key =
              'c${c.advance}|${c.glyphs.map((GlyphPlacement g) => '${g.gid}:${g.dx}:${g.dy}').join(',')}';
          out.add(
            _codeFor(
              key,
              <(int, int, int)>[
                for (final GlyphPlacement g in c.glyphs) (g.gid, g.dx, g.dy),
              ],
              c.advance,
              c.text,
            ),
          );
        }
      }
      run.clear();
    }

    for (final int r in text.runes) {
      if (isDevanagariCode(r)) {
        run.writeCharCode(r);
        continue;
      }
      flushRun();
      if (r == 0x200B || r == 0x2060) continue;
      final int? gid = font.cmap[r] ?? font.cmap[_substitutes[r] ?? -1];
      if (gid == null) {
        missing.add(r);
        out.add(
          _codeFor(
            'g0',
            const <(int, int, int)>[(0, 0, 0)],
            font.advance(0),
            '',
          ),
        );
        continue;
      }
      out.add(
        _codeFor(
          'g$gid',
          <(int, int, int)>[(gid, 0, 0)],
          font.advance(gid),
          String.fromCharCode(r),
        ),
      );
    }
    flushRun();
    _encoded[text] = out;
    return out;
  }

  /// What stands in for a character the faces do not carry.
  static const Map<int, int> _substitutes = <int, int>{
    0x2032: 0x27, // prime -> apostrophe
    0x2033: 0x22, // double prime -> quotation mark
    0x2212: 0x2D, // minus -> hyphen
    0x2011: 0x2D, // non-breaking hyphen
    0x2010: 0x2D,
    0x2192: 0x2D, // arrow -> hyphen
  };

  double _em(int units) => units / font.unitsPerEm;

  // -- PdfFont ---------------------------------------------------------------

  @override
  String get fontName => font.postScriptName;

  @override
  double get ascent => face.lineAscent;

  @override
  double get descent => face.lineDescent;

  @override
  int get unitsPerEm => font.unitsPerEm;

  @override
  bool isRuneSupported(int charCode) => true;

  @override
  PdfFontMetrics glyphMetrics(int charCode) {
    final List<int> codes = encode(String.fromCharCode(charCode));
    if (codes.isEmpty) return PdfFontMetrics.zero;
    return _metricsOf(codes.first);
  }

  PdfFontMetrics _metricsOf(int code) {
    final _Code c = _codes[code];
    return PdfFontMetrics(
      left: 0,
      top: -0.2,
      right: _em(c.advance),
      bottom: face.lineAscent,
      ascent: face.lineAscent,
      descent: face.lineDescent,
      advanceWidth: _em(c.advance),
      leftBearing: 0,
    );
  }

  @override
  PdfFontMetrics stringMetrics(String s, {double letterSpacing = 0}) {
    if (s.isEmpty) return PdfFontMetrics.zero;
    final List<int> codes = encode(s);
    if (codes.isEmpty) return PdfFontMetrics.zero;
    return PdfFontMetrics.append(
      codes.map(_metricsOf),
      letterSpacing: letterSpacing,
    );
  }

  @override
  void putText(PdfStream stream, String text) {
    if (recordDrawn) drawn.add(text);
    final List<int> codes = encode(text);
    stream.putByte(0x3c);
    for (final int c in codes) {
      stream.putBytes(latin1.encode(c.toRadixString(16).padLeft(4, '0')));
    }
    stream.putByte(0x3e);
  }

  // -- Writing ---------------------------------------------------------------

  @override
  void prepare() {
    super.prepare();

    final Uint8List ttf = buildSubsetFont(font, <SubsetGlyph>[
      for (int i = 1; i < _codes.length; i++)
        SubsetGlyph(_codes[i].parts, _codes[i].advance),
    ]);
    file.buf.putBytes(ttf);
    file.params['/Length1'] = PdfNum(ttf.length);

    final String tag = _subsetTag();
    final String baseName = '$tag+${font.postScriptName}';

    // Widths, one per code.
    final PdfArray ws = PdfArray();
    for (final _Code c in _codes) {
      ws.add(PdfNum((c.advance * 1000.0 / font.unitsPerEm).round()));
    }
    widths.params.values.addAll(ws.values);

    descriptor.params['/Type'] = const PdfName('/FontDescriptor');
    descriptor.params['/FontName'] = PdfName('/$baseName');
    descriptor.params['/Flags'] = const PdfNum(4);
    descriptor.params['/FontBBox'] = PdfArray.fromNum(<num>[
      (font.xMin * 1000 / font.unitsPerEm).round(),
      (font.yMin * 1000 / font.unitsPerEm).round(),
      (font.xMax * 1000 / font.unitsPerEm).round(),
      (font.yMax * 1000 / font.unitsPerEm).round(),
    ]);
    descriptor.params['/ItalicAngle'] = const PdfNum(0);
    descriptor.params['/Ascent'] = PdfNum(
      (font.ascender * 1000 / font.unitsPerEm).round(),
    );
    descriptor.params['/Descent'] = PdfNum(
      (font.descender * 1000 / font.unitsPerEm).round(),
    );
    descriptor.params['/CapHeight'] = PdfNum(
      (font.ascender * 700 / font.unitsPerEm).round(),
    );
    descriptor.params['/StemV'] = const PdfNum(80);
    descriptor.params['/FontFile2'] = file.ref();

    descendant.params['/Type'] = const PdfName('/Font');
    descendant.params['/Subtype'] = const PdfName('/CIDFontType2');
    descendant.params['/BaseFont'] = PdfName('/$baseName');
    descendant.params['/CIDSystemInfo'] = PdfDict.values(<String, PdfDataType>{
      '/Registry': PdfString.fromString('Adobe'),
      '/Ordering': PdfString.fromString('Identity'),
      '/Supplement': const PdfNum(0),
    });
    descendant.params['/FontDescriptor'] = descriptor.ref();
    descendant.params['/CIDToGIDMap'] = const PdfName('/Identity');
    descendant.params['/DW'] = const PdfNum(1000);
    descendant.params['/W'] = PdfArray(<PdfDataType>[
      const PdfNum(0),
      widths.ref(),
    ]);

    params['/BaseFont'] = PdfName('/$baseName');
    params['/Encoding'] = const PdfName('/Identity-H');
    params['/DescendantFonts'] = PdfArray(<PdfDataType>[descendant.ref()]);
    params['/ToUnicode'] = toUnicode.ref();

    toUnicode.buf.putString(_toUnicodeCMap());
  }

  String _subsetTag() {
    int h = 17;
    for (final int c in font.postScriptName.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < 6; i++) {
      b.writeCharCode(0x41 + h % 26);
      h ~/= 26;
      if (h == 0) h = 7919 + i;
    }
    return b.toString();
  }

  String _hex16(String text) {
    final StringBuffer b = StringBuffer();
    for (final int u in text.codeUnits) {
      b.write(u.toRadixString(16).toUpperCase().padLeft(4, '0'));
    }
    return b.toString();
  }

  String _toUnicodeCMap() {
    final List<String> lines = <String>[];
    for (int i = 1; i < _codes.length; i++) {
      final String t = _codes[i].text;
      if (t.isEmpty) continue;
      lines.add(
        '<${i.toRadixString(16).toUpperCase().padLeft(4, '0')}> <${_hex16(t)}>',
      );
    }
    final StringBuffer b = StringBuffer()
      ..write('/CIDInit /ProcSet findresource begin\n')
      ..write('12 dict begin\n')
      ..write('begincmap\n')
      ..write(
        '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n',
      )
      ..write('/CMapName /Adobe-Identity-UCS def\n')
      ..write('/CMapType 2 def\n')
      ..write('1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n');
    for (int i = 0; i < lines.length; i += 100) {
      final List<String> chunk = lines.sublist(
        i,
        i + 100 > lines.length ? lines.length : i + 100,
      );
      b.write('${chunk.length} beginbfchar\n');
      b.write(chunk.join('\n'));
      b.write('\nendbfchar\n');
    }
    b.write('endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend');
    return b.toString();
  }
}

/// The widget-layer handle for a font: lazily becomes a [ShapedPdfFont] in
/// whichever document first draws with it.
class ShapedFont extends pw.Font {
  ShapedFont(this.face);

  final ShapedFace face;

  /// When true the fonts built from this record every string they draw.
  bool recordDrawn = false;

  final List<ShapedPdfFont> built = <ShapedPdfFont>[];

  @override
  PdfFont buildFont(PdfDocument pdfDocument) {
    final ShapedPdfFont f = ShapedPdfFont(pdfDocument, face)
      ..recordDrawn = recordDrawn;
    built.add(f);
    return f;
  }

  @override
  String get fontName => face.font.postScriptName;
}
