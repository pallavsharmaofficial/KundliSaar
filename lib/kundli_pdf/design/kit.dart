import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../honesty.dart';
import '../text/shaped_font.dart';
import 'chart_paint.dart';
import 'ornament.dart';
import 'palette.dart';

/// The four faces the book is set in.
class PdfFonts {
  const PdfFonts({
    required this.regular,
    required this.semi,
    required this.serif,
    required this.display,
  });

  /// Body text, and its heavier weight.
  final ShapedFont regular;
  final ShapedFont semi;

  /// Tiro Devanagari Hindi, for sub-headings and the name.
  final ShapedFont serif;

  /// Yatra One, for the title and the section headings.
  final ShapedFont display;

  List<ShapedFont> get all => <ShapedFont>[regular, semi, serif, display];
}

/// Which page each section starts on, learnt while the pages are laid out and
/// read when the contents page is painted, which is after all of them are.
class SectionPages {
  final Map<String, int> byId = <String, int>{};
}

class _Marker extends pw.Widget {
  _Marker(this.id, this.pages);

  final String id;
  final SectionPages pages;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    box = PdfRect.zero;
    pages.byId[id] = context.pageNumber;
  }
}

class _LateNumber extends pw.Widget {
  _LateNumber(this.id, this.pages, this.font, this.size, this.width);

  final String id;
  final SectionPages pages;
  final ShapedFont font;
  final double size;
  final double width;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    box = PdfRect(0, 0, width, size * 1.5);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final String text = '${pages.byId[id] ?? ''}';
    final PdfFont f = font.getFont(context);
    final double w = f.stringMetrics(text).advanceWidth * size;
    context.canvas
      ..setFillColor(Pal.ink)
      ..drawString(f, size, text, box!.right - w, box!.bottom + size * 0.32);
  }
}

enum ToneLook { supportive, mixed, demanding }

/// A heading, which [flow] keeps from being left alone at the foot of a page.
class _Heading extends pw.Inseparable {
  _Heading(pw.Widget child, this.needs) : super(child: child);

  /// The room, in points, that must be left on the page for it to stay there.
  final double needs;
}

/// Puts a page break before every heading that would otherwise be stranded
/// with too little room under it.
List<pw.Widget> flow(List<pw.Widget> widgets) {
  final List<pw.Widget> out = <pw.Widget>[];
  for (final pw.Widget w in widgets) {
    if (w is _Heading && !(out.isNotEmpty && out.last is pw.NewPage)) {
      out.add(pw.NewPage(freeSpace: w.needs));
    }
    out.add(w);
  }
  return out;
}

/// Everything the sections are built from. Every string that is set on a page
/// goes through here, and so into [ledger], which is how the tests read what
/// the book says without parsing the PDF.
class Kit {
  Kit({required this.fonts, required this.pages});

  final PdfFonts fonts;
  final SectionPages pages;
  final List<String> ledger = <String>[];

  /// The remedy lines among them (mantra, fast, giving, deity, the plain act),
  /// which the tests hold to the rules for remedies.
  final List<String> remedyLedger = <String>[];

  /// Pieces of text that were left out because they carried a refused word.
  final List<String> omitted = <String>[];

  /// True when [hindi] carries a word the book never prints; the caller then
  /// leaves that piece out, and it is recorded here.
  bool isRefused(String hindi, {bool yoga = false}) {
    if (!isRefusedHindi(hindi, yoga: yoga)) return false;
    omitted.add(hindi);
    return true;
  }

  static const double bodySize = 9.8;

  // -- styles ----------------------------------------------------------------

  pw.TextStyle style(
    ShapedFont font,
    double size, {
    PdfColor color = Pal.ink,
    double spacing = 2.0,
  }) => pw.TextStyle(
    font: font,
    fontNormal: font,
    fontBold: font,
    fontItalic: font,
    fontBoldItalic: font,
    fontSize: size,
    color: color,
    lineSpacing: spacing,
  );

