import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/matching.dart' show hasMangalDosha;
import '../engine/jyotish/phaladesh.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/varga.dart';
import 'ask_context.dart';
import 'ask_language.dart';

/// A part of life the chart is asked about. A topic is a set of houses and
/// natural significators to read, never an event to forecast.
class Topic {
  const Topic({
    required this.key,
    required this.keywords,
    required this.readHouses,
    required this.touchHouses,
    required this.karakas,
    required this.nameEn,
    required this.nameHi,
    required this.titleEn,
    required this.titleHi,
    required this.introEn,
    required this.introHi,
    this.words = const <String>[],
  });

  final String key;

  /// Substrings that mark a question as being about this topic.
  final List<String> keywords;

  /// Short keywords that only count as whole words.
  final List<String> words;

  /// The houses read in full.
  final List<int> readHouses;

  /// Every house a period may concentrate on for it to count as being about
  /// this topic.
  final Set<int> touchHouses;

  /// The grahas that signify it by nature.
  final List<Graha> karakas;

  final String nameEn;
  final String nameHi;
  final String titleEn;
  final String titleHi;

  /// One sentence saying what is read for it.
  final String introEn;
  final String introHi;
}

const Topic marriageTopic = Topic(
  key: 'marriage',
  keywords: <String>[
    'marriage',
    'wedding',
    'spouse',
    'marry',
    'married',
    'shadi',
    'shaadi',
    'vivah',
    'विवाह',
    'शादी',
    'जीवनसाथी',
    'जीवन साथी',
    'रिश्ता',
    'रिश्ते',
    'husband',
    'wife',
    'partner',
  ],
  words: <String>['पति', 'पत्नी'],
  readHouses: <int>[7],
  touchHouses: <int>{7},
  karakas: <Graha>[Graha.venus],
  nameEn: 'marriage and partnership',
  nameHi: 'विवाह और साझेदारी',
  titleEn: 'Marriage and partnership',
  titleHi: 'विवाह और साझेदारी',
  introEn:
      'For marriage and partnership the tradition reads the seventh house, its lord, Venus as the natural significator, and the navamsa.',
  introHi:
      'विवाह और साझेदारी के लिए शास्त्र सातवाँ भाव, उसका स्वामी, कारक शुक्र और नवांश देखता है।',
);

const Topic careerTopic = Topic(
  key: 'career',
  keywords: <String>[
    'career',
    'job',
    'work',
    'business',
    'profession',
    'naukri',
    'kaam',
    'करियर',
    'नौकरी',
    'काम',
    'व्यापार',
    'रोज़गार',
    'रोजगार',
    'कारोबार',
    'employment',
  ],
  readHouses: <int>[10],
  touchHouses: <int>{10, 6, 11},
  karakas: <Graha>[Graha.saturn],
  nameEn: 'work and career',
  nameHi: 'काम और करियर',
  titleEn: 'Work and career',
  titleHi: 'काम और करियर',
  introEn:
      'For work the tradition reads the tenth house, its lord, Saturn as the significator of work, and the dasamsa; the sixth and eleventh houses are read alongside for daily work and for gains.',
  introHi:
      'काम के लिए शास्त्र दसवाँ भाव, उसका स्वामी, कारक शनि और दशमांश देखता है; रोज़ के काम और कमाई के लिए छठा और ग्यारहवाँ भाव साथ में पढ़े जाते हैं।',
);

const Topic moneyTopic = Topic(
  key: 'money',
  keywords: <String>[
    'money',
    'wealth',
    'dhan',
    'income',
    'paisa',
    'earning',
    'salary',
    'धन',
    'पैसा',
    'कमाई',
    'वेतन',
    'पैसे',
    'पैसों',
    'आमदनी',
    'आर्थिक',
    'finance',
    'financial',
    'savings',
    'बचत',
  ],
  words: <String>['आय'],
  readHouses: <int>[2, 11],
  touchHouses: <int>{2, 11},
  karakas: <Graha>[Graha.jupiter],
  nameEn: 'money and income',
  nameHi: 'पैसा और कमाई',
  titleEn: 'Money and income',
  titleHi: 'पैसा और कमाई',
  introEn:
      'For money the tradition reads the second house for what is kept and the eleventh for what comes in, with their lords and Jupiter as the natural significator. This is a reading of the chart, not investment advice.',
  introHi:
      'पैसे के लिए शास्त्र दूसरा भाव (जो बचता है) और ग्यारहवाँ भाव (जो आता है), उनके स्वामी और कारक गुरु को देखता है। यह कुंडली का पाठ है, निवेश की सलाह नहीं।',
);

