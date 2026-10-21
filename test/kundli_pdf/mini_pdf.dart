import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kundlisaar/kundli_pdf/crypto/pdf_aes256.dart';

/// A small reader for the files this app writes, enough to open them the way
/// a viewer would: find the objects, check the encryption entries against a
/// password, decrypt and inflate streams, read the pages, the fonts and the
/// text. It is a test tool, not a general PDF parser.
class PdfObj {
  PdfObj(this.id, this.dict, this.raw);

  final int id;
  final String dict;

  /// The stream bytes as stored (encrypted and compressed), or null.
  final Uint8List? raw;

  bool get isStream => raw != null;
}

class MiniPdf {
  MiniPdf._(this.bytes, this.objects, this.text);

  final Uint8List bytes;
  final Map<int, PdfObj> objects;
  final String text;

  static MiniPdf parse(Uint8List bytes) {
    final String text = latin1.decode(bytes);
    final Map<int, PdfObj> objects = <int, PdfObj>{};
    final RegExp head = RegExp(r'(?:^|[\r\n])(\d+) 0 obj\s*');
    int at = 0;
    while (true) {
      final Iterator<RegExpMatch> found = head.allMatches(text, at).iterator;
      if (!found.moveNext()) break;
      final RegExpMatch m = found.current;
      final int id = int.parse(m.group(1)!);
      final int bodyStart = m.end;
      // Dictionary runs to "stream" or to "endobj".
      final int streamAt = text.indexOf('stream', bodyStart);
      final int endObj = text.indexOf('endobj', bodyStart);
      if (streamAt != -1 &&
          (endObj == -1 || streamAt < endObj) &&
          text.startsWith(RegExp(r'stream\r?\n'), streamAt)) {
        final String dict = text.substring(bodyStart, streamAt);
        final int len = int.parse(
          RegExp(r'/Length (\d+)').firstMatch(dict)!.group(1)!,
        );
        int dataStart = streamAt + 'stream'.length;
        if (text.codeUnitAt(dataStart) == 0x0d) dataStart++;
        if (text.codeUnitAt(dataStart) == 0x0a) dataStart++;
        objects[id] = PdfObj(
          id,
          dict,
          Uint8List.sublistView(bytes, dataStart, dataStart + len),
        );
        at = dataStart + len;
        final int e = text.indexOf('endobj', at);
        at = e == -1 ? text.length : e + 6;
      } else {
        objects[id] = PdfObj(id, text.substring(bodyStart, endObj), null);
        at = endObj + 6;
      }
      if (at >= text.length) break;
    }
    return MiniPdf._(bytes, objects, text);
  }

  bool get hasHeader => text.startsWith('%PDF-');
  bool get hasEof => text.trimRight().endsWith('%%EOF');

  /// The cross-reference stream object, whose dictionary is the trailer.
  PdfObj? get trailer {
    for (final PdfObj o in objects.values) {
      if (o.dict.contains('/Type/XRef') || o.dict.contains('/Type /XRef')) {
        return o;
      }
    }
    return null;
  }

  /// Offset the file says its cross-reference data starts at.
  int get startXref =>
      int.parse(RegExp(r'startxref\s+(\d+)').allMatches(text).last.group(1)!);

  int? refOf(String dict, String key) {
    final RegExpMatch? m = RegExp('$key\\s*(\\d+) 0 R').firstMatch(dict);
    return m == null ? null : int.parse(m.group(1)!);
  }

  PdfObj? get encrypt {
    final int? id = refOf(trailer!.dict, '/Encrypt');
    return id == null ? null : objects[id];
  }

  Uint8List hexEntry(String key) {
    final RegExpMatch m = RegExp(
      '$key\\s*<([0-9a-fA-F]+)>',
    ).firstMatch(encrypt!.dict)!;
    final String h = m.group(1)!;
    return Uint8List.fromList(<int>[
      for (int i = 0; i < h.length; i += 2)
        int.parse(h.substring(i, i + 2), radix: 16),
    ]);
  }

  /// The stream of [o] decrypted with [fileKey] (when given) and inflated.
  Uint8List stream(PdfObj o, {Uint8List? fileKey}) {
    Uint8List data = o.raw!;
    if (fileKey != null) data = PdfAes256Encryption.decryptWith(fileKey, data);
    if (o.dict.contains('/FlateDecode')) {
      data = Uint8List.fromList(zlib.decode(data));
    }
    return data;
  }

