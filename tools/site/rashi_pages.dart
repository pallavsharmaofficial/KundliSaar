/// The 12 rashi pages.
///
/// A sign is described by what the engine holds about it (lord, element,
/// quality, symbol), by the nakshatra padas that tile it, by the grahas the
/// engine places in dignity there, and by the rules the app applies to a Moon
/// in that sign: Sade Sati and the supportive transit houses.
library;

import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/transits.dart';
import 'package:kundlisaar/engine/jyotish/varga.dart';

import 'common.dart';
import 'glossary_hi.dart';

const int _signArc = 1800;
const int _padaArc = 200;

class _SignPada {
  const _SignPada(this.nakshatra, this.pada, this.startInSign, this.navamsa);
  final NakshatraInfo nakshatra;
  final int pada;
  final int startInSign;
  final Rashi navamsa;
  int get endInSign => startInSign + _padaArc;
}

List<_SignPada> _padasInSign(int sign) => <_SignPada>[
  for (int i = 0; i < 9; i++)
    () {
      final int startArc = sign * _signArc + i * _padaArc;
      return _SignPada(
        nakshatraTable[startArc ~/ 800],
        (startArc % 800) ~/ _padaArc + 1,
        i * _padaArc,
        Rashi.values[vargaSign(Varga.d9, (startArc + _padaArc / 2) / 60.0)],
      );
    }(),
];

/// The nakshatras that touch a sign, with the padas of each that fall in it.
List<(NakshatraInfo, List<int>)> _nakshatraRuns(List<_SignPada> padas) {
  final List<(NakshatraInfo, List<int>)> runs = <(NakshatraInfo, List<int>)>[];
  for (final _SignPada p in padas) {
    if (runs.isEmpty || runs.last.$1.index != p.nakshatra.index) {
      runs.add((p.nakshatra, <int>[]));
    }
    runs.last.$2.add(p.pada);
  }
  return runs;
}

String _padasEnglish(List<int> padas) => padas.length == 1
    ? 'pada ${padas.first}'
    : 'padas ${padas.first} to ${padas.last}';

String _padasHindi(List<int> padas) => padas.length == 1
    ? 'चरण ${padas.first}'
    : 'चरण ${padas.first} से ${padas.last}';

List<Graha> _where(bool Function(GrahaInfo) test) => <Graha>[
  for (final GrahaInfo g in grahaTable)
    if (test(g)) g.graha,
];

/// Friends, neutrals and enemies of a graha in the Parashari table, or null
/// for Rahu and Ketu, which that table does not cover.
(List<Graha>, List<Graha>, List<Graha>)? relationsOf(Graha graha) {
  final Map<Graha, Relation>? row = naturalRelations[graha];
  if (row == null) return null;
  final List<Graha> friends = <Graha>[];
  final List<Graha> neutrals = <Graha>[];
  final List<Graha> enemies = <Graha>[];
  for (final MapEntry<Graha, Relation> entry in row.entries) {
    switch (entry.value) {
      case Relation.friend:
        friends.add(entry.key);
      case Relation.neutral:
        neutrals.add(entry.key);
      case Relation.enemy:
        enemies.add(entry.key);
    }
  }
  return (friends, neutrals, enemies);
}

final Map<String, (int, int)> rashiProseWords = <String, (int, int)>{};

/// A link to a graha's page. In English prose the Sun and the Moon take an
/// article, which sits outside the anchor.
String _graha(
  String from,
  Graha g, {
  required bool hindi,
  bool sentence = false,
}) {
  final GrahaInfo info = grahaInfo(g);
  final String anchor = link(
    from,
    grahaRefs()[grahaIndexOf(g)].path,
    esc(hindi ? info.hindi : info.english),
    lang: hindi ? 'hi' : null,
  );
  return !hindi && sentence && grahaForSentence(info.english) != info.english
      ? 'the $anchor'
      : anchor;
}

