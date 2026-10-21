import 'dart:typed_data';

/// OpenType Layout: the GDEF, GSUB and GPOS tables, parsed into plain Dart
/// objects, and the engine that runs their lookups over a run of glyphs.
///
/// Only what the bundled Devanagari fonts (and a reasonable neighbour of them)
/// use is implemented: single, multiple, alternate and ligature substitution,
/// the three contextual formats and their chaining forms, and extension
/// lookups; on the positioning side single and pair adjustment, mark-to-base,
/// mark-to-mark and the contextual lookups. A lookup type the engine does not
/// know is parsed as a no-op instead of aborting the run.

// ---------------------------------------------------------------------------
// Low level tables
// ---------------------------------------------------------------------------

class Coverage {
  Coverage(this._index);

  final Map<int, int> _index;

  int indexOf(int gid) => _index[gid] ?? -1;
  bool contains(int gid) => _index.containsKey(gid);
  Iterable<int> get glyphs => _index.keys;

  static Coverage parse(ByteData d, int o) {
    final int format = d.getUint16(o);
    final Map<int, int> map = <int, int>{};
    if (format == 1) {
      final int n = d.getUint16(o + 2);
      for (int i = 0; i < n; i++) {
        map[d.getUint16(o + 4 + i * 2)] = i;
      }
    } else {
      final int n = d.getUint16(o + 2);
      for (int i = 0; i < n; i++) {
        final int start = d.getUint16(o + 4 + i * 6);
        final int end = d.getUint16(o + 6 + i * 6);
        final int first = d.getUint16(o + 8 + i * 6);
        for (int g = start; g <= end; g++) {
          map[g] = first + (g - start);
        }
      }
    }
    return Coverage(map);
  }
}

class ClassDef {
  ClassDef(this._classes);

  final Map<int, int> _classes;

  int classOf(int gid) => _classes[gid] ?? 0;

  static ClassDef empty() => ClassDef(<int, int>{});

  static ClassDef parse(ByteData d, int o) {
    final int format = d.getUint16(o);
    final Map<int, int> map = <int, int>{};
    if (format == 1) {
      final int start = d.getUint16(o + 2);
      final int n = d.getUint16(o + 4);
      for (int i = 0; i < n; i++) {
        map[start + i] = d.getUint16(o + 6 + i * 2);
      }
    } else if (format == 2) {
      final int n = d.getUint16(o + 2);
      for (int i = 0; i < n; i++) {
        final int start = d.getUint16(o + 4 + i * 6);
        final int end = d.getUint16(o + 6 + i * 6);
        final int cls = d.getUint16(o + 8 + i * 6);
        for (int g = start; g <= end; g++) {
          map[g] = cls;
        }
      }
    }
    return ClassDef(map);
  }
}

/// Glyph classes from GDEF.
class Gdef {
  Gdef(this.glyphClasses, this.markAttach, this.markSets);

  final ClassDef glyphClasses;
  final ClassDef markAttach;
  final List<Coverage> markSets;

  /// 0 unclassified, 1 base, 2 ligature, 3 mark, 4 component.
  int classOf(int gid) => glyphClasses.classOf(gid);

  static Gdef parse(ByteData d, int o) {
    final int minor = d.getUint16(o + 2);
    final int classOff = d.getUint16(o + 4);
    final int attachOff = d.getUint16(o + 10);
    int setsOff = 0;
    if (minor >= 2) setsOff = d.getUint16(o + 12);
    final List<Coverage> sets = <Coverage>[];
    if (setsOff != 0) {
      final int so = o + setsOff;
      final int n = d.getUint16(so + 2);
      for (int i = 0; i < n; i++) {
        sets.add(Coverage.parse(d, so + d.getUint32(so + 4 + i * 4)));
      }
    }
    return Gdef(
      classOff == 0 ? ClassDef.empty() : ClassDef.parse(d, o + classOff),
      attachOff == 0 ? ClassDef.empty() : ClassDef.parse(d, o + attachOff),
      sets,
    );
  }
}

// ---------------------------------------------------------------------------
// Matching
// ---------------------------------------------------------------------------

abstract class Matcher {
  const Matcher();
  bool matches(int gid);
}

class GlyphMatcher extends Matcher {
  const GlyphMatcher(this.gid);
  final int gid;
  @override
  bool matches(int g) => g == gid;
}

class ClassMatcher extends Matcher {
  const ClassMatcher(this.defs, this.cls);
  final ClassDef defs;
  final int cls;
  @override
  bool matches(int g) => defs.classOf(g) == cls;
}

class CoverageMatcher extends Matcher {
  const CoverageMatcher(this.coverage);
  final Coverage coverage;
  @override
  bool matches(int g) => coverage.contains(g);
}

class LookupRecord {
  const LookupRecord(this.sequenceIndex, this.lookupIndex);
  final int sequenceIndex;
  final int lookupIndex;
}

/// One contextual rule. [input] includes the first glyph; [backtrack] is
/// nearest-first.
class ContextRule {
  const ContextRule(this.backtrack, this.input, this.lookahead, this.records);
  final List<Matcher> backtrack;
  final List<Matcher> input;
  final List<Matcher> lookahead;
  final List<LookupRecord> records;
}

// ---------------------------------------------------------------------------
// Subtables
// ---------------------------------------------------------------------------