const Topic educationTopic = Topic(
  key: 'education',
  keywords: <String>[
    'education',
    'study',
    'exam',
    'padhai',
    'शिक्षा',
    'पढ़ाई',
    'पढाई',
    'विद्या',
    'पढ़ने',
    'पढ़ना',
    'student',
    'college',
    'school',
    'विद्यार्थी',
    'कॉलेज',
    'स्कूल',
  ],
  readHouses: <int>[4, 5],
  touchHouses: <int>{4, 5},
  karakas: <Graha>[Graha.mercury, Graha.jupiter],
  nameEn: 'study and learning',
  nameHi: 'पढ़ाई और विद्या',
  titleEn: 'Study and learning',
  titleHi: 'पढ़ाई और विद्या',
  introEn:
      'For study the tradition reads the fourth and fifth houses, Mercury and Jupiter as the significators of learning, and the D24. It reads how learning goes, not how any single examination will turn out.',
  introHi:
      'पढ़ाई के लिए शास्त्र चौथा और पाँचवाँ भाव, कारक बुध और गुरु और चतुर्विंशांश (D24) देखता है। यहाँ पढ़ाई का रुझान पढ़ा जाता है, किसी एक परीक्षा के नतीजे का अनुमान नहीं लगाया जाता।',
);

const List<Topic> allTopics = <Topic>[
  marriageTopic,
  careerTopic,
  moneyTopic,
  educationTopic,
];

