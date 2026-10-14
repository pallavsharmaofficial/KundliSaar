import '../engine/astro/angles.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/dasha.dart' show vimshottariYear, vimshottariYears;
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/matching.dart' show hasMangalDosha;
import '../engine/jyotish/nakshatra.dart';
import '../engine/jyotish/phaladesh.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/remedies.dart';
import '../engine/jyotish/shadbala.dart' show shadbalaGrahas;
import '../engine/jyotish/transits.dart';
import '../engine/jyotish/varga.dart';
import '../engine/jyotish/yogas.dart';
import 'answer_model.dart';
import 'ask_context.dart';
import 'ask_language.dart';
import 'ask_story.dart';

// =============================================================================
// The shorter answers.
//
// They keep the shape of the long one: what the chart shows, what it tends to
// mean, a word from the tradition, and the closing line. Where a question
// touches the running dasha, they say so, so no answer stands apart from the
// time the person is living in.
// =============================================================================

AnswerSection _section(
  String key,
  AskLang l,
  String en,
  String hi,
  List<String> paragraphs,
) => AnswerSection(
  key: key,
  heading: l.t(en, hi),
  paragraphs: paragraphs.where((String p) => p.trim().isNotEmpty).toList(),
);

/// "Right now you are in the Mars mahadasha and the Venus antardasha."
String runningNow(AskCtx c) {
  final PeriodReading? maha = c.maha;
  final PeriodReading? antar = c.antar;
  if (maha == null || antar == null) return '';
  return c.l.t(
    'Right now you are in the ${c.name(maha.lord)} mahadasha and the ${c.name(antar.lord)} antardasha, which runs from ${c.date(antar.start)} to ${c.date(antar.end)}.',
    'अभी आप ${c.name(maha.lord)} की महादशा और ${c.name(antar.lord)} की अंतर्दशा में हैं, जो ${c.date(antar.start)} से ${c.date(antar.end)} तक है।',
  );
}

/// What the running mahadasha lord is for this lagna, in one sentence.
String runningNature(AskCtx c) {
  final PeriodReading? maha = c.maha;
  if (maha == null) return '';
  final String m = c.name(maha.lord);
  return c.l.t(
    'The $m mahadasha is running, and $m ${natureClause(c, maha.lord)}.',
    'अभी $m की महादशा चल रही है, और $m ${natureClause(c, maha.lord)}।',
  );
}

Answer _answer(
  AskCtx c,
  String titleEn,
  String titleHi,
  List<AnswerSection> sections,
  List<String> basis,
) => Answer(
  title: c.l.t(titleEn, titleHi),
  sections: <AnswerSection>[...sections, closeSection(c.l)],
  basis: basis,
);

// -----------------------------------------------------------------------------
// Lagna, moon sign, nakshatra
// -----------------------------------------------------------------------------

Answer lagnaAnswer(AskCtx c) {
  final AskLang l = c.l;
  final Kundli k = c.k;
  final RashiInfo info = rashiInfo(k.lagnaRashi);
  final Graha lord = info.lord;
  final PlacedGraha lp = k.grahas[lord]!;
  final String sign = c.lagna;
  return _answer(
    c,
    'Your lagna',
    'आपका लग्न',
    <AnswerSection>[
      _section(SectionKey.now, l, 'What the chart shows', 'कुंडली में क्या मिला', <
        String
      >[
        l.t(
          'At your birth $sign was rising on the eastern horizon, at ${formatDegrees(k.ascendant % 30)}. That is your lagna, and the twelve houses of the chart are counted from it.',
          'जन्म के समय $sign राशि पूर्व क्षितिज पर उदय हो रही थी, ${formatDegrees(k.ascendant % 30)} पर। यही आपका लग्न है, और कुंडली के बारह भाव इसी से गिने जाते हैं।',
        ),
        l.t(
          'The lord of the lagna is ${c.name(lord)}. ${c.standing(lord, depth: 2)}',
          'लग्न का स्वामी (लग्नेश) ${c.name(lord)} है। ${c.standing(lord, depth: 2)}',
        ),
      ]),
      _section(SectionKey.effect, l, 'What it tends to mean', 'इसका मतलब क्या है', <
        String
      >[
        l.t(
          '$sign is a sign of ${l.element(info.element)}, so people with this lagna tend to be ${l.elementNature(info.element)}. It is also ${l.qualityNature(info.quality)}.',
          '$sign ${l.element(info.element)} तत्व की राशि है, इसलिए इस लग्न के लोग अक्सर ${l.elementNature(info.element)} होते हैं। ${l.qualityNature(info.quality)}।',
        ),
        l.t(
          'The lagna lord ${c.name(lord)} stands in ${l.house(lp.house)}, so the direction of the life leans towards ${l.area(lp.house)}.',
          'लग्नेश ${c.name(lord)} ${l.house(lp.house)} में है, इसलिए जीवन का झुकाव ${l.area(lp.house)} की ओर रहता है।',
        ),
        runningNature(c),
      ]),
      _section(
        SectionKey.how,
        l,
        'What the shastra says',
        'शास्त्र क्या कहता है',
        <String>[
          l.t(
            'In the shastra the lagna is the house of the body, the temperament and the direction of a life, and every other house is counted from it. The standing and strength of its lord are taken as the foundation of the whole chart.',
            'शास्त्र में लग्न शरीर, स्वभाव और जीवन की दिशा का भाव है, और बाक़ी सारे भाव इसी से गिने जाते हैं। लग्नेश की स्थिति और बल को पूरी कुंडली की नींव माना जाता है।',
          ),
        ],
      ),
    ],
    <String>[
      l.t('Lagna: $sign', 'लग्न: $sign'),
      l.t(
        'Lagna lord: ${c.name(lord)}, house ${lp.house}',
        'लग्नेश: ${c.name(lord)}, भाव ${lp.house}',
      ),
      l.t(
        'Ayanamsa: ${formatDegrees(k.ayanamsaValue)}',
        'अयनांश: ${formatDegrees(k.ayanamsaValue)}',
      ),
    ],
  );
}

