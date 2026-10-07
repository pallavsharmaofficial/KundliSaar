import '../engine/astro/angles.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/dasha.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/matching.dart';
import '../engine/jyotish/nakshatra.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/varga.dart';
import '../engine/jyotish/yogas.dart';

/// An answer composed from the computed chart.
///
/// Nothing here is generated text: each answer is written by hand in both
/// languages and filled from the engine, so it can be read out loud, it works
/// offline, and it cannot invent a planet. The optional language model, when
/// it arrives, sits on top of exactly this material.
class Answer {
  const Answer({
    required this.title,
    required this.body,
    required this.basis,
    this.isRefusal = false,
    this.isFallback = false,
  });

  final String title;
  final String body;

  /// The chart factors the answer was read from.
  final List<String> basis;
  final bool isRefusal;
  final bool isFallback;
}

class _Intent {
  const _Intent(this.key, this.keywords);

  final String key;
  final List<String> keywords;
}

const List<_Intent> _intents = <_Intent>[
  _Intent('refuse', <String>[
    'die',
    'death',
    'kab marunga',
    'mrityu',
    'cancer',
    'disease',
    'illness',
    'pregnan',
    'abortion',
    'court case',
    // Education as an area of life is read; a result is not predicted.
    // 'exam' alone stays with education, so these have to be the
    // result-seeking phrasings, and refuse is matched before it.
    'exam result',
    'exam ka result',
    'will i pass',
    'will i clear',
    'pass the exam',
    'clear the exam',
    'pass hounga',
    'pass hoonga',
    'paas hounga',
    'exam me pass',
    'result kya',
    'परीक्षा में पास',
    'पास हूँगा',
    'पास होऊंगा',
    'रिजल्ट',
    'नतीजा',
    'jail',
    'stock',
    'invest',
    'lottery',
    'satta',
    'मृत्यु',
    'मौत',
    'बीमारी',
    'रोग',
    'गर्भ',
    'मुकदमा',
    'शेयर',
    'सट्टा',
  ]),
  _Intent('lagna', <String>['lagna', 'ascendant', 'rising', 'लग्न']),
  _Intent('moon', <String>['moon sign', 'rashi', 'chandra', 'राशि', 'चंद्र']),
  _Intent('nakshatra', <String>['nakshatra', 'star', 'janma', 'नक्षत्र']),
  _Intent('dasha', <String>[
    'dasha',
    'period',
    'mahadasha',
    'antardasha',
    'चल रही',
    'दशा',
    'समय',
  ]),
  _Intent('sadesati', <String>[
    'sade sati',
    'sadesati',
    'shani',
    'साढ़े साती',
    'शनि',
  ]),
  _Intent('mangal', <String>['mangal', 'manglik', 'kuja', 'मंगल', 'मांगलिक']),
  _Intent('marriage', <String>[
    'marriage',
    'wedding',
    'spouse',
    'shadi',
    'vivah',
    'विवाह',
    'शादी',
    'जीवनसाथी',
  ]),
  _Intent('career', <String>[
    'career',
    'job',
    'work',
    'business',
    'naukri',
    'करियर',
    'नौकरी',
    'काम',
    'व्यापार',
  ]),
  _Intent('education', <String>[
    'education',
    'study',
    'exam',
    'padhai',
    'शिक्षा',
    'पढ़ाई',
    'विद्या',
  ]),
  _Intent('money', <String>[
    'money',
    'wealth',
    'dhan',
    'income',
    'paisa',
    'धन',
    'पैसा',
    'आय',
  ]),
  _Intent('remedy', <String>[
    'remedy',
    'upay',
    'mantra',
    'gemstone',
    'उपाय',
    'मंत्र',
    'रत्न',
  ]),
  _Intent('strength', <String>[
    'strongest',
    'weakest',
    'strong',
    'weak',
    'बलवान',
    'कमज़ोर',
    'मजबूत',
  ]),
  _Intent('retrograde', <String>['retrograde', 'vakri', 'वक्री']),
  _Intent('yogas', <String>['yoga', 'dosha', 'योग', 'दोष']),
  _Intent('navamsa', <String>['navamsa', 'd9', 'नवांश']),
  _Intent('whatis_nakshatra', <String>['what is a nakshatra', 'नक्षत्र क्या']),
  _Intent('whatis_dasha', <String>['what is dasha', 'दशा क्या']),
];