sealed class Subtable {
  const Subtable();
}

class SingleSubst extends Subtable {
  const SingleSubst(this.map);
  final Map<int, int> map;
}

class MultipleSubst extends Subtable {
  const MultipleSubst(this.map);
  final Map<int, List<int>> map;
}

class AlternateSubst extends Subtable {
  const AlternateSubst(this.map);
  final Map<int, List<int>> map;
}

class Ligature {
  const Ligature(this.components, this.glyph);
  final List<int> components; // after the first glyph
  final int glyph;
}

class LigatureSubst extends Subtable {
  const LigatureSubst(this.map);
  final Map<int, List<Ligature>> map;
}

/// Contextual and chaining-contextual lookups of all three formats, reduced to
/// the same shape: the glyphs that may start a match, and the rules to try for
/// each of them.
class ContextSubtable extends Subtable {
  const ContextSubtable(this.firstGlyph, this.rulesFor);

  /// Whether the glyph can start a match at all.
  final bool Function(int gid) firstGlyph;

  /// The rules to try, in order, when [gid] starts a match.
  final List<ContextRule> Function(int gid) rulesFor;
}

class NoopSubtable extends Subtable {
  const NoopSubtable();
}

class ValueRecord {
  const ValueRecord(
    this.xPlacement,
    this.yPlacement,
    this.xAdvance,
    this.yAdvance,
  );
  final int xPlacement;
  final int yPlacement;
  final int xAdvance;
  final int yAdvance;
  static const ValueRecord zero = ValueRecord(0, 0, 0, 0);
  bool get isZero =>
      xPlacement == 0 && yPlacement == 0 && xAdvance == 0 && yAdvance == 0;
}

class SinglePos extends Subtable {
  const SinglePos(this.map);
  final Map<int, ValueRecord> map;
}

class PairPos extends Subtable {
  const PairPos({
    required this.coverage,
    this.pairs,
    this.classDef1,
    this.classDef2,
    this.matrix,
  });
  final Coverage coverage;

  /// Format 1: first glyph -> second glyph -> (value1, value2).
  final Map<int, Map<int, (ValueRecord, ValueRecord)>>? pairs;

  /// Format 2.
  final ClassDef? classDef1;
  final ClassDef? classDef2;
  final List<List<(ValueRecord, ValueRecord)>>? matrix;
}

class Anchor {
  const Anchor(this.x, this.y);
  final int x;
  final int y;
}

/// Mark-to-base and mark-to-mark share the same layout.
class MarkAttachPos extends Subtable {
  const MarkAttachPos({
    required this.markCoverage,
    required this.baseCoverage,
    required this.markClasses,
    required this.markAnchors,
    required this.baseAnchors,
    required this.isMarkToMark,
  });
  final Coverage markCoverage;
  final Coverage baseCoverage;
  final List<int> markClasses; // by mark coverage index
  final List<Anchor> markAnchors; // by mark coverage index
  final List<List<Anchor?>> baseAnchors; // [baseIndex][class]
  final bool isMarkToMark;
}

class Lookup {
  const Lookup(this.type, this.flag, this.markSet, this.subtables);
  final int type;
  final int flag;
  final int markSet;
  final List<Subtable> subtables;
}

// ---------------------------------------------------------------------------
// The table
// ---------------------------------------------------------------------------

class LayoutTable {
  LayoutTable._(this.isGsub, this.lookups, this._scripts, this._features);

  final bool isGsub;
  final List<Lookup> lookups;

  /// script tag -> (language tag or '' for the default) -> feature indices
  final Map<String, Map<String, List<int>>> _scripts;
  final List<(String, List<int>)> _features;

  bool hasScript(String tag) => _scripts.containsKey(tag);

  /// Lookup indices by feature tag for a script and language, merging the
  /// language system over the script's default one.
  Map<String, List<int>> featureLookups(String script, {String? language}) {
    final Map<String, List<int>>? langs = _scripts[script];
    if (langs == null) return <String, List<int>>{};
    final List<int>? indices =
        (language == null ? null : langs[language]) ?? langs[''];
    final Map<String, List<int>> out = <String, List<int>>{};
    if (indices == null) return out;
    for (final int fi in indices) {
      final (String, List<int>) f = _features[fi];
      final List<int> list = out.putIfAbsent(f.$1, () => <int>[]);
      for (final int l in f.$2) {
        if (!list.contains(l)) list.add(l);
      }
    }
    return out;
  }