  late final pw.TextStyle body = style(fonts.regular, bodySize);
  late final pw.TextStyle bodyStrong = style(fonts.semi, bodySize);
  late final pw.TextStyle small = style(
    fonts.regular,
    8.5,
    color: Pal.inkSoft,
    spacing: 1.5,
  );
  late final pw.TextStyle smallStrong = style(
    fonts.semi,
    8.5,
    color: Pal.inkSoft,
    spacing: 1.5,
  );
  late final pw.TextStyle tiny = style(
    fonts.regular,
    7.6,
    color: Pal.inkSoft,
    spacing: 1.2,
  );

  // -- text ------------------------------------------------------------------

  pw.Widget text(
    String s, {
    pw.TextStyle? style,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    ledger.add(s);
    return pw.Text(s, style: style ?? body, textAlign: align);
  }

  pw.Widget gap(double h) => pw.SizedBox(height: h);

  pw.Widget p(String s, {pw.TextStyle? style}) => text(s, style: style);

  /// A paragraph with a little air below it.
  pw.Widget para(String s, {pw.TextStyle? style}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4.5),
    child: text(s, style: style),
  );

  pw.Widget note(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: text(s, style: small),
  );

  /// A small gold label over a block of text.
  pw.Widget labelled(String label, String s, {pw.TextStyle? style}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            text(label, style: style_(fonts.semi, 8.2, Pal.gold)),
            pw.SizedBox(height: 0.6),
            text(s, style: style),
          ],
        ),
      );

  pw.TextStyle style_(ShapedFont f, double size, PdfColor c) =>
      style(f, size, color: c, spacing: 1.6);

  pw.Widget h2(String s) => _Heading(
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          text(
            s,
            style: style(fonts.serif, 15, color: Pal.maroon, spacing: 1.5),
          ),
          pw.SizedBox(height: 2.5),
          pw.Container(height: 0.8, color: Pal.gold),
        ],
      ),
    ),
    130,
  );

  pw.Widget h3(String s, {PdfColor color = Pal.ink}) => _Heading(
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
      child: text(
        s,
        style: style(fonts.semi, 11.6, color: color, spacing: 1.5),
      ),
    ),
    100,
  );

  /// A diamond bullet and a line of text.
  pw.Widget bullet(String s, {pw.TextStyle? style}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2.6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5.2, right: 6, left: 2),
          child: pw.SizedBox(
            width: 4.2,
            height: 4.2,
            child: pw.CustomPaint(
              painter: (PdfGraphics g, PdfPoint size) {
                g.setFillColor(Pal.maroon);
                g.moveTo(size.x / 2, size.y);
                g.lineTo(size.x, size.y / 2);
                g.lineTo(size.x / 2, 0);
                g.lineTo(0, size.y / 2);
                g.closePath();
                g.fillPath();
              },
            ),
          ),
        ),
        pw.Expanded(
          child: text(
            s,
            style: style ?? small.copyWith(fontSize: 9.0, color: Pal.ink),
          ),
        ),
      ],
    ),
  );

  pw.Widget bullets(List<String> items, {pw.TextStyle? style}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      for (final String s in items) bullet(s, style: style),
    ],
  );

  pw.Widget rule({double top = 4, double bottom = 6}) => pw.Padding(
    padding: pw.EdgeInsets.only(top: top, bottom: bottom),
    child: pw.Container(height: 0.5, color: Pal.rule),
  );

  /// A tone mark that reads in black and white: a full dot, a half dot and an
  /// empty ring.
  pw.Widget toneMark(ToneLook tone, {double size = 8}) => pw.SizedBox(
    width: size,
    height: size,
    child: pw.CustomPaint(
      painter: (PdfGraphics g, PdfPoint s) {
        final double r = s.x / 2 - 0.5;
        g.setStrokeColor(Pal.ink);
        g.setLineWidth(0.8);
        g.setFillColor(Pal.ink);
        switch (tone) {
          case ToneLook.supportive:
            g.drawEllipse(s.x / 2, s.y / 2, r, r);
            g.fillAndStrokePath();
          case ToneLook.demanding:
            g.drawEllipse(s.x / 2, s.y / 2, r, r);
            g.strokePath();
          case ToneLook.mixed:
            g.drawEllipse(s.x / 2, s.y / 2, r, r);
            g.strokePath();
            g.moveTo(s.x / 2, s.y / 2 - r);
            g.curveTo(
              s.x / 2 + r * 1.3,
              s.y / 2 - r,
              s.x / 2 + r * 1.3,
              s.y / 2 + r,
              s.x / 2,
              s.y / 2 + r,
            );
            g.closePath();
            g.fillPath();
        }
      },
    ),
  );

  /// A rounded label: the tone, with its mark, or any short phrase.
  pw.Widget chip(String s, {ToneLook? tone, PdfColor color = Pal.inkSoft}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: Pal.rule, width: 0.7),
          color: Pal.white,
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: <pw.Widget>[
            if (tone != null) ...<pw.Widget>[
              toneMark(tone, size: 7.2),
              pw.SizedBox(width: 3.5),
            ],
            text(s, style: style(fonts.semi, 8.4, color: color, spacing: 1)),
          ],
        ),
      );

  pw.Widget chips(List<pw.Widget> items) =>
      pw.Wrap(spacing: 5, runSpacing: 4, children: items);

  // -- tables ----------------------------------------------------------------

  /// A table with a tinted header and hairline rows. Columns are relative
  /// widths; [align] is per column.
  pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widths,
    List<pw.TextAlign>? align,
    double size = 9.2,
    Set<int> highlightRows = const <int>{},
    Set<int> boldColumns = const <int>{0},
    bool keep = true,
  }) {
    final List<pw.TextAlign> a =
        align ?? List<pw.TextAlign>.filled(headers.length, pw.TextAlign.left);
    pw.Widget cell(String s, int col, {bool head = false, bool hi = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 3),
          child: text(
            s,
            align: a[col],
            style: head
                ? style(fonts.semi, size - 0.4, color: Pal.maroon, spacing: 1)
                : style(
                    boldColumns.contains(col) || hi
                        ? fonts.semi
                        : fonts.regular,
                    size,
                    spacing: 1.2,
                  ),
          ),
        );

    final pw.Widget built = pw.Table(
      columnWidths: <int, pw.TableColumnWidth>{
        for (int i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      border: const pw.TableBorder(
        top: pw.BorderSide(color: Pal.gold, width: 0.9),
        bottom: pw.BorderSide(color: Pal.gold, width: 0.9),
        horizontalInside: pw.BorderSide(color: Pal.rule, width: 0.4),
      ),
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: Pal.panel),
          children: <pw.Widget>[
            for (int i = 0; i < headers.length; i++)
              cell(headers[i], i, head: true),
          ],
        ),
        for (int r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: highlightRows.contains(r)
                ? const pw.BoxDecoration(color: Pal.panel)
                : null,
            children: <pw.Widget>[
              for (int i = 0; i < rows[r].length; i++)
                cell(rows[r][i], i, hi: highlightRows.contains(r)),
            ],
          ),
      ],
    );
    // A small table stays on one page.
    return keep && rows.length <= 16 ? pw.Inseparable(child: built) : built;
  }

  /// Label and value, one to a line.
  pw.Widget kv(String label, String value, {bool strong = false}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(
          width: 122,
          child: text(
            label,
            style: style(fonts.regular, 9.4, color: Pal.inkSoft, spacing: 1.2),
          ),
        ),
        pw.Expanded(
          child: text(
            value,
            style: style(strong ? fonts.semi : fonts.regular, 10, spacing: 1.2),
          ),
        ),
      ],
    ),
  );

  // -- sections --------------------------------------------------------------

  /// A page-opening title: a rule with a diamond, the part number, the
  /// heading in the display face and a line under it.
  pw.Widget sectionTitle({
    required String id,
    required String number,
    required String title,
    String? subtitle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _Marker(id, pages),
        pw.Anchor(
          name: id,
          child: pw.Outline(
            name: id,
            title: title,
            level: 0,
            child: pw.SizedBox(height: 0.1),
          ),
        ),
        pw.SizedBox(
          height: 14,
          child: pw.CustomPaint(
            painter: (PdfGraphics g, PdfPoint s) =>
                Ornament.divider(g, 70, 7, 62),
          ),
        ),
        pw.SizedBox(height: 4),
        text(
          number,
          style: style(fonts.semi, 9.6, color: Pal.gold, spacing: 1),
        ),
        pw.SizedBox(height: 1),
        text(
          title,
          style: style(fonts.display, 26, color: Pal.maroon, spacing: 1),
        ),
        if (subtitle != null) ...<pw.Widget>[
          pw.SizedBox(height: 4),
          text(
            subtitle,
            style: style(fonts.serif, 10.6, color: Pal.inkSoft, spacing: 2.2),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Container(height: 1.1, color: Pal.maroon),
        pw.SizedBox(height: 1.6),
        pw.Container(height: 0.4, color: Pal.gold),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// A contents line: a link to the section, a dotted leader and its page.
  pw.Widget contentsLine(
    String id,
    String number,
    String title, {
    String? sub,
  }) {
    ledger.add('$number $title');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5.5),
      child: pw.Link(
        destination: id,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.SizedBox(
              width: 26,
              child: pw.Text(
                number,
                style: style(fonts.semi, 10, color: Pal.gold),
              ),
            ),
            pw.Text(title, style: style(fonts.semi, 11, spacing: 1)),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 5, right: 5, bottom: 3),
                child: pw.SizedBox(
                  height: 1,
                  child: pw.CustomPaint(
                    painter: (PdfGraphics g, PdfPoint s) {
                      // A dotted leader is one dashed stroke with round caps.
                      g.setStrokeColor(Pal.inkFaint);
                      g.setLineWidth(1.0);
                      g.setLineCap(PdfLineCap.round);
                      g.setLineDashPattern(<num>[0.1, 3.6]);
                      g.moveTo(0, 0.5);
                      g.lineTo(s.x, 0.5);
                      g.strokePath();
                      g.setLineDashPattern();
                    },
                  ),
                ),
              ),
            ),
            _LateNumber(id, pages, fonts.semi, 10, 22),
          ],
        ),
      ),
    );
  }

  // -- charts ----------------------------------------------------------------

  pw.Widget northChart(
    double size,
    List<HouseBox> houses, {
    double labelSize = 0,
    int perRow = 2,
  }) => pw.Builder(
    builder: (pw.Context c) {
      final PdfFont font = fonts.semi.getFont(c);
      return pw.SizedBox(
        width: size,
        height: size,
        child: pw.CustomPaint(
          painter: (PdfGraphics g, PdfPoint s) => ChartPaint.north(
            g,
            font,
            0,
            0,
            size,
            houses,
            labelSize: labelSize,
            perRow: perRow,
          ),
        ),
      );
    },
  );

  pw.Widget southChart(
    double size,
    List<HouseBox> houses, {
    double labelSize = 0,
    int perRow = 2,
    List<String>? centre,
  }) => pw.Builder(
    builder: (pw.Context c) {
      final PdfFont font = fonts.semi.getFont(c);
      return pw.SizedBox(
        width: size,
        height: size,
        child: pw.CustomPaint(
          painter: (PdfGraphics g, PdfPoint s) => ChartPaint.south(
            g,
            font,
            0,
            0,
            size,
            houses,
            labelSize: labelSize,
            perRow: perRow,
            centreLines: centre,
          ),
        ),
      );
    },
  );

  /// A bar for a value out of a maximum, with an optional mark.
  pw.Widget barWidget(
    double width,
    double height,
    double value,
    double maximum, {
    double? mark,
  }) => pw.SizedBox(
    width: width,
    height: height + 4,
    child: pw.CustomPaint(
      painter: (PdfGraphics g, PdfPoint s) =>
          ChartPaint.bar(g, 0, 2, width, height, value, maximum, mark: mark),
    ),
  );
}
