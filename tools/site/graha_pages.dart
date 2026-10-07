/// The nine graha pages.
///
/// Dignity, remedies and dasha years come straight from the engine tables.
/// Rahu and Ketu are the cases where the tradition itself disagrees (their
/// exaltation signs, whether they own any sign, which day they are fasted
/// on), so those pages say plainly that the values are one convention.
library;

import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/panchang.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/remedies.dart';
import 'package:kundlisaar/engine/jyotish/transits.dart';

import 'common.dart';
import 'glossary_hi.dart';
import 'rashi_pages.dart' show relationsOf;

final Map<String, (int, int)> grahaProseWords = <String, (int, int)>{};

bool _isNode(Graha g) => g == Graha.rahu || g == Graha.ketu;

Map<String, String> buildGrahaPages() {
  final List<PageRef> refs = grahaRefs();
  final List<PageRef> rashis = rashiRefs();
  final List<PageRef> naks = nakshatraRefs();
  final Map<String, String> pages = <String, String>{};
  check(grahaTable.length == 9, 'the engine no longer has 9 grahas');
  check(
    vimshottariOrder.length == 9 &&
        vimshottariOrder.toSet().length == 9,
    'the dasha order no longer names nine distinct grahas',
  );

  for (int index = 0; index < grahaTable.length; index++) {
    final GrahaInfo info = grahaTable[index];
    final Graha graha = info.graha;
    final PageRef ref = refs[index];
    final String path = ref.path;
    final bool node = _isNode(graha);

    String grahaLink(Graha g, {required bool hindi, bool sentence = false}) {
      final GrahaInfo other = grahaInfo(g);
      final String anchor = link(
        path,
        refs[grahaIndexOf(g)].path,
        esc(hindi ? other.hindi : other.english),
        lang: hindi ? 'hi' : null,
      );
      return !hindi &&
              sentence &&
              grahaForSentence(other.english) != other.english
          ? 'the $anchor'
          : anchor;
    }

    String signLink(int sign, {required bool hindi}) => link(
      path,
      rashis[sign % 12].path,
      esc(hindi ? rashiTable[sign % 12].hindi : rashiTable[sign % 12].english),
      lang: hindi ? 'hi' : null,
    );

    final double years = vimshottariYears[graha]!;
    final int orderIndex = vimshottariOrder.indexOf(graha);
    final Graha before = vimshottariOrder[(orderIndex + 8) % 9];
    final Graha after = vimshottariOrder[(orderIndex + 1) % 9];
    final List<NakshatraInfo> ruled = <NakshatraInfo>[
      for (final NakshatraInfo n in nakshatraTable)
        if (n.lord == graha) n,
    ];
    final (List<Graha>, List<Graha>, List<Graha>)? rel = relationsOf(graha);
    final int? exaltSign = info.exaltationDegree == null
        ? null
        : (info.exaltationDegree! / 30).floor();
    final int? debilSign = exaltSign == null ? null : (exaltSign + 6) % 12;
    final int deepest = info.exaltationDegree == null
        ? 0
        : ((info.exaltationDegree! % 30) * 60).round();
    final List<double>? trikona = info.moolatrikona;
    final int japa = japaCounts[graha]!;
    final String fastEn = weekdayEnglish[info.weekday];
    final String fastHi = weekdayNamesHindi[info.weekday];
    final String japaText = japa.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match m) => '${m[1]},',
    );

    String list(List<Graha> grahas, {required bool hindi}) => grahas.isEmpty
        ? (hindi ? 'कोई नहीं' : 'none')
        : (hindi ? joinHindi : joinEnglish)(<String>[
            for (final Graha g in grahas) grahaLink(g, hindi: hindi),
          ]);
    String nakList({required bool hindi}) => (hindi ? joinHindi : joinEnglish)(
      <String>[
        for (final NakshatraInfo n in ruled)
          link(
            path,
            naks[n.index].path,
            esc(hindi ? n.hindi : n.english),
            lang: hindi ? 'hi' : null,
          ),
      ],
    );
    final String favourable = favourableFromMoon[graha]!.join(', ');

    // Prose --------------------------------------------------------------
    final String nodeNoteEn = node
        ? ' It is not a body but a point where the Moon’s path crosses the ecliptic; the app uses the mean node, which can differ from the true node by more than a degree.'
        : '';
    final String nodeNoteHi = node
        ? ' यह कोई पिंड नहीं, बल्कि वह बिंदु है जहाँ चंद्रमा का पथ क्रांतिवृत्त को काटता है; ऐप माध्य पात लेता है, जो स्पष्ट पात से एक अंश से भी अधिक भिन्न हो सकता है।'
        : '';
    final String sanskritPart = info.sanskrit == info.english
        ? ''
        : ' (${esc(info.sanskrit)})';
    final String p1En =
        '${esc(info.english)}$sanskritPart is one of the nine grahas, the seven visible bodies and the two lunar nodes. '
        'It signifies ${esc(info.karaka.toLowerCase())}, and its presiding deity is ${esc(deityForSentence(info.deityEnglish))}.$nodeNoteEn';
    final String p1Hi =
        '${esc(info.hindi)} नवग्रहों में से एक हैं, यानी सात दिखाई देने वाले पिंड और चंद्रमा के दो पात, राहु और केतु। '
        'ये ${esc(karakaHindi(info.karaka))} से जुड़े माने जाते हैं और इनके अधिष्ठाता देवता ${esc(info.deityHindi)} हैं।$nodeNoteHi';

    final String dignityEn;
    final String dignityHi;
    if (node) {
      dignityEn =
          'The app places ${esc(info.english)}’s exaltation in ${signLink(exaltSign!, hindi: false)} and its debilitation in ${signLink(debilSign!, hindi: false)}, and gives it no sign of its own. Authorities differ on those signs and on whether the nodes rule any sign at all, so treat the nodes’ dignity as convention rather than consensus.';
      dignityHi =
          'ऐप ${esc(info.hindi)} की उच्च राशि ${signLink(exaltSign, hindi: true)} और नीच राशि ${signLink(debilSign, hindi: true)} मानता है, और इन्हें कोई स्वराशि नहीं देता। इन राशियों पर, और इस पर कि छाया ग्रह किसी राशि के स्वामी हैं या नहीं, विद्वान एकमत नहीं; इसलिए राहु-केतु की उच्च-नीच स्थिति को आम सहमति नहीं, एक परिपाटी मानें।';
    } else {
      final String trikonaEn = trikona == null
          ? ''
          : ' Its moolatrikona is ${signLink(trikona[0].toInt(), hindi: false)} from ${arcText((trikona[1] * 60).round())} to ${arcText((trikona[2] * 60).round())}, which the app ranks just below exaltation and above own sign.';
      final String trikonaHi = trikona == null
          ? ''
          : ' इसका मूलत्रिकोण ${signLink(trikona[0].toInt(), hindi: true)} में ${arcText((trikona[1] * 60).round())} से ${arcText((trikona[2] * 60).round())} तक है, जिसे ऐप उच्च से नीचे और स्वराशि से ऊपर रखता है।';
      dignityEn =
          'It is exalted in ${signLink(exaltSign!, hindi: false)}, deepest at ${arcText(deepest)}, and debilitated in ${signLink(debilSign!, hindi: false)}, the sign opposite; the app counts the whole sign, not just that degree. '
          'It owns ${joinEnglish(<String>[for (final int s in info.ownSigns) signLink(s, hindi: false)])}.$trikonaEn'
          '${info.combustionOrb > 0 ? ' It is called combust when within ${info.combustionOrb.round()}° of the Sun.' : ''}';
      dignityHi =
          'यह ${signLink(exaltSign, hindi: true)} में उच्च है, सबसे गहरा बिंदु ${arcText(deepest)} पर, और ${signLink(debilSign, hindi: true)} में नीच है, जो उसके ठीक सामने की राशि है; ऐप केवल उस अंश को नहीं, पूरी राशि को गिनता है। '
          'इसकी स्वराशि ${joinHindi(<String>[for (final int s in info.ownSigns) signLink(s, hindi: true)])} है।$trikonaHi'
          '${info.combustionOrb > 0 ? ' सूर्य से ${info.combustionOrb.round()}° के भीतर होने पर इसे अस्त कहा जाता है।' : ''}';
    }

    final String p3En =
        'In the Vimshottari cycle ${esc(grahaForSentence(info.english))} holds ${years.round()} of the 120 years, after ${grahaLink(before, hindi: false, sentence: true)} and before ${grahaLink(after, hindi: false, sentence: true)}. '
        'It lords the nakshatras ${nakList(hindi: false)}, so anyone born with the Moon in one of them begins life in its period.';
    final String p3Hi =
        'विंशोत्तरी चक्र में ${esc(info.hindi)} के हिस्से 120 में से ${years.round()} वर्ष हैं; इनसे पहले ${grahaLink(before, hindi: true)} और बाद में ${grahaLink(after, hindi: true)} की दशा आती है। '
        'ये ${nakList(hindi: true)} नक्षत्रों के स्वामी हैं, इसलिए जिसका जन्म चंद्रमा इनमें से किसी में हो, उसका जीवन इन्हीं की दशा से आरंभ होता है।';
    final String fastNoteEn = node
        ? ' Sources differ on the day to fast for ${esc(info.english)}; the app uses $fastEn.'
        : '';
    final String fastNoteHi = node
        ? ' ${esc(info.hindi)} के व्रत के दिन पर स्रोत भिन्न हैं; ऐप $fastHi लेता है।'
        : '';
    final String p4En =
        'Among its traditional remedies the app lists ${esc(info.gemstone.toLowerCase())} set in ${esc(info.metal.toLowerCase())}, the mantra “${esc(info.mantra)}” with $japaText repetitions for one full round, and fasting on $fastEn.$fastNoteEn '
        'The texts themselves treat a gemstone as strong medicine, so the app always says to ask someone knowledgeable before wearing one; mantra, fasting and giving suit anyone.';
    final String p4Hi =
        'पारंपरिक उपायों में ऐप रत्न ${esc(info.gemstoneHindi)} (${esc(metalHindiIn(info.metal))} में जड़ा हुआ), मंत्र “${esc(mantraHindi(graha))}” का एक पूरे चक्र में $japaText जप, और $fastHi का व्रत बताता है।$fastNoteHi '
        'ग्रंथ स्वयं रत्न को तेज़ औषधि की तरह मानते हैं, इसलिए ऐप पहनने से पहले किसी जानकार से पूछने को कहता है; मंत्र, व्रत और दान हर किसी के लिए हैं।';

    final List<String> proseEn = <String>[p1En, dignityEn, p3En, p4En];
    final List<String> proseHi = <String>[p1Hi, dignityHi, p3Hi, p4Hi];
    final (int, int) words = (
      wordCount(plainText(proseEn.join(' '))),
      wordCount(plainText(proseHi.join(' '))),
    );
    grahaProseWords[path] = words;
    check(
      words.$1 >= 150 && words.$1 <= 250,
      '${info.english}: English prose is ${words.$1} words, outside 150-250',
    );
    check(
      words.$2 >= 150 && words.$2 <= 250,
      '${info.english}: Hindi prose is ${words.$2} words, outside 150-250',
    );

    // Facts ----------------------------------------------------------------
    final String factsEn = factsHtml(<(String, String)>[
      (
        'Name',
        '${esc(info.english)} · <span lang="hi">${esc(info.hindi)}</span>${info.sanskrit == info.english ? '' : ' · Sanskrit ${esc(info.sanskrit)}'}',
      ),
      ('Signifies', esc(info.karaka)),
      ('Deity', esc(info.deityEnglish)),
      (
        'Exaltation',
        '${signLink(exaltSign, hindi: false)}, deepest at ${arcText(deepest)}${node ? ' (one convention)' : ''}',
      ),
      (
        'Debilitation',
        '${signLink(debilSign, hindi: false)}, deepest at ${arcText(deepest)}${node ? ' (one convention)' : ''}',
      ),
      (
        'Own signs',
        info.ownSigns.isEmpty
            ? 'None in the app (authorities differ)'
            : joinEnglish(<String>[
                for (final int s in info.ownSigns) signLink(s, hindi: false),
              ]),
      ),
      (
        'Moolatrikona',
        trikona == null
            ? 'None in the app'
            : '${signLink(trikona[0].toInt(), hindi: false)}, ${arcText((trikona[1] * 60).round())} to ${arcText((trikona[2] * 60).round())}',
      ),
      (
        'Combustion',
        info.combustionOrb > 0
            ? 'Within ${info.combustionOrb.round()}° of the Sun'
            : 'Not applied',
      ),
      ('Gemstone', esc(info.gemstone)),
      ('Metal', esc(info.metal)),
      ('Mantra', '${esc(info.mantra)}<br><small>$japaText repetitions for one full round</small>'),
      ('Fasting day', fastEn + (node ? ' (sources differ)' : '')),
      (
        'Vimshottari years',
        '${years.round()} of 120 · follows ${grahaLink(before, hindi: false)}, precedes ${grahaLink(after, hindi: false)}',
      ),
      ('Lords the nakshatras', nakList(hindi: false)),
      if (rel == null)
        (
          'Natural friendships',
          'The Parashari table covers the seven visible grahas only, so it says nothing about ${esc(info.english)}',
        )
      else ...<(String, String)>[
        ('Natural friends', list(rel.$1, hindi: false)),
        ('Natural neutrals', list(rel.$2, hindi: false)),
        ('Natural enemies', list(rel.$3, hindi: false)),
      ],
      (
        'Supportive transit houses from the Moon',
        favourable,
      ),
    ]);
    final String factsHi = factsHtml(<(String, String)>[
      (
        'नाम',
        '${esc(info.hindi)}${sanskritHindi(graha) == info.hindi ? '' : ' · संस्कृत नाम ${esc(sanskritHindi(graha))}'}',
      ),
      ('कारक', esc(karakaHindi(info.karaka))),
      ('देवता', esc(info.deityHindi)),
      (
        'उच्च राशि',
        '${signLink(exaltSign, hindi: true)}, सबसे गहरा बिंदु ${arcText(deepest)}${node ? ' (एक परिपाटी)' : ''}',
      ),
      (
        'नीच राशि',
        '${signLink(debilSign, hindi: true)}, सबसे गहरा बिंदु ${arcText(deepest)}${node ? ' (एक परिपाटी)' : ''}',
      ),
      (
        'स्वराशि',
        info.ownSigns.isEmpty
            ? 'ऐप में कोई नहीं (विद्वानों में मतभेद)'
            : joinHindi(<String>[
                for (final int s in info.ownSigns) signLink(s, hindi: true),
              ]),
      ),
      (
        'मूलत्रिकोण',
        trikona == null
            ? 'ऐप में कोई नहीं'
            : '${signLink(trikona[0].toInt(), hindi: true)}, ${arcText((trikona[1] * 60).round())} से ${arcText((trikona[2] * 60).round())}',
      ),
      (
        'अस्त',
        info.combustionOrb > 0
            ? 'सूर्य से ${info.combustionOrb.round()}° के भीतर'
            : 'लागू नहीं',
      ),
      ('रत्न', esc(info.gemstoneHindi)),
      ('धातु', esc(metalHindi(info.metal))),
      (
        'मंत्र',
        '${esc(mantraHindi(graha))}<br><small>एक पूरे चक्र में $japaText जप</small>',
      ),
      ('व्रत का दिन', fastHi + (node ? ' (स्रोत भिन्न हैं)' : '')),
      (
        'विंशोत्तरी वर्ष',
        '120 में से ${years.round()} · पहले ${grahaLink(before, hindi: true)}, बाद में ${grahaLink(after, hindi: true)}',
      ),
      ('इन नक्षत्रों के स्वामी', nakList(hindi: true)),
      if (rel == null)
        (
          'नैसर्गिक मैत्री',
          'पराशरी तालिका केवल सात दृश्य ग्रहों को लेती है, इसलिए ${esc(info.hindi)} के बारे में वह कुछ नहीं कहती',
        )
      else ...<(String, String)>[
        ('नैसर्गिक मित्र', list(rel.$1, hindi: true)),
        ('नैसर्गिक सम', list(rel.$2, hindi: true)),
        ('नैसर्गिक शत्रु', list(rel.$3, hindi: true)),
      ],
      ('चंद्र से अनुकूल गोचर भाव', favourable),
    ]);

    final String body =
        '''
  <section id="english" lang="en">
    <h2>${esc(info.english)} at a glance</h2>
$factsEn
    <h2>Understanding ${esc(grahaForSentence(info.english))}</h2>
${proseEn.map((String p) => '    <p class="prose">$p</p>').join('\n')}
${ctaBlock(from: path, heading: (en: 'See ${info.english} in your own chart', hi: ''), body: (en: 'KundliSaar shows where ${info.english} stood at your birth, its sign, house, nakshatra and strength, and the dasha it runs. It is free, runs on your device and needs no account.', hi: ''), button: (en: 'Open the app', hi: ''), hindi: false)}
    <p class="note">Facts come from the same engine the app uses. Where the tradition differs between authorities, that is said. This is traditional reference material, not a prediction, and not medical or financial advice.</p>
    <p class="langjump"><a href="#hindi" lang="hi">हिन्दी में पढ़ें ↓</a></p>
  </section>

  <section id="hindi" lang="hi">
    <h2>${esc(info.hindi)} एक नज़र में</h2>
$factsHi
    <h2>${esc(info.hindi)} को समझें</h2>
${proseHi.map((String p) => '    <p class="prose">$p</p>').join('\n')}
${ctaBlock(from: path, heading: (en: '', hi: 'अपनी कुंडली में ${info.hindi} देखें'), body: (en: '', hi: 'कुंडलीसार बताता है कि आपके जन्म पर ${info.hindi} किस राशि, भाव और नक्षत्र में थे, कितने बलवान थे और कौन-सी दशा चलाते हैं। यह मुफ़्त है, आपके फ़ोन पर चलता है और खाता नहीं माँगता।'), button: (en: '', hi: 'ऐप खोलें'), hindi: true)}
    <p class="note">तथ्य उसी इंजन से आते हैं जिसे ऐप चलाता है। जहाँ विद्वानों में मतभेद है, वहाँ यह कहा गया है। यह पारंपरिक जानकारी है, भविष्यवाणी नहीं, और चिकित्सा या वित्तीय सलाह भी नहीं।</p>
    <p class="langjump"><a href="#english" lang="en">Read in English ↑</a></p>
  </section>
''';

    final PageRef prev = refs[index == 0 ? 0 : index - 1];
    final PageRef next = refs[index == refs.length - 1 ? index : index + 1];
    final String title =
        '${info.english} (${info.hindi}) in Vedic Astrology: Signs, Gemstone, Mantra and Dasha Years';
    final String description =
        '${info.english} (${info.hindi}), ${info.sanskrit}: signifies ${info.karaka.toLowerCase()}; exaltation, debilitation and own signs, gemstone ${info.gemstone.toLowerCase()}, mantra, fasting day and ${years.round()} dasha years. ${info.hindi}: उच्च-नीच राशि, रत्न, मंत्र, व्रत और दशा।';
    final List<Crumb> crumbs = <Crumb>[
      const Crumb('KundliSaar', ''),
      const Crumb('Learn', 'learn/'),
      const Crumb('Grahas', 'learn/#grahas'),
      Crumb('${info.english} · ${info.hindi}', path),
    ];
    final String html = renderPage(
      PageSpec(
        path: path,
        title: title,
        description: description,
        heading:
            '${esc(info.english)} <span class="h1-hi" lang="hi">· ${esc(info.hindi)}</span>',
        lede:
            'Graha ${index + 1} of 9: signifies ${esc(info.karaka.toLowerCase())}; ${years.round()} years of the Vimshottari cycle.<br><span lang="hi">नौ ग्रहों में ${ordinalsHindi[index]}: ${esc(karakaHindi(info.karaka))} के कारक; विंशोत्तरी में ${years.round()} वर्ष।</span>',
        body: body,
        crumbs: crumbs,
        jumpLinks: true,
        previous: index == 0
            ? null
            : SiblingLink(
                path: prev.path,
                title:
                    '${esc(prev.english)} · <span lang="hi">${esc(prev.hindi)}</span>',
              ),
        next: index == refs.length - 1
            ? null
            : SiblingLink(
                path: next.path,
                title:
                    '${esc(next.english)} · <span lang="hi">${esc(next.hindi)}</span>',
              ),
        jsonLd: <Map<String, Object?>>[
          articleLd(
            path: path,
            headline: '${info.english} (${info.hindi}) in Vedic astrology',
            description: description,
            dateModified: referenceUpdated,
          ),
          breadcrumbLd(crumbs, '$siteBase$path'),
        ],
      ),
    );
    checkText(path, html);
    pages[path] = html;
  }
  return pages;
}