String _name(Graha graha, bool hindi) =>
    hindi ? grahaInfo(graha).hindi : grahaInfo(graha).english;

String _sign(Rashi rashi, bool hindi) =>
    hindi ? rashiInfo(rashi).hindi : rashiInfo(rashi).english;

String _nak(NakshatraInfo info, bool hindi) =>
    hindi ? info.hindi : info.english;

String _date(DateTime value, bool hindi) =>
    '${value.day}/${value.month}/${value.year}';

List<String> suggestedQuestions(bool hindi) => hindi
    ? const <String>[
        'मेरी चंद्र राशि क्या है?',
        'अभी कौन सी दशा चल रही है?',
        'क्या मुझे मंगल दोष है?',
        'क्या साढ़े साती चल रही है?',
        'मेरी कुंडली में कौन से योग हैं?',
        'विवाह के बारे में कुंडली क्या कहती है?',
        'करियर के लिए कौन से भाव देखे जाते हैं?',
        'मेरे लिए कौन सा उपाय बताया गया है?',
      ]
    : const <String>[
        'What is my moon sign?',
        'Which dasha is running now?',
        'Do I have Mangal dosha?',
        'Is Sade Sati running?',
        'Which yogas does my chart carry?',
        'What does the chart say about marriage?',
        'Which houses are read for career?',
        'What remedy does the tradition give me?',
      ];

Answer answerQuestion(
  Kundli kundli,
  String question, {
  required bool hindi,
  DateTime? now,
}) {
  final DateTime moment = now ?? DateTime.now();
  final String text = question.toLowerCase();
  String key = 'fallback';
  for (final _Intent intent in _intents) {
    if (intent.keywords.any(text.contains)) {
      key = intent.key;
      break;
    }
  }
  return _compose(kundli, key, hindi: hindi, moment: moment);
}

