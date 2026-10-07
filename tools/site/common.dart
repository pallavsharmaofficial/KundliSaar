/// What the two site generators share: where the site lives, the page shell
/// that makes every generated page look like the hand-written ones, JSON-LD,
/// the sitemap, and the guards that stop a bad page from being published.
///
/// Nothing in here knows any astrology. The facts all come from the engine in
/// lib/engine; this file only knows how to put them on a page.
library;

import 'dart:convert';
import 'dart:io';

import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';

/// The site is a GitHub project page, so everything lives under /KundliSaar/.
/// That is also why internal links are relative: an absolute "/app/" would
/// point at the account's root and 404.
const String siteBase = 'https://pallavsharmaofficial.github.io/KundliSaar/';

/// When the reference prose was last meaningfully revised. This is a constant
/// on purpose: a date taken from the clock would change every build and make
/// every generated page differ for no reason. Bump it when the wording changes.
const String referenceUpdated = '2026-10-07';

/// An English and a Hindi rendering of the same thing.
typedef Bi = ({String en, String hi});

/// The repository root, found from this script's own location so the
/// generators work from any working directory.
Directory repoRoot() {
  final Directory fromScript = File.fromUri(
    Platform.script,
  ).parent.parent.parent;
  if (Directory('${fromScript.path}/site').existsSync()) return fromScript;
  if (Directory('site').existsSync()) return Directory.current;
  throw StateError('Run from the repository root: dart run tools/site/<x>.dart');
}

Directory siteDir() => Directory('${repoRoot().path}/site');

/// Writes [content] only when it differs from what is on disk, so a rebuild
/// that changes nothing touches nothing. Returns whether it wrote.
bool writeIfChanged(File file, String content) {
  if (file.existsSync() && file.readAsStringSync() == content) return false;
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  return true;
}

String esc(String text) => const HtmlEscape(HtmlEscapeMode.element).convert(text);

String escAttr(String text) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

/// Everything the generators publish at one URL.
class PageRef {
  const PageRef({
    required this.kind,
    required this.slug,
    required this.english,
    required this.hindi,
    required this.path,
  });

  /// 'nakshatra', 'rashi' or 'graha'.
  final String kind;
  final String slug;
  final String english;
  final String hindi;

  /// Path from the site root, for example learn/nakshatra/rohini.html.
  final String path;

  String get url => '$siteBase$path';
}

/// Position of a graha in the engine's table, which is also its page's index.
int grahaIndexOf(Graha graha) =>
    grahaTable.indexWhere((GrahaInfo info) => info.graha == graha);

String slugOf(String english) =>
    english.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

List<PageRef> nakshatraRefs() => <PageRef>[
  for (final NakshatraInfo n in nakshatraTable)
    PageRef(
      kind: 'nakshatra',
      slug: slugOf(n.english),
      english: n.english,
      hindi: n.hindi,
      path: 'learn/nakshatra/${slugOf(n.english)}.html',
    ),
];

List<PageRef> rashiRefs() => <PageRef>[
  for (final RashiInfo r in rashiTable)
    PageRef(
      kind: 'rashi',
      slug: slugOf(r.english),
      english: r.english,
      hindi: r.hindi,
      path: 'learn/rashi/${slugOf(r.english)}.html',
    ),
];

List<PageRef> grahaRefs() => <PageRef>[
  for (final GrahaInfo g in grahaTable)
    PageRef(
      kind: 'graha',
      slug: slugOf(g.english),
      english: g.english,
      hindi: g.hindi,
      path: 'learn/graha/${slugOf(g.english)}.html',
    ),
];

/// A relative URL from one site path to another. A trailing slash means a
/// directory and the empty string means the site root.
String rel(String from, String to) {
  final List<String> fromDirs = from.split('/')..removeLast();
  final List<String> toParts = to.split('/');
  int shared = 0;
  while (shared < fromDirs.length &&
      shared < toParts.length - 1 &&
      fromDirs[shared] == toParts[shared]) {
    shared++;
  }
  final String up = '../' * (fromDirs.length - shared);
  final String down = toParts.sublist(shared).join('/');
  final String joined = '$up$down';
  return joined.isEmpty ? './' : joined;
}