Answer moonAnswer(AskCtx c) {
  final AskLang l = c.l;
  final Kundli k = c.k;
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final PlacedGraha sun = k.grahas[Graha.sun]!;
  final RashiInfo info = rashiInfo(moon.rashi);
  final String sign = l.sign(moon.rashi);
  final String nak = l.nakshatra(moon.nakshatra);
  return _answer(
    c,
    'Your moon sign',
    'आपकी चंद्र राशि',
    <AnswerSection>[
      _section(SectionKey.now, l, 'What the chart shows', 'कुंडली में क्या मिला', <
        String
      >[
        l.t(
          'The Moon stands in $sign at ${formatDegrees(moon.degreesInSign)}, in the ${l.ordinal(moon.pada)} pada of $nak nakshatra. In Indian practice “your rashi” usually means this moon sign rather than the sun sign; your sun sign is ${l.sign(sun.rashi)}.',
          'चंद्रमा $sign राशि में ${formatDegrees(moon.degreesInSign)} पर है, $nak नक्षत्र के ${l.ordinal(moon.pada)} पाद में। भारतीय परंपरा में “आपकी राशि” का मतलब आमतौर पर यही चंद्र राशि है, सूर्य राशि नहीं; आपकी सूर्य राशि ${l.sign(sun.rashi)} है।',
        ),
        c.standing(Graha.moon, depth: 2),
      ]),
      _section(SectionKey.effect, l, 'What it tends to mean', 'इसका मतलब क्या है', <
        String
      >[
        l.t(
          'The Moon stands for the mind. $sign is a sign of ${l.element(info.element)}, so the mind tends to be ${l.elementMind(info.element)}.',
          'चंद्रमा मन का कारक है। $sign ${l.element(info.element)} तत्व की राशि है, इसलिए मन अक्सर ${l.elementMind(info.element)} रहता है।',
        ),
        l.t(
          'The Moon stands in ${l.house(moon.house)} of your chart, so the mind leans towards ${l.area(moon.house)}.',
          'चंद्रमा आपकी कुंडली के ${l.house(moon.house)} में है, इसलिए मन का झुकाव ${l.area(moon.house)} की ओर रहता है।',
        ),
        runningNature(c),
      ]),
      _section(
        SectionKey.how,
        l,
        'What the shastra says',
        'शास्त्र क्या कहता है',
        <String>[
          l.t(
            'The count of dashas begins from the Moon’s nakshatra. Yours is $nak, whose lord is ${c.name(moon.nakshatra.lord)}, so your Vimshottari dasha began with ${c.name(moon.nakshatra.lord)}. The transits, and Sade Sati, are counted from this moon sign too.',
            'दशा की गिनती चंद्रमा के नक्षत्र से शुरू होती है। आपका नक्षत्र $nak है, जिसके स्वामी ${c.name(moon.nakshatra.lord)} हैं, इसलिए आपकी विंशोत्तरी दशा ${c.name(moon.nakshatra.lord)} से शुरू हुई। गोचर और साढ़े साती भी इसी चंद्र राशि से गिने जाते हैं।',
          ),
        ],
      ),
    ],
    <String>[
      l.t(
        'Moon: $sign ${formatDegrees(moon.degreesInSign)}',
        'चंद्र: $sign ${formatDegrees(moon.degreesInSign)}',
      ),
      l.t('Nakshatra: $nak', 'नक्षत्र: $nak'),
      l.t('Sun: ${l.sign(sun.rashi)}', 'सूर्य: ${l.sign(sun.rashi)}'),
    ],
  );
}

Answer nakshatraAnswer(AskCtx c) {
  final AskLang l = c.l;
  final Kundli k = c.k;
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final NakshatraInfo n = moon.nakshatra;
  final String nak = l.nakshatra(n);
  final String lord = c.name(n.lord);
  final double leftYears = k.vimshottari.first.lengthDays / vimshottariYear;
  final String full = vimshottariYears[n.lord]!.round().toString();
  return _answer(
    c,
    'Your janma nakshatra',
    'आपका जन्म नक्षत्र',
    <AnswerSection>[
      _section(SectionKey.now, l, 'What the chart shows', 'कुंडली में क्या मिला', <
        String
      >[
        l.t(
          '$nak, pada ${moon.pada}. Its deity is ${n.deityEnglish} and its lord is $lord. Its symbol is ${n.symbolEnglish.toLowerCase()}.',
          '$nak, पाद ${moon.pada}। इसके देवता ${n.deityHindi} हैं और स्वामी $lord।',
        ),
      ]),
      _section(
        SectionKey.effect,
        l,
        'How it ties to your dasha',
        'आपकी दशा से इसका रिश्ता',
        <String>[
          l.t(
            'The Moon stood in $nak at your birth, and its lord is $lord. So your life began in the middle of the $lord mahadasha: of its $full years, about ${leftYears.toStringAsFixed(1)} were left when you were born. Every dasha that followed comes from that starting point.',
            'जन्म के समय चंद्रमा $nak में था, जिसके स्वामी $lord हैं। इसलिए आपका जीवन $lord की महादशा के बीच से शुरू हुआ: उसके $full साल में से जन्म के समय लगभग ${leftYears.toStringAsFixed(1)} साल बचे थे। बाद की हर दशा इसी शुरुआत से निकलती है।',
          ),
          runningNow(c),
        ],
      ),
      _section(
        SectionKey.how,
        l,
        'What the shastra says',
        'शास्त्र क्या कहता है',
        <String>[
          l.t(
            'The shastra divides the circle of 360 degrees into 27 equal parts of 13°20′, and each part is a nakshatra. The one the Moon stands in at birth is the janma nakshatra, and the Vimshottari dasha begins with its lord.',
            'शास्त्र 360 अंश के घेरे को 27 बराबर भागों में बाँटता है, हर भाग 13°20′ का, और हर भाग एक नक्षत्र है। जन्म के समय चंद्रमा जिस नक्षत्र में हो, वही जन्म नक्षत्र है, और विंशोत्तरी दशा उसी के स्वामी से शुरू होती है।',
          ),
        ],
      ),
    ],
    <String>[
      l.t(
        'Moon longitude: ${formatDegrees(moon.siderealLongitude)}',
        'चंद्र देशांतर: ${formatDegrees(moon.siderealLongitude)}',
      ),
      l.t(
        'Nakshatra: $nak, pada ${moon.pada}',
        'नक्षत्र: $nak, पाद ${moon.pada}',
      ),
      l.t('Nakshatra lord: $lord', 'नक्षत्र स्वामी: $lord'),
    ],
  );
}

// -----------------------------------------------------------------------------
// What a nakshatra is, what a dasha is: the explanation, then your own
// -----------------------------------------------------------------------------