Answer _compose(
  Kundli k,
  String key, {
  required bool hindi,
  required DateTime moment,
}) {
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final PlacedGraha sun = k.grahas[Graha.sun]!;
  switch (key) {
    case 'refuse':
      return Answer(
        title: hindi ? 'यह मैं नहीं बता सकता' : 'I will not answer that',
        body: hindi
            ? 'यह ऐप मृत्यु, बीमारी, गर्भ, मुकदमे या निवेश के बारे में भविष्यवाणी नहीं करता। ये विषय किसी योग्य व्यक्ति से पूछें। कुंडली के बाक़ी हिस्सों के बारे में बेझिझक पूछिए।'
            : 'This app does not predict death, illness, pregnancy, court cases or investments. Those belong with a qualified professional. Ask me anything else about the chart.',
        basis: const <String>[],
        isRefusal: true,
      );

    case 'lagna':
      return Answer(
        title: hindi ? 'आपका लग्न' : 'Your lagna',
        body: hindi
            ? 'जन्म के समय ${_sign(k.lagnaRashi, true)} राशि उदय हो रही थी, ${formatDegrees(k.ascendant % 30)} अंश पर। लग्न का स्वामी ${_name(rashiInfo(k.lagnaRashi).lord, true)} है, जो ${k.grahas[rashiInfo(k.lagnaRashi).lord]!.house}वें भाव में ${_sign(k.grahas[rashiInfo(k.lagnaRashi).lord]!.rashi, true)} राशि में है। लग्न शरीर, स्वभाव और जीवन की दिशा का भाव है।'
            : 'At your birth ${_sign(k.lagnaRashi, false)} was rising, at ${formatDegrees(k.ascendant % 30)}. Its lord is ${_name(rashiInfo(k.lagnaRashi).lord, false)}, standing in house ${k.grahas[rashiInfo(k.lagnaRashi).lord]!.house} in ${_sign(k.grahas[rashiInfo(k.lagnaRashi).lord]!.rashi, false)}. The lagna is read for the body, the temperament and the direction of a life.',
        basis: <String>[
          hindi
              ? 'लग्न: ${_sign(k.lagnaRashi, true)}'
              : 'Lagna: ${_sign(k.lagnaRashi, false)}',
          hindi
              ? 'अयनांश: ${formatDegrees(k.ayanamsaValue)}'
              : 'Ayanamsa: ${formatDegrees(k.ayanamsaValue)}',
        ],
      );

    case 'moon':
      return Answer(
        title: hindi ? 'आपकी चंद्र राशि' : 'Your moon sign',
        body: hindi
            ? 'चंद्रमा ${_sign(moon.rashi, true)} राशि में ${formatDegrees(moon.degreesInSign)} पर है, ${_nak(moon.nakshatra, true)} नक्षत्र के ${moon.pada}वें पाद में। भारतीय परंपरा में "राशि" का अर्थ प्रायः यही चंद्र राशि है, सूर्य राशि नहीं। आपकी सूर्य राशि ${_sign(sun.rashi, true)} है।'
            : 'The Moon stands in ${_sign(moon.rashi, false)} at ${formatDegrees(moon.degreesInSign)}, in ${_nak(moon.nakshatra, false)} nakshatra, pada ${moon.pada}. In Indian practice "your rashi" means this moon sign rather than the sun sign; your sun sign is ${_sign(sun.rashi, false)}.',
        basis: <String>[
          hindi
              ? 'चंद्र: ${_sign(moon.rashi, true)} ${formatDegrees(moon.degreesInSign)}'
              : 'Moon: ${_sign(moon.rashi, false)} ${formatDegrees(moon.degreesInSign)}',
          hindi
              ? 'नक्षत्र: ${_nak(moon.nakshatra, true)}'
              : 'Nakshatra: ${_nak(moon.nakshatra, false)}',
        ],
      );

    case 'nakshatra':
      final NakshatraInfo n = moon.nakshatra;
      return Answer(
        title: hindi ? 'आपका जन्म नक्षत्र' : 'Your janma nakshatra',
        body: hindi
            ? '${_nak(n, true)}, पाद ${moon.pada}। इसके देवता ${n.deityHindi} हैं और स्वामी ${_name(n.lord, true)}। इसी स्वामी से आपकी विंशोत्तरी दशा शुरू होती है। प्रतीक: ${n.symbolEnglish}।'
            : '${_nak(n, false)}, pada ${moon.pada}. Its deity is ${n.deityEnglish} and its lord is ${_name(n.lord, false)}, which is where your Vimshottari dasha begins. Its symbol is ${n.symbolEnglish.toLowerCase()}.',
        basis: <String>[
          hindi
              ? 'चंद्र देशांतर: ${formatDegrees(moon.siderealLongitude)}'
              : 'Moon longitude: ${formatDegrees(moon.siderealLongitude)}',
        ],
      );

    case 'dasha':
      final List<DashaPeriod> chain = k.dashaChainAt(moment);
      if (chain.isEmpty) {
        return _fallback(hindi);
      }
      final DashaPeriod maha = chain[0];
      final DashaPeriod antar = chain.length > 1 ? chain[1] : chain[0];
      return Answer(
        title: hindi ? 'अभी चल रही दशा' : 'The period running now',
        body: hindi
            ? '${_name(maha.lord, true)} की महादशा चल रही है, जो ${_date(maha.end, true)} तक रहेगी। इसके भीतर ${_name(antar.lord, true)} की अंतर्दशा ${_date(antar.end, true)} तक है। महादशा जीवन का बड़ा अध्याय है; अंतर्दशा उसका वर्तमान पन्ना।'
            : '${_name(maha.lord, false)} mahadasha is running until ${_date(maha.end, false)}, and inside it the ${_name(antar.lord, false)} antardasha runs until ${_date(antar.end, false)}. The mahadasha is the long chapter; the antardasha is the page you are on.',
        basis: <String>[
          hindi
              ? 'जन्म के समय शेष: ${_name(k.vimshottari.first.lord, true)}'
              : 'Balance at birth: ${_name(k.vimshottari.first.lord, false)}',
          hindi
              ? 'आधार: चंद्र नक्षत्र ${_nak(moon.nakshatra, true)}'
              : 'From the Moon in ${_nak(moon.nakshatra, false)}',
        ],
      );

    case 'sadesati':
      final SadeSati status = sadeSatiStatus(k, moment);
      return Answer(
        title: hindi ? 'साढ़े साती' : 'Sade Sati',
        body: hindi
            ? '${status.detailHindi} साढ़े साती तब कही जाती है जब शनि जन्म चंद्र राशि से बारहवीं, पहली या दूसरी राशि में हों। यह परिश्रम और ज़िम्मेदारी का काल माना जाता है, दंड का नहीं।'
            : '${status.detail} Sade Sati is the stretch when Saturn transits the twelfth, first and second signs from the natal Moon. The tradition reads it as a period of work and responsibility, not punishment.',
        basis: <String>[
          hindi
              ? 'जन्म चंद्र राशि: ${_sign(k.moonRashi, true)}'
              : 'Natal moon sign: ${_sign(k.moonRashi, false)}',
        ],
      );

    case 'mangal':
      final bool has = hasMangalDosha(k);
      final PlacedGraha mars = k.grahas[Graha.mars]!;
      return Answer(
        title: hindi ? 'मंगल दोष' : 'Mangal dosha',
        body: has
            ? (hindi
                  ? 'हाँ, परंपरागत नियम से यह कुंडली मांगलिक है: मंगल लग्न से ${mars.house}वें भाव में ${_sign(mars.rashi, true)} राशि में है। यह दोष बहुत आम है, और शास्त्र इसके कई भंग भी बताते हैं। यह किसी व्यक्ति पर फ़ैसला नहीं है।'
                  : 'Yes, by the classical rule this chart is manglik: Mars stands in house ${mars.house} in ${_sign(mars.rashi, false)}. The condition is very common and the texts give several cancellations for it. It is not a verdict on anyone.')
            : (hindi
                  ? 'नहीं। मंगल लग्न से ${mars.house}वें भाव में है, और मांगलिक भाव (1, 2, 4, 7, 8, 12) में नहीं आता।'
                  : 'No. Mars stands in house ${mars.house}, which is not one of the manglik houses (1, 2, 4, 7, 8, 12).'),
        basis: <String>[
          hindi
              ? 'मंगल: ${_sign(mars.rashi, true)}, भाव ${mars.house}'
              : 'Mars: ${_sign(mars.rashi, false)}, house ${mars.house}',
        ],
      );

    case 'marriage':
      final int seventhSign = k.signOfHouse(7);
      final Graha seventhLord = rashiInfo(Rashi.values[seventhSign]).lord;
      final PlacedGraha venus = k.grahas[Graha.venus]!;
      return Answer(
        title: hindi ? 'विवाह के भाव' : 'What the chart reads for marriage',
        body: hindi
            ? 'विवाह के लिए सातवाँ भाव, उसका स्वामी, शुक्र और नवांश (D9) देखे जाते हैं। आपके यहाँ सातवाँ भाव ${_sign(Rashi.values[seventhSign], true)} का है, स्वामी ${_name(seventhLord, true)} ${k.grahas[seventhLord]!.house}वें भाव में है, और शुक्र ${_sign(venus.rashi, true)} राशि में ${venus.house}वें भाव में है। नवांश में लग्न ${_sign(Rashi.values[k.vargaLagna(Varga.d9)], true)} है। ऐप तिथि या फ़ैसला नहीं बताता; ये वे सूत्र हैं जिनसे परंपरा पढ़ती है।'
            : 'Marriage is read from the seventh house, its lord, Venus and the navamsa. Here the seventh house is ${_sign(Rashi.values[seventhSign], false)}, its lord ${_name(seventhLord, false)} stands in house ${k.grahas[seventhLord]!.house}, and Venus is in ${_sign(venus.rashi, false)} in house ${venus.house}. In the navamsa your lagna is ${_sign(Rashi.values[k.vargaLagna(Varga.d9)], false)}. The app gives you the factors, not a date or a decision.',
        basis: <String>[
          hindi
              ? 'सातवाँ भाव: ${_sign(Rashi.values[seventhSign], true)}'
              : 'Seventh house: ${_sign(Rashi.values[seventhSign], false)}',
          hindi
              ? 'नवांश लग्न: ${_sign(Rashi.values[k.vargaLagna(Varga.d9)], true)}'
              : 'Navamsa lagna: ${_sign(Rashi.values[k.vargaLagna(Varga.d9)], false)}',
        ],
      );

    case 'career':
      final int tenthSign = k.signOfHouse(10);
      final Graha tenthLord = rashiInfo(Rashi.values[tenthSign]).lord;
      return Answer(
        title: hindi ? 'करियर के भाव' : 'What the chart reads for work',
        body: hindi
            ? 'कर्म के लिए दसवाँ भाव, उसका स्वामी, शनि और दशमांश (D10) देखे जाते हैं। आपका दसवाँ भाव ${_sign(Rashi.values[tenthSign], true)} है और उसका स्वामी ${_name(tenthLord, true)} ${k.grahas[tenthLord]!.house}वें भाव में ${_sign(k.grahas[tenthLord]!.rashi, true)} राशि में है। दशमांश में लग्न ${_sign(Rashi.values[k.vargaLagna(Varga.d10)], true)} है।'
            : 'Work is read from the tenth house, its lord, Saturn and the dasamsa. Your tenth house is ${_sign(Rashi.values[tenthSign], false)} and its lord ${_name(tenthLord, false)} stands in house ${k.grahas[tenthLord]!.house} in ${_sign(k.grahas[tenthLord]!.rashi, false)}. In the dasamsa your lagna is ${_sign(Rashi.values[k.vargaLagna(Varga.d10)], false)}.',
        basis: <String>[
          hindi
              ? 'दसवाँ भाव: ${_sign(Rashi.values[tenthSign], true)}'
              : 'Tenth house: ${_sign(Rashi.values[tenthSign], false)}',
        ],
      );

    case 'education':
      final PlacedGraha mercury = k.grahas[Graha.mercury]!;
      final PlacedGraha jupiter = k.grahas[Graha.jupiter]!;
      return Answer(
        title: hindi ? 'शिक्षा के भाव' : 'What the chart reads for study',
        body: hindi
            ? 'विद्या के लिए चौथा और पाँचवाँ भाव, बुध, गुरु और चतुर्विंशांश (D24) देखे जाते हैं। बुध ${_sign(mercury.rashi, true)} में ${mercury.house}वें भाव में है और गुरु ${_sign(jupiter.rashi, true)} में ${jupiter.house}वें भाव में।'
            : 'Study is read from the fourth and fifth houses, Mercury, Jupiter and the D24. Mercury stands in ${_sign(mercury.rashi, false)} in house ${mercury.house}, and Jupiter in ${_sign(jupiter.rashi, false)} in house ${jupiter.house}.',
        basis: <String>[
          hindi
              ? 'बुध भाव ${mercury.house}'
              : 'Mercury in house ${mercury.house}',
          hindi
              ? 'गुरु भाव ${jupiter.house}'
              : 'Jupiter in house ${jupiter.house}',
        ],
      );

    case 'money':
      final int secondSign = k.signOfHouse(2);
      final int eleventhSign = k.signOfHouse(11);
      return Answer(
        title: hindi ? 'धन के भाव' : 'What the chart reads for wealth',
        body: hindi
            ? 'धन के लिए दूसरा (संचय) और ग्यारहवाँ (आय) भाव और उनके स्वामी देखे जाते हैं। यहाँ दूसरा भाव ${_sign(Rashi.values[secondSign], true)} और ग्यारहवाँ ${_sign(Rashi.values[eleventhSign], true)} है। ऐप निवेश की सलाह नहीं देता।'
            : 'Wealth is read from the second house for what is kept and the eleventh for what comes in, with their lords. Here the second is ${_sign(Rashi.values[secondSign], false)} and the eleventh is ${_sign(Rashi.values[eleventhSign], false)}. The app gives no investment advice.',
        basis: <String>[
          hindi
              ? 'दूसरा भाव: ${_sign(Rashi.values[secondSign], true)}'
              : 'Second house: ${_sign(Rashi.values[secondSign], false)}',
        ],
      );

    case 'remedy':
      final Graha lagnaLord = rashiInfo(k.lagnaRashi).lord;
      final GrahaInfo info = grahaInfo(lagnaLord);
      return Answer(
        title: hindi ? 'परंपरागत उपाय' : 'The traditional remedy',
        body: hindi
            ? 'आपके लग्न के स्वामी ${info.hindi} हैं। परंपरा में इनके लिए बताया गया है: मंत्र "${info.mantra}", रत्न ${info.gemstoneHindi} (धातु: ${info.metal}), देवता ${info.deityHindi}, और ${['रविवार', 'सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार'][info.weekday]} का व्रत या दान। रत्न धारण करने से पहले किसी जानकार से पूछें; मंत्र और दान सबके लिए सुरक्षित हैं।'
            : 'Your lagna lord is ${info.english}. The tradition gives it the mantra "${info.mantra}", the gemstone ${info.gemstone} set in ${info.metal.toLowerCase()}, the deity ${info.deityEnglish}, and fasting or giving on ${<String>['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][info.weekday]}. Ask someone knowledgeable before wearing a stone; mantra and giving are safe for anyone.',
        basis: <String>[
          hindi ? 'लग्न स्वामी: ${info.hindi}' : 'Lagna lord: ${info.english}',
        ],
      );

    case 'strength':
      final List<PlacedGraha> ranked =
          k.grahas.values
              .where(
                (PlacedGraha g) =>
                    g.graha != Graha.rahu && g.graha != Graha.ketu,
              )
              .toList()
            ..sort(
              (PlacedGraha a, PlacedGraha b) =>
                  _dignityRank(a.dignity).compareTo(_dignityRank(b.dignity)),
            );
      final PlacedGraha best = ranked.first;
      final PlacedGraha worst = ranked.last;
      return Answer(
        title: hindi ? 'बलवान और कमज़ोर ग्रह' : 'Strong and weak grahas',
        body: hindi
            ? 'स्थिति के आधार पर सबसे अच्छी अवस्था में ${_name(best.graha, true)} है (${_dignityName(best.dignity, true)}, ${_sign(best.rashi, true)} राशि, भाव ${best.house})। सबसे दबा हुआ ${_name(worst.graha, true)} है (${_dignityName(worst.dignity, true)}, ${_sign(worst.rashi, true)} राशि, भाव ${worst.house})। यह केवल राशि-बल है; षड्बल आगे जोड़ा जाएगा।'
            : 'By sign placement the best placed is ${_name(best.graha, false)} (${_dignityName(best.dignity, false)} in ${_sign(best.rashi, false)}, house ${best.house}). The most pressed is ${_name(worst.graha, false)} (${_dignityName(worst.dignity, false)} in ${_sign(worst.rashi, false)}, house ${worst.house}). This is dignity alone; shadbala comes later.',
        basis: <String>[hindi ? 'अवस्था तालिका से' : 'From the dignity table'],
      );

    case 'retrograde':
      final List<PlacedGraha> retro = k.grahas.values
          .where((PlacedGraha g) => g.isRetrograde)
          .toList();
      return Answer(
        title: hindi ? 'वक्री ग्रह' : 'Retrograde grahas',
        body: retro.isEmpty
            ? (hindi
                  ? 'जन्म के समय कोई ग्रह वक्री नहीं था (राहु और केतु सदा वक्र गति में रहते हैं)।'
                  : 'No graha was retrograde at your birth, apart from Rahu and Ketu, which always move backwards.')
            : (hindi
                  ? 'जन्म के समय ${retro.map((PlacedGraha g) => _name(g.graha, true)).join(', ')} वक्री थे। वक्री ग्रह को परंपरा में भीतर की ओर मुड़ा हुआ, और प्रायः अधिक बलवान माना जाता है।'
                  : '${retro.map((PlacedGraha g) => _name(g.graha, false)).join(', ')} were retrograde at your birth. The tradition reads a retrograde graha as turned inward, and often as stronger rather than weaker.'),
        basis: <String>[
          hindi ? 'गति की गणना से' : 'From the computed daily motion',
        ],
      );

    case 'yogas':
      final List<YogaFinding> findings = findYogas(k);
      if (findings.isEmpty) {
        return Answer(
          title: hindi ? 'योग और दोष' : 'Yogas and doshas',
          body: hindi
              ? 'इस कुंडली में कोई बड़ा योग या दोष प्रमुख नहीं निकला।'
              : 'No major yoga or dosha stands out in this chart.',
          basis: const <String>[],
        );
      }
      return Answer(
        title: hindi ? 'आपकी कुंडली के योग' : 'The yogas in your chart',
        body: findings
            .map(
              (YogaFinding f) =>
                  '• ${hindi ? f.nameHindi : f.nameEnglish}: ${hindi ? f.ruleHindi : f.ruleEnglish}',
            )
            .join('\n'),
        basis: <String>[
          hindi
              ? '${findings.length} योग/दोष मिले'
              : '${findings.length} findings',
        ],
      );

    case 'navamsa':
      return Answer(
        title: hindi ? 'नवांश (D9)' : 'The navamsa (D9)',
        body: hindi
            ? 'नवांश में आपका लग्न ${_sign(Rashi.values[k.vargaLagna(Varga.d9)], true)} है। नवांश राशि के हर 3°20\' का चार्ट है और इसे विवाह, धर्म और भीतरी बल के लिए पढ़ा जाता है। जो ग्रह राशि में कमज़ोर दिखे पर नवांश में बलवान हो, उसे परंपरा दुबारा बलवान मानती है।'
            : 'In the navamsa your lagna is ${_sign(Rashi.values[k.vargaLagna(Varga.d9)], false)}. The navamsa divides every sign into nine parts of 3°20\' and is read for marriage, dharma and inner strength. A graha that looks weak in the rasi chart but strong here is read as recovering its strength.',
        basis: <String>[hindi ? 'D9 गणना' : 'D9 computation'],
      );

    case 'whatis_nakshatra':
      return Answer(
        title: hindi ? 'नक्षत्र क्या है' : 'What a nakshatra is',
        body: hindi
            ? 'आकाश के 360 अंशों को 27 बराबर भागों में बाँटा गया है; हर भाग 13°20\' का है और उसे नक्षत्र कहते हैं। चंद्रमा एक दिन में लगभग एक नक्षत्र पार करता है। जन्म के समय चंद्र जिस नक्षत्र में हो, वही जन्म नक्षत्र है, और उसी से विंशोत्तरी दशा शुरू होती है।'
            : 'The circle of 360 degrees is divided into 27 equal parts of 13°20\' each, and each part is a nakshatra. The Moon crosses about one a day. The one it stands in at birth is your janma nakshatra, and it is where the Vimshottari dasha starts.',
        basis: const <String>[],
      );

    case 'whatis_dasha':
      return Answer(
        title: hindi ? 'दशा क्या है' : 'What a dasha is',
        body: hindi
            ? 'विंशोत्तरी दशा 120 वर्ष का चक्र है जिसमें हर ग्रह को एक निश्चित अवधि मिलती है: केतु 7, शुक्र 20, सूर्य 6, चंद्र 10, मंगल 7, राहु 18, गुरु 16, शनि 19 और बुध 17 वर्ष। जन्म के समय चंद्र जिस नक्षत्र में था, उसके स्वामी की दशा से शुरुआत होती है, और उसका बचा हुआ भाग ही पहली दशा होती है।'
            : 'Vimshottari is a 120-year cycle in which each graha holds a fixed span: Ketu 7, Venus 20, Sun 6, Moon 10, Mars 7, Rahu 18, Jupiter 16, Saturn 19 and Mercury 17 years. It starts with the lord of the nakshatra the Moon stood in at birth, and only the unspent part of that span is left to you.',
        basis: const <String>[],
      );

    default:
      return _fallback(hindi);
  }
}