String joinEnglish(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

String joinHindi(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} और ${items.last}';
}

/// 13°20′ from arc-minutes.
String arcText(int arcMinutes) {
  final int degrees = arcMinutes ~/ 60;
  final int minutes = arcMinutes % 60;
  return '$degrees°${minutes.toString().padLeft(2, '0')}′';
}

/// "7 years 6 months" from a number of months.
String monthsEnglish(int months) {
  if (months == 0) return 'none';
  final int years = months ~/ 12;
  final int rest = months % 12;
  final List<String> parts = <String>[
    if (years > 0) '$years ${years == 1 ? 'year' : 'years'}',
    if (rest > 0) '$rest ${rest == 1 ? 'month' : 'months'}',
  ];
  return parts.join(' ');
}

String monthsHindi(int months) {
  if (months == 0) return 'कुछ नहीं';
  final int years = months ~/ 12;
  final int rest = months % 12;
  final List<String> parts = <String>[
    if (years > 0) '$years वर्ष',
    if (rest > 0) '$rest माह',
  ];
  return parts.join(' ');
}

// ---------------------------------------------------------------------------
// Page shell
// ---------------------------------------------------------------------------

/// A link from the page at [from] to the site path [to].
String link(String from, String to, String text, {String? lang}) =>
    '<a href="${escAttr(rel(from, to))}"${lang == null ? '' : ' lang="$lang"'}>$text</a>';

/// A table that scrolls sideways on a phone instead of breaking the layout.
String tableHtml({
  required List<String> headers,
  required List<List<String>> rows,
  String? caption,
  String cssClass = '',
}) {
  final StringBuffer out = StringBuffer()
    ..writeln('<div class="scroll">')
    ..writeln('<table${cssClass.isEmpty ? '' : ' class="$cssClass"'}>');
  if (caption != null) out.writeln('<caption>${esc(caption)}</caption>');
  out
    ..writeln('<thead><tr>')
    ..writeln(
      headers.map((String h) => '<th scope="col">$h</th>').join(),
    )
    ..writeln('</tr></thead>')
    ..writeln('<tbody>');
  for (final List<String> row in rows) {
    out.writeln('<tr>${row.map((String c) => '<td>$c</td>').join()}</tr>');
  }
  out
    ..writeln('</tbody>')
    ..writeln('</table>')
    ..writeln('</div>');
  return out.toString();
}

/// A two-column table of facts, label then value.
String factsHtml(List<(String, String)> rows) {
  final StringBuffer out = StringBuffer()
    ..writeln('<div class="scroll">')
    ..writeln('<table class="facts">')
    ..writeln('<tbody>');
  for (final (String label, String value) in rows) {
    out.writeln('<tr><th scope="row">$label</th><td>$value</td></tr>');
  }
  out
    ..writeln('</tbody>')
    ..writeln('</table>')
    ..writeln('</div>');
  return out.toString();
}

class Crumb {
  const Crumb(this.name, this.path);
  final String name;

  /// Site path of the crumb, or an anchor-bearing path.
  final String path;
}

class SiblingLink {
  const SiblingLink({required this.path, required this.title});
  final String path;

  /// Already-escaped HTML for the link text.
  final String title;
}

/// Everything needed to emit one page.
class PageSpec {
  const PageSpec({
    required this.path,
    required this.title,
    required this.description,
    required this.heading,
    required this.lede,
    required this.body,
    required this.crumbs,
    required this.jsonLd,
    this.ogType = 'article',
    this.previous,
    this.next,
    this.jumpLinks = false,
    this.extraHead = '',
  });

  final String path;
  final String title;
  final String description;

  /// HTML for the h1.
  final String heading;

  /// HTML for the sub line under the h1.
  final String lede;
  final String body;
  final List<Crumb> crumbs;
  final List<Map<String, Object?>> jsonLd;
  final String ogType;
  final SiblingLink? previous;
  final SiblingLink? next;

  /// Whether to show the English / Hindi jump links under the heading.
  final bool jumpLinks;
  final String extraHead;
}

