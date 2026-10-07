/// The three font families the report is set in, embedded as data URIs so the
/// PDF needs no network and no font installed on the machine that builds it,
/// plus a coverage check so a name with a character none of them has is
/// caught here rather than printed as an empty box.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class EmbeddedFont {
  const EmbeddedFont(this.family, this.weight, this.file);

  final String family;
  final int weight;
  final String file;
}

const List<EmbeddedFont> reportFonts = <EmbeddedFont>[
  EmbeddedFont('Mukta', 400, 'Mukta-Regular.ttf'),
  EmbeddedFont('Mukta', 600, 'Mukta-SemiBold.ttf'),
  EmbeddedFont('Mukta', 700, 'Mukta-Bold.ttf'),
  EmbeddedFont('Tiro', 400, 'TiroDevanagariHindi-Regular.ttf'),
  EmbeddedFont('Yatra', 400, 'YatraOne-Regular.ttf'),
];

/// @font-face rules for every font, with the file contents inline.
String fontFaceCss(Directory fontsDir) {
  final StringBuffer out = StringBuffer();
  for (final EmbeddedFont f in reportFonts) {
    final File file = File('${fontsDir.path}/${f.file}');
    final String data = base64Encode(file.readAsBytesSync());
    out.writeln(
      "@font-face{font-family:'${f.family}';font-weight:${f.weight};"
      "font-style:normal;src:url(data:font/ttf;base64,$data) format('truetype');}",
    );
  }
  return out.toString();
}

/// Code points the font files cover, read from their cmap tables.
Set<int> coveredCodePoints(Directory fontsDir) {
  final Set<int> covered = <int>{};
  for (final EmbeddedFont f in reportFonts) {
    covered.addAll(
      _cmap(File('${fontsDir.path}/${f.file}').readAsBytesSync()),
    );
  }
  return covered;
}

Set<int> _cmap(Uint8List bytes) {
  final ByteData d = ByteData.sublistView(bytes);
  final int tables = d.getUint16(4);
  int cmapOffset = -1;
  for (int i = 0; i < tables; i++) {
    final int record = 12 + i * 16;
    final String tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmapOffset = d.getUint32(record + 8);
  }
  if (cmapOffset < 0) return <int>{};

  final int count = d.getUint16(cmapOffset + 2);
  final Set<int> out = <int>{};
  for (int i = 0; i < count; i++) {
    final int sub = cmapOffset + d.getUint32(cmapOffset + 4 + i * 8 + 4);
    final int format = d.getUint16(sub);
    if (format == 4) {
      _format4(d, sub, out);
    } else if (format == 12) {
      _format12(d, sub, out);
    }
  }
  return out;
}

void _format4(ByteData d, int at, Set<int> out) {
  final int segments = d.getUint16(at + 6) ~/ 2;
  final int endCodes = at + 14;
  final int startCodes = endCodes + segments * 2 + 2;
  final int deltas = startCodes + segments * 2;
  final int rangeOffsets = deltas + segments * 2;
  for (int s = 0; s < segments; s++) {
    final int end = d.getUint16(endCodes + s * 2);
    final int start = d.getUint16(startCodes + s * 2);
    final int delta = d.getInt16(deltas + s * 2);
    final int rangeOffset = d.getUint16(rangeOffsets + s * 2);
    if (start == 0xFFFF) continue;
    for (int c = start; c <= end; c++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final int slot = rangeOffsets + s * 2 + rangeOffset + (c - start) * 2;
        if (slot + 2 > d.lengthInBytes) continue;
        glyph = d.getUint16(slot);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      if (glyph != 0) out.add(c);
    }
  }
}

void _format12(ByteData d, int at, Set<int> out) {
  final int groups = d.getUint32(at + 12);
  for (int g = 0; g < groups; g++) {
    final int record = at + 16 + g * 12;
    final int start = d.getUint32(record);
    final int end = d.getUint32(record + 4);
    for (int c = start; c <= end; c++) {
      out.add(c);
    }
  }
}

/// Characters in [html] that no embedded font can draw. Markup, scripts and
/// the base64 font blobs are stripped first; whitespace and joiners are not
/// drawn and so are not reported.
Map<int, int> uncoveredCharacters(String html, Set<int> covered) {
  final String text = html
      .replaceAll(RegExp(r'@font-face\{[^}]*\}'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  final Map<int, int> missing = <int, int>{};
  for (final int rune in text.runes) {
    if (rune <= 0x20 || rune == 0x200C || rune == 0x200D || rune == 0xFEFF) {
      continue;
    }
    if (!covered.contains(rune)) missing[rune] = (missing[rune] ?? 0) + 1;
  }
  return missing;
}
