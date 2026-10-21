import 'ot_font.dart';
import 'ot_layout.dart';

// A Devanagari shaping engine, written for the PDF export.
//
// Dart's PDF writer places one glyph per character and knows nothing of
// conjuncts, reph, or the pre-base vowel sign, so Hindi set that way comes out
// as a row of separate letters with the i-matra on the wrong side. This is the
// missing step: it follows the OpenType "dev2" model (syllable clusters,
// reordering, the basic-forms and presentation-forms feature stages, then
// positioning) and runs the font's own GSUB and GPOS lookups. It is checked,
// glyph for glyph, against HarfBuzz in test/kundli_pdf/shaping_test.dart.

// Syllable categories.
const int _cX = 0; // anything that stands alone
const int _cC = 1; // consonant
const int _cV = 2; // independent vowel
const int _cN = 3; // nukta
const int _cH = 4; // virama
const int _cM = 5; // dependent vowel sign
const int _cSM = 6; // anusvara, chandrabindu, visarga
const int _cA = 7; // accent
const int _cP = 8; // placeholder (no-break space)
const int _cO = 9; // dotted circle
const int _cRa = 10; // the consonant ra

// Positions, in the order the syllable is sorted into. The numbers are the
// order itself (5 to 7, 10 and 12 are positions other scripts use and
// Devanagari does not).
const int _pStart = 0;
const int _pRaToBecomeReph = 1;
const int _pPreM = 2;
const int _pPreC = 3;
const int _pBaseC = 4;
const int _pBelowC = 8;
const int _pAfterSub = 9;
const int _pPostC = 11;
const int _pFinalC = 13;
const int _pSmvd = 14;

// Feature masks.
const int _mGlobal = 1;
const int _mRphf = 2;
const int _mPref = 4;
const int _mBlwf = 8;
const int _mAbvf = 16;
const int _mHalf = 32;
const int _mPstf = 64;

/// The category and (for dependent vowels) the side a code point sits on.
(int, int) _classify(int cp) {
  if (cp == 0x00A0) return (_cP, _pBaseC);
  if (cp == 0x25CC) return (_cO, _pBaseC);
  if (cp < 0x0900 || cp > 0x097F) return (_cX, _pStart);
  if (cp <= 0x0903) return (_cSM, _pSmvd);
  if (cp >= 0x0904 && cp <= 0x0914) return (_cV, _pBaseC);
  if (cp == 0x0930) return (_cRa, _pBaseC);
  if (cp >= 0x0915 && cp <= 0x0939) return (_cC, _pBaseC);
  if (cp == 0x093A || cp == 0x093B) return (_cM, _pAfterSub);
  if (cp == 0x093C) return (_cN, _pStart);
  if (cp == 0x093D) return (_cX, _pStart);
  if (cp == 0x093F || cp == 0x094E) return (_cM, _pPreM);
  if (cp >= 0x093E && cp <= 0x094C) return (_cM, _pAfterSub);
  if (cp == 0x094D) return (_cH, _pStart);
  if (cp == 0x094F) return (_cM, _pAfterSub);
  if (cp >= 0x0951 && cp <= 0x0954) return (_cA, _pSmvd);
  if (cp == 0x0955 || cp == 0x0956 || cp == 0x0957) return (_cM, _pAfterSub);
  if (cp >= 0x0958 && cp <= 0x095F) return (_cC, _pBaseC);
  if (cp == 0x0960 || cp == 0x0961) return (_cV, _pBaseC);
  if (cp == 0x0962 || cp == 0x0963) return (_cM, _pAfterSub);
  if (cp >= 0x0972 && cp <= 0x0977) return (_cV, _pBaseC);
  if (cp >= 0x0978 && cp <= 0x097F) return (_cC, _pBaseC);
  return (_cX, _pStart);
}

bool _isConsonant(ShapedGlyph g) =>
    g.category == _cC ||
    g.category == _cRa ||
    g.category == _cV ||
    g.category == _cP ||
    g.category == _cO;