  static LayoutTable parse(ByteData d, int o, {required bool isGsub}) {
    final int scriptListOff = o + d.getUint16(o + 4);
    final int featureListOff = o + d.getUint16(o + 6);
    final int lookupListOff = o + d.getUint16(o + 8);

    final Map<String, Map<String, List<int>>> scripts =
        <String, Map<String, List<int>>>{};
    final int scriptCount = d.getUint16(scriptListOff);
    for (int i = 0; i < scriptCount; i++) {
      final String tag = _tag(d, scriptListOff + 2 + i * 6);
      final int so = scriptListOff + d.getUint16(scriptListOff + 2 + i * 6 + 4);
      final Map<String, List<int>> langs = <String, List<int>>{};
      final int defaultOff = d.getUint16(so);
      List<int> readLangSys(int lo) {
        final int req = d.getUint16(lo + 2);
        final int n = d.getUint16(lo + 4);
        final List<int> out = <int>[];
        if (req != 0xFFFF) out.add(req);
        for (int k = 0; k < n; k++) {
          out.add(d.getUint16(lo + 6 + k * 2));
        }
        return out;
      }

      if (defaultOff != 0) langs[''] = readLangSys(so + defaultOff);
      final int langCount = d.getUint16(so + 2);
      for (int k = 0; k < langCount; k++) {
        final String lt = _tag(d, so + 4 + k * 6).trimRight();
        langs[lt] = readLangSys(so + d.getUint16(so + 4 + k * 6 + 4));
      }
      scripts[tag] = langs;
    }

    final List<(String, List<int>)> features = <(String, List<int>)>[];
    final int featureCount = d.getUint16(featureListOff);
    for (int i = 0; i < featureCount; i++) {
      final String tag = _tag(d, featureListOff + 2 + i * 6);
      final int fo =
          featureListOff + d.getUint16(featureListOff + 2 + i * 6 + 4);
      final int n = d.getUint16(fo + 2);
      features.add((
        tag,
        <int>[for (int k = 0; k < n; k++) d.getUint16(fo + 4 + k * 2)],
      ));
    }

    final List<Lookup> lookups = <Lookup>[];
    final int lookupCount = d.getUint16(lookupListOff);
    for (int i = 0; i < lookupCount; i++) {
      final int lo = lookupListOff + d.getUint16(lookupListOff + 2 + i * 2);
      lookups.add(_parseLookup(d, lo, isGsub));
    }
    return LayoutTable._(isGsub, lookups, scripts, features);
  }
}

String _tag(ByteData d, int o) => String.fromCharCodes(<int>[
  d.getUint8(o),
  d.getUint8(o + 1),
  d.getUint8(o + 2),
  d.getUint8(o + 3),
]);

Lookup _parseLookup(ByteData d, int o, bool isGsub) {
  int type = d.getUint16(o);
  final int flag = d.getUint16(o + 2);
  final int n = d.getUint16(o + 4);
  final List<Subtable> subs = <Subtable>[];
  int effective = type;
  for (int i = 0; i < n; i++) {
    int so = o + d.getUint16(o + 6 + i * 2);
    int t = type;
    if (isGsub ? type == 7 : type == 9) {
      t = d.getUint16(so + 2);
      so = so + d.getUint32(so + 4);
    }
    effective = t;
    subs.add(isGsub ? _parseGsub(d, so, t) : _parseGpos(d, so, t));
  }
  final int markSet = (flag & 0x10) != 0 ? d.getUint16(o + 6 + n * 2) : 0;
  type = effective;
  return Lookup(type, flag, markSet, subs);
}

List<LookupRecord> _records(ByteData d, int o, int n) => <LookupRecord>[
  for (int i = 0; i < n; i++)
    LookupRecord(d.getUint16(o + i * 4), d.getUint16(o + i * 4 + 2)),
];

Subtable _parseGsub(ByteData d, int o, int type) {
  switch (type) {
    case 1:
      {
        final int format = d.getUint16(o);
        final Coverage cov = Coverage.parse(d, o + d.getUint16(o + 2));
        final Map<int, int> map = <int, int>{};
        if (format == 1) {
          final int delta = d.getInt16(o + 4);
          for (final int g in cov.glyphs) {
            map[g] = (g + delta) & 0xFFFF;
          }
        } else {
          for (final int g in cov.glyphs) {
            map[g] = d.getUint16(o + 6 + cov.indexOf(g) * 2);
          }
        }
        return SingleSubst(map);
      }
    case 2:
    case 3:
      {
        final Coverage cov = Coverage.parse(d, o + d.getUint16(o + 2));
        final Map<int, List<int>> map = <int, List<int>>{};
        for (final int g in cov.glyphs) {
          final int so = o + d.getUint16(o + 6 + cov.indexOf(g) * 2);
          final int n = d.getUint16(so);
          map[g] = <int>[
            for (int k = 0; k < n; k++) d.getUint16(so + 2 + k * 2),
          ];
        }
        return type == 2 ? MultipleSubst(map) : AlternateSubst(map);
      }
    case 4:
      {
        final Coverage cov = Coverage.parse(d, o + d.getUint16(o + 2));
        final Map<int, List<Ligature>> map = <int, List<Ligature>>{};
        for (final int g in cov.glyphs) {
          final int setOff = o + d.getUint16(o + 6 + cov.indexOf(g) * 2);
          final int n = d.getUint16(setOff);
          final List<Ligature> ligs = <Ligature>[];
          for (int k = 0; k < n; k++) {
            final int lo = setOff + d.getUint16(setOff + 2 + k * 2);
            final int glyph = d.getUint16(lo);
            final int cc = d.getUint16(lo + 2);
            ligs.add(
              Ligature(<int>[
                for (int c = 0; c < cc - 1; c++) d.getUint16(lo + 4 + c * 2),
              ], glyph),
            );
          }
          map[g] = ligs;
        }
        return LigatureSubst(map);
      }
    case 5:
      return _parseContext(d, o, chain: false);
    case 6:
      return _parseContext(d, o, chain: true);
    default:
      return const NoopSubtable();
  }
}