String _nakshatra(String from, NakshatraInfo n, {required bool hindi}) => link(
  from,
  nakshatraRefs()[n.index].path,
  esc(hindi ? n.hindi : n.english),
  lang: hindi ? 'hi' : null,
);

Map<String, String> buildRashiPages() {
  final List<PageRef> refs = rashiRefs();
  final Map<String, String> pages = <String, String>{};
  check(rashiTable.length == 12, 'the engine no longer has 12 rashis');

  for (final RashiInfo info in rashiTable) {
    final int sign = info.rashi.index;
    final PageRef ref = refs[sign];
    final String path = ref.path;
    final GrahaInfo lord = grahaInfo(info.lord);
    final List<_SignPada> padas = _padasInSign(sign);
    final List<(NakshatraInfo, List<int>)> runs = _nakshatraRuns(padas);
    // Sade Sati is Saturn in the twelfth, first and second signs from the Moon.
    final List<RashiInfo> sade = <RashiInfo>[
      rashiTable[(sign + 11) % 12],
      rashiTable[sign],
      rashiTable[(sign + 1) % 12],
    ];

    // Dignities held in this sign.
    final List<Graha> exalted = _where(
      (GrahaInfo g) =>
          g.exaltationDegree != null &&
          (g.exaltationDegree! / 30).floor() == sign,
    );
    final List<Graha> debilitated = _where(
      (GrahaInfo g) =>
          g.exaltationDegree != null &&
          ((g.exaltationDegree! / 30).floor() + 6) % 12 == sign,
    );
    final List<Graha> own = _where((GrahaInfo g) => g.ownSigns.contains(sign));
    final List<Graha> trikona = _where(
      (GrahaInfo g) => g.moolatrikona != null && g.moolatrikona![0] == sign,
    );
    String dignityList(List<Graha> list, {required bool hindi}) => list.isEmpty
        ? (hindi ? 'कोई नहीं' : 'None')
        : (hindi ? joinHindi : joinEnglish)(<String>[
            for (final Graha g in list)
              '${_graha(path, g, hindi: hindi)}${(g == Graha.rahu || g == Graha.ketu) ? (hindi ? ' (मतभेद है)' : ' (disputed)') : ''}',
          ]);

    // Prose.
    final (List<Graha>, List<Graha>, List<Graha>) rel = relationsOf(info.lord)!;
    String relList(List<Graha> list, {required bool hindi}) => list.isEmpty
        ? ''
        : (hindi ? joinHindi : joinEnglish)(<String>[
            for (final Graha g in list) _graha(path, g, hindi: hindi, sentence: true),
          ]);
    final List<String> relEn = <String>[
      if (rel.$1.isNotEmpty) '${relList(rel.$1, hindi: false)} as friends',
      if (rel.$2.isNotEmpty) '${relList(rel.$2, hindi: false)} as neutral',
      if (rel.$3.isNotEmpty) '${relList(rel.$3, hindi: false)} as enemies',
    ];
    final List<String> relHi = <String>[
      if (rel.$1.isNotEmpty) '${relList(rel.$1, hindi: true)} को मित्र',
      if (rel.$2.isNotEmpty) '${relList(rel.$2, hindi: true)} को सम',
      if (rel.$3.isNotEmpty) '${relList(rel.$3, hindi: true)} को शत्रु',
    ];

    final List<(NakshatraInfo, List<int>)> fullRuns = <(NakshatraInfo, List<int>)>[
      for (final (NakshatraInfo, List<int>) r in runs)
        if (r.$2.length == 4) r,
    ];
    final List<(NakshatraInfo, List<int>)> partRuns = <(NakshatraInfo, List<int>)>[
      for (final (NakshatraInfo, List<int>) r in runs)
        if (r.$2.length != 4) r,
    ];
    final String holdsEn =
        '${joinEnglish(<String>[for (final (NakshatraInfo, List<int>) r in fullRuns) _nakshatra(path, r.$1, hindi: false)])} in full'
        '${partRuns.isEmpty ? '' : ', together with ${joinEnglish(<String>[for (final (NakshatraInfo, List<int>) r in partRuns) '${_padasEnglish(r.$2)} of ${_nakshatra(path, r.$1, hindi: false)}'])}'}';
    final String holdsHi =
        '${joinHindi(<String>[for (final (NakshatraInfo, List<int>) r in fullRuns) _nakshatra(path, r.$1, hindi: true)])} पूरे'
        '${partRuns.isEmpty ? '' : ', और साथ में ${joinHindi(<String>[for (final (NakshatraInfo, List<int>) r in partRuns) '${_nakshatra(path, r.$1, hindi: true)} के ${_padasHindi(r.$2)}'])}'}';
    final Rashi firstNav = padas.first.navamsa;
    final Rashi lastNav = padas.last.navamsa;

    final String p1En =
        '${esc(info.english)} is the ${ordinalEnglish(sign + 1)} of the twelve rashis, the 30° divisions of the zodiac, and covers ${arcText(sign * _signArc)} to ${arcText((sign + 1) * _signArc)} of the sidereal circle. '
        'Its symbol is the ${esc(info.symbolEnglish.toLowerCase())}; it is a ${elementEnglish(info.element)} sign of ${qualityEnglish(info.quality)} quality, ruled by ${_graha(path, info.lord, hindi: false, sentence: true)}. '
        'The four elements and the three qualities repeat in turn around the zodiac, so every sign is a different pairing of the two. '
        'In Indian practice “your rashi” normally means the sign the Moon occupied at birth rather than the Sun sign.';
    final String p1Hi =
        '${esc(info.hindi)} बारह राशियों में ${ordinalsHindiFeminine[sign]} राशि है। राशि राशिचक्र का 30° का भाग है, और ${esc(info.hindi)} निरयन वृत्त के ${arcText(sign * _signArc)} से ${arcText((sign + 1) * _signArc)} तक है। '
        'इसका प्रतीक ${esc(info.symbolHindi)} है; यह ${elementHindi(info.element)} तत्व की, ${qualityHindi(info.quality)} स्वभाव की राशि है और इसके स्वामी ${_graha(path, info.lord, hindi: true)} हैं। '
        'तत्व और स्वभाव बारी-बारी से आते हैं, इसलिए हर राशि इनका अलग जोड़ा है। '
        'भारतीय परंपरा में “आपकी राशि” का अर्थ प्रायः जन्म के समय चंद्रमा की राशि होता है, सूर्य राशि नहीं।';
    final String p2En =
        'The sign holds nine nakshatra padas: $holdsEn. Each pada is one navamsa, so the nine navamsas of ${esc(info.english)} run in order from ${esc(rashiInfo(firstNav).english)} to ${esc(rashiInfo(lastNav).english)}.';
    final String p2Hi =
        'इस राशि में नक्षत्रों के नौ चरण आते हैं: $holdsHi। हर चरण एक नवांश है, इसलिए ${esc(info.hindi)} के नौ नवांश ${esc(rashiInfo(firstNav).hindi)} से ${esc(rashiInfo(lastNav).hindi)} तक क्रम से चलते हैं।';
    final String p3En =
        '${esc(sentenceCase(grahaForSentence(lord.english)))} stands for ${esc(lord.karaka.toLowerCase())}, and the tradition reads a sign largely through its lord. In the Parashari table of natural friendships ${esc(grahaForSentence(lord.english))} counts ${joinEnglish(relEn)}.';
    final String p3Hi =
        '${esc(lord.hindi)} ${esc(karakaHindi(lord.karaka))} के कारक हैं, और परंपरा राशि को बहुत कुछ उसके स्वामी के माध्यम से पढ़ती है। पराशरी नैसर्गिक मैत्री तालिका में ${esc(lord.hindi)} ${joinHindi(relHi)} मानते हैं।';
    final String p4En =
        'As a Moon sign it sets Sade Sati: the seven and a half years while ${_graha(path, Graha.saturn, hindi: false)} passes through ${joinEnglish(<String>[for (final RashiInfo r in sade) link(path, refs[r.rashi.index].path, esc(r.english))])}, which the tradition reads as a stretch of work and responsibility, not punishment. '
        'In Ashtakoota matching the sign enters through graha maitri, which compares the two sign lords, and bhakoot, scored zero when the two Moon signs stand 2/12, 5/9 or 6/8 from each other. The app applies that plain rule, and many authorities allow exceptions.';
    final String p4Hi =
        'चंद्र राशि के रूप में यह साढ़ेसाती तय करती है: जब ${_graha(path, Graha.saturn, hindi: true)} ${joinHindi(<String>[for (final RashiInfo r in sade) link(path, refs[r.rashi.index].path, esc(r.hindi), lang: 'hi')])} राशियों से गुज़रते हैं, तब साढ़े सात वर्ष का वह काल चलता है जिसे परंपरा परिश्रम और ज़िम्मेदारी का समय मानती है, दंड नहीं। '
        'अष्टकूट मिलान में राशि ग्रह-मैत्री (दोनों राशि-स्वामियों की तुलना) और भकूट के रूप में आती है; भकूट में शून्य तब मिलता है जब दोनों चंद्र राशियाँ एक-दूसरे से 2/12, 5/9 या 6/8 स्थान पर हों। ऐप सीधा नियम लगाता है; कई विद्वान अपवाद मानते हैं।';
    final List<String> proseEn = <String>[p1En, p2En, p3En, p4En];
    final List<String> proseHi = <String>[p1Hi, p2Hi, p3Hi, p4Hi];
    final (int, int) words = (
      wordCount(plainText(proseEn.join(' '))),
      wordCount(plainText(proseHi.join(' '))),
    );
    rashiProseWords[path] = words;
    check(
      words.$1 >= 150 && words.$1 <= 250,
      '${info.english}: English prose is ${words.$1} words, outside 150-250',
    );
    check(
      words.$2 >= 150 && words.$2 <= 250,
      '${info.english}: Hindi prose is ${words.$2} words, outside 150-250',
    );

    // Tables.
    String signName(int s, {required bool hindi}) =>
        hindi ? rashiTable[s % 12].hindi : rashiTable[s % 12].english;
    final String padaTableEn = tableHtml(
      headers: <String>['Degrees in the sign', 'Nakshatra and pada', 'Navamsa'],
      rows: <List<String>>[
        for (final _SignPada p in padas)
          <String>[
            '${arcText(p.startInSign)} to ${arcText(p.endInSign)}',
            '${_nakshatra(path, p.nakshatra, hindi: false)}, pada ${p.pada}',
            esc(rashiInfo(p.navamsa).english),
          ],
      ],
    );
    final String padaTableHi = tableHtml(
      headers: <String>['राशि में अंश', 'नक्षत्र और चरण', 'नवांश'],
      rows: <List<String>>[
        for (final _SignPada p in padas)
          <String>[
            '${arcText(p.startInSign)} से ${arcText(p.endInSign)}',
            '${_nakshatra(path, p.nakshatra, hindi: true)}, चरण ${p.pada}',
            esc(rashiInfo(p.navamsa).hindi),
          ],
      ],
    );
    String gochar({required bool hindi}) => tableHtml(
      headers: hindi
          ? <String>['ग्रह', 'चंद्र से अनुकूल भाव', 'वे राशियाँ']
          : <String>['Graha', 'Supportive houses from the Moon', 'Those signs'],
      rows: <List<String>>[
        for (final GrahaInfo g in grahaTable)
          <String>[
            _graha(path, g.graha, hindi: hindi),
            favourableFromMoon[g.graha]!.join(', '),
            (hindi ? joinHindi : joinEnglish)(<String>[
              for (final int house in favourableFromMoon[g.graha]!)
                esc(signName(sign + house - 1, hindi: hindi)),
            ]),
          ],
      ],
    );

    final String factsEn = factsHtml(<(String, String)>[
      ('Position', '${sign + 1} of 12'),
      ('Name', '${esc(info.english)} · <span lang="hi">${esc(info.hindi)}</span>'),
      ('Symbol', esc(info.symbolEnglish)),
      ('Lord', _graha(path, info.lord, hindi: false)),
      ('Element', elementEnglish(info.element)),
      ('Quality', qualityEnglish(info.quality)),
      (
        'Sidereal span',
        '${arcText(sign * _signArc)} to ${arcText((sign + 1) * _signArc)}',
      ),
      (
        'Nakshatras inside',
        joinEnglish(<String>[
          for (final (NakshatraInfo, List<int>) r in runs)
            '${_nakshatra(path, r.$1, hindi: false)}${r.$2.length == 4 ? '' : ' (${_padasEnglish(r.$2)})'}',
        ]),
      ),
      ('Exalted here', dignityList(exalted, hindi: false)),
      ('Debilitated here', dignityList(debilitated, hindi: false)),
      ('Own sign of', dignityList(own, hindi: false)),
      ('Moolatrikona of', dignityList(trikona, hindi: false)),
      (
        'Sade Sati (Moon here)',
        'Saturn in ${joinEnglish(<String>[for (final RashiInfo r in sade) esc(r.english)])}',
      ),
    ]);
    final String factsHi = factsHtml(<(String, String)>[
      ('क्रम', '12 में से ${sign + 1}'),
      ('नाम', esc(info.hindi)),
      ('प्रतीक', esc(info.symbolHindi)),
      ('स्वामी', _graha(path, info.lord, hindi: true)),
      ('तत्व', elementHindi(info.element)),
      ('स्वभाव', qualityHindi(info.quality)),
      (
        'निरयन विस्तार',
        '${arcText(sign * _signArc)} से ${arcText((sign + 1) * _signArc)}',
      ),
      (
        'भीतर के नक्षत्र',
        joinHindi(<String>[
          for (final (NakshatraInfo, List<int>) r in runs)
            '${_nakshatra(path, r.$1, hindi: true)}${r.$2.length == 4 ? '' : ' (${_padasHindi(r.$2)})'}',
        ]),
      ),
      ('यहाँ उच्च', dignityList(exalted, hindi: true)),
      ('यहाँ नीच', dignityList(debilitated, hindi: true)),
      ('स्वराशि किसकी', dignityList(own, hindi: true)),
      ('मूलत्रिकोण किसका', dignityList(trikona, hindi: true)),
      (
        'साढ़ेसाती (चंद्र यहाँ हो तो)',
        'शनि ${joinHindi(<String>[for (final RashiInfo r in sade) esc(r.hindi)])} में',
      ),
    ]);

    final String body =
        '''
  <section id="english" lang="en">
    <h2>${esc(info.english)} rashi at a glance</h2>
$factsEn
    <h2>Understanding ${esc(info.english)}</h2>
${proseEn.map((String p) => '    <p class="prose">$p</p>').join('\n')}
    <h2>The nine padas and navamsas of ${esc(info.english)}</h2>
$padaTableEn
    <h2>Transits when the Moon is in ${esc(info.english)}</h2>
    <p class="note">The houses the tradition counts as supportive for each graha, counted from the natal Moon, turned into the signs they fall on for a Moon in ${esc(info.english)}.</p>
${gochar(hindi: false)}
${ctaBlock(from: path, heading: (en: 'Find your own Moon sign', hi: ''), body: (en: 'KundliSaar computes your Moon sign, nakshatra and Sade Sati dates from your birth details, on your device, free and without an account.', hi: ''), button: (en: 'Open the app', hi: ''), hindi: false)}
    <p class="note">Degrees are sidereal, on the Lahiri ayanamsa. Facts come from the same engine the app uses. Where the tradition differs between authorities, that is said. This is traditional reference material, not a prediction.</p>
    <p class="langjump"><a href="#hindi" lang="hi">हिन्दी में पढ़ें ↓</a></p>
  </section>

  <section id="hindi" lang="hi">
    <h2>${esc(info.hindi)} राशि एक नज़र में</h2>
$factsHi
    <h2>${esc(info.hindi)} को समझें</h2>
${proseHi.map((String p) => '    <p class="prose">$p</p>').join('\n')}
    <h2>${esc(info.hindi)} के नौ चरण और नवांश</h2>
$padaTableHi
    <h2>चंद्रमा ${esc(info.hindi)} में हो तो गोचर</h2>
    <p class="note">हर ग्रह के लिए जन्म चंद्र से गिने गए वे भाव जिन्हें परंपरा अनुकूल मानती है, और चंद्र ${esc(info.hindi)} में हो तो वे किन राशियों पर पड़ते हैं।</p>
${gochar(hindi: true)}
${ctaBlock(from: path, heading: (en: '', hi: 'अपनी चंद्र राशि जानें'), body: (en: '', hi: 'कुंडलीसार आपके जन्म-विवरण से चंद्र राशि, नक्षत्र और साढ़ेसाती की तारीख़ें आपके फ़ोन पर ही निकालता है; मुफ़्त और बिना खाते के।'), button: (en: '', hi: 'ऐप खोलें'), hindi: true)}
    <p class="note">अंश निरयन हैं, लाहिरी अयनांश पर। तथ्य उसी इंजन से आते हैं जिसे ऐप चलाता है। जहाँ विद्वानों में मतभेद है, वहाँ यह कहा गया है। यह पारंपरिक जानकारी है, भविष्यवाणी नहीं।</p>
    <p class="langjump"><a href="#english" lang="en">Read in English ↑</a></p>
  </section>
''';

    final PageRef before = refs[(sign + 11) % 12];
    final PageRef after = refs[(sign + 1) % 12];
    final String title =
        '${info.english} Rashi (${info.hindi} राशि): Lord, Element, Nakshatras and Navamsa';
    final String description =
        '${info.english} (${info.hindi}) rashi: ruled by ${lord.english}, a ${elementEnglish(info.element)} sign of ${qualityEnglish(info.quality)} quality, with the nakshatra padas and navamsas it holds. ${info.hindi} राशि: स्वामी ${lord.hindi}, तत्व ${elementHindi(info.element)}, स्वभाव ${qualityHindi(info.quality)}।';
    final List<Crumb> crumbs = <Crumb>[
      const Crumb('KundliSaar', ''),
      const Crumb('Learn', 'learn/'),
      const Crumb('Rashis', 'learn/#rashis'),
      Crumb('${info.english} · ${info.hindi}', path),
    ];
    final String html = renderPage(
      PageSpec(
        path: path,
        title: title,
        description: description,
        heading:
            '${esc(info.english)} rashi <span class="h1-hi" lang="hi">· ${esc(info.hindi)} राशि</span>',
        lede:
            'The ${ordinalEnglish(sign + 1)} sign of the zodiac: ${elementEnglish(info.element)}, ${qualityEnglish(info.quality)}, ruled by ${esc(lord.english)}.<br><span lang="hi">राशिचक्र की ${ordinalsHindiFeminine[sign]} राशि: ${elementHindi(info.element)} तत्व, ${qualityHindi(info.quality)} स्वभाव, स्वामी ${esc(lord.hindi)}।</span>',
        body: body,
        crumbs: crumbs,
        jumpLinks: true,
        previous: SiblingLink(
          path: before.path,
          title:
              '${esc(before.english)} · <span lang="hi">${esc(before.hindi)}</span>',
        ),
        next: SiblingLink(
          path: after.path,
          title:
              '${esc(after.english)} · <span lang="hi">${esc(after.hindi)}</span>',
        ),
        jsonLd: <Map<String, Object?>>[
          articleLd(
            path: path,
            headline: '${info.english} rashi (${info.hindi} राशि)',
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