/// True for a code point the Devanagari shaper owns.
bool isDevanagariCode(int cp) =>
    (cp >= 0x0900 && cp <= 0x097F) || cp == 0x200C || cp == 0x200D;

class GlyphPlacement {
  const GlyphPlacement(this.gid, this.dx, this.dy);
  final int gid;

  /// Offset of the glyph's origin from the start of its cluster, in font units.
  final int dx;
  final int dy;
}

/// One syllable (or one stray character) after shaping: the glyphs in drawing
/// order with their offsets, and how far the pen moves after it.
class ShapedCluster {
  const ShapedCluster(this.text, this.glyphs, this.advance);
  final String text;
  final List<GlyphPlacement> glyphs;
  final int advance;

  bool get isSimple =>
      glyphs.length == 1 && glyphs.first.dx == 0 && glyphs.first.dy == 0;
}

class DevanagariShaper {
  DevanagariShaper(this.font, {this.language = 'HIN'}) {
    final LayoutTable? gsub = font.gsub;
    final LayoutTable? gpos = font.gpos;
    final String script = (gsub?.hasScript('dev2') ?? false) ? 'dev2' : 'deva';
    if (gsub != null) {
      _gsub = LayoutEngine(font.gdef, gsub);
      _features = gsub.featureLookups(script, language: language);
    }
    if (gpos != null) {
      _gpos = LayoutEngine(font.gdef, gpos);
      _posFeatures = gpos.featureLookups(script, language: language);
    }
    _viramaGid = font.cmap[0x094D] ?? 0;
  }

  final OtFont font;
  final String language;

  LayoutEngine? _gsub;
  LayoutEngine? _gpos;
  Map<String, List<int>> _features = <String, List<int>>{};
  Map<String, List<int>> _posFeatures = <String, List<int>>{};
  late final int _viramaGid;

  final Map<String, List<ShapedCluster>> _cache =
      <String, List<ShapedCluster>>{};

  /// Debug hook: called after each stage with the glyph run.
  void Function(String stage, List<ShapedGlyph> glyphs)? trace;

  /// For each syllable of the run being shaped, the code points it covers.
  List<(int, int)> _spans = <(int, int)>[];

  // -------------------------------------------------------------------------
  // Public
  // -------------------------------------------------------------------------

  /// Shapes a run of Devanagari text into clusters.
  List<ShapedCluster> shape(String text) {
    final List<ShapedCluster>? hit = _cache[text];
    if (hit != null) return hit;
    final List<ShapedCluster> out = _shape(text);
    if (_cache.length > 20000) _cache.clear();
    _cache[text] = out;
    return out;
  }

  // -------------------------------------------------------------------------
  // Normalisation
  // -------------------------------------------------------------------------

  List<int> _normalise(String text) {
    final List<int> raw = <int>[];
    for (final int r in text.runes) {
      // The joiners only ask for a particular conjunct form; the printed text
      // never needs them, so they are dropped.
      if (r == 0x200C || r == 0x200D) continue;
      raw.add(r);
    }
    final List<int> out = <int>[];
    for (int i = 0; i < raw.length; i++) {
      final int c = raw[i];
      // Consonant + nukta written as one code point: decompose, then put the
      // three that Unicode composes back together if the font has the glyph.
      switch (c) {
        case 0x0958:
        case 0x0959:
        case 0x095A:
        case 0x095B:
        case 0x095C:
        case 0x095D:
        case 0x095E:
        case 0x095F:
          const List<int> base = <int>[
            0x0915,
            0x0916,
            0x0917,
            0x091C,
            0x0921,
            0x0922,
            0x092B,
            0x092F,
          ];
          out.add(base[c - 0x0958]);
          out.add(0x093C);
        case 0x0929:
          out.add(0x0928);
          out.add(0x093C);
        case 0x0931:
          out.add(0x0930);
          out.add(0x093C);
        case 0x0934:
          out.add(0x0933);
          out.add(0x093C);
        default:
          out.add(c);
      }
    }
    // Recompose n+nukta, r+nukta, l+nukta when the font draws them as letters.
    final List<int> composed = <int>[];
    for (int i = 0; i < out.length; i++) {
      final int c = out[i];
      if (i + 1 < out.length && out[i + 1] == 0x093C) {
        final int? whole = switch (c) {
          0x0928 => 0x0929,
          0x0930 => 0x0931,
          0x0933 => 0x0934,
          _ => null,
        };
        if (whole != null && font.hasGlyphFor(whole)) {
          composed.add(whole);
          i++;
          continue;
        }
      }
      composed.add(c);
    }
    return composed;
  }

