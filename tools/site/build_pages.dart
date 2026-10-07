/// Generates the Learn section of the website from the app's own engine:
/// 27 nakshatra pages, 12 rashi pages, 9 graha pages and the index that links
/// them, written to site/learn/, plus the sitemap.
///
///     dart run tools/site/build_pages.dart
///
/// The output is a pure function of the engine: nothing here reads the clock,
/// so a rebuild that changes no engine data changes no file. The generator
/// refuses to write anything if a page fails its checks (prose length,
/// broken internal links, a leaked placeholder), because a half-published
/// reference section is worse than yesterday's whole one.
library;

import 'dart:io';

import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';

import 'common.dart';
import 'glossary_hi.dart';
import 'graha_pages.dart';
import 'nakshatra_pages.dart';
import 'rashi_pages.dart';

const String _indexPath = 'learn/index.html';

String _card(
  String from,
  PageRef ref,
  String number,
  String detailEn,
  String detailHi,
) =>
    '''
      <a class="card" href="${escAttr(rel(from, ref.path))}">
        <h3>$number${esc(ref.english)} <span class="h3-hi" lang="hi">${esc(ref.hindi)}</span></h3>
        <p>${esc(detailEn)}<br><span lang="hi">${esc(detailHi)}</span></p>
      </a>''';