Subtable _parseContext(ByteData d, int o, {required bool chain}) {
  final int format = d.getUint16(o);
  if (format == 3) {
    int p = o + 2;
    List<Matcher> cov(int count, int at) => <Matcher>[
      for (int i = 0; i < count; i++)
        CoverageMatcher(Coverage.parse(d, o + d.getUint16(at + i * 2))),
    ];
    List<Matcher> back = const <Matcher>[];
    if (chain) {
      final int bc = d.getUint16(p);
      back = cov(bc, p + 2);
      p += 2 + bc * 2;
    }
    final int ic = d.getUint16(p);
    final List<Matcher> input = cov(ic, p + 2);
    p += 2 + ic * 2;
    List<Matcher> ahead = const <Matcher>[];
    if (chain) {
      final int lc = d.getUint16(p);
      ahead = cov(lc, p + 2);
      p += 2 + lc * 2;
    }
    final int rc = d.getUint16(p);
    final ContextRule rule = ContextRule(
      back,
      input,
      ahead,
      _records(d, p + 2, rc),
    );
    final Coverage first = (input.first as CoverageMatcher).coverage;
    return ContextSubtable(first.contains, (int g) => <ContextRule>[rule]);
  }

  final Coverage cov = Coverage.parse(d, o + d.getUint16(o + 2));
  if (format == 1) {
    final int setCount = d.getUint16(o + 4);
    final List<List<ContextRule>> sets = <List<ContextRule>>[];
    for (int s = 0; s < setCount; s++) {
      final int so0 = d.getUint16(o + 6 + s * 2);
      if (so0 == 0) {
        sets.add(const <ContextRule>[]);
        continue;
      }
      final int so = o + so0;
      final int n = d.getUint16(so);
      final List<ContextRule> rules = <ContextRule>[];
      for (int r = 0; r < n; r++) {
        final int ro = so + d.getUint16(so + 2 + r * 2);
        rules.add(_readGlyphRule(d, ro, chain: chain));
      }
      sets.add(rules);
    }
    return ContextSubtable(
      cov.contains,
      (int g) => sets[cov.indexOf(g)].map((ContextRule r) {
        return ContextRule(
          r.backtrack,
          <Matcher>[GlyphMatcher(g), ...r.input],
          r.lookahead,
          r.records,
        );
      }).toList(),
    );
  }
  // format 2
  int p = o + 4;
  ClassDef? backDef;
  ClassDef inputDef;
  ClassDef? aheadDef;
  if (chain) {
    backDef = ClassDef.parse(d, o + d.getUint16(p));
    inputDef = ClassDef.parse(d, o + d.getUint16(p + 2));
    aheadDef = ClassDef.parse(d, o + d.getUint16(p + 4));
    p += 6;
  } else {
    inputDef = ClassDef.parse(d, o + d.getUint16(p));
    p += 2;
  }
  final int setCount = d.getUint16(p);
  final List<List<ContextRule>> sets = <List<ContextRule>>[];
  for (int s = 0; s < setCount; s++) {
    final int so0 = d.getUint16(p + 2 + s * 2);
    if (so0 == 0) {
      sets.add(const <ContextRule>[]);
      continue;
    }
    final int so = o + so0;
    final int n = d.getUint16(so);
    final List<ContextRule> rules = <ContextRule>[];
    for (int r = 0; r < n; r++) {
      final int ro = so + d.getUint16(so + 2 + r * 2);
      int q = ro;
      List<Matcher> back = const <Matcher>[];
      if (chain) {
        final int bc = d.getUint16(q);
        back = <Matcher>[
          for (int i = 0; i < bc; i++)
            ClassMatcher(backDef!, d.getUint16(q + 2 + i * 2)),
        ];
        q += 2 + bc * 2;
      }
      final int ic = d.getUint16(q);
      final List<Matcher> input = <Matcher>[
        ClassMatcher(inputDef, s),
        for (int i = 0; i < ic - 1; i++)
          ClassMatcher(inputDef, d.getUint16(q + 2 + i * 2)),
      ];
      q += 2 + (ic - 1) * 2;
      List<Matcher> ahead = const <Matcher>[];
      if (chain) {
        final int lc = d.getUint16(q);
        ahead = <Matcher>[
          for (int i = 0; i < lc; i++)
            ClassMatcher(aheadDef!, d.getUint16(q + 2 + i * 2)),
        ];
        q += 2 + lc * 2;
      }
      final int rc = d.getUint16(q);
      rules.add(ContextRule(back, input, ahead, _records(d, q + 2, rc)));
    }
    sets.add(rules);
  }
  return ContextSubtable(cov.contains, (int g) {
    final int c = inputDef.classOf(g);
    return c < sets.length ? sets[c] : const <ContextRule>[];
  });
}