Answer whatIsNakshatraAnswer(AskCtx c) {
  final AskLang l = c.l;
  final PlacedGraha moon = c.k.grahas[Graha.moon]!;
  final String nak = l.nakshatra(moon.nakshatra);
  return _answer(
    c,
    'What a nakshatra is',
    'नक्षत्र क्या है',
    <AnswerSection>[
      _section(SectionKey.now, l, 'The idea', 'बात क्या है', <String>[
        l.t(
          'The circle of 360 degrees is divided into 27 equal parts of 13°20′ each, and each part is a nakshatra. The Moon crosses about one a day. The one it stands in at birth is your janma nakshatra, and it is where the Vimshottari dasha starts.',
          'आकाश के 360 अंश को 27 बराबर भागों में बाँटा गया है; हर भाग 13°20′ का है और उसे नक्षत्र कहते हैं। चंद्रमा एक दिन में लगभग एक नक्षत्र पार करता है। जन्म के समय चंद्र जिस नक्षत्र में हो, वही जन्म नक्षत्र है, और उसी से विंशोत्तरी दशा शुरू होती है।',
        ),
      ]),
      _section(SectionKey.effect, l, 'Yours', 'आपका नक्षत्र', <String>[
        l.t(
          'At your birth the Moon stood in $nak, pada ${moon.pada}, and its lord is ${c.name(moon.nakshatra.lord)}. That is why your dasha count began with ${c.name(moon.nakshatra.lord)}.',
          'आपके जन्म के समय चंद्रमा $nak नक्षत्र के पाद ${moon.pada} में था, जिसके स्वामी ${c.name(moon.nakshatra.lord)} हैं। इसीलिए आपकी दशा की गिनती ${c.name(moon.nakshatra.lord)} से शुरू हुई।',
        ),
        runningNow(c),
      ]),
    ],
    <String>[
      l.t('Nakshatra: $nak', 'नक्षत्र: $nak'),
      l.t(
        'Nakshatra lord: ${c.name(moon.nakshatra.lord)}',
        'नक्षत्र स्वामी: ${c.name(moon.nakshatra.lord)}',
      ),
    ],
  );
}

Answer whatIsDashaAnswer(AskCtx c) {
  final AskLang l = c.l;
  final PlacedGraha moon = c.k.grahas[Graha.moon]!;
  final PeriodReading? maha = c.maha;
  final String years = vimshottariOrderText(l);
  return _answer(
    c,
    'What a dasha is',
    'दशा क्या है',
    <AnswerSection>[
      _section(SectionKey.now, l, 'The idea', 'बात क्या है', <String>[
        l.t(
          'Vimshottari is a 120-year cycle in which each graha holds a fixed span: $years. It starts with the lord of the nakshatra the Moon stood in at birth, and only the unspent part of that span is left to you.',
          'विंशोत्तरी दशा 120 वर्ष का चक्र है जिसमें हर ग्रह को एक निश्चित अवधि मिलती है: $years। जन्म के समय चंद्र जिस नक्षत्र में था, उसके स्वामी की दशा से शुरुआत होती है, और उसका बचा हुआ भाग ही पहली दशा होती है।',
        ),
        l.t(
          'Each long period, the mahadasha, is divided in the same proportions into antardashas, and each of those into pratyantardashas. Think of a chapter, a page and a line.',
          'हर लंबी अवधि, यानी महादशा, इसी अनुपात में अंतर्दशाओं में बँटती है, और हर अंतर्दशा प्रत्यंतर्दशाओं में। इसे अध्याय, पन्ना और पंक्ति की तरह समझिए।',
        ),
      ]),
      _section(SectionKey.effect, l, 'Yours', 'आपकी दशा', <String>[
        l.t(
          'Your Moon stood in ${l.nakshatra(moon.nakshatra)}, whose lord is ${c.name(moon.nakshatra.lord)}, so your count began with ${c.name(moon.nakshatra.lord)}.',
          'आपका चंद्रमा ${l.nakshatra(moon.nakshatra)} में था, जिसके स्वामी ${c.name(moon.nakshatra.lord)} हैं, इसलिए आपकी गिनती ${c.name(moon.nakshatra.lord)} से शुरू हुई।',
        ),
        runningNow(c),
        if (maha != null)
          l.t(
            'The ${c.name(maha.lord)} mahadasha runs until ${c.monthYear(maha.end)}.',
            '${c.name(maha.lord)} की महादशा ${c.monthYear(maha.end)} तक चलेगी।',
          ),
      ]),
    ],
    <String>[
      l.t(
        'Nakshatra lord: ${c.name(moon.nakshatra.lord)}',
        'नक्षत्र स्वामी: ${c.name(moon.nakshatra.lord)}',
      ),
      if (maha != null)
        l.t(
          'Mahadasha now: ${c.name(maha.lord)}',
          'अभी की महादशा: ${c.name(maha.lord)}',
        ),
    ],
  );
}

/// "Ketu 7, Venus 20, ..." in the order of the cycle.
String vimshottariOrderText(AskLang l) {
  const List<Graha> order = <Graha>[
    Graha.ketu,
    Graha.venus,
    Graha.sun,
    Graha.moon,
    Graha.mars,
    Graha.rahu,
    Graha.jupiter,
    Graha.saturn,
    Graha.mercury,
  ];
  return l.list(<String>[
    for (final Graha g in order)
      '${l.graha(g)} ${vimshottariYears[g]!.round()}',
  ]);
}

// -----------------------------------------------------------------------------
// Sade Sati
// -----------------------------------------------------------------------------