  // -------------------------------------------------------------------------
  // The pipeline
  // -------------------------------------------------------------------------

  List<ShapedCluster> _shape(String text) {
    final List<int> cps = _normalise(text);
    if (cps.isEmpty) return const <ShapedCluster>[];

    final List<ShapedGlyph> buf = <ShapedGlyph>[];
    for (int i = 0; i < cps.length; i++) {
      final int cp = cps[i];
      final ShapedGlyph g = ShapedGlyph(font.cmap[cp] ?? 0, i);
      final (int, int) cls = _classify(cp);
      g.category = cls.$1;
      g.position = cls.$2;
      buf.add(g);
    }

    _segment(buf);
    trace?.call('segmented', buf);

    // Stage 0: locl and ccmp, before anything is reordered.
    _runFeatures(buf, <String>['locl', 'ccmp'], _mGlobal);
    trace?.call('locl', buf);

    _initialReordering(buf);
    trace?.call('initial', buf);

    // The basic forms, one feature at a time.
    for (final (String, int) f in <(String, int)>[
      ('nukt', _mGlobal),
      ('akhn', _mGlobal),
      ('rphf', _mRphf),
      ('rkrf', _mGlobal),
      ('pref', _mPref),
      ('blwf', _mBlwf),
      ('abvf', _mAbvf),
      ('half', _mHalf),
      ('pstf', _mPstf),
      ('vatu', _mGlobal),
      ('cjct', _mGlobal),
    ]) {
      _runFeatures(buf, <String>[f.$1], f.$2);
      trace?.call(f.$1, buf);
    }

    _finalReordering(buf);
    trace?.call('final', buf);

    // Presentation forms, all together.
    _runFeatures(buf, <String>[
      'pres',
      'abvs',
      'blws',
      'psts',
      'haln',
      'calt',
      'clig',
    ], _mGlobal);
    _runFeatures(buf, <String>['rlig', 'liga', 'rclt'], _mGlobal);

    _position(buf);
    return _clusters(buf, cps);
  }

  void _runFeatures(List<ShapedGlyph> buf, List<String> tags, int mask) {
    final LayoutEngine? engine = _gsub;
    if (engine == null) return;
    final Set<int> lookups = <int>{};
    for (final String t in tags) {
      final List<int>? l = _features[t];
      if (l != null) lookups.addAll(l);
    }
    final List<int> sorted = lookups.toList()..sort();
    for (final int idx in sorted) {
      engine.run(buf, idx, mask);
    }
  }