String ldScript(List<Map<String, Object?>> graph) {
  final String json = const JsonEncoder.withIndent('  ').convert(
    <String, Object?>{'@context': 'https://schema.org', '@graph': graph},
  );
  // A literal "</script>" inside a string would end the block early.
  return '<script type="application/ld+json">\n${json.replaceAll('</', r'<\/')}\n</script>';
}

Map<String, Object?> breadcrumbLd(List<Crumb> crumbs, String pageUrl) =>
    <String, Object?>{
      '@type': 'BreadcrumbList',
      'itemListElement': <Object?>[
        for (int i = 0; i < crumbs.length; i++)
          <String, Object?>{
            '@type': 'ListItem',
            'position': i + 1,
            'name': crumbs[i].name,
            'item': '$siteBase${crumbs[i].path}',
          },
      ],
    };

/// The publisher block every Article points at.
const Map<String, Object?> publisherLd = <String, Object?>{
  '@type': 'Organization',
  'name': 'KundliSaar',
  'url': siteBase,
  'logo': <String, Object?>{
    '@type': 'ImageObject',
    'url': '${siteBase}favicon.png',
  },
};

Map<String, Object?> articleLd({
  required String path,
  required String headline,
  required String description,
  required String dateModified,
  String datePublished = referenceUpdated,
}) => <String, Object?>{
  '@type': 'Article',
  'headline': headline,
  'description': description,
  'inLanguage': <String>['en', 'hi'],
  'datePublished': datePublished,
  'dateModified': dateModified,
  'mainEntityOfPage': '$siteBase$path',
  'image': '${siteBase}og-image.png',
  'author': publisherLd,
  'publisher': publisherLd,
};