  /// The pages, in order.
  List<PdfObj> get pages {
    final PdfObj root = objects.values.firstWhere(
      (PdfObj o) => RegExp(r'/Type\s*/Pages\b').hasMatch(o.dict),
    );
    final RegExpMatch kids = RegExp(
      r'/Kids\s*\[([^\]]*)\]',
    ).firstMatch(root.dict)!;
    return <PdfObj>[
      for (final RegExpMatch r in RegExp(
        r'(\d+) 0 R',
      ).allMatches(kids.group(1)!))
        objects[int.parse(r.group(1)!)]!,
    ];
  }

  List<PdfObj> contentsOf(PdfObj page) {
    final RegExpMatch? arr = RegExp(
      r'/Contents\s*\[([^\]]*)\]',
    ).firstMatch(page.dict);
    if (arr != null) {
      return <PdfObj>[
        for (final RegExpMatch r in RegExp(
          r'(\d+) 0 R',
        ).allMatches(arr.group(1)!))
          objects[int.parse(r.group(1)!)]!,
      ];
    }
    final int? id = refOf(page.dict, '/Contents');
    return id == null ? <PdfObj>[] : <PdfObj>[objects[id]!];
  }

  /// Font resource name -> font object, for a page.
  Map<String, PdfObj> fontsOf(PdfObj page) {
    final RegExpMatch? m = RegExp(r'/Font\s*<<(.*?)>>').firstMatch(page.dict);
    if (m == null) return <String, PdfObj>{};
    return <String, PdfObj>{
      for (final RegExpMatch r in RegExp(
        r'/(F\d+)\s*(\d+) 0 R',
      ).allMatches(m.group(1)!))
        r.group(1)!: objects[int.parse(r.group(2)!)]!,
    };
  }

  /// The XObjects a page draws.
  List<int> xobjectsOf(PdfObj page) {
    final RegExpMatch? m = RegExp(
      r'/XObject\s*<<(.*?)>>',
    ).firstMatch(page.dict);
    if (m == null) return <int>[];
    return <int>[
      for (final RegExpMatch r in RegExp(
        r'/X?\w+\s*(\d+) 0 R',
      ).allMatches(m.group(1)!))
        int.parse(r.group(1)!),
    ];
  }

  /// CID -> text from a font's ToUnicode map.
  Map<int, String> toUnicode(PdfObj font, {Uint8List? fileKey}) {
    final int id = refOf(font.dict, '/ToUnicode')!;
    final String cmap = latin1.decode(stream(objects[id]!, fileKey: fileKey));
    final Map<int, String> out = <int, String>{};
    for (final RegExpMatch m in RegExp(
      r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]+)>',
    ).allMatches(cmap)) {
      final String h = m.group(2)!;
      final StringBuffer b = StringBuffer();
      for (int i = 0; i + 4 <= h.length; i += 4) {
        b.writeCharCode(int.parse(h.substring(i, i + 4), radix: 16));
      }
      out[int.parse(m.group(1)!, radix: 16)] = b.toString();
    }
    return out;
  }

  /// The font file embedded for a Type0 font.
  Uint8List fontFile(PdfObj font, {Uint8List? fileKey}) {
    final int desc = refOf(font.dict, '/DescendantFonts\\s*\\[')!;
    final PdfObj cid = objects[desc]!;
    final PdfObj descriptor = objects[refOf(cid.dict, '/FontDescriptor')!]!;
    return stream(
      objects[refOf(descriptor.dict, '/FontFile2')!]!,
      fileKey: fileKey,
    );
  }

  /// The words a page draws, in order, as the viewer would read them.
  List<String> pageWords(
    PdfObj page, {
    Uint8List? fileKey,
    Map<PdfObj, Map<int, String>>? cache,
  }) {
    final Map<String, PdfObj> fonts = fontsOf(page);
    final Map<String, Map<int, String>> maps = <String, Map<int, String>>{
      for (final MapEntry<String, PdfObj> f in fonts.entries)
        f.key: (cache != null
            ? (cache[f.value] ??= toUnicode(f.value, fileKey: fileKey))
            : toUnicode(f.value, fileKey: fileKey)),
    };
    final List<String> words = <String>[];
    for (final PdfObj c in contentsOf(page)) {
      final String content = latin1.decode(stream(c, fileKey: fileKey));
      String? current;
      for (final RegExpMatch m in RegExp(
        r'/(F\d+) [-\d.]+ Tf|\[<([0-9a-fA-F]+)>\]TJ',
      ).allMatches(content)) {
        if (m.group(1) != null) {
          current = m.group(1);
        } else if (current != null) {
          final String hex = m.group(2)!;
          final StringBuffer b = StringBuffer();
          for (int i = 0; i + 4 <= hex.length; i += 4) {
            b.write(
              maps[current]![int.parse(hex.substring(i, i + 4), radix: 16)] ??
                  '�',
            );
          }
          words.add(b.toString());
        }
      }
    }
    return words;
  }
}