String _buildIndex() {
  final List<PageRef> naks = nakshatraRefs();
  final List<PageRef> rashis = rashiRefs();
  final List<PageRef> grahas = grahaRefs();

  // The sidereal and tropical zodiacs are about this far apart today, read
  // from the engine's own ayanamsa at the date the prose was last revised.
  final DateTime revised = DateTime.parse('${referenceUpdated}T00:00:00Z');
  final double offset = ayanamsaDegrees(
    Ayanamsa.lahiri,
    Instant.fromUtc(revised).centuriesTt,
  );
  final String offsetText = offset.floor().toString();

  final List<List<String>> dashaRows = <List<String>>[
    for (int i = 0; i < vimshottariOrder.length; i++)
      () {
        final Graha lord = vimshottariOrder[i];
        final GrahaInfo info = grahaInfo(lord);
        final List<NakshatraInfo> ruled = <NakshatraInfo>[
          for (final NakshatraInfo n in nakshatraTable)
            if (n.lord == lord) n,
        ];
        return <String>[
          '${i + 1}',
          '${link(_indexPath, grahas[grahaIndexOf(lord)].path, esc(info.english))} · <span lang="hi">${esc(info.hindi)}</span>',
          '${vimshottariYears[lord]!.round()}',
          ruled
              .map(
                (NakshatraInfo n) =>
                    '${link(_indexPath, naks[n.index].path, esc(n.english))} <span lang="hi">(${esc(n.hindi)})</span>',
              )
              .join(', '),
        ];
      }(),
  ];

  const String introEn = '''
    <h2>A working reference to the nakshatras, rashis and grahas</h2>
    <p class="prose">Vedic astrology, or Jyotish, describes a birth chart with three vocabularies. The 27 nakshatras divide the zodiac into equal lunar mansions of 13°20′. The 12 rashis divide it into signs of 30°. The nine grahas are the Sun, the Moon, the five visible planets and the two lunar nodes, Rahu and Ketu. Every page below gives the facts the KundliSaar app computes with, taken from the same code, in English and in Hindi.</p>
    <p class="prose">Start with the Moon. Your janma nakshatra and janma rashi are the nakshatra and sign the Moon occupied when you were born, and the lord of that nakshatra decides which Vimshottari dasha you begin life in. The table below lists each dasha lord, its years in the 120-year cycle and the three nakshatras it rules.</p>
''';
  final String introEn2 =
      '''
    <p class="prose">All degrees are sidereal, measured against the stars on the Lahiri ayanamsa, which is why they sit about $offsetText° behind the tropical signs of a Western horoscope. Where the tradition differs between authorities, the page says so instead of picking a side quietly.</p>
${ctaBlock(from: _indexPath, heading: (en: 'Find your own nakshatra', hi: ''), body: (en: 'The Moon’s position at your birth needs your date, time and place. KundliSaar works it out on your device, free and without an account.', hi: ''), button: (en: 'Open the app', hi: ''), hindi: false)}
''';
  const String introHi = '''
    <h2>नक्षत्र, राशि और ग्रह: एक उपयोगी संदर्भ</h2>
    <p class="prose">वैदिक ज्योतिष, यानी जातक शास्त्र, कुंडली को तीन शब्दावलियों से पढ़ता है। 27 नक्षत्र राशिचक्र को 13°20′ के बराबर चंद्र-भवनों में बाँटते हैं। 12 राशियाँ उसे 30° की राशियों में बाँटती हैं। नौ ग्रह हैं सूर्य, चंद्र, पाँच दृश्य ग्रह और दो चंद्र-पात, राहु और केतु। नीचे के हर पन्ने में वही तथ्य हैं जिनसे कुंडलीसार गणना करता है, उसी कोड से लिए गए, हिंदी और अंग्रेज़ी दोनों में।</p>
    <p class="prose">शुरुआत चंद्रमा से करें। आपका जन्म नक्षत्र और जन्म राशि वे हैं जिनमें जन्म के समय चंद्रमा था, और उस नक्षत्र के स्वामी से तय होता है कि आप जीवन की शुरुआत किस विंशोत्तरी दशा में करते हैं। नीचे की तालिका में हर दशा-स्वामी, 120 वर्ष के चक्र में उसके वर्ष और उसके तीन नक्षत्र दिए हैं।</p>
''';
  final String introHi2 =
      '''
    <p class="prose">सभी अंश निरयन हैं, यानी तारों के सापेक्ष, लाहिरी अयनांश पर; इसीलिए वे पश्चिमी कुंडली की सायन राशियों से लगभग $offsetText° पीछे रहते हैं। जहाँ परंपरा में विद्वानों के बीच मतभेद है, वहाँ पन्ना चुपचाप कोई पक्ष नहीं चुनता, साफ़ कहता है।</p>
${ctaBlock(from: _indexPath, heading: (en: '', hi: 'अपना नक्षत्र जानें'), body: (en: '', hi: 'जन्म के समय चंद्रमा कहाँ था, यह जानने के लिए तारीख़, समय और स्थान चाहिए। कुंडलीसार इसे आपके फ़ोन पर ही निकालता है; मुफ़्त और बिना खाते के।'), button: (en: '', hi: 'ऐप खोलें'), hindi: true)}
''';

  final String dashaTable = tableHtml(
    headers: <String>[
      'Order · क्रम',
      'Dasha lord · दशा स्वामी',
      'Years · वर्ष',
      'Nakshatras · नक्षत्र',
    ],
    rows: dashaRows,
    caption: 'The Vimshottari cycle at a glance · विंशोत्तरी चक्र एक नज़र में',
  );

  final StringBuffer nakCards = StringBuffer();
  for (final NakshatraInfo n in nakshatraTable) {
    final RashiInfo rashi = rashiInfo(Rashi.values[n.index * 800 ~/ 1800]);
    nakCards.writeln(
      _card(
        _indexPath,
        naks[n.index],
        '${n.index + 1}. ',
        'Lord ${grahaInfo(n.lord).english} · ${rashi.english}',
        'स्वामी ${grahaInfo(n.lord).hindi} · ${rashi.hindi}',
      ),
    );
  }
  final StringBuffer rashiCards = StringBuffer();
  for (final RashiInfo r in rashiTable) {
    rashiCards.writeln(
      _card(
        _indexPath,
        rashis[r.rashi.index],
        '${r.rashi.index + 1}. ',
        'Lord ${grahaInfo(r.lord).english} · ${elementEnglish(r.element)}',
        'स्वामी ${grahaInfo(r.lord).hindi} · ${elementHindi(r.element)}',
      ),
    );
  }
  final StringBuffer grahaCards = StringBuffer();
  for (final GrahaInfo g in grahaTable) {
    grahaCards.writeln(
      _card(
        _indexPath,
        grahas[grahaIndexOf(g.graha)],
        '',
        g.karaka,
        karakaHindi(g.karaka),
      ),
    );
  }

  final String body =
      '''
  <section id="english" lang="en">
$introEn$introEn2  </section>

  <section id="hindi" lang="hi">
$introHi$introHi2  </section>

  <section id="dasha">
    <h2>Which nakshatras belong to which dasha lord · किस दशा-स्वामी के कौन-से नक्षत्र</h2>
$dashaTable  </section>

  <section id="nakshatras">
    <h2>The 27 nakshatras · 27 नक्षत्र</h2>
    <p class="note">In zodiac order from Ashwini, with the lord of each and the sign it begins in. · अश्विनी से राशिचक्र के क्रम में, हर नक्षत्र का स्वामी और वह राशि जिसमें वह आरंभ होता है।</p>
    <div class="grid">
$nakCards    </div>
  </section>

  <section id="rashis">
    <h2>The 12 rashis · 12 राशियाँ</h2>
    <p class="note">From Mesha to Meena, with each sign's lord and element. · मेष से मीन तक, हर राशि का स्वामी और तत्व।</p>
    <div class="grid">
$rashiCards    </div>
  </section>

  <section id="grahas">
    <h2>The 9 grahas · 9 ग्रह</h2>
    <p class="note">In the order the app lists them, with what each signifies. · ऐप के क्रम में, हर ग्रह किसका कारक है।</p>
    <div class="grid">
$grahaCards    </div>
  </section>
''';

  const String title =
      'Nakshatras, Rashis and Grahas: Vedic Astrology Reference (नक्षत्र, राशि, ग्रह)';
  const String description =
      'A bilingual reference to the 27 nakshatras, 12 rashis and 9 grahas of Vedic astrology: lords, deities, padas, signs, dignities and dasha years. नक्षत्र, राशि और ग्रह की हिंदी-अंग्रेज़ी संदर्भ सूची।';
  final List<Crumb> crumbs = <Crumb>[
    const Crumb('KundliSaar', ''),
    const Crumb('Learn', 'learn/'),
  ];
  final List<PageRef> all = <PageRef>[...naks, ...rashis, ...grahas];
  checkText(_indexPath, body);
  return renderPage(
    PageSpec(
      path: _indexPath,
      title: title,
      description: description,
      ogType: 'website',
      heading:
          'Learn <span class="h1-hi" lang="hi">· नक्षत्र, राशि और ग्रह सीखें</span>',
      lede:
          'The 27 nakshatras, 12 rashis and 9 grahas, in English and Hindi. <a href="#nakshatras">Nakshatras</a> · <a href="#rashis">Rashis</a> · <a href="#grahas">Grahas</a>',
      body: body,
      crumbs: crumbs,
      jumpLinks: true,
      jsonLd: <Map<String, Object?>>[
        <String, Object?>{
          '@type': 'CollectionPage',
          'name': 'Nakshatras, Rashis and Grahas',
          'description': description,
          'inLanguage': <String>['en', 'hi'],
          'url': '$siteBase$_indexPath',
          'dateModified': referenceUpdated,
          'publisher': publisherLd,
          'mainEntity': <String, Object?>{
            '@type': 'ItemList',
            'numberOfItems': all.length,
            'itemListElement': <Object?>[
              for (int i = 0; i < all.length; i++)
                <String, Object?>{
                  '@type': 'ListItem',
                  'position': i + 1,
                  'name': '${all[i].english} (${all[i].hindi})',
                  'url': all[i].url,
                },
            ],
          },
        },
        breadcrumbLd(crumbs, '$siteBase$_indexPath'),
      ],
    ),
  );
}