String renderPage(PageSpec spec) {
  final String url = '$siteBase${spec.path}';
  final String root = rel(spec.path, '');
  final StringBuffer out = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('<title>${esc(spec.title)}</title>')
    ..writeln('<meta name="description" content="${escAttr(spec.description)}">')
    ..writeln('<link rel="canonical" href="${escAttr(url)}">');
  if (spec.previous != null) {
    out.writeln(
      '<link rel="prev" href="${escAttr(rel(spec.path, spec.previous!.path))}">',
    );
  }
  if (spec.next != null) {
    out.writeln(
      '<link rel="next" href="${escAttr(rel(spec.path, spec.next!.path))}">',
    );
  }
  out
    ..writeln('<link rel="icon" type="image/png" href="${root}favicon.png">')
    ..writeln('<meta name="theme-color" content="#6B1D1D">')
    ..writeln('<link rel="preconnect" href="https://fonts.googleapis.com">')
    ..writeln(
      '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
    )
    ..writeln(
      '<link href="https://fonts.googleapis.com/css2?family=Mukta:wght@400;600;700&family=Yatra+One&display=swap" rel="stylesheet">',
    )
    ..writeln('<meta property="og:type" content="${spec.ogType}">')
    ..writeln('<meta property="og:site_name" content="KundliSaar">')
    ..writeln('<meta property="og:title" content="${escAttr(spec.title)}">')
    ..writeln(
      '<meta property="og:description" content="${escAttr(spec.description)}">',
    )
    ..writeln('<meta property="og:image" content="${siteBase}og-image.png">')
    ..writeln('<meta property="og:url" content="${escAttr(url)}">')
    ..writeln('<meta property="og:locale" content="en_IN">')
    ..writeln('<meta property="og:locale:alternate" content="hi_IN">')
    ..writeln('<meta name="twitter:card" content="summary_large_image">');
  if (spec.extraHead.isNotEmpty) out.writeln(spec.extraHead);
  out
    ..writeln('<link rel="stylesheet" href="${root}style.css">')
    ..writeln(ldScript(spec.jsonLd))
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<div class="wrap">')
    ..writeln('  <header class="plain page-head">')
    ..writeln('    <nav class="topnav" aria-label="Site">')
    ..writeln('      <a href="$root">KundliSaar</a>')
    ..writeln('      <a href="${root}learn/">Learn · सीखें</a>')
    ..writeln('      <a href="${root}panchang/">Panchang · पंचांग</a>')
    ..writeln('      <a href="${root}app/">Open the app · ऐप</a>')
    ..writeln('    </nav>');
  if (spec.crumbs.length > 1) {
    out.writeln('    <nav class="crumbs" aria-label="Breadcrumb"><ol>');
    for (int i = 0; i < spec.crumbs.length; i++) {
      final Crumb crumb = spec.crumbs[i];
      final bool last = i == spec.crumbs.length - 1;
      out.writeln(
        last
            ? '      <li aria-current="page">${esc(crumb.name)}</li>'
            : '      <li><a href="${escAttr(rel(spec.path, crumb.path))}">${esc(crumb.name)}</a></li>',
      );
    }
    out.writeln('    </ol></nav>');
  }
  out
    ..writeln('    <h1>${spec.heading}</h1>')
    ..writeln('    <p class="sub">${spec.lede}</p>');
  if (spec.jumpLinks) {
    out.writeln(
      '    <p class="langjump"><a href="#english">Read in English</a> · <a href="#hindi" lang="hi">हिन्दी में पढ़ें</a></p>',
    );
  }
  out
    ..writeln('  </header>')
    ..writeln('  <main>')
    ..write(spec.body)
    ..writeln('  </main>');
  if (spec.previous != null || spec.next != null) {
    out.writeln('  <nav class="sibs" aria-label="Neighbouring pages">');
    if (spec.previous != null) {
      out.writeln(
        '    <a class="sib prev" rel="prev" href="${escAttr(rel(spec.path, spec.previous!.path))}"><span class="dir">← Previous · पिछला</span>${spec.previous!.title}</a>',
      );
    } else {
      out.writeln('    <span></span>');
    }
    if (spec.next != null) {
      out.writeln(
        '    <a class="sib next" rel="next" href="${escAttr(rel(spec.path, spec.next!.path))}"><span class="dir">Next · अगला →</span>${spec.next!.title}</a>',
      );
    }
    out.writeln('  </nav>');
  }
  out
    ..writeln('  <footer>')
    ..writeln(
      '    <p>Built by <a href="https://github.com/pallavsharmaofficial">pallavsharmaofficial</a> · MIT licensed · Ephemeris from JPL DE440s</p>',
    )
    ..writeln(
      '    <p>Traditional Vedic guidance and cultural material, not medical, legal or financial advice. · पारंपरिक वैदिक जानकारी, चिकित्सा, कानूनी या वित्तीय सलाह नहीं।</p>',
    )
    ..writeln(
      '    <p><a href="${root}learn/">Learn</a> · <a href="${root}panchang/">Panchang</a> · <a href="${root}privacy.html">Privacy</a> · <a href="${root}terms.html">Terms</a> · <a href="${root}app/">Open the app</a></p>',
    )
    ..writeln('  </footer>')
    ..writeln('</div>')
    ..writeln('</body>')
    ..writeln('</html>');
  return out.toString();
}

/// The call to action that closes each language section.
String ctaBlock({
  required String from,
  required Bi heading,
  required Bi body,
  required Bi button,
  required bool hindi,
}) {
  final String text = hindi ? body.hi : body.en;
  final String title = hindi ? heading.hi : heading.en;
  final String label = hindi ? button.hi : button.en;
  return '''
<aside class="callout">
  <h3>${esc(title)}</h3>
  <p>${esc(text)}</p>
  <p><a class="btn primary" href="${escAttr(rel(from, 'app/'))}">${esc(label)}</a></p>
</aside>
''';
}

// ---------------------------------------------------------------------------
// Sitemap
// ---------------------------------------------------------------------------

class SitemapEntry {
  const SitemapEntry({
    required this.path,
    required this.priority,
    this.changefreq,
    this.lastmod,
  });

  final String path;
  final String priority;
  final String? changefreq;
  final String? lastmod;