  bool _wouldFeature(String tag, List<int> gids) {
    final LayoutEngine? engine = _gsub;
    final List<int>? lookups = _features[tag];
    if (engine == null || lookups == null) return false;
    for (final int l in lookups) {
      if (engine.wouldSubstitute(l, gids)) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Syllables
  // -------------------------------------------------------------------------

  static const String _cons = '[CR]';
  static const String _tail = '(?:SS?)?A*';
  static final RegExp _consonantSyllable = RegExp(
    '$_cons'
    'N{0,2}'
    '(?:H$_cons'
    'N{0,2})*'
    '(?:H|(?:MN?H?){0,4})'
    '$_tail',
  );
  static final RegExp _vowelSyllable = RegExp(
    '(?:RH)?VN{0,2}'
    '(?:H$_cons'
    'N{0,2})*'
    '(?:H|(?:MN?H?){0,4})'
    '$_tail',
  );
  static final RegExp _standalone = RegExp(
    '(?:(?:RH)?[PO])N{0,2}'
    '(?:H$_cons'
    'N{0,2})*'
    '(?:H|(?:MN?H?){0,4})'
    '$_tail',
  );
  static final RegExp _broken = RegExp(
    '(?:RH)?N{0,2}'
    '(?:H$_cons'
    'N{0,2})*'
    '(?:H|(?:MN?H?){0,4})'
    '$_tail',
  );

  static const String _letters = 'XCVNHMSAPOR';

  /// Splits the run into syllables and numbers them in each glyph.
  void _segment(List<ShapedGlyph> buf) {
    final String cats = String.fromCharCodes(<int>[
      for (final ShapedGlyph g in buf) _letters.codeUnitAt(g.category),
    ]);
    int i = 0;
    int id = 0;
    _spans = <(int, int)>[];
    while (i < cats.length) {
      int len = 0;
      for (final RegExp re in <RegExp>[
        _vowelSyllable,
        _consonantSyllable,
        _standalone,
        _broken,
      ]) {
        final Match? m = re.matchAsPrefix(cats, i);
        if (m != null && m.end > i) {
          // The pattern is anchored with ^ for the prefix match.
          len = m.end - i;
          break;
        }
      }
      if (len == 0) len = 1;
      for (int k = i; k < i + len; k++) {
        buf[k].syllable = id;
      }
      _spans.add((i, i + len));
      id++;
      i += len;
    }
  }

  /// Contiguous ranges of glyphs that share a syllable id.
  List<(int, int)> _ranges(List<ShapedGlyph> buf) {
    final List<(int, int)> out = <(int, int)>[];
    int s = 0;
    for (int i = 1; i <= buf.length; i++) {
      if (i == buf.length || buf[i].syllable != buf[s].syllable) {
        out.add((s, i));
        s = i;
      }
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Initial reordering
  // -------------------------------------------------------------------------

  int _consonantPosition(int gid) {
    final int v = _viramaGid;
    if (_wouldFeature('blwf', <int>[v, gid]) ||
        _wouldFeature('blwf', <int>[gid, v])) {
      return _pBelowC;
    }
    if (_wouldFeature('pstf', <int>[v, gid]) ||
        _wouldFeature('pstf', <int>[gid, v])) {
      return _pPostC;
    }
    if (_wouldFeature('pref', <int>[v, gid]) ||
        _wouldFeature('pref', <int>[gid, v])) {
      return _pPostC;
    }
    return _pBaseC;
  }

  void _initialReordering(List<ShapedGlyph> buf) {
    // Consonants find out whether the font has a below- or post-base form.
    for (final ShapedGlyph g in buf) {
      if (g.position == _pBaseC && _isConsonant(g)) {
        g.position = _consonantPosition(g.gid);
      }
    }
    // Reordering moves glyphs about, so work from a fresh range list for each
    // syllable, left to right.
    final List<(int, int)> ranges = _ranges(buf);
    for (final (int, int) r in ranges) {
      final ShapedGlyph first = buf[r.$1];
      if (first.category == _cX) continue;
      _reorderSyllable(buf, r.$1, r.$2);
    }
  }

  void _reorderSyllable(List<ShapedGlyph> b, int start, int end) {
    int base = end;
    bool hasReph = false;
    int limit = start;

    if (start + 3 <= end &&
        b[start].category == _cRa &&
        b[start + 1].category == _cH) {
      if (_wouldFeature('rphf', <int>[b[start].gid, b[start + 1].gid])) {
        limit += 2;
        base = start;
        hasReph = true;
      }
    }

    {
      bool seenBelow = false;
      int i = end;
      do {
        i--;
        if (_isConsonant(b[i])) {
          if (b[i].position != _pBelowC &&
              (b[i].position != _pPostC || seenBelow)) {
            base = i;
            break;
          }
          if (b[i].position == _pBelowC) seenBelow = true;
          base = i;
        }
      } while (i > limit);
    }

    if (hasReph && base == start && limit - base <= 2) hasReph = false;

    // Everything before the base is at most "pre-base".
    for (int i = start; i < base; i++) {
      if (b[i].position > _pPreC) b[i].position = _pPreC;
    }
    if (base < end) b[base].position = _pBaseC;

    // A consonant after a vowel sign is a final consonant.
    for (int i = base + 1; i < end; i++) {
      if (b[i].category == _cM) {
        for (int j = i + 1; j < end; j++) {
          if (_isConsonant(b[j])) {
            b[j].position = _pFinalC;
            break;
          }
        }
        break;
      }
    }

    if (hasReph) b[start].position = _pRaToBecomeReph;

    // Nuktas and viramas travel with the letter before them.
    {
      int lastPos = _pStart;
      for (int i = start; i < end; i++) {
        final int cat = b[i].category;
        if (cat == _cN || cat == _cH) {
          b[i].position = lastPos;
          if (cat == _cH && b[i].position == _pPreM) {
            for (int j = i; j > start; j--) {
              if (b[j - 1].position != _pPreM) {
                b[i].position = b[j - 1].position;
                break;
              }
            }
          }
        } else if (b[i].position != _pSmvd) {
          lastPos = b[i].position;
        }
      }
    }

    // Post-base consonants own whatever stands between them and the last
    // consonant or vowel sign.
    {
      int last = base;
      for (int i = base + 1; i < end; i++) {
        if (_isConsonant(b[i])) {
          for (int j = last + 1; j < i; j++) {
            if (b[j].position < _pSmvd) b[j].position = b[i].position;
          }
          last = i;
        } else if (b[i].category == _cM) {
          last = i;
        }
      }
    }

    // Stable sort by position.
    final List<MapEntry<int, ShapedGlyph>> keyed = <MapEntry<int, ShapedGlyph>>[
      for (int i = start; i < end; i++) MapEntry<int, ShapedGlyph>(i, b[i]),
    ];
    keyed.sort((MapEntry<int, ShapedGlyph> x, MapEntry<int, ShapedGlyph> y) {
      final int c = x.value.position.compareTo(y.value.position);
      return c != 0 ? c : x.key.compareTo(y.key);
    });
    for (int i = 0; i < keyed.length; i++) {
      b[start + i] = keyed[i].value;
    }

    base = end;
    for (int i = start; i < end; i++) {
      if (b[i].position == _pBaseC) {
        base = i;
        break;
      }
    }

    // Feature masks.
    for (int i = start; i < end && b[i].position == _pRaToBecomeReph; i++) {
      b[i].mask |= _mRphf;
    }
    for (int i = start; i < base; i++) {
      b[i].mask |= _mHalf | _mBlwf;
    }
    for (int i = base + 1; i < end; i++) {
      b[i].mask |= _mBlwf | _mAbvf | _mPstf;
    }
    if (base + 2 < end) {
      for (int i = base + 1; i + 1 < end; i++) {
        if (_wouldFeature('pref', <int>[b[i].gid, b[i + 1].gid])) {
          b[i].mask |= _mPref;
          b[i + 1].mask |= _mPref;
          break;
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Final reordering
  // -------------------------------------------------------------------------

  bool _isHalant(ShapedGlyph g) => g.category == _cH && !g.ligated;

  void _finalReordering(List<ShapedGlyph> buf) {
    for (final (int, int) r in _ranges(buf)) {
      if (buf[r.$1].category == _cX) continue;
      _finalReorderSyllable(buf, r.$1, r.$2);
    }
  }

  void _finalReorderSyllable(List<ShapedGlyph> b, int start, int end) {
    int base;
    for (base = start; base < end; base++) {
      if (b[base].position >= _pBaseC) break;
    }
    if (base < end) {
      while (start < base &&
          (b[base].category == _cN || b[base].category == _cH)) {
        base--;
      }
    }

    // The vowel sign that goes before the letter moves to just before the
    // base (or before the last conjunct still joined by a visible virama).
    if (start + 1 < end && start < base) {
      int newPos = base == end ? base - 2 : base - 1;
      while (newPos > start &&
          !(b[newPos].category == _cM || b[newPos].category == _cH)) {
        newPos--;
      }
      if (b[newPos].category == _cH && b[newPos].position != _pPreM) {
        if (newPos + 1 < end) newPos++;
      } else {
        newPos = start;
      }
      if (start < newPos && b[newPos].position != _pPreM) {
        for (int i = newPos; i > start; i--) {
          if (b[i - 1].position == _pPreM) {
            final int oldPos = i - 1;
            if (oldPos < base && base <= newPos) base--;
            final ShapedGlyph tmp = b[oldPos];
            for (int k = oldPos; k < newPos; k++) {
              b[k] = b[k + 1];
            }
            b[newPos] = tmp;
            newPos--;
          }
        }
      }
    }

    // Reph goes after the base and its signs.
    if (start + 1 < end &&
        b[start].position == _pRaToBecomeReph &&
        (b[start].ligated && !b[start].multiplied)) {
      int newReph = start + 1;
      bool found = false;
      while (newReph < base && !_isHalant(b[newReph])) {
        newReph++;
      }
      if (newReph < base && _isHalant(b[newReph])) {
        found = true;
      }
      if (!found) {
        newReph = end - 1;
        while (newReph > start && b[newReph].position == _pSmvd) {
          newReph--;
        }
        if (_isHalant(b[newReph])) {
          for (int i = base + 1; i < newReph; i++) {
            if (b[i].category == _cM) newReph--;
          }
        }
      }
      final ShapedGlyph reph = b[start];
      for (int k = start; k < newReph; k++) {
        b[k] = b[k + 1];
      }
      b[newReph] = reph;
    }
  }

  // -------------------------------------------------------------------------
  // Positioning
  // -------------------------------------------------------------------------

  void _position(List<ShapedGlyph> buf) {
    for (final ShapedGlyph g in buf) {
      g.xAdvance = font.advance(g.gid);
      g.xOffset = 0;
      g.yOffset = 0;
      g.yAdvance = 0;
      g.attachChain = 0;
    }
    final LayoutEngine? engine = _gpos;
    if (engine != null) {
      final Set<int> lookups = <int>{};
      for (final String t in <String>[
        'dist',
        'abvm',
        'blwm',
        'kern',
        'mark',
        'mkmk',
      ]) {
        final List<int>? l = _posFeatures[t];
        if (l != null) lookups.addAll(l);
      }
      final List<int> sorted = lookups.toList()..sort();
      for (final int idx in sorted) {
        engine.run(buf, idx, _mGlobal);
      }
      LayoutEngine.propagateAttachments(buf);
    }
  }

  // -------------------------------------------------------------------------
  // Clusters
  // -------------------------------------------------------------------------

  List<ShapedCluster> _clusters(List<ShapedGlyph> buf, List<int> cps) {
    final List<ShapedCluster> out = <ShapedCluster>[];
    for (final (int, int) r in _ranges(buf)) {
      final (int, int) span = _spans[buf[r.$1].syllable];
      final String text = String.fromCharCodes(cps.sublist(span.$1, span.$2));
      int pen = 0;
      final List<GlyphPlacement> glyphs = <GlyphPlacement>[];
      for (int i = r.$1; i < r.$2; i++) {
        final ShapedGlyph g = buf[i];
        glyphs.add(GlyphPlacement(g.gid, pen + g.xOffset, g.yOffset));
        pen += g.xAdvance;
      }
      out.add(ShapedCluster(text, glyphs, pen));
    }
    return out;
  }
}