Answer sadeSatiAnswer(AskCtx c) {
  final AskLang l = c.l;
  final TransitReport report = c.transits;
  final SadeSatiWindow window = report.sadeSati;
  final TransitPosition saturn = report.positions[Graha.saturn]!;
  final String moonSign = l.sign(c.k.moonRashi);
  final String saturnSign = l.sign(saturn.rashi);
  final int hm = saturn.houseFromMoon;
  final GrahaStanding st = c.st(Graha.saturn);
  final bool dhaiya = !window.isRunning && (hm == 4 || hm == 8);

  final List<AnswerSection> sections = <AnswerSection>[];

  // Now.
  final List<String> now = <String>[];
  if (window.isRunning) {
    final String phase = l.t(
      <String>['', 'first', 'second', 'third'][window.phase],
      <String>['', 'पहला', 'दूसरा', 'तीसरा'][window.phase],
    );
    final String phaseEnd = window.phaseEnd == null
        ? ''
        : l.t(
            ' This phase lasts until ${c.date(window.phaseEnd!)}',
            ' यह चरण ${c.date(window.phaseEnd!)} तक है',
          );
    final String whole = window.end == null
        ? ''
        : l.t(
            ', and the whole of Sade Sati until ${c.date(window.end!)}.',
            ', और पूरी साढ़े साती ${c.date(window.end!)} तक।',
          );
    now.add(
      l.t(
        'Yes, Sade Sati is running. Saturn is in $saturnSign, the ${l.ordinalFem(hm)} sign from your moon sign $moonSign, so this is the $phase of its three phases.$phaseEnd${whole.isEmpty ? '.' : whole}',
        'हाँ, अभी साढ़े साती चल रही है। शनि $saturnSign राशि में है, जो आपकी चंद्र राशि $moonSign से ${l.ordinalFem(hm)} राशि है, इसलिए यह तीन में से $phase चरण है।$phaseEnd${whole.isEmpty ? '।' : whole}',
      ),
    );
  } else {
    now.add(
      l.t(
        'No, Sade Sati is not running now. Saturn is in $saturnSign, the ${l.ordinalFem(hm)} sign from your moon sign $moonSign. Sade Sati is counted only while Saturn is in the 12th, 1st or 2nd sign from the moon sign.',
        'नहीं, अभी साढ़े साती नहीं चल रही। शनि $saturnSign राशि में है, जो आपकी चंद्र राशि $moonSign से ${l.ordinalFem(hm)} राशि है। साढ़े साती तभी गिनी जाती है जब शनि चंद्र राशि से बारहवीं, पहली या दूसरी राशि में हो।',
      ),
    );
    if (dhaiya) {
      now.add(
        l.t(
          'Saturn in the ${l.ordinalFem(hm)} sign from the Moon is popularly called dhaiya, a long stretch that asks for patience; it passes.',
          'शनि का चंद्र राशि से ${l.ordinalFem(hm)} राशि में होना लोक में ढैया कहलाता है; यह लंबा समय धैर्य माँगता है, और यह बीत जाता है।',
        ),
      );
    }
  }
  sections.add(
    _section(
      SectionKey.now,
      l,
      'Where Sade Sati stands now',
      'अभी साढ़े साती कहाँ है',
      now,
    ),
  );

  // What it asks of this person, read from this chart.
  final bool kind =
      st.nature == FunctionalNature.yogakaraka ||
      st.nature == FunctionalNature.benefic;
  sections.add(
    _section(
      SectionKey.effect,
      l,
      'What it asks of you, in this chart',
      'इस कुंडली में यह आपसे क्या माँगती है',
      <String>[
        l.t(
          'Sade Sati is the seven-and-a-half-year stretch in which Saturn passes over the 12th, 1st and 2nd signs from the natal Moon. The tradition reads it as a time of work and responsibility, not as punishment.',
          'साढ़े साती वह लगभग साढ़े सात साल का समय है जिसमें शनि जन्म चंद्र से बारहवीं, पहली और दूसरी राशि से गुज़रता है। परंपरा इसे मेहनत और ज़िम्मेदारी का समय मानती है, दंड का नहीं।',
        ),
        c.standing(Graha.saturn, depth: 2),
        kind
            ? l.t(
                'Because Saturn gives good results for your lagna, the time of Sade Sati tends to feel more like a teacher than a test.',
                'क्योंकि शनि आपके लग्न के लिए शुभ फल देने वाला ग्रह है, साढ़े साती का समय परीक्षा से ज़्यादा सिखाने वाले गुरु जैसा लगता है।',
              )
            : l.t(
                'Because Saturn rules houses that ask for effort in your chart, the share of work in the time of Sade Sati tends to be larger; a Saturn with enough strength still delivers what it promises.',
                'क्योंकि इस कुंडली में शनि मेहनत माँगने वाले भावों का स्वामी है, साढ़े साती के समय में मेहनत का हिस्सा बड़ा रहता है; पर पर्याप्त बल वाला शनि अपना वादा निभाता है।',
              ),
        l.t(
          'It passes over the Moon, so the Moon’s strength matters too. ${c.strengthLine(Graha.moon)}',
          'यह चंद्रमा के ऊपर से गुज़रती है, इसलिए चंद्रमा का बल भी मायने रखता है। ${c.strengthLine(Graha.moon)}',
        ),
      ],
    ),
  );

  // What helps.
  sections.add(
    _section(SectionKey.remedy, l, 'What can help', 'क्या उपाय करें', <String>[
      l.t(
        'Saturn teaches patience, regular work and keeping your word, and that is also the first thing that helps through such a time.',
        'शनि धैर्य, नियमित काम और वचन निभाना सिखाता है, और ऐसे समय में सबसे पहले यही बातें काम आती हैं।',
      ),
      ...kitParagraphs(c, Graha.saturn),
      l.t(
        'Nothing here has to be bought; what is in your house is enough. Keep these as a practice: they steady the mind, but they promise nothing about what will come.',
        'इनमें कुछ भी ख़रीदना ज़रूरी नहीं है; जो आपके घर में है, उसी से हो जाता है। इन्हें अभ्यास की तरह रखिए। ये मन को स्थिर करते हैं, पर आगे क्या होगा, इसका कोई वादा नहीं करते।',
      ),
    ]),
  );

  // How long, and what changes after.
  final List<String> better = <String>[];
  if (window.isRunning && window.end != null) {
    final List<PeriodReading> then = c.p.dasha.chainAt(window.end!);
    final String lords = then.length >= 2
        ? l.t(
            'On that date the ${c.name(then[0].lord)} mahadasha and the ${c.name(then[1].lord)} antardasha are the ones running.',
            'उस तारीख़ पर ${c.name(then[0].lord)} की महादशा और ${c.name(then[1].lord)} की अंतर्दशा चलती है।',
          )
        : '';
    better.add(
      l.t(
        '$compareMarkerEnglish, once Saturn has gone past the 2nd sign from your Moon, its direct weight on the Moon lifts: the mind, the home and everyday duties are no longer under the same slow pressure. The passage ends on ${c.date(window.end!)}. $lords',
        '$compareMarkerHindi: जब शनि चंद्र से दूसरी राशि को पार कर लेता है, तब चंद्रमा पर उसका सीधा बोझ हट जाता है: मन, घर और रोज़ की ज़िम्मेदारियों पर वही धीमा दबाव नहीं रहता। यह दौर ${c.date(window.end!)} को पूरा होता है। $lords',
      ),
    );
    better.add(
      l.t(
        'This date marks where Saturn leaves that sign, not a day on which anything is due to happen.',
        'यह तारीख़ शनि के उस राशि से निकलने की है, किसी घटना की नहीं।',
      ),
    );
  } else {
    final int twelfth = (c.k.moonRashi.index + 11) % 12;
    better.add(
      l.t(
        '$compareMarkerEnglish: while Sade Sati runs, Saturn rests its weight on the Moon, and today it does not. It would count as begun when Saturn enters ${l.sign(Rashi.values[twelfth])}, the sign before your moon sign; the app does not name a date for that here.',
        '$compareMarkerHindi: साढ़े साती के दौरान शनि चंद्रमा पर अपना भार डालता है, जो आज नहीं है। यह तब शुरू मानी जाएगी जब शनि आपकी चंद्र राशि से पहले वाली राशि ${l.sign(Rashi.values[twelfth])} में पहुँचेगा; यहाँ इसकी कोई तारीख़ नहीं दी जा रही।',
      ),
    );
  }
  sections.add(
    _section(
      SectionKey.better,
      l,
      'How long it lasts, and what changes after',
      'कब तक चलती है, और उसके बाद क्या बदलता है',
      better,
    ),
  );

  // What the tradition says.
  final int? own = st.ownBindus;
  sections.add(
    _section(SectionKey.how, l, 'What the shastra says', 'शास्त्र क्या कहता है', <
      String
    >[
      l.t(
        'The shastra counts Sade Sati by sign: it begins when Saturn enters the sign before the natal Moon’s and ends when it leaves the sign after it. The weight of a slow transit is read together with the dasha, because the dasha points the way and the transit delivers.',
        'शास्त्र साढ़े साती को राशि के हिसाब से गिनता है: यह तब शुरू होती है जब शनि जन्म चंद्र वाली राशि से पहले की राशि में आता है, और तब पूरी होती है जब वह उससे अगली राशि को छोड़ता है। धीमे गोचर का असर दशा के साथ मिलाकर पढ़ा जाता है, क्योंकि दशा संकेत देती है और गोचर फल देता है।',
      ),
      if (own != null)
        l.t(
          'In Saturn’s own ashtakavarga the sign it stands in now holds ${report.positions[Graha.saturn]!.bindusInSign} sarvashtakavarga bindus; Saturn’s weight is lighter where the count is good and heavier where it is thin.',
          'शनि जिस राशि में अभी है, उसमें सर्वाष्टकवर्ग के ${report.positions[Graha.saturn]!.bindusInSign} बिंदु हैं; जहाँ गिनती अच्छी हो वहाँ शनि का भार हल्का और जहाँ कम हो वहाँ भारी माना जाता है।',
        ),
    ]),
  );

  return _answer(c, 'Sade Sati', 'साढ़े साती', sections, <String>[
    l.t('Natal moon sign: $moonSign', 'जन्म चंद्र राशि: $moonSign'),
    l.t(
      'Saturn now: $saturnSign, ${l.ordinalFem(hm)} sign from the Moon',
      'शनि अभी: $saturnSign, चंद्र राशि से ${l.ordinalFem(hm)}',
    ),
    if (window.isRunning)
      l.t('Phase ${window.phase} of 3', 'तीन में से चरण ${window.phase}'),
  ]);
}