/// Every relative link on every generated page must land on a page the
/// generator is writing or a file already in site/. A broken link in a
/// reference section is the kind of thing a crawler reports and a reader
/// never forgives.
void _checkLinks(Map<String, String> pages, Directory site) {
  // These are produced by other steps of the same deploy.
  const Set<String> external = <String>{'app/', 'panchang/', ''};
  final RegExp hrefs = RegExp(r'''href="([^"]+)"''');
  for (final MapEntry<String, String> entry in pages.entries) {
    final List<String> base = entry.key.split('/')..removeLast();
    for (final RegExpMatch m in hrefs.allMatches(entry.value)) {
      final String href = m.group(1)!;
      if (href.startsWith('http') || href.startsWith('#')) continue;
      final String bare = href.split('#').first;
      final List<String> parts = <String>[...base];
      for (final String piece in bare.split('/')) {
        if (piece == '..') {
          if (parts.isNotEmpty) parts.removeLast();
        } else if (piece != '.' && piece.isNotEmpty) {
          parts.add(piece);
        }
      }
      final String target = parts.join('/') + (bare.endsWith('/') ? '/' : '');
      if (external.contains(target) || bare == './') continue;
      final String file = target.endsWith('/') ? '${target}index.html' : target;
      final bool exists =
          pages.containsKey(file) || File('${site.path}/$file').existsSync();
      check(exists, '${entry.key}: link to "$href" goes nowhere ($file)');
    }
  }
}

