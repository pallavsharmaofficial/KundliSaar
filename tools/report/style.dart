/// The stylesheet: A4 pages with real margins, a running header carrying the
/// buyer's name and the chapter, page numbers, and the break rules that keep
/// a printed book's tables whole and its headings attached to what they head.
///
/// The palette is the site's (haldi, sindoor, maroon, indigo, parchment) so a
/// buyer who came from the sales page recognises what they bought.
library;

import 'i18n.dart';

/// One chapter of the book: its id doubles as the anchor and the page name.
class Chapter {
  const Chapter(this.id, this.title);

  final String id;
  final Bi title;
}

String _cssString(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\a ')
    .replaceAll('\r', '');

String reportCss({
  required Loc loc,
  required String headerName,
  required String headerBrand,
  required List<Chapter> chapters,
  required bool plainPaper,
}) {
  final StringBuffer pages = StringBuffer();
  for (final Chapter c in chapters) {
    pages.writeln(
      '@page ch_${c.id} { @top-right { content: "${_cssString(loc.plain(c.title))}"; } }',
    );
  }
  return '''
:root {
  --haldi: #e3a008;
  --sindoor: #c1272d;
  --maroon: #6b1d1d;
  --indigo: #1f2a5e;
  --ink: #221a14;
  --ink-soft: #4a3d30;
  --muted: #7a6a58;
  --gold: #b8860b;
  --paper: ${plainPaper ? '#ffffff' : '#fdf6e8'};
  --paper-deep: ${plainPaper ? '#f6efe0' : '#f4e6c9'};
  --card: ${plainPaper ? '#ffffff' : 'rgba(255,255,255,0.55)'};
  --rule: rgba(107,29,29,0.28);
  --hairline: rgba(34,26,20,0.14);
  --good: #2f6b3a;
  --warn: #9a5b00;
  --bad: #a3262b;
}

@page {
  size: A4;
  margin: 25mm 19mm 23mm 19mm;
  @top-left {
    content: "${_cssString(headerName)}";
    font: 600 8pt Mukta, sans-serif;
    color: #6b1d1d;
    vertical-align: bottom;
    padding-bottom: 2.6mm;
    border-bottom: 0.5pt solid rgba(107,29,29,0.35);
  }
  @top-right {
    content: "";
    font: 400 8pt Mukta, sans-serif;
    color: #7a6a58;
    text-align: right;
    vertical-align: bottom;
    padding-bottom: 2.6mm;
    border-bottom: 0.5pt solid rgba(107,29,29,0.35);
  }
  @bottom-center {
    content: counter(page);
    font: 400 9pt Yatra, Mukta, sans-serif;
    color: #b8860b;
    vertical-align: top;
    padding-top: 6mm;
  }
  @bottom-left {
    content: "${_cssString(headerBrand)}";
    font: 400 7pt Mukta, sans-serif;
    color: #7a6a58;
    vertical-align: top;
    padding-top: 6.6mm;
  }
}
@page cover {
  margin: 0;
  @top-left { content: none; border: none; }
  @top-right { content: none; border: none; }
  @bottom-center { content: none; }
  @bottom-left { content: none; }
}
$pages

* { box-sizing: border-box; }
html {
  background: var(--paper);
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
body {
  margin: 0;
  font-family: Mukta, sans-serif;
  font-size: 9.6pt;
  line-height: 1.55;
  color: var(--ink);
  font-kerning: normal;
  text-rendering: optimizeLegibility;
}
[lang="hi"] { font-family: Mukta, sans-serif; }
p { margin: 0 0 2.2mm; orphans: 3; widows: 3; text-wrap: pretty; }
p.hi { font-size: 10.2pt; line-height: 1.72; }
.m-both p.en { font-size: 8.9pt; line-height: 1.5; color: var(--ink-soft); }
.m-both p.hi + p.en { margin-top: -0.6mm; }
b, strong { font-weight: 600; }
.sub { color: var(--muted); }
.sub2 { display: block; font-size: 0.78em; line-height: 1.25; color: var(--muted); }
.nowrap { white-space: nowrap; }
.num { font-feature-settings: "tnum"; text-align: right; white-space: nowrap; }
.c { text-align: center; }

/* ---- chapters ---- */
.chapter { page-break-before: always; }
.chap-head {
  display: flex; align-items: flex-end; gap: 5mm;
  padding-bottom: 3.2mm; margin: 0 0 6mm; position: relative;
  border-bottom: 0.9pt solid var(--maroon);
  break-after: avoid;
}
.chap-head::after {
  content: ""; position: absolute; left: 0; right: 0; bottom: -3.2pt;
  border-bottom: 0.4pt solid var(--gold);
}
.chap-no { font: 400 31pt/0.95 Yatra, Mukta, sans-serif; color: var(--haldi); }
.chap-title {
  margin: 0; font: 400 20pt/1.18 Yatra, Mukta, sans-serif; color: var(--maroon);
}
.h-en {
  display: block; font: 600 8.6pt/1.3 Mukta, sans-serif; color: var(--muted);
  letter-spacing: 0.07em; text-transform: uppercase; margin-top: 0.8mm;
}
.chap-intro { margin: 0 0 5mm; color: var(--ink-soft); }
h2 {
  margin: 6.5mm 0 2.6mm; font: 400 13pt/1.25 Yatra, Mukta, sans-serif;
  color: var(--maroon); break-after: avoid; page-break-after: avoid;
}
h2 .h-en { font-size: 7.8pt; margin-top: 0.4mm; }
h3 {
  margin: 4mm 0 1.4mm; font: 600 10.4pt/1.3 Mukta, sans-serif;
  color: var(--indigo); break-after: avoid; page-break-after: avoid;
}
h3 .h-en { text-transform: none; letter-spacing: 0; font-size: 8.2pt; }
.keep { break-inside: avoid; page-break-inside: avoid; }
.flush-top { margin-top: 0; }

/* ---- cover ---- */
.cover {
  page: cover; width: 210mm; height: 296mm; overflow: hidden; position: relative;
  background: var(--paper); text-align: center;
}
.cover .band {
  background: var(--maroon); color: #fdf6e8; height: 98mm; padding: 17mm 20mm 0;
  position: relative;
}
.cover .band::after {
  content: ""; position: absolute; left: 0; right: 0; bottom: -2.4mm;
  height: 1.4mm; background: var(--haldi);
}
.cover .brand {
  font: 400 10pt Yatra, Mukta, sans-serif; letter-spacing: 0.28em; color: var(--haldi);
  text-transform: uppercase;
}
.cover .title {
  font: 400 40pt/1.12 Yatra, Mukta, sans-serif; margin: 7mm 0 0; color: #fdf6e8;
}
.cover .title .h-en {
  color: #e9d6ad; font: 600 11pt Mukta, sans-serif; letter-spacing: 0.22em; margin-top: 3mm;
}
.cover .tagline { margin: 6mm auto 0; max-width: 130mm; font-size: 10pt; color: #ecdcb6; }
.cover .chart-wrap { margin: 9mm auto 0; width: 112mm; }
.cover .who { margin: 7mm 0 0; font: 400 25pt/1.2 Yatra, Mukta, sans-serif; color: var(--maroon); }
.cover .born { margin: 2mm 0 0; font-size: 10.5pt; color: var(--ink-soft); }
.cover .chips {
  position: absolute; left: 20mm; right: 20mm; bottom: 24mm;
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 4mm;
}
.cover .chip {
  border-top: 1.2pt solid var(--maroon); padding-top: 2.4mm; text-align: center;
}
.cover .chip .k { font-size: 7.6pt; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }
.cover .chip .v { font: 400 14pt/1.25 Yatra, Mukta, sans-serif; color: var(--maroon); margin-top: 0.8mm; }
.cover .foot {
  position: absolute; left: 0; right: 0; bottom: 9mm; font-size: 7.6pt; color: var(--muted);
}

/* ---- contents ---- */
.toc { margin: 0; padding: 0; list-style: none; }
.toc li {
  display: flex; align-items: baseline; gap: 2mm; padding: 1.35mm 0;
  border-bottom: 0.4pt dotted rgba(34,26,20,0.3);
}
.toc a { color: inherit; text-decoration: none; display: contents; }
.toc .n { width: 8mm; font: 400 10pt Yatra, Mukta, sans-serif; color: var(--haldi); }
.toc .t { flex: 1; font-weight: 600; }
.toc .t .sub2 { font-weight: 400; }
.toc .p { font: 400 10pt Yatra, Mukta, sans-serif; color: var(--maroon); min-width: 7mm; text-align: right; }

/* ---- cards, callouts, chips ---- */
.card {
  background: var(--card); border: 0.6pt solid var(--rule); border-radius: 1.8mm;
  padding: 3.2mm 4.2mm; margin: 0 0 3.2mm; break-inside: avoid; page-break-inside: avoid;
}
.card h3 { margin-top: 0; }
.card p:last-child { margin-bottom: 0; }
.callout {
  background: var(--paper-deep); border-left: 1.4mm solid var(--haldi);
  padding: 2.8mm 4mm; margin: 3mm 0; border-radius: 0 1.4mm 1.4mm 0;
  break-inside: avoid; page-break-inside: avoid;
}
.callout p:last-child { margin-bottom: 0; }
.callout.warn { border-left-color: var(--sindoor); }
.callout.quiet { background: transparent; border-left-color: var(--rule); }
.small { font-size: 8.4pt; line-height: 1.45; color: var(--ink-soft); }
.small p, p.small { font-size: 8.4pt; line-height: 1.45; }
p.small.hi { font-size: 8.9pt; line-height: 1.6; }
.m-both p.small.en { font-size: 8pt; }
.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 4mm; }
.grid3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4mm; }
.grid4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 3.4mm; }
.stat { background: var(--card); border: 0.6pt solid var(--rule); border-radius: 1.8mm; padding: 3.2mm 3.6mm; break-inside: avoid; }
.stat .k { font-size: 7.4pt; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); }
.stat .v { font: 400 15pt/1.25 Yatra, Mukta, sans-serif; color: var(--maroon); margin: 0.6mm 0 0.8mm; }
.stat .d { font-size: 8.2pt; line-height: 1.4; color: var(--ink-soft); }
.tag {
  display: inline-block; padding: 0 1.8mm; border-radius: 1mm; font-size: 7.6pt; font-weight: 600;
  line-height: 1.55; background: var(--paper-deep); color: var(--ink-soft); white-space: nowrap;
}
.tag.good { background: rgba(47,107,58,0.13); color: var(--good); }
.tag.warn { background: rgba(154,91,0,0.14); color: var(--warn); }
.tag.bad { background: rgba(163,38,43,0.12); color: var(--bad); }
.tag.gold { background: rgba(227,160,8,0.2); color: #7a5300; }
ul.plain { margin: 0 0 2.4mm; padding-left: 4.6mm; }
ul.plain li { margin-bottom: 1.2mm; }
ul.facts { list-style: none; margin: 0 0 3mm; padding: 0; }
ul.facts li {
  padding: 1.7mm 0 1.7mm 5.2mm; position: relative; border-bottom: 0.4pt solid var(--hairline);
  break-inside: avoid;
}
ul.facts li::before {
  content: ""; position: absolute; left: 0.6mm; top: 3.3mm; width: 1.9mm; height: 1.9mm;
  background: var(--haldi); transform: rotate(45deg);
}
ul.facts li p { margin: 0; }
ul.facts li p + p { margin-top: 0.6mm; }

/* ---- tables ---- */
table.data { width: 100%; border-collapse: collapse; font-size: 8.8pt; line-height: 1.35; margin: 0 0 3mm; }
.data th {
  font: 600 7.4pt/1.25 Mukta, sans-serif; color: var(--maroon); text-align: left; vertical-align: bottom;
  padding: 1.6mm 1.4mm; border-bottom: 1.1pt solid var(--maroon);
}
.data th.num, .data th.c { vertical-align: bottom; }
.data td { padding: 1.55mm 1.4mm; border-bottom: 0.4pt solid var(--hairline); vertical-align: middle; }
.data tbody tr:nth-child(even) td { background: rgba(244,230,201,0.42); }
.data tr { break-inside: avoid; page-break-inside: avoid; }
.data thead { display: table-header-group; }
.data td.name { font-weight: 600; }
.data tr.hl td { background: rgba(227,160,8,0.17) !important; }
.data tr.total td { border-top: 1pt solid var(--maroon); font-weight: 600; }
.data td .sub2, .data th .sub2 { font-weight: 400; }
.data.tight { font-size: 8pt; }
.data.tight td { padding: 1.25mm 0.9mm; }
.data.tight th { padding: 1.3mm 0.9mm; font-size: 7pt; }

/* ---- charts ---- */
figure { margin: 0; break-inside: avoid; page-break-inside: avoid; }
figcaption { text-align: center; font-size: 8.2pt; color: var(--muted); margin-top: 1.4mm; line-height: 1.35; }
figcaption b { color: var(--maroon); font-weight: 600; }
svg.chart { display: block; width: 100%; height: auto; }
svg.chart .ln { stroke: #6b1d1d; stroke-opacity: 0.62; fill: none; stroke-width: 1.3; }
svg.chart .ln.thin { stroke-width: 0.8; stroke-opacity: 0.4; }
svg.chart .lagna-fill { fill: #e3a008; fill-opacity: 0.2; }
svg.chart text { font-family: Mukta, sans-serif; fill: #221a14; text-anchor: middle; }
svg.chart .g { font-weight: 600; }
svg.chart .gs { font-weight: 600; }
svg.chart .sg { fill: #8a6a1a; fill-opacity: 0.85; font-size: 12px; }
svg.chart .lg { fill: #6b1d1d; font-weight: 600; font-size: 10.5px; }
svg.chart .ret { fill: #c1272d; font-weight: 700; }
svg.chart .ttl { fill: #6b1d1d; font-family: Yatra, Mukta, sans-serif; }
svg.chart .ttl2 { fill: #7a6a58; }
svg.chart .big { font-weight: 600; fill: #6b1d1d; }
svg.chart .strong { fill: #2f6b3a; }
svg.chart .weak { fill: #a3262b; }

/* ---- bars ---- */
.bar { position: relative; height: 3.4mm; background: rgba(34,26,20,0.07); border-radius: 0.8mm; }
.bar > i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--maroon); border-radius: 0.8mm; }
.bar > i.ok { background: var(--good); }
.bar > i.low { background: var(--sindoor); }
.bar > i.mid { background: var(--haldi); }
.bar > u { position: absolute; top: -0.9mm; bottom: -0.9mm; width: 0.5mm; background: var(--ink); text-decoration: none; }
.legend { font-size: 8pt; color: var(--muted); margin: 1mm 0 2.5mm; }
.legend span { margin-right: 4mm; white-space: nowrap; }
.sw { display: inline-block; width: 2.8mm; height: 2.8mm; border-radius: 0.6mm; vertical-align: -0.5mm; margin-right: 1.1mm; }

/* ---- Lo Shu ---- */
table.loshu { border-collapse: separate; border-spacing: 1.6mm; margin: 0 auto; }
.loshu td {
  width: 19mm; height: 19mm; text-align: center; vertical-align: middle;
  border: 0.8pt solid var(--rule); border-radius: 1.6mm; background: var(--card);
  font: 400 15pt Yatra, Mukta, sans-serif; color: var(--maroon); position: relative;
}
.loshu td.has { background: rgba(227,160,8,0.22); }
.loshu td small {
  position: absolute; left: 1.5mm; top: 0.8mm; font: 400 6.6pt Mukta, sans-serif; color: var(--muted);
}
.loshu td.none { color: rgba(34,26,20,0.28); }
.ornament { text-align: center; color: var(--gold); margin: 4mm 0; font-size: 9pt; letter-spacing: 0.6em; }
.rule-gold { border: 0; border-top: 0.5pt solid var(--gold); margin: 4mm 0; }
a { color: var(--indigo); text-decoration: none; }
''';
}