// -----------------------------------------------------------------------------
// Mangal dosha
// -----------------------------------------------------------------------------

Answer mangalAnswer(AskCtx c) {
  final AskLang l = c.l;
  final bool has = hasMangalDosha(c.k);
  final PlacedGraha mars = c.k.grahas[Graha.mars]!;
  final int fromMoon = ((mars.rashi.index - c.k.moonRashi.index + 12) % 12) + 1;
  YogaFinding? finding;
  for (final YogaFinding y in c.pc.yogas) {
    if (y.key == 'mangal_dosha') finding = y;
  }
  final List<AnswerSection> sections = <AnswerSection>[];

  sections.add(
    _section(SectionKey.now, l, 'What the chart shows', 'कुंडली में क्या मिला', <
      String
    >[
      has
          ? l.t(
              'Yes, by the traditional rule this chart is manglik. Mars stands in ${l.house(mars.house)} from the lagna, in ${l.sign(mars.rashi)}, and in the ${l.ordinal(fromMoon)} place from the Moon. The rule looks at the 1st, 2nd, 4th, 7th, 8th and 12th houses, from the lagna and from the Moon.',
              'हाँ, परंपरागत नियम से यह कुंडली मांगलिक है। मंगल लग्न से ${l.house(mars.house)} में, ${l.sign(mars.rashi)} राशि में है, और चंद्र से ${l.ordinal(fromMoon)} स्थान पर। नियम लग्न से और चंद्र से, पहले, दूसरे, चौथे, सातवें, आठवें और बारहवें भाव को देखता है।',
            )
          : l.t(
              'No. Mars stands in ${l.house(mars.house)} from the lagna and in the ${l.ordinal(fromMoon)} place from the Moon, and neither is among the manglik houses (1, 2, 4, 7, 8, 12).',
              'नहीं। मंगल लग्न से ${l.house(mars.house)} में है और चंद्र से ${l.ordinal(fromMoon)} स्थान पर, और इनमें से कोई मांगलिक भाव (1, 2, 4, 7, 8, 12) नहीं है।',
            ),
      c.standing(Graha.mars, depth: 2),
    ]),
  );

  sections.add(
    _section(SectionKey.effect, l, 'What it tends to mean', 'इसका मतलब क्या है', <
      String
    >[
      if (has && finding != null)
        l.t(finding.meaningEnglish, finding.meaningHindi)
      else if (has)
        l.t(
          'The tradition links it with friction in marriage and a hot temper. It is very common and it is not a verdict on anyone.',
          'परंपरा इसे विवाह में टकराव और उग्र स्वभाव से जोड़ती है। यह बहुत आम है और किसी पर फ़ैसला नहीं है।',
        )
      else
        l.t(
          'So this particular worry does not arise for this chart. The other houses and the Venus of the marriage are read in the question on marriage.',
          'इसलिए इस कुंडली में यह चिंता खड़ी नहीं होती। विवाह के बाक़ी भाव और शुक्र को विवाह वाले सवाल में पढ़ा गया है।',
        ),
      runningNature(c),
    ]),
  );

  if (has) {
    final String? cancel = finding == null
        ? null
        : (c.hindi ? finding.cancellationHindi : finding.cancellationEnglish);
    final String? mitigate = finding == null
        ? null
        : (c.hindi ? finding.mitigationHindi : finding.mitigationEnglish);
    sections.add(
      _section(SectionKey.remedy, l, 'What eases it', 'इसे कैसे सँभालें', <
        String
      >[
        if (cancel != null)
          l.t(
            'The chart itself carries a cancellation: $cancel',
            'कुंडली में ही इसका भंग मौजूद है: $cancel',
          )
        else if (mitigate != null)
          l.t(
            'No classical cancellation stands in this chart, so the tradition gives a way of living with it. $mitigate',
            'इस कुंडली में कोई शास्त्रीय भंग नहीं बैठता, इसलिए परंपरा इसके साथ जीने का तरीक़ा बताती है: $mitigate',
          ),
        ...kitParagraphs(c, Graha.mars, brief: false),
        l.t(
          'Nothing here has to be bought; what is in your house is enough.',
          'इनमें कुछ भी ख़रीदना ज़रूरी नहीं है; जो आपके घर में है, उसी से हो जाता है।',
        ),
      ]),
    );
  }

  final List<String> why = <String>[
    l.t(
      'The shastra gives several ways in which this condition is weakened: Mars in its own or exalted sign, the aspect of Jupiter, and both partners being manglik, in which case the two are taken to balance each other. This is why the condition, though common, is never read as a verdict.',
      'शास्त्र इस स्थिति के कई भंग बताता है: मंगल अपनी या उच्च राशि में हो, गुरु की दृष्टि हो, या दोनों साथियों की कुंडली मांगलिक हो, तब दोनों एक-दूसरे का संतुलन माने जाते हैं। इसीलिए यह स्थिति आम होते हुए भी फ़ैसले की तरह नहीं पढ़ी जाती।',
    ),
  ];
  final GrahaStanding ms = c.st(Graha.mars);
  final List<String> here = <String>[
    if (l.strongDignity(mars.dignity))
      l.t(
        'Here Mars stands ${l.dignityIn(mars.dignity)}.',
        'यहाँ मंगल ${l.dignityIn(mars.dignity)} है।',
      ),
    if (ms.aspectedBy.contains(Graha.jupiter))
      l.t(
        'Here Jupiter also aspects Mars.',
        'यहाँ गुरु की दृष्टि भी मंगल पर है।',
      ),
  ];
  if (here.isNotEmpty) why.add(here.join(' '));
  sections.add(
    _section(
      SectionKey.how,
      l,
      'What the shastra says',
      'शास्त्र क्या कहता है',
      why,
    ),
  );

  return _answer(c, 'Mangal dosha', 'मंगल दोष', sections, <String>[
    l.t(
      'Mars: ${l.sign(mars.rashi)}, house ${mars.house}',
      'मंगल: ${l.sign(mars.rashi)}, भाव ${mars.house}',
    ),
    l.t(
      'From the Moon: ${l.ordinal(fromMoon)} place',
      'चंद्र से: ${l.ordinal(fromMoon)} स्थान',
    ),
  ]);
}