/// The topic a lowercased question is about, or null. The order is the order
/// of the intents, so a question that names two gets the first.
Topic? topicOf(String question) {
  final String text = foldHindi(question.toLowerCase());
  for (final Topic t in allTopics) {
    if (t.keywords.any((String k) => text.contains(foldHindi(k)))) return t;
    if (t.words.any((String w) => hasWholeWord(text, foldHindi(w)))) return t;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Reading a topic from the chart
// ---------------------------------------------------------------------------

String _sarvaWord(AskCtx c, int bindus) {
  if (bindus >= 30) return c.l.t('a good count', 'अच्छी गिनती');
  if (bindus >= 25) return c.l.t('an average count', 'सामान्य गिनती');
  return c.l.t('a lighter count', 'कुछ कम गिनती');
}

String _housePara(AskCtx c, int h) {
  final l = c.l;
  final BhavaReading b = c.p.bhavas[h - 1];
  final String sign = l.sign(b.sign);
  final String lord = c.name(b.lord);
  final String lordSign = l.sign(b.lordSign);
  final List<String> out = <String>[
    l.t(
      'Your ${l.ordinal(h)} house is $sign, and its lord $lord stands in ${l.house(b.lordHouse)}, in $lordSign, ${l.dignityIn(b.lordDignity)}.',
      'आपका ${l.houseSubject(h)} $sign राशि का है, और उसका स्वामी $lord $lordSign राशि में, ${l.house(b.lordHouse)} में बैठा है — ${l.dignityIn(b.lordDignity)}।',
    ),
  ];
  if (b.occupants.isEmpty) {
    out.add(
      l.t('No graha sits in this house.', 'इस भाव में कोई ग्रह नहीं बैठा है।'),
    );
  } else {
    final String who = l.list(b.occupants.map(c.name).toList());
    out.add(l.t('$who sits in this house.', 'इस भाव में $who बैठा है।'));
  }
  if (b.aspectedBy.isNotEmpty) {
    final String who = l.list(b.aspectedBy.map(c.name).toList());
    out.add(
      l.t('It receives the aspect of $who.', 'इस भाव पर $who की दृष्टि है।'),
    );
  }
  out.add(
    l.t(
      'The sign carries ${b.signBindus} sarvashtakavarga bindus, ${_sarvaWord(c, b.signBindus)}.',
      'इस राशि में सर्वाष्टकवर्ग के ${b.signBindus} बिंदु हैं, जो ${_sarvaWord(c, b.signBindus)} है।',
    ),
  );
  out.add(
    l.t(
      'Taken together, the house reads as ${l.toneWord(b.tone)}.',
      'सब मिलाकर यह भाव ${l.toneWord(b.tone)} पढ़ा गया है।',
    ),
  );
  if (b.relief != null && b.tone != Tone.supportive) {
    out.add(
      l.t('What eases it: ${b.relief!.en}', 'राहत की बात: ${b.relief!.hi}'),
    );
  }
  return out.join(' ');
}

String _karakaPara(AskCtx c, Topic t) {
  final l = c.l;
  final List<String> lines = <String>[];
  for (final Graha g in t.karakas) {
    final PlacedGraha p = c.k.grahas[g]!;
    lines.add(
      l.t(
        '${c.name(g)}, the natural significator, stands in ${l.house(p.house)}, in ${l.sign(p.rashi)}, ${l.dignityIn(p.dignity)}. ${c.strengthLine(g)}',
        'कारक ${c.name(g)} ${l.sign(p.rashi)} राशि में, ${l.house(p.house)} में बैठा है — ${l.dignityIn(p.dignity)}। ${c.strengthLine(g)}',
      ),
    );
  }
  return lines.join(' ');
}

String? _vargaLine(AskCtx c, Topic t) {
  final l = c.l;
  switch (t.key) {
    case 'marriage':
      final String s = l.sign(Rashi.values[c.k.vargaLagna(Varga.d9)]);
      return l.t(
        'In the navamsa (D9), which is read for marriage and inner strength, your lagna is $s.',
        'नवांश (D9) में, जिसे विवाह और भीतरी बल के लिए पढ़ा जाता है, आपका लग्न $s है।',
      );
    case 'career':
      final String s = l.sign(Rashi.values[c.k.vargaLagna(Varga.d10)]);
      return l.t(
        'In the dasamsa (D10), which is read for work and position, your lagna is $s.',
        'दशमांश (D10) में, जिसे काम और पद के लिए पढ़ा जाता है, आपका लग्न $s है।',
      );
    case 'education':
      final String s = l.sign(Rashi.values[c.k.vargaLagna(Varga.d24)]);
      return l.t(
        'In the D24, which is read for learning, your lagna is $s.',
        'D24 में, जिसे विद्या के लिए पढ़ा जाता है, आपका लग्न $s है।',
      );
  }
  return null;
}

/// How a graha is tied to a topic, as clauses that follow its name.
List<String> _concernParts(
  AskLang l, {
  required bool rules,
  required bool sits,
  required bool karaka,
}) => <String>[
  if (rules && sits)
    l.t(
      'both rules and stands in a house read for it',
      'इस विषय के भाव का स्वामी भी है और ऐसे भाव में बैठा भी है',
    )
  else if (rules)
    l.t('rules a house read for it', 'इस विषय के भाव का स्वामी है')
  else if (sits)
    l.t('stands in a house read for it', 'इस विषय के भाव में बैठा है'),
  if (karaka) l.t('is its natural significator', 'इस विषय का कारक है'),
];

/// How a period lord stands to the topic: the houses it rules, the houses it
/// stands in, and whether it is the natural significator. [linked] is false
/// when none of the three holds.
({bool linked, String text}) _link(
  AskCtx c,
  Topic t,
  Graha g, {
  required String roleEn,
  required String roleHi,
  required String roleHiOblique,
  required int depth,
}) {
  final l = c.l;
  final GrahaStanding s = c.st(g);
  final bool rules = s.houses(c.pc).any(t.touchHouses.contains);
  final bool sits = t.touchHouses.contains(s.placed.house);
  final bool karaka = t.karakas.contains(g);
  final String me = c.name(g);
  final String where = c.standing(g, depth: depth);
  final String short = c.standing(g, depth: 0);
  final List<String> parts = _concernParts(
    l,
    rules: rules,
    sits: sits,
    karaka: karaka,
  );
  if (parts.isEmpty) {
    return (
      linked: false,
      text: l.t(
        'The $roleEn is $me. $short It has no direct link with this part of life, so it works behind the scenes here.',
        '$roleHi $me है। $short $roleHiOblique का ज़िंदगी के इस हिस्से से सीधा संबंध नहीं है, इसलिए वह यहाँ पीछे काम करता है।',
      ),
    );
  }
  return (
    linked: true,
    text: l.t(
      'The $roleEn is $me. $where So $me ${l.list(parts)}.',
      '$roleHi $me है। $where इसलिए $me ${l.list(parts)}।',
    ),
  );
}

/// The paragraphs that read the topic from the chart and then link it to the
/// periods running now. Nothing in them is an event.
List<String> topicEffectParagraphs(AskCtx c, Topic t, {bool compact = false}) {
  final l = c.l;
  final List<String> out = <String>[l.t(t.introEn, t.introHi)];
  for (final int h in t.readHouses) {
    out.add(_housePara(c, h));
  }
  out.add(_karakaPara(c, t));
  final String? varga = _vargaLine(c, t);
  if (varga != null && !compact) out.add(varga);
  if (t.key == 'marriage' && hasMangalDosha(c.k) && !compact) {
    out.add(
      l.t(
        'By the traditional rule this chart is manglik. That is very common, and the shastra gives several cancellations for it; it is not a verdict on anyone. The question on Mangal dosha explains it in full.',
        'परंपरागत नियम से यह कुंडली मांगलिक है। यह बहुत आम है, और शास्त्र इसके कई भंग भी बताता है; यह किसी पर फ़ैसला नहीं है। मंगल दोष वाले सवाल में इसे पूरा समझाया गया है।',
      ),
    );
  }

  final PeriodReading? maha = c.maha;
  final PeriodReading? antar = c.antar;
  if (maha != null && antar != null) {
    final ({bool linked, String text}) a = _link(
      c,
      t,
      maha.lord,
      roleEn: 'mahadasha lord',
      roleHi: 'महादशा का स्वामी',
      roleHiOblique: 'महादशा के स्वामी',
      depth: 1,
    );
    final bool same = antar.lord == maha.lord;
    final ({bool linked, String text}) b = same
        ? a
        : _link(
            c,
            t,
            antar.lord,
            roleEn: 'antardasha lord',
            roleHi: 'अंतर्दशा का स्वामी',
            roleHiOblique: 'अंतर्दशा के स्वामी',
            depth: 0,
          );
    out.add(
      l.t(
        'Now link the running periods to it. ${a.text}${same ? ' The antardasha belongs to the very same graha, so the mahadasha’s own nature comes forward in its plainest form.' : ''}',
        'अब चल रही दशा को इससे जोड़कर देखिए। ${a.text}${same ? ' अंतर्दशा भी उसी ग्रह की है, इसलिए महादशा का अपना स्वभाव सबसे सीधे रूप में सामने रहता है।' : ''}',
      ),
    );
    if (!same) {
      out.add('${b.text} ${c.modifierLine(antar)}');
    }
    out.add(
      a.linked || b.linked
          ? l.t(
              'So this part of life is in front during this period, and the standing of the houses, lords and strength described above decides how smoothly it moves.',
              'इसलिए ज़िंदगी का यह हिस्सा इस दौर में सामने रहता है, और ऊपर बताई गई भावों, स्वामियों और बल की स्थिति तय करती है कि यह कितनी सहजता से आगे बढ़ता है।',
            )
          : l.t(
              'So this part of life stays in the background for now; the period’s weight lies elsewhere.',
              'इसलिए ज़िंदगी का यह हिस्सा अभी पीछे रहता है; दशा का ज़ोर दूसरी ओर है।',
            ),
    );
  }
  return out;
}

/// One sentence saying why a lord's period belongs to this part of life, or
/// null when it does not.
String? topicLinkSentence(AskCtx c, Topic t, Graha g) {
  final l = c.l;
  final GrahaStanding s = c.st(g);
  final bool rules = s.houses(c.pc).any(t.touchHouses.contains);
  final bool sits = t.touchHouses.contains(s.placed.house);
  final bool karaka = t.karakas.contains(g);
  final String me = c.name(g);
  final String name = l.t(t.nameEn, t.nameHi);
  final List<String> parts = _concernParts(
    l,
    rules: rules,
    sits: sits,
    karaka: karaka,
  );
  if (parts.isEmpty) return null;
  return l.t(
    'And $me ${l.list(parts)}, which is why this stretch belongs to $name.',
    'और $me ${l.list(parts)}, इसीलिए यह दौर $name से जुड़ता है।',
  );
}