int _visibleWords(String html) {
  final String body = html.contains('<body>')
      ? html.substring(html.indexOf('<body>'))
      : html;
  return wordCount(plainText(body));
}

void main(List<String> args) {
  final Directory site = siteDir();
  final Map<String, String> pages = <String, String>{
    ...buildNakshatraPages(),
    ...buildRashiPages(),
    ...buildGrahaPages(),
    _indexPath: _buildIndex(),
  };
  check(
    pages.length == 27 + 12 + 9 + 1,
    'expected 49 pages (48 reference pages and the index), built ${pages.length}',
  );
  _checkLinks(pages, site);

  // `--show=rohini` prints the prose of one page with its word count, which is
  // how the 150-250 word budget gets tuned without opening a browser.
  for (final String arg in args.where((String a) => a.startsWith('--show='))) {
    final String slug = arg.substring('--show='.length);
    for (final MapEntry<String, String> entry in pages.entries) {
      if (!entry.key.endsWith('/$slug.html')) continue;
      stdout.writeln('--- ${entry.key}');
      for (final RegExpMatch m in RegExp(
        r'<p class="prose">(.*?)</p>',
        dotAll: true,
      ).allMatches(entry.value)) {
        final String text = plainText(m.group(1)!).replaceAll(RegExp(r'\s+'), ' ').trim();
        stdout.writeln('[${wordCount(text)}] $text\n');
      }
    }
  }
  finishOrFail();

  // The learn folder is wholly generated, so anything in it that this run did
  // not produce is a leftover from a rename and would be a dead page.
  final Directory learn = Directory('${site.path}/learn');
  int removed = 0;
  if (learn.existsSync()) {
    for (final FileSystemEntity entity in learn.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.html')) continue;
      final String relative = entity.path.substring(site.path.length + 1);
      if (!pages.containsKey(relative)) {
        entity.deleteSync();
        removed++;
      }
    }
  }

  int written = 0;
  for (final MapEntry<String, String> entry in pages.entries) {
    if (writeIfChanged(File('${site.path}/${entry.key}'), entry.value)) {
      written++;
    }
  }
  final bool sitemapChanged = writeSitemap(
    site,
    panchangDate: panchangDateOnDisk(site),
  );

  int proseEn = 0;
  int proseHi = 0;
  for (final Map<String, (int, int)> group in <Map<String, (int, int)>>[
    nakshatraProseWords,
    rashiProseWords,
    grahaProseWords,
  ]) {
    for (final (int, int) words in group.values) {
      proseEn += words.$1;
      proseHi += words.$2;
    }
  }
  final int visible = pages.values.fold<int>(
    0,
    (int sum, String html) => sum + _visibleWords(html),
  );
  stdout.writeln(
    'Learn section: ${pages.length} pages (${pages.length - 1} reference pages + index), '
    '$written written, ${pages.length - written} unchanged, $removed stale removed.',
  );
  stdout.writeln(
    'Prose: $proseEn English + $proseHi Hindi words in the explanatory paragraphs; '
    '$visible visible words across all pages.',
  );
  stdout.writeln(
    'Sitemap: ${sitemapChanged ? 'updated' : 'unchanged'}.',
  );
}