// -----------------------------------------------------------------------------
// Remedy
// -----------------------------------------------------------------------------

Answer remedyAnswer(AskCtx c) {
  final AskLang l = c.l;
  final PeriodReading? maha = c.maha;
  final PeriodReading? antar = c.antar;
  final List<AnswerSection> sections = <AnswerSection>[];

  sections.add(
    _section(SectionKey.now, l, 'What the remedy is for', 'उपाय किसके लिए है', <
      String
    >[
      runningNow(c),
      if (maha != null && antar != null) toneSentence(l, maha.tone, antar.tone),
    ]),
  );

  final List<String> paras = <String>[];
  if (maha != null) {
    final List<Remedy> remedies = pickRemedies(c, null);
    if (remedies.isEmpty) {
      paras.add(
        l.t(
          'Nothing in this chart presses hard on the running period, so a remedy is not a cure for anything here. It only keeps a good time strong, through the graha whose period it is.',
          'इस कुंडली में चल रही दशा पर कोई बड़ा दबाव नहीं दिखता, इसलिए यहाँ उपाय किसी तकलीफ़ का इलाज नहीं है। यह सिर्फ़ अच्छे समय को मज़बूत रखने के लिए है, उस ग्रह के ज़रिए जिसकी दशा चल रही है।',
        ),
      );
      paras.addAll(kitParagraphs(c, maha.lord));
    } else {
      paras.addAll(
        kitParagraphs(c, remedies.first.graha, why: remedies.first.addresses),
      );
      if (remedies.length > 1) {
        paras.addAll(
          kitParagraphs(
            c,
            remedies[1].graha,
            why: remedies[1].addresses,
            brief: true,
          ),
        );
      }
    }
  } else {
    final Graha lord = rashiInfo(c.k.lagnaRashi).lord;
    paras.add(
      l.t(
        'Your lagna lord is ${c.name(lord)}, so the remedy begins there.',
        'आपके लग्न के स्वामी ${c.name(lord)} हैं, इसलिए उपाय वहीं से शुरू होता है।',
      ),
    );
    paras.addAll(kitParagraphs(c, lord));
  }
  paras.add(
    l.t(
      'Nothing here has to be bought; what is in your house is enough. Keep these as a practice: they steady the mind, but they promise nothing about what will come.',
      'इनमें कुछ भी ख़रीदना ज़रूरी नहीं है; जो आपके घर में है, उसी से हो जाता है। इन्हें अभ्यास की तरह रखिए। ये मन को स्थिर करते हैं, पर आगे क्या होगा, इसका कोई वादा नहीं करते।',
    ),
  );
  sections.add(
    _section(
      SectionKey.remedy,
      l,
      'What the tradition gives',
      'परंपरा क्या बताती है',
      paras,
    ),
  );

  sections.add(
    _section(SectionKey.how, l, 'What the shastra says', 'शास्त्र क्या कहता है', <
      String
    >[
      l.t(
        'The tradition strengthens a graha through mantra, a light fast, giving and service, all of which anyone can do at home. This app does not suggest gemstones, rings or anything that has to be bought; if you ever think of a stone, ask someone knowledgeable first.',
        'परंपरा ग्रह को बल मंत्र, हल्के व्रत, दान और सेवा से देती है, जो कोई भी घर पर कर सकता है। यह ऐप रत्न, अंगूठी या कोई ख़रीदने वाली चीज़ नहीं बताता; कभी रत्न का मन हो तो पहले किसी जानकार से पूछ लीजिए।',
      ),
    ]),
  );

  final Graha first = maha?.lord ?? rashiInfo(c.k.lagnaRashi).lord;
  return _answer(
    c,
    'The traditional remedy',
    'परंपरागत उपाय',
    sections,
    <String>[
      if (maha != null)
        l.t('Mahadasha: ${c.name(maha.lord)}', 'महादशा: ${c.name(maha.lord)}'),
      if (antar != null)
        l.t(
          'Antardasha: ${c.name(antar.lord)}',
          'अंतर्दशा: ${c.name(antar.lord)}',
        ),
      l.t('Remedy for: ${c.name(first)}', 'उपाय: ${c.name(first)} के लिए'),
    ],
  );
}

// -----------------------------------------------------------------------------
// Strength
// -----------------------------------------------------------------------------