int _dignityRank(Dignity dignity) => switch (dignity) {
  Dignity.exalted => 0,
  Dignity.moolatrikona => 1,
  Dignity.own => 2,
  Dignity.friend => 3,
  Dignity.neutral => 4,
  Dignity.enemy => 5,
  Dignity.debilitated => 6,
};

String _dignityName(Dignity dignity, bool hindi) => switch (dignity) {
  Dignity.exalted => hindi ? 'उच्च' : 'exalted',
  Dignity.moolatrikona => hindi ? 'मूलत्रिकोण' : 'moolatrikona',
  Dignity.own => hindi ? 'स्वराशि' : 'own sign',
  Dignity.friend => hindi ? 'मित्र राशि' : 'friendly sign',
  Dignity.neutral => hindi ? 'सम राशि' : 'neutral sign',
  Dignity.enemy => hindi ? 'शत्रु राशि' : 'enemy sign',
  Dignity.debilitated => hindi ? 'नीच' : 'debilitated',
};

Answer _fallback(bool hindi) => Answer(
  title: hindi ? 'अभी इसका उत्तर नहीं' : 'Not yet',
  body: hindi
      ? 'इस कुंडली से अभी इसका उत्तर नहीं दे सकता। नीचे दिए सवालों में से कोई चुनें, या दूसरे शब्दों में पूछें।'
      : 'I cannot answer that from this chart yet. Pick one of the questions below, or ask it in other words.',
  basis: const <String>[],
  isFallback: true,
);