/// A format 1 rule, whose first glyph is added by the caller.
ContextRule _readGlyphRule(ByteData d, int o, {required bool chain}) {
  int q = o;
  List<Matcher> back = const <Matcher>[];
  if (chain) {
    final int bc = d.getUint16(q);
    back = <Matcher>[
      for (int i = 0; i < bc; i++) GlyphMatcher(d.getUint16(q + 2 + i * 2)),
    ];
    q += 2 + bc * 2;
  }
  final int ic = d.getUint16(q);
  int recordCount;
  List<Matcher> rest;
  List<Matcher> ahead = const <Matcher>[];
  if (chain) {
    rest = <Matcher>[
      for (int i = 0; i < ic - 1; i++) GlyphMatcher(d.getUint16(q + 2 + i * 2)),
    ];
    q += 2 + (ic - 1) * 2;
    final int lc = d.getUint16(q);
    ahead = <Matcher>[
      for (int i = 0; i < lc; i++) GlyphMatcher(d.getUint16(q + 2 + i * 2)),
    ];
    q += 2 + lc * 2;
    recordCount = d.getUint16(q);
    q += 2;
  } else {
    recordCount = d.getUint16(q + 2);
    rest = <Matcher>[
      for (int i = 0; i < ic - 1; i++) GlyphMatcher(d.getUint16(q + 4 + i * 2)),
    ];
    q += 4 + (ic - 1) * 2;
  }
  return ContextRule(back, rest, ahead, _records(d, q, recordCount));
}

int _valueSize(int format) {
  int n = 0;
  for (int b = 0; b < 8; b++) {
    if ((format & (1 << b)) != 0) n++;
  }
  return n * 2;
}

ValueRecord _value(ByteData d, int o, int format) {
  if (format == 0) return ValueRecord.zero;
  int p = o;
  int xp = 0, yp = 0, xa = 0, ya = 0;
  if ((format & 0x1) != 0) {
    xp = d.getInt16(p);
    p += 2;
  }
  if ((format & 0x2) != 0) {
    yp = d.getInt16(p);
    p += 2;
  }
  if ((format & 0x4) != 0) {
    xa = d.getInt16(p);
    p += 2;
  }
  if ((format & 0x8) != 0) {
    ya = d.getInt16(p);
  }
  return ValueRecord(xp, yp, xa, ya);
}

Anchor _anchor(ByteData d, int o) =>
    Anchor(d.getInt16(o + 2), d.getInt16(o + 4));