Answer strengthAnswer(AskCtx c) {
  final AskLang l = c.l;
  final List<Graha> ranked =
      <Graha>[
        for (final Graha g in shadbalaGrahas)
          if (c.st(g).bala != null) g,
      ]..sort(
        (Graha a, Graha b) =>
            c.st(b).bala!.ratio.compareTo(c.st(a).bala!.ratio),
      );
  final Graha best = ranked.first;
  final Graha second = ranked[1];
  final Graha worst = ranked.last;
  final Graha nextWorst = ranked[ranked.length - 2];

  String line(Graha g) {
    final PlacedGraha p = c.k.grahas[g]!;
    return l.t(
      '${c.name(g)} stands in ${l.house(p.house)}, in ${l.sign(p.rashi)}, ${l.dignityIn(p.dignity)}. ${c.strengthLine(g)}',
      '${c.name(g)} ${l.sign(p.rashi)} राशि में, ${l.house(p.house)} में बैठा है — ${l.dignityIn(p.dignity)}। ${c.strengthLine(g)}',
    );
  }

  final PeriodReading? maha = c.maha;
  final String tie = maha == null
      ? ''
      : (() {
          final b = c.st(maha.lord).bala;
          if (b == null) return '';
          return l.t(
            'This matters for the time you are in: the running mahadasha belongs to ${c.name(maha.lord)}. ${c.strengthLine(maha.lord, named: true)}',
            'यह आपके अभी के समय के लिए मायने रखता है: चल रही महादशा ${c.name(maha.lord)} की है। ${c.strengthLine(maha.lord, named: true)}',
          );
        })();

  return _answer(
    c,
    'Strong and weak grahas',
    'बलवान और कमज़ोर ग्रह',
    <AnswerSection>[
      _section(SectionKey.now, l, 'What the chart shows', 'कुंडली में क्या मिला', <
        String
      >[
        l.t(
          'Counted by shadbala, the strongest graha in your chart is ${c.name(best)}, with ${c.name(second)} next. ${line(best)}',
          'षड्बल के हिसाब से आपकी कुंडली का सबसे बलवान ग्रह ${c.name(best)} है, उसके बाद ${c.name(second)}। ${line(best)}',
        ),
        l.t(
          'The one with the least strength is ${c.name(worst)}, with ${c.name(nextWorst)} just above it. ${line(worst)}',
          'सबसे कम बल वाला ग्रह ${c.name(worst)} है, और उससे ठीक ऊपर ${c.name(nextWorst)}। ${line(worst)}',
        ),
      ]),
      _section(
        SectionKey.effect,
        l,
        'What it tends to mean',
        'इसका मतलब क्या है',
        <String>[
          l.t(
            'A strong graha gives the things it stands for more easily: ${c.name(best)} stands for ${l.themes(best)}. A graha short of strength does better with support, and in its matters, ${l.themes(worst)}, more effort goes in for the same result.',
            'बलवान ग्रह अपने विषय ज़्यादा सहजता से देता है: ${c.name(best)} ${l.themes(best)} का कारक है। जिस ग्रह में बल कम है, उसे सहारे की ज़रूरत रहती है, और उसके विषयों, यानी ${l.themes(worst)}, में उतना ही फल पाने के लिए ज़्यादा मेहनत लगती है।',
          ),
          tie,
        ],
      ),
      _section(
        SectionKey.remedy,
        l,
        'Support for the weaker one',
        'कमज़ोर को सहारा',
        <String>[
          ...kitParagraphs(c, worst, compact: true),
          l.t(
            'Nothing here has to be bought; what is in your house is enough.',
            'इनमें कुछ भी ख़रीदना ज़रूरी नहीं है; जो आपके घर में है, उसी से हो जाता है।',
          ),
        ],
      ),
      _section(
        SectionKey.how,
        l,
        'What the shastra says',
        'शास्त्र क्या कहता है',
        <String>[
          l.t(
            'Shadbala is the sum of six kinds of strength: of position, of direction, of time, of motion, of nature, and of aspect. The texts set a minimum for each graha, and one that clears it is read as able to give what it promises. Nodes are left out, because their shadbala is not defined.',
            'षड्बल छह तरह के बल का जोड़ है: स्थान, दिशा, काल, चेष्टा, नैसर्गिक और दृष्टि बल। ग्रंथ हर ग्रह के लिए एक न्यूनतम तय करते हैं, और जो उसे पार कर ले, वह अपना वादा निभाने में सक्षम माना जाता है। राहु और केतु इसमें नहीं गिने जाते, क्योंकि उनका षड्बल परिभाषित नहीं है।',
          ),
        ],
      ),
    ],
    <String>[
      l.t(
        'Strongest: ${c.name(best)} (${c.num1(c.st(best).bala!.totalRupas)} rupas)',
        'सबसे बलवान: ${c.name(best)} (${c.num1(c.st(best).bala!.totalRupas)} रूप)',
      ),
      l.t(
        'Weakest: ${c.name(worst)} (${c.num1(c.st(worst).bala!.totalRupas)} rupas)',
        'सबसे कम बल: ${c.name(worst)} (${c.num1(c.st(worst).bala!.totalRupas)} रूप)',
      ),
    ],
  );
}

// -----------------------------------------------------------------------------
// Retrograde
// -----------------------------------------------------------------------------

Answer retrogradeAnswer(AskCtx c) {
  final AskLang l = c.l;
  final List<PlacedGraha> retro = c.k.grahas.values
      .where((PlacedGraha g) => g.isRetrograde)
      .toList();
  final PeriodReading? maha = c.maha;
  final PeriodReading? antar = c.antar;

  final List<String> now = <String>[];
  if (retro.isEmpty) {
    now.add(
      l.t(
        'No graha was retrograde at your birth, apart from Rahu and Ketu, which always move backwards.',
        'जन्म के समय कोई ग्रह वक्री नहीं था। राहु और केतु की बात अलग है, वे हमेशा उलटी चाल चलते हैं।',
      ),
    );
  } else {
    now.add(
      l.t(
        '${l.list(retro.map((PlacedGraha g) => c.name(g.graha)).toList())} ${retro.length == 1 ? 'was' : 'were'} retrograde at your birth.',
        'जन्म के समय ${l.list(retro.map((PlacedGraha g) => c.name(g.graha)).toList())} वक्री ${retro.length == 1 ? 'था' : 'थे'}।',
      ),
    );
    for (final PlacedGraha g in retro) {
      now.add(
        l.t(
          '${c.name(g.graha)} stands in ${l.house(g.house)}, in ${l.sign(g.rashi)}, ${l.dignityIn(g.dignity)}.',
          '${c.name(g.graha)} ${l.sign(g.rashi)} राशि में, ${l.house(g.house)} में बैठा है — ${l.dignityIn(g.dignity)}।',
        ),
      );
    }
  }

  final List<PlacedGraha> inDasha = retro
      .where((PlacedGraha g) => g.graha == maha?.lord || g.graha == antar?.lord)
      .toList();
  return _answer(
    c,
    'Retrograde grahas',
    'वक्री ग्रह',
    <AnswerSection>[
      _section(
        SectionKey.now,
        l,
        'What the chart shows',
        'कुंडली में क्या मिला',
        now,
      ),
      _section(SectionKey.effect, l, 'What it tends to mean', 'इसका मतलब क्या है', <
        String
      >[
        l.t(
          'A retrograde graha seems, as seen from the Earth, to move backwards for a while. The tradition reads it as turned inward, and often as stronger rather than weaker; its matters tend to come back round for a second look.',
          'वक्री ग्रह पृथ्वी से देखने पर कुछ समय के लिए उलटी चाल चलता दिखता है। परंपरा उसे भीतर की ओर मुड़ा हुआ, और अक्सर कमज़ोर नहीं, बल्कि और बलवान मानती है; उसके विषय दोबारा परखने के लिए लौटकर आते हैं।',
        ),
        if (inDasha.isNotEmpty)
          l.t(
            'This touches your present time: ${l.list(inDasha.map((PlacedGraha g) => c.name(g.graha)).toList())} ${inDasha.length == 1 ? 'is' : 'are'} retrograde in the chart and also ${inDasha.length == 1 ? 'is' : 'are'} the lord of a running period, so those matters are being looked at again now.',
            'यह आपके अभी के समय को छूता है: ${l.list(inDasha.map((PlacedGraha g) => c.name(g.graha)).toList())} कुंडली में वक्री ${inDasha.length == 1 ? 'है' : 'हैं'} और चल रही दशा का स्वामी भी ${inDasha.length == 1 ? 'है' : 'हैं'}, इसलिए उन विषयों पर अभी दोबारा नज़र जा रही है।',
          )
        else
          runningNow(c),
      ]),
      _section(
        SectionKey.how,
        l,
        'What the shastra says',
        'शास्त्र क्या कहता है',
        <String>[
          l.t(
            'The Sun and Moon are never retrograde. Rahu and Ketu always move backwards, so they are not counted as retrograde in the usual sense. For the others, the tradition gives a retrograde graha a high share of strength of motion (cheshta bala).',
            'सूर्य और चंद्र कभी वक्री नहीं होते। राहु और केतु हमेशा उलटी चाल चलते हैं, इसलिए उन्हें आम अर्थ में वक्री नहीं गिना जाता। बाक़ी ग्रहों में परंपरा वक्री ग्रह को चेष्टा बल, यानी चाल के बल, का ऊँचा हिस्सा देती है।',
          ),
        ],
      ),
    ],
    <String>[
      if (retro.isEmpty)
        l.t('From the computed daily motion', 'गति की गणना से')
      else
        for (final PlacedGraha g in retro)
          l.t(
            '${c.name(g.graha)}: retrograde, house ${g.house}',
            '${c.name(g.graha)}: वक्री, भाव ${g.house}',
          ),
    ],
  );
}