  String render() {
    final StringBuffer out = StringBuffer()
      ..writeln('  <url>')
      ..writeln('    <loc>$siteBase$path</loc>');
    if (lastmod != null) out.writeln('    <lastmod>$lastmod</lastmod>');
    if (changefreq != null) {
      out.writeln('    <changefreq>$changefreq</changefreq>');
    }
    out
      ..writeln('    <priority>$priority</priority>')
      ..write('  </url>');
    return out.toString();
  }
}

/// The date the panchang page was last generated, read back from the page
/// itself so the sitemap and the page can never disagree.
String? panchangDateOnDisk(Directory site) {
  final File page = File('${site.path}/panchang/index.html');
  if (!page.existsSync()) return null;
  final RegExpMatch? match = RegExp(
    r'<meta name="kundlisaar:generated" content="(\d{4}-\d{2}-\d{2})">',
  ).firstMatch(page.readAsStringSync());
  return match?.group(1);
}

/// Rewrites site/sitemap.xml: every entry that is not ours is kept exactly as
/// it was, so a page someone else adds by hand is never dropped, and the
/// generated section is rebuilt from the engine's own tables.
bool writeSitemap(Directory site, {String? panchangDate}) {
  final File file = File('${site.path}/sitemap.xml');
  final String existing = file.existsSync() ? file.readAsStringSync() : '';
  final List<String> kept = <String>[
    for (final RegExpMatch m in RegExp(
      r'<url>.*?</url>',
      dotAll: true,
    ).allMatches(existing))
      if (!m.group(0)!.contains('<loc>${siteBase}learn/') &&
          !m.group(0)!.contains('<loc>${siteBase}panchang/'))
        '  ${m.group(0)!}',
  ];
  final List<SitemapEntry> ours = <SitemapEntry>[
    SitemapEntry(
      path: 'panchang/',
      priority: '0.8',
      changefreq: 'daily',
      lastmod: panchangDate,
    ),
    const SitemapEntry(path: 'learn/', priority: '0.8', changefreq: 'monthly'),
    for (final PageRef ref in <PageRef>[
      ...nakshatraRefs(),
      ...rashiRefs(),
      ...grahaRefs(),
    ])
      SitemapEntry(path: ref.path, priority: '0.6', changefreq: 'monthly'),
  ];
  final StringBuffer out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final String block in kept) {
    out.writeln(block);
  }
  for (final SitemapEntry entry in ours) {
    out.writeln(entry.render());
  }
  out.writeln('</urlset>');
  return writeIfChanged(file, out.toString());
}

// ---------------------------------------------------------------------------
// Guards
// ---------------------------------------------------------------------------

/// Visible text of an HTML fragment.
String plainText(String html) => html
    .replaceAll(RegExp(r'<script.*?</script>', dotAll: true), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&nbsp;', ' ');

int wordCount(String text) => text
    .split(RegExp(r'\s+'))
    .where((String w) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(w))
    .length;

/// Problems found while generating. The scripts print them and exit non-zero
/// rather than quietly publish a page that is wrong.
final List<String> problems = <String>[];

void check(bool condition, String message) {
  if (!condition) problems.add(message);
}

/// Hindi letters written as one code point instead of base plus nukta search
/// and render inconsistently, and every string in the engine uses the split
/// form, so a stray precomposed one means a typo.
void checkText(String label, String html) {
  for (final int rune in html.runes) {
    if (rune >= 0x0958 && rune <= 0x095F) {
      problems.add(
        '$label: contains precomposed nukta letter U+${rune.toRadixString(16).toUpperCase()}',
      );
      return;
    }
  }
  if (html.contains('null') && RegExp(r'\bnull\b').hasMatch(plainText(html))) {
    problems.add('$label: the word "null" leaked into visible text');
  }
  if (html.contains(r'$')) {
    final String visible = plainText(html);
    if (RegExp(r'\$\{|\$[a-zA-Z]').hasMatch(visible)) {
      problems.add('$label: an unexpanded interpolation leaked into the page');
    }
  }
}

void finishOrFail() {
  if (problems.isEmpty) return;
  stderr.writeln('The site was not published cleanly:');
  for (final String problem in problems) {
    stderr.writeln('  - $problem');
  }
  exit(1);
}