Subtable _parseGpos(ByteData d, int o, int type) {
  switch (type) {
    case 1:
      {
        final int format = d.getUint16(o);
        final Coverage cov = Coverage.parse(d, o + d.getUint16(o + 2));
        final int vf = d.getUint16(o + 4);
        final Map<int, ValueRecord> map = <int, ValueRecord>{};
        if (format == 1) {
          final ValueRecord v = _value(d, o + 6, vf);
          for (final int g in cov.glyphs) {
            map[g] = v;
          }
        } else {
          final int count = d.getUint16(o + 6);
          final int size = _valueSize(vf);
          final List<int?> order = List<int?>.filled(count, null);
          for (final int g in cov.glyphs) {
            final int idx = cov.indexOf(g);
            if (idx < count) order[idx] = g;
          }
          for (int i = 0; i < count; i++) {
            final int? g = order[i];
            if (g != null) map[g] = _value(d, o + 8 + i * size, vf);
          }
        }
        return SinglePos(map);
      }
    case 2:
      {
        final int format = d.getUint16(o);
        final Coverage cov = Coverage.parse(d, o + d.getUint16(o + 2));
        final int vf1 = d.getUint16(o + 4);
        final int vf2 = d.getUint16(o + 6);
        final int s1 = _valueSize(vf1);
        final int s2 = _valueSize(vf2);
        if (format == 1) {
          final int setCount = d.getUint16(o + 8);
          final List<int> order = List<int>.filled(setCount, 0);
          for (final int g in cov.glyphs) {
            final int idx = cov.indexOf(g);
            if (idx < setCount) order[idx] = g;
          }
          final Map<int, Map<int, (ValueRecord, ValueRecord)>> pairs =
              <int, Map<int, (ValueRecord, ValueRecord)>>{};
          for (int s = 0; s < setCount; s++) {
            final int so = o + d.getUint16(o + 10 + s * 2);
            final int n = d.getUint16(so);
            final Map<int, (ValueRecord, ValueRecord)> m =
                <int, (ValueRecord, ValueRecord)>{};
            int p = so + 2;
            for (int k = 0; k < n; k++) {
              final int second = d.getUint16(p);
              m[second] = (_value(d, p + 2, vf1), _value(d, p + 2 + s1, vf2));
              p += 2 + s1 + s2;
            }
            pairs[order[s]] = m;
          }
          return PairPos(coverage: cov, pairs: pairs);
        }
        final ClassDef c1 = ClassDef.parse(d, o + d.getUint16(o + 8));
        final ClassDef c2 = ClassDef.parse(d, o + d.getUint16(o + 10));
        final int n1 = d.getUint16(o + 12);
        final int n2 = d.getUint16(o + 14);
        final List<List<(ValueRecord, ValueRecord)>> matrix =
            <List<(ValueRecord, ValueRecord)>>[];
        int p = o + 16;
        for (int a = 0; a < n1; a++) {
          final List<(ValueRecord, ValueRecord)> row =
              <(ValueRecord, ValueRecord)>[];
          for (int b = 0; b < n2; b++) {
            row.add((_value(d, p, vf1), _value(d, p + s1, vf2)));
            p += s1 + s2;
          }
          matrix.add(row);
        }
        return PairPos(
          coverage: cov,
          classDef1: c1,
          classDef2: c2,
          matrix: matrix,
        );
      }
    case 4:
    case 6:
      {
        final Coverage markCov = Coverage.parse(d, o + d.getUint16(o + 2));
        final Coverage baseCov = Coverage.parse(d, o + d.getUint16(o + 4));
        final int classCount = d.getUint16(o + 6);
        final int markArray = o + d.getUint16(o + 8);
        final int baseArray = o + d.getUint16(o + 10);
        final int markCount = d.getUint16(markArray);
        final List<int> classes = <int>[];
        final List<Anchor> anchors = <Anchor>[];
        for (int i = 0; i < markCount; i++) {
          classes.add(d.getUint16(markArray + 2 + i * 4));
          anchors.add(
            _anchor(d, markArray + d.getUint16(markArray + 2 + i * 4 + 2)),
          );
        }
        final int baseCount = d.getUint16(baseArray);
        final List<List<Anchor?>> bases = <List<Anchor?>>[];
        for (int i = 0; i < baseCount; i++) {
          final List<Anchor?> row = <Anchor?>[];
          for (int c = 0; c < classCount; c++) {
            final int ao = d.getUint16(
              baseArray + 2 + (i * classCount + c) * 2,
            );
            row.add(ao == 0 ? null : _anchor(d, baseArray + ao));
          }
          bases.add(row);
        }
        return MarkAttachPos(
          markCoverage: markCov,
          baseCoverage: baseCov,
          markClasses: classes,
          markAnchors: anchors,
          baseAnchors: bases,
          isMarkToMark: type == 6,
        );
      }
    case 7:
      return _parseContext(d, o, chain: false);
    case 8:
      return _parseContext(d, o, chain: true);
    default:
      return const NoopSubtable();
  }
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

/// One glyph in the run being shaped.
class ShapedGlyph {
  ShapedGlyph(this.gid, this.cluster);

  int gid;
  int cluster;

  /// Which features this glyph takes part in.
  int mask = 1;

  /// Indic syllable bookkeeping, see devanagari_shaper.dart.
  int category = 0;
  int position = 0;
  int syllable = 0;

  /// Set when a ligature lookup produced this glyph, and when a multiple
  /// substitution did.
  bool ligated = false;
  bool multiplied = false;

  int xAdvance = 0;
  int yAdvance = 0;
  int xOffset = 0;
  int yOffset = 0;

  /// For attached marks: how many glyphs back the base is.
  int attachChain = 0;

  ShapedGlyph copy() => ShapedGlyph(gid, cluster)
    ..mask = mask
    ..category = category
    ..position = position
    ..syllable = syllable
    ..ligated = ligated
    ..multiplied = multiplied
    ..xAdvance = xAdvance
    ..yAdvance = yAdvance
    ..xOffset = xOffset
    ..yOffset = yOffset
    ..attachChain = attachChain;
}

class LayoutEngine {
  LayoutEngine(this.gdef, this.table);

  final Gdef? gdef;
  final LayoutTable table;

  // -- skipping --------------------------------------------------------------

  bool _skipped(int gid, Lookup lk) {
    final int flag = lk.flag;
    if ((flag & 0xFF1E) == 0) return false;
    final int cls = gdef?.classOf(gid) ?? 0;
    if ((flag & 0x2) != 0 && cls == 1) return true;
    if ((flag & 0x4) != 0 && cls == 2) return true;
    if (cls == 3) {
      if ((flag & 0x8) != 0) return true;
      if ((flag & 0x10) != 0) {
        final List<Coverage> sets = gdef?.markSets ?? const <Coverage>[];
        if (lk.markSet >= sets.length || !sets[lk.markSet].contains(gid)) {
          return true;
        }
      } else if ((flag & 0xFF00) != 0) {
        if ((gdef?.markAttach.classOf(gid) ?? 0) != (flag >> 8)) return true;
      }
    }
    return false;
  }

  /// The next glyph after [from] that the lookup does not skip, or -1. With
  /// [mask] set, a glyph outside the mask ends the search (it cannot be part
  /// of the match); context glyphs pass -1 so they are never excluded.
  int _next(List<ShapedGlyph> buf, int from, Lookup lk, int mask) {
    int j = from + 1;
    while (j < buf.length) {
      final ShapedGlyph g = buf[j];
      if (_skipped(g.gid, lk)) {
        j++;
        continue;
      }
      if ((g.mask & mask) == 0) return -1;
      return j;
    }
    return -1;
  }

  int _prev(List<ShapedGlyph> buf, int from, Lookup lk) {
    int j = from - 1;
    while (j >= 0) {
      if (_skipped(buf[j].gid, lk)) {
        j--;
        continue;
      }
      return j;
    }
    return -1;
  }

  // -- running a lookup over a run ------------------------------------------

  /// Applies one lookup to the whole run. Glyphs take part only when their
  /// mask shares a bit with [mask].
  void run(List<ShapedGlyph> buf, int lookupIndex, int mask) {
    if (lookupIndex >= table.lookups.length) return;
    final Lookup lk = table.lookups[lookupIndex];
    int i = 0;
    while (i < buf.length) {
      final ShapedGlyph g = buf[i];
      if ((g.mask & mask) == 0 || _skipped(g.gid, lk)) {
        i++;
        continue;
      }
      final int? next = _applyAt(buf, lk, i, mask, 0);
      i = next ?? i + 1;
    }
  }

  /// Tries every subtable of [lk] at [i]. Returns the index to continue from,
  /// or null if nothing applied.
  int? _applyAt(List<ShapedGlyph> buf, Lookup lk, int i, int mask, int depth) {
    if (depth > 6) return null;
    for (final Subtable sub in lk.subtables) {
      final int? next = _applySub(buf, lk, sub, i, mask, depth);
      if (next != null) return next;
    }
    return null;
  }

  int? _applySub(
    List<ShapedGlyph> buf,
    Lookup lk,
    Subtable sub,
    int i,
    int mask,
    int depth,
  ) {
    final ShapedGlyph g = buf[i];
    switch (sub) {
      case SingleSubst():
        final int? to = sub.map[g.gid];
        if (to == null) return null;
        g.gid = to;
        return i + 1;
      case MultipleSubst():
        final List<int>? seq = sub.map[g.gid];
        if (seq == null) return null;
        if (seq.length == 1) {
          g.gid = seq.first;
          return i + 1;
        }
        final List<ShapedGlyph> repl = <ShapedGlyph>[
          for (final int gid in seq)
            g.copy()
              ..gid = gid
              ..multiplied = true,
        ];
        buf.replaceRange(i, i + 1, repl);
        return i + repl.length;
      case AlternateSubst():
        final List<int>? alts = sub.map[g.gid];
        if (alts == null || alts.isEmpty) return null;
        g.gid = alts.first;
        return i + 1;
      case LigatureSubst():
        final List<Ligature>? ligs = sub.map[g.gid];
        if (ligs == null) return null;
        for (final Ligature lig in ligs) {
          final List<int> at = <int>[i];
          int cur = i;
          bool ok = true;
          for (final int comp in lig.components) {
            cur = _next(buf, cur, lk, mask);
            if (cur < 0 || buf[cur].gid != comp) {
              ok = false;
              break;
            }
            at.add(cur);
          }
          if (!ok) continue;
          g.gid = lig.glyph;
          g.ligated = true;
          for (int k = at.length - 1; k >= 1; k--) {
            if (buf[at[k]].cluster < g.cluster) g.cluster = buf[at[k]].cluster;
            buf.removeAt(at[k]);
          }
          return i + 1;
        }
        return null;
      case ContextSubtable():
        if (!sub.firstGlyph(g.gid)) return null;
        for (final ContextRule rule in sub.rulesFor(g.gid)) {
          final List<int>? matched = _matchRule(buf, lk, rule, i, mask);
          if (matched == null) continue;
          return _applyRecords(buf, rule, matched, mask, depth);
        }
        return null;
      case NoopSubtable():
        return null;
      case SinglePos():
        final ValueRecord? v = sub.map[g.gid];
        if (v == null) return null;
        _addValue(g, v);
        return i + 1;
      case PairPos():
        return _applyPair(buf, lk, sub, i, mask);
      case MarkAttachPos():
        return _applyMark(buf, lk, sub, i);
    }
  }

  List<int>? _matchRule(
    List<ShapedGlyph> buf,
    Lookup lk,
    ContextRule rule,
    int i,
    int mask,
  ) {
    final List<int> at = <int>[i];
    int cur = i;
    for (int k = 1; k < rule.input.length; k++) {
      cur = _next(buf, cur, lk, mask);
      if (cur < 0 || !rule.input[k].matches(buf[cur].gid)) return null;
      at.add(cur);
    }
    if (!rule.input[0].matches(buf[i].gid)) return null;
    int b = i;
    for (final Matcher m in rule.backtrack) {
      b = _prev(buf, b, lk);
      if (b < 0 || !m.matches(buf[b].gid)) return null;
    }
    int a = cur;
    for (final Matcher m in rule.lookahead) {
      a = a + 1;
      while (a < buf.length && _skipped(buf[a].gid, lk)) {
        a++;
      }
      if (a >= buf.length || !m.matches(buf[a].gid)) return null;
    }
    return at;
  }

  int _applyRecords(
    List<ShapedGlyph> buf,
    ContextRule rule,
    List<int> matched,
    int mask,
    int depth,
  ) {
    final List<int> pos = List<int>.of(matched);
    int end = pos.last + 1;
    for (final LookupRecord rec in rule.records) {
      if (rec.sequenceIndex >= pos.length) continue;
      if (rec.lookupIndex >= table.lookups.length) continue;
      final int at = pos[rec.sequenceIndex];
      if (at >= buf.length) continue;
      final int before = buf.length;
      final int? ok = _applyAt(
        buf,
        table.lookups[rec.lookupIndex],
        at,
        mask,
        depth + 1,
      );
      if (ok == null) continue;
      int delta = buf.length - before;
      if (delta == 0) continue;
      end += delta;
      if (end < at) {
        delta += at - end;
        end = at;
      }
      final int next = rec.sequenceIndex + 1;
      if (delta > 0) {
        for (int j = next; j < pos.length; j++) {
          pos[j] += delta;
        }
      } else {
        final int drop = (-delta).clamp(0, pos.length - next);
        pos.removeRange(next, next + drop);
        for (int j = next; j < pos.length; j++) {
          pos[j] += delta;
        }
      }
    }
    return end;
  }

  // -- positioning -----------------------------------------------------------

  void _addValue(ShapedGlyph g, ValueRecord v) {
    g.xOffset += v.xPlacement;
    g.yOffset += v.yPlacement;
    g.xAdvance += v.xAdvance;
    g.yAdvance += v.yAdvance;
  }

  int? _applyPair(
    List<ShapedGlyph> buf,
    Lookup lk,
    PairPos sub,
    int i,
    int mask,
  ) {
    final ShapedGlyph first = buf[i];
    if (!sub.coverage.contains(first.gid)) return null;
    final int j = _next(buf, i, lk, mask);
    if (j < 0) return null;
    final ShapedGlyph second = buf[j];
    (ValueRecord, ValueRecord)? pair;
    if (sub.pairs != null) {
      pair = sub.pairs![first.gid]?[second.gid];
    } else {
      final int c1 = sub.classDef1!.classOf(first.gid);
      final int c2 = sub.classDef2!.classOf(second.gid);
      if (c1 < sub.matrix!.length && c2 < sub.matrix![c1].length) {
        pair = sub.matrix![c1][c2];
      }
    }
    if (pair == null) return null;
    _addValue(first, pair.$1);
    _addValue(second, pair.$2);
    // The second glyph is consumed only when it received a value.
    return pair.$2.isZero ? i + 1 : j + 1;
  }

  int? _applyMark(List<ShapedGlyph> buf, Lookup lk, MarkAttachPos sub, int i) {
    final ShapedGlyph mark = buf[i];
    final int markIndex = sub.markCoverage.indexOf(mark.gid);
    if (markIndex < 0) return null;
    int j;
    if (sub.isMarkToMark) {
      j = _prev(buf, i, lk);
      if (j < 0) return null;
      if ((gdef?.classOf(buf[j].gid) ?? 0) != 3) return null;
    } else {
      // Back past marks to the base glyph.
      j = i - 1;
      while (j >= 0 && (gdef?.classOf(buf[j].gid) ?? 0) == 3) {
        j--;
      }
      if (j < 0) return null;
    }
    final int baseIndex = sub.baseCoverage.indexOf(buf[j].gid);
    if (baseIndex < 0) return null;
    final int cls = sub.markClasses[markIndex];
    if (baseIndex >= sub.baseAnchors.length ||
        cls >= sub.baseAnchors[baseIndex].length) {
      return null;
    }
    final Anchor? baseAnchor = sub.baseAnchors[baseIndex][cls];
    if (baseAnchor == null) return null;
    final Anchor markAnchor = sub.markAnchors[markIndex];
    mark.xOffset = baseAnchor.x - markAnchor.x;
    mark.yOffset = baseAnchor.y - markAnchor.y;
    mark.attachChain = i - j;
    return i + 1;
  }

  /// Turns the per-mark offsets (which are relative to the base the mark
  /// attached to) into offsets from the mark's own pen position.
  static void propagateAttachments(List<ShapedGlyph> buf) {
    final List<bool> done = List<bool>.filled(buf.length, false);
    void fix(int i) {
      if (done[i]) return;
      done[i] = true;
      final int chain = buf[i].attachChain;
      if (chain == 0) return;
      final int j = i - chain;
      if (j < 0 || j >= buf.length) return;
      fix(j);
      buf[i].xOffset += buf[j].xOffset;
      buf[i].yOffset += buf[j].yOffset;
      for (int k = j; k < i; k++) {
        buf[i].xOffset -= buf[k].xAdvance;
        buf[i].yOffset -= buf[k].yAdvance;
      }
      buf[i].attachChain = 0;
    }

    for (int i = 0; i < buf.length; i++) {
      fix(i);
    }
  }

  /// Would [lookupIndex] substitute the exact sequence [gids], seeing nothing
  /// of its surroundings? It is how Indic shaping asks whether a font has a
  /// below-base or post-base form for a consonant.
  bool wouldSubstitute(int lookupIndex, List<int> gids) {
    if (lookupIndex >= table.lookups.length) return false;
    final Lookup lk = table.lookups[lookupIndex];
    for (final Subtable sub in lk.subtables) {
      switch (sub) {
        case SingleSubst():
          if (gids.length == 1 && sub.map.containsKey(gids[0])) return true;
        case MultipleSubst():
          if (gids.length == 1 && sub.map.containsKey(gids[0])) return true;
        case AlternateSubst():
          if (gids.length == 1 && sub.map.containsKey(gids[0])) return true;
        case LigatureSubst():
          final List<Ligature>? ligs = sub.map[gids.first];
          if (ligs == null) break;
          for (final Ligature l in ligs) {
            if (l.components.length != gids.length - 1) continue;
            bool same = true;
            for (int k = 0; k < l.components.length; k++) {
              if (l.components[k] != gids[k + 1]) {
                same = false;
                break;
              }
            }
            if (same) return true;
          }
        case ContextSubtable():
          if (!sub.firstGlyph(gids.first)) break;
          for (final ContextRule r in sub.rulesFor(gids.first)) {
            if (r.backtrack.isNotEmpty || r.lookahead.isNotEmpty) continue;
            if (r.input.length != gids.length) continue;
            bool all = true;
            for (int k = 0; k < gids.length; k++) {
              if (!r.input[k].matches(gids[k])) {
                all = false;
                break;
              }
            }
            if (all) return true;
          }
        default:
          break;
      }
    }
    return false;
  }
}