// -----------------------------------------------------------------------------
// Navamsa
// -----------------------------------------------------------------------------

Answer navamsaAnswer(AskCtx c) {
  final AskLang l = c.l;
  final Kundli k = c.k;
  final int lagna9 = k.vargaLagna(Varga.d9);
  final Map<Graha, int> d9 = k.vargaPlacements(Varga.d9);
  final List<Graha> vargottama = <Graha>[
    for (final Graha g in Graha.values)
      if (d9[g] == k.grahas[g]!.rashi.index) g,
  ];
  // Weak in the sign, at home in the navamsa.
  final List<Graha> recovered = <Graha>[
    for (final Graha g in Graha.values)
      if (g != Graha.rahu &&
          g != Graha.ketu &&
          (k.grahas[g]!.dignity == Dignity.debilitated ||
              k.grahas[g]!.dignity == Dignity.enemy) &&
          _atHomeIn(g, d9[g]!))
        g,
  ];
  final PlacedGraha venus = k.grahas[Graha.venus]!;
  return _answer(
    c,
    'The navamsa (D9)',
    'नवांश (D9)',
    <AnswerSection>[
      _section(SectionKey.now, l, 'What the chart shows', 'कुंडली में क्या मिला', <
        String
      >[
        l.t(
          'In the navamsa your lagna is ${l.sign(Rashi.values[lagna9])}. Venus, the significator of marriage, stands in ${l.sign(Rashi.values[d9[Graha.venus]!])} there, while in the main chart it is in ${l.sign(venus.rashi)}.',
          'नवांश में आपका लग्न ${l.sign(Rashi.values[lagna9])} है। विवाह का कारक शुक्र वहाँ ${l.sign(Rashi.values[d9[Graha.venus]!])} राशि में है, जबकि मुख्य कुंडली में वह ${l.sign(venus.rashi)} में है।',
        ),
      ]),
      _section(SectionKey.effect, l, 'What it tends to mean', 'इसका मतलब क्या है', <
        String
      >[
        vargottama.isEmpty
            ? l.t(
                'No graha stands in the same sign in the main chart and the navamsa, so none is vargottama.',
                'कोई ग्रह मुख्य कुंडली और नवांश में एक ही राशि में नहीं है, इसलिए कोई वर्गोत्तम नहीं है।',
              )
            : l.t(
                '${l.list(vargottama.map(c.name).toList())} stands in the same sign in both charts. The tradition calls this vargottama and reads it as a graha that is steadied and strengthened.',
                '${l.list(vargottama.map(c.name).toList())} दोनों कुंडलियों में एक ही राशि में ${vargottama.length == 1 ? 'है' : 'हैं'}। परंपरा इसे वर्गोत्तम कहती है और ऐसे ग्रह को स्थिर और बलवान मानती है।',
              ),
        if (recovered.isNotEmpty)
          l.t(
            '${l.list(recovered.map(c.name).toList())} looks pressed in the main chart but stands at home in the navamsa, which the tradition reads as strength recovered.',
            '${l.list(recovered.map(c.name).toList())} मुख्य कुंडली में दबा दिखता है पर नवांश में अपने घर में है, जिसे परंपरा दुबारा मिला हुआ बल मानती है।',
          ),
        runningNature(c),
      ]),
      _section(
        SectionKey.how,
        l,
        'What the shastra says',
        'शास्त्र क्या कहता है',
        <String>[
          l.t(
            'The navamsa divides every sign into nine parts of 3°20′ and is read for marriage, dharma and inner strength. It is looked at beside the main chart, never in place of it.',
            'नवांश हर राशि को 3°20′ के नौ भागों में बाँटता है और इसे विवाह, धर्म और भीतरी बल के लिए पढ़ा जाता है। इसे मुख्य कुंडली के साथ देखा जाता है, उसकी जगह नहीं।',
          ),
        ],
      ),
    ],
    <String>[
      l.t(
        'Navamsa lagna: ${l.sign(Rashi.values[lagna9])}',
        'नवांश लग्न: ${l.sign(Rashi.values[lagna9])}',
      ),
      if (vargottama.isNotEmpty)
        l.t(
          'Vargottama: ${l.list(vargottama.map(c.name).toList())}',
          'वर्गोत्तम: ${l.list(vargottama.map(c.name).toList())}',
        ),
    ],
  );
}

bool _atHomeIn(Graha g, int sign) {
  final GrahaInfo info = grahaInfo(g);
  if (info.ownSigns.contains(sign)) return true;
  final double? exalt = info.exaltationDegree;
  return exalt != null && (exalt / 30).floor() % 12 == sign;
}
