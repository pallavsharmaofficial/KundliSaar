import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'mat.dart';
import 'rashi.dart';
import 'shadbala.dart' show isBenefic;
import 'tajika_aspects.dart';
import 'tajika_bala.dart';
import 'tajika_common.dart';

// =============================================================================
// Where the Tajika books differ: मतभेद on aspects and yogas.
//
// Four of the sixteen Tajika yogas (Gairi-kamboola, Tambira, Kuttha, Durapha)
// used to be left out because their definitions are not agreed. They are here
// now, each worked out on the year chart under every definition that could be
// read. So are three rules the engine had settled silently: how large the
// orb of a pair is, and when a pair counts as Ishrafa.
//
// What was read. Hayanaratna (Balabhadra) in Martin Gansten's English
// translation on wisdomlib, sections 2.6, 3.3, 3.4, 3.9, 3.14, 3.15 and 3.16;
// the Hindi commentary printed with Tajika Neelakanthi in the Venkateshwar
// Press edition on Sanskrit Wikisource; and PyJHora's Tajaka code. K. S.
// Charak's A Textbook of Varshaphala was NOT seen: what is credited to it here
// is what a developer's transcription of it (the teistro-sdk project's notes)
// says, and each such line says so.
// =============================================================================

const Bi _hayanaratnaEn = Bi(
  'Balabhadra’s Hayanaratna, read in Gansten’s English translation',
  'बलभद्र का हायनरत्न, गैन्स्टन के अंग्रेज़ी अनुवाद में पढ़ा',
);

const Bi _charakViaSdk = Bi(
  'K. S. Charak’s A Textbook of Varshaphala, as a developer’s transcription '
      'of the book reports it; the book itself was not seen',
  'के. एस. चरक की ए टेक्स्टबुक ऑफ़ वर्षफल, जैसा एक डेवलपर के बनाए नोट्स उसे बताते '
      'है; पुस्तक स्वयं नहीं देखी गई',
);

const Bi _wikisourceNeelakanthi = Bi(
  'The Hindi commentary printed with the Tajika Neelakanthi (the Venkateshwar '
      'Press edition on Sanskrit Wikisource)',
  'ताजिक नीलकण्ठी के साथ छपी हिंदी टीका (संस्कृत विकिस्रोत पर वेंकटेश्वर प्रेस '
      'का संस्करण)',
);

const Bi _pyjhoraTajika = Bi(
  'PyJHora, the open-source port of Jagannatha Hora (its Tajaka code was read)',
  'PyJHora, जगन्नाथ होरा का ओपन-सोर्स रूप (इसका ताजक कोड पढ़ा गया)',
);

const Bi _hayanaratnaMainSource = Bi(
  'Hayanaratna is the app’s main Tajika source, so its definition is the one '
      'computed; the other is shown beside it.',
  'हायनरत्न ऐप का मुख्य ताजिक स्रोत है, इसलिए उसकी परिभाषा से गिना गया है; '
      'दूसरी उसके बगल में दिखाई है।',
);

bool _strong(PlacedGraha g) =>
    g.dignity == Dignity.exalted ||
    g.dignity == Dignity.moolatrikona ||
    g.dignity == Dignity.own;

bool _kendra(int h) => const <int>[1, 4, 7, 10].contains(h);
bool _kendraOrPanaphara(int h) =>
    const <int>[1, 2, 4, 5, 7, 8, 10, 11].contains(h);
bool _trika(int h) => const <int>[6, 8, 12].contains(h);

Bi _join(Iterable<Bi> parts, {String and = ', '}) {
  final List<Bi> list = parts.toList(growable: false);
  return Bi(
    list.map((Bi b) => b.en).join(and),
    list.map((Bi b) => b.hi).join(and),
  );
}

Bi _where(Kundli chart, Graha g) {
  final PlacedGraha p = chart.grahas[g]!;
  return Bi(
    '${grahaBi(g).en} at ${degText(p.degreesInSign)} ${rashiBi(p.rashi.index).en}',
    '${grahaBi(g).hi} ${rashiBi(p.rashi.index).hi} ${degText(p.degreesInSign)} पर',
  );
}

// ---------------------------------------------------------------------------
// Pairs, orbs and the Ishrafa onset
// ---------------------------------------------------------------------------

class _Pair {
  const _Pair(this.faster, this.slower, this.gap);

  final Graha faster;
  final Graha slower;

  /// Degrees by which the swifter is behind the slower, within the signs:
  /// positive while applying, negative once it has passed.
  final double gap;
}

/// Every pair whose signs are in a Tajika relation and whose swifter graha is
/// not retrograde, whatever the gap: the raw material each orb is applied to.
List<_Pair> _relatedPairs(Kundli chart) {
  final List<_Pair> out = <_Pair>[];
  for (int i = 0; i < tajikaGrahas.length; i++) {
    for (int j = i + 1; j < tajikaGrahas.length; j++) {
      final Graha a = tajikaGrahas[i];
      final Graha b = tajikaGrahas[j];
      final Graha faster = isSwifter(a, b) ? a : b;
      final Graha slower = faster == a ? b : a;
      final PlacedGraha f = chart.grahas[faster]!;
      final PlacedGraha s = chart.grahas[slower]!;
      if (signAspectOf(signDistance(f.rashi.index, s.rashi.index)) == null) {
        continue;
      }
      if (f.isRetrograde) continue;
      out.add(_Pair(faster, slower, s.degreesInSign - f.degreesInSign));
    }
  }
  return out;
}

Bi _pairText(_Pair p) {
  final Bi fast = grahaBi(p.faster);
  final Bi slow = grahaBi(p.slower);
  return p.gap >= 0
      ? Bi(
          '${fast.en} ${degText(p.gap)} behind ${slow.en}',
          '${fast.hi} ${slow.hi} से ${degText(p.gap)} पीछे',
        )
      : Bi(
          '${fast.en} ${degText(-p.gap)} past ${slow.en}',
          '${fast.hi} ${slow.hi} से ${degText(-p.gap)} आगे',
        );
}

Bi _pairsResult(List<_Pair> pairs, Bi lead, Bi none) {
  if (pairs.isEmpty) return none;
  final Bi list = _join(pairs.map(_pairText), and: '; ');
  return Bi('${lead.en} ${list.en}.', '${lead.hi} ${list.hi}।');
}

Matbhed _orbMatbhed(Kundli chart) {
  final List<_Pair> related = _relatedPairs(chart);
  List<_Pair> within(double Function(_Pair) orb) =>
      related.where((_Pair p) => p.gap.abs() <= orb(p)).toList(growable: false);
  final List<_Pair> mean = within((_Pair p) => meanOrb(p.faster, p.slower));
  final List<_Pair> own = within((_Pair p) => deeptamsha[p.faster]!);
  final List<_Pair> twelve = within((_Pair p) => 12.0);
  Bi result(List<_Pair> pairs) => _pairsResult(
    pairs,
    Bi(
      '${pairs.length} pair${pairs.length == 1 ? '' : 's'} in aspect:',
      '${pairs.length} जोड़ी दृष्टि में:',
    ),
    const Bi(
      'No pair is in aspect within this orb.',
      'इस दीप्तांश में कोई जोड़ी दृष्टि में नहीं।',
    ),
  );
  return Matbhed(
    key: 'tajika_orb',
    topic: const Bi(
      'How close a pair must be to be in aspect',
      'दो ग्रह कितने पास हों तो दृष्टि मानी जाए',
    ),
    whyTheyDiffer: const Bi(
      'Each graha has its own orb of light (Sun 15°, Moon 12°, Mars 8°, '
          'Mercury and Venus 7°, Jupiter and Saturn 9°), and the sources '
          'agree on those. What they do not state alike is the orb of a pair.',
      'हर ग्रह का अपना दीप्तांश है (सूर्य 15°, चंद्र 12°, मंगल 8°, बुध और शुक्र 7°, '
          'गुरु और शनि 9°), और इन पर स्रोत एकमत हैं। दो ग्रहों की जोड़ी का दीप्तांश '
          'वे एक-सा नहीं बताते।',
    ),
    defaultReason: const Bi(
      'The app has used the half-sum from the start, and the only source '
          'found for a rule on pairs is the transcription of Charak. '
          'Hayanaratna gives each graha’s orb but no rule for a pair.',
      'ऐप शुरू से आधा-योग लेता आया है, और जोड़ी के नियम के लिए जो एकमात्र स्रोत '
          'मिला वह चरक पर एक डेवलपर के नोट्स हैं। हायनरत्न हर ग्रह का दीप्तांश देता है, जोड़ी का '
          'नियम नहीं।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: mean.length.toDouble(),
        position: const Bi(
          'The pair shares half the sum of its two orbs.',
          'जोड़ी दोनों दीप्तांशों के योग का आधा साझा रखती है।',
        ),
        holder: _charakViaSdk,
        reasoning: const Bi(
          'The two lights meet midway: the orb that applies is the mean of '
              'the two grahas’ orbs.',
          'दोनों के प्रकाश बीच में मिलते हैं: लागू होने वाला दीप्तांश दोनों ग्रहों '
              'के दीप्तांशों का औसत है।',
        ),
        result: result(mean),
      ),
      Mat(
        value: own.length.toDouble(),
        position: const Bi(
          'The pair is judged by the swifter graha’s own orb.',
          'जोड़ी को शीघ्रगामी ग्रह के अपने दीप्तांश से परखा जाता है।',
        ),
        holder: Bi(
          '${_wikisourceNeelakanthi.en}; Hayanaratna’s strength formula for '
              'an Itthasala divides by the swifter graha’s orb',
          '${_wikisourceNeelakanthi.hi}; हायनरत्न का इत्थशाल-बल का सूत्र शीघ्रगामी '
              'ग्रह के दीप्तांश से भाग देता है',
        ),
        reasoning: const Bi(
          'It is the swifter graha that comes up to the slower one and gives '
              'it light, so its reach is what counts.',
          'शीघ्रगामी ग्रह ही मंदगामी के पास आकर उसे प्रकाश देता है, इसलिए उसकी '
              'पहुँच ही गिनी जाती है।',
        ),
        result: result(own),
      ),
      Mat(
        value: twelve.length.toDouble(),
        position: const Bi(
          'Within the planets’ own orbs “or within twelve degrees”.',
          'ग्रहों के अपने दीप्तांश में “या बारह अंश के भीतर”।',
        ),
        holder: const Bi(
          'Tajikatilaka, as Balabhadra quotes it in Hayanaratna 3.3',
          'ताजिकतिलक, जैसा बलभद्र हायनरत्न 3.3 में उद्धृत करते हैं',
        ),
        reasoning: const Bi(
          'The quoted line allows a wider reach of twelve degrees, without '
              'giving a reason. Here it is worked as twelve for every pair.',
          'उद्धृत पंक्ति बारह अंश की चौड़ी पहुँच मानती है, कारण दिए बिना। यहाँ इसे '
              'हर जोड़ी के लिए बारह गिना गया है।',
        ),
        result: result(twelve),
      ),
    ],
  );
}

Matbhed _ishrafaMatbhed(Kundli chart) {
  double orbMean(_Pair p) => meanOrb(p.faster, p.slower);
  final List<_Pair> past = _relatedPairs(chart)
      .where((_Pair p) => p.gap < 0 && p.gap.abs() <= orbMean(p))
      .toList(growable: false);
  final List<_Pair> byAnyDistance = past;
  final List<_Pair> byDegree = past
      .where((_Pair p) => p.gap.abs() >= 1.0)
      .toList(growable: false);
  final List<_Pair> stillJoining = past
      .where((_Pair p) => p.gap.abs() < 1.0)
      .toList(growable: false);
  return Matbhed(
    key: 'tajika_ishrafa',
    topic: const Bi(
      'When a pair becomes Ishrafa (separating)',
      'जोड़ी कब ईसराफ़ (दूर जाती हुई) मानी जाए',
    ),
    whyTheyDiffer: const Bi(
      'Everyone agrees that Ishrafa is the swifter graha having gone past the '
          'slower. The question is whether the first few minutes of arc past '
          'exactness already count.',
      'सब मानते हैं कि ईसराफ़ वह है जब शीघ्रगामी ग्रह मंदगामी से आगे निकल जाए। '
          'सवाल यह है कि ठीक-ठीक मिलन के बाद के पहले कुछ कला-अंश भी गिने जाएँ या '
          'नहीं।',
    ),
    defaultReason: const Bi(
      'The app waits for the full degree, because that is what the verse '
          'says. Counting from the first moment the swifter graha is past '
          'matches one software’s code and no text, and is shown beside it.',
      'ऐप पूरे एक अंश का इंतज़ार करता है, क्योंकि श्लोक यही कहता है। आगे निकलते ही '
          'गिन लेना एक सॉफ़्टवेयर के कोड से मेल खाता है, किसी ग्रंथ से नहीं — वह '
          'मत बगल में दिखाया है।',
    ),
    views: <Mat>[
      Mat(
        value: byAnyDistance.length.toDouble(),
        position: const Bi(
          'Ishrafa from the first moment the swifter graha is past the slower, '
              'within the orb.',
          'ईसराफ़ तब से जब शीघ्रगामी ग्रह मंदगामी से आगे निकल जाए, दीप्तांश के '
              'भीतर।',
        ),
        holder: _pyjhoraTajika,
        reasoning: const Bi(
          'Once the swifter graha has passed, it is no longer approaching: the '
              'aspect is separating. The code sets no minimum distance.',
          'आगे निकलते ही शीघ्रगामी ग्रह पास नहीं आ रहा: दृष्टि दूर जा रही है। कोड '
              'कोई न्यूनतम दूरी नहीं रखता।',
        ),
        result: _pairsResult(
          byAnyDistance,
          Bi(
            '${byAnyDistance.length} Ishrafa:',
            '${byAnyDistance.length} ईसराफ़:',
          ),
          const Bi(
            'No pair has passed exactness inside its orb: no Ishrafa.',
            'किसी जोड़ी ने अपने दीप्तांश में मिलन पार नहीं किया: कोई ईसराफ़ नहीं।',
          ),
        ),
      ),
      Mat(
        isDefault: true,
        value: byDegree.length.toDouble(),
        position: const Bi(
          'Ishrafa only when the swifter graha is a full degree past; short of '
              'that it is still Itthasala.',
          'ईसराफ़ तभी जब शीघ्रगामी ग्रह पूरा एक अंश आगे हो; उससे कम पर भी वह '
              'इत्थशाल ही है।',
        ),
        holder: Bi(
          'Tajikabhushana 4.10 as quoted in Hayanaratna 3.4 (an unnamed '
              'ancient commentator there adds that minutes of arc short of a '
              'degree are still Itthasala); also ${_wikisourceNeelakanthi.en}',
          'ताजिकभूषण 4.10, जैसा हायनरत्न 3.4 में उद्धृत है (वहाँ एक अनाम प्राचीन '
              'टीकाकार जोड़ता है कि एक अंश से कम, कला-अंशों तक, भी इत्थशाल ही है); '
              'और ${_wikisourceNeelakanthi.hi}',
        ),
        reasoning: const Bi(
          'The verse defines Ishrafa as the swifter graha being one degree in '
              'front. A graha only minutes past exactness has not yet left.',
          'श्लोक ईसराफ़ को शीघ्रगामी ग्रह का एक अंश आगे होना कहता है। जो ग्रह मिलन '
              'से केवल कुछ कला-अंश आगे है वह अभी गया नहीं।',
        ),
        result: _pairsResult(
          byDegree,
          Bi('${byDegree.length} Ishrafa:', '${byDegree.length} ईसराफ़:'),
          Bi(
            stillJoining.isEmpty
                ? 'No pair is a full degree past: no Ishrafa.'
                : 'No pair is a full degree past, so none is Ishrafa; '
                      '${stillJoining.length} still count as Itthasala.',
            stillJoining.isEmpty
                ? 'कोई जोड़ी पूरे अंश आगे नहीं: कोई ईसराफ़ नहीं।'
                : 'कोई जोड़ी पूरे अंश आगे नहीं, इसलिए कोई ईसराफ़ नहीं; '
                      '${stillJoining.length} अब भी इत्थशाल गिनी जाती हैं।',
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// The four yogas that were left out
// ---------------------------------------------------------------------------

class _Clause {
  const _Clause(this.ok, this.miss);

  final bool ok;

  /// What the chart shows when the clause fails.
  final Bi miss;
}

/// The matters (houses 2 to 12) for which every clause holds, and the nearest
/// miss: the failing clause of the matter that got furthest.
({List<int> houses, Bi? nearMiss}) _perMatter(
  Kundli chart,
  List<_Clause> Function(int house, Graha lagnesha, Graha karyesha) clauses,
) {
  final List<int> houses = <int>[];
  Bi? nearMiss;
  int best = -1;
  final Graha lagnesha = houseLord(chart, 1);
  for (int h = 2; h <= 12; h++) {
    final Graha karyesha = houseLord(chart, h);
    if (karyesha == lagnesha) continue;
    final List<_Clause> list = clauses(h, lagnesha, karyesha);
    int passed = 0;
    while (passed < list.length && list[passed].ok) {
      passed++;
    }
    if (passed == list.length) {
      houses.add(h);
    } else if (passed > best) {
      best = passed;
      nearMiss = list[passed].miss;
    }
  }
  return (houses: houses, nearMiss: nearMiss);
}

Bi _formsFor(List<int> houses, Bi detail) {
  final Bi h = housesBi(houses);
  return Bi(
    'Forms for the matters of ${h.en}. ${detail.en}',
    '${h.hi} के विषयों के लिए बनता है। ${detail.hi}',
  );
}

Bi _doesNotForm(Bi? nearMiss) => nearMiss == null
    ? const Bi(
        'Does not form for any matter this year.',
        'इस वर्ष किसी भी विषय के लिए नहीं बनता।',
      )
    : Bi(
        'Does not form for any matter this year. Nearest miss: ${nearMiss.en}',
        'इस वर्ष किसी भी विषय के लिए नहीं बनता। सबसे निकट चूक: ${nearMiss.hi}',
      );

/// The graha, other than [except], standing in the sign after [sign] whose
/// degree is within the orb the Moon-or-mover [mover] would have on entering
/// at 0°. Closest first.
List<PlacedGraha> _inNextSign(
  Kundli chart,
  int sign,
  Graha mover, {
  Set<Graha> except = const <Graha>{},
  bool strongOnly = false,
}) {
  final int next = (sign + 1) % 12;
  final List<PlacedGraha> out = <PlacedGraha>[
    for (final Graha g in tajikaGrahas)
      if (g != mover && !except.contains(g))
        if (chart.grahas[g]!.rashi.index == next)
          if (chart.grahas[g]!.degreesInSign <= meanOrb(mover, g))
            if (!strongOnly || _strong(chart.grahas[g]!)) chart.grahas[g]!,
  ];
  out.sort(
    (PlacedGraha a, PlacedGraha b) =>
        a.degreesInSign.compareTo(b.degreesInSign),
  );
  return out;
}

Matbhed _gairiKamboolaMatbhed(Kundli chart, TajikaReport report) {
  final PlacedGraha moon = chart.grahas[Graha.moon]!;
  final int moonSign = moon.rashi.index;
  bool applying(Graha a, Graha b) {
    final TajikaAspect? t = report.aspectBetween(a, b);
    return t != null && t.isApplying;
  }

  bool sees(Graha a, Graha b) =>
      signAspectOf(
        signDistance(
          chart.grahas[a]!.rashi.index,
          chart.grahas[b]!.rashi.index,
        ),
      ) !=
      null;

  final ({List<int> houses, Bi? nearMiss}) hayanaratna = _perMatter(chart, (
    int h,
    Graha l,
    Graha k,
  ) {
    final List<PlacedGraha> entry = _inNextSign(chart, moonSign, Graha.moon);
    return <_Clause>[
      _Clause(
        l != Graha.moon && k != Graha.moon,
        const Bi(
          'the Moon is itself one of the two lords.',
          'चंद्र स्वयं दोनों स्वामियों में से एक है।',
        ),
      ),
      _Clause(
        applying(l, k),
        Bi(
          'the lagna lord ${grahaBi(l).en} and the lord of ${houseBi(h).en}, '
              '${grahaBi(k).en}, are not in Itthasala.',
          'लग्नेश ${grahaBi(l).hi} और ${houseBi(h).hi} के स्वामी ${grahaBi(k).hi} '
              'में इत्थशाल नहीं है।',
        ),
      ),
      _Clause(
        !sees(Graha.moon, l) && !sees(Graha.moon, k),
        Bi(
          'the Moon’s sign is in a Tajika relation with one of the two lords.',
          'चंद्र की राशि का दोनों में से एक स्वामी से ताजिक संबंध है।',
        ),
      ),
      _Clause(
        moon.degreesInSign >= 29.0,
        Bi(
          '${_where(chart, Graha.moon).en} is not in the last degree of its '
              'sign.',
          '${_where(chart, Graha.moon).hi} चंद्र अपनी राशि के अंतिम अंश में नहीं है।',
        ),
      ),
      _Clause(
        entry.isNotEmpty,
        Bi(
          'no graha stands in ${rashiBi((moonSign + 1) % 12).en}, the sign the '
              'Moon enters, close enough to be met on entry.',
          '${rashiBi((moonSign + 1) % 12).hi}, जिसमें चंद्र प्रवेश करेगा, में कोई ग्रह '
              'इतना पास नहीं कि प्रवेश पर मिले।',
        ),
      ),
    ];
  });
  Bi? favourable;
  if (hayanaratna.houses.isNotEmpty) {
    final PlacedGraha g = _inNextSign(chart, moonSign, Graha.moon).first;
    final bool dignified = _strong(g);
    final String favourableEn = dignified
        ? 'The Moon, ${_where(chart, Graha.moon).en}, is about to enter '
              '${rashiBi((moonSign + 1) % 12).en} and meet ${grahaBi(g.graha).en}, '
              'which is in its own sign or exaltation there: the result is '
              'read like a Kamboola, favourable.'
        : 'The Moon, ${_where(chart, Graha.moon).en}, is about to enter '
              '${rashiBi((moonSign + 1) % 12).en} and meet ${grahaBi(g.graha).en}, '
              'which is not in its own sign or exaltation there: the result is '
              'read as unfavourable.';
    final String favourableHi = dignified
        ? '${_where(chart, Graha.moon).hi} चंद्र ${rashiBi((moonSign + 1) % 12).hi} '
              'में जाने वाला है और ${grahaBi(g.graha).hi} से मिलेगा, जो वहाँ अपनी या '
              'उच्च राशि में है: फल कम्बूल जैसा, शुभ पढ़ा जाता है।'
        : '${_where(chart, Graha.moon).hi} चंद्र ${rashiBi((moonSign + 1) % 12).hi} '
              'में जाने वाला है और ${grahaBi(g.graha).hi} से मिलेगा, जो वहाँ अपनी या '
              'उच्च राशि में नहीं है: फल अशुभ पढ़ा जाता है।';
    favourable = Bi(favourableEn, favourableHi);
  }

  // Charak, through the transcription.
  final bool moonUnaspected = report.aspectsOf(Graha.moon).isEmpty;
  final bool moonAlone = !tajikaGrahas.any(
    (Graha g) => g != Graha.moon && chart.grahas[g]!.rashi.index == moonSign,
  );
  final bool moonPlain =
      moon.dignity != Dignity.exalted &&
      moon.dignity != Dignity.debilitated &&
      haddaLordOf(moon.siderealLongitude) != Graha.moon &&
      drekkanaLordOf(moon.siderealLongitude) != Graha.moon &&
      navamshaLordOf(moon.siderealLongitude) != Graha.moon;
  final Bi notPlain = _join(<Bi>[
    if (!moonPlain)
      const Bi(
        'exalted, debilitated or in its own division',
        'उच्च, नीच या अपने ही विभाग में',
      ),
    if (!moonUnaspected)
      const Bi('in aspect with another graha', 'किसी और ग्रह से दृष्टि में'),
    if (!moonAlone)
      const Bi(
        'sharing its sign with another graha',
        'किसी और ग्रह के साथ एक राशि में',
      ),
  ], and: ' and ');
  final ({List<int> houses, Bi? nearMiss}) charak = _perMatter(chart, (
    int h,
    Graha l,
    Graha k,
  ) {
    final List<PlacedGraha> withLord = <PlacedGraha>[
      ..._inNextSign(
        chart,
        moonSign,
        Graha.moon,
        except: <Graha>{
          for (final Graha g in tajikaGrahas)
            if (g != l && g != k) g,
        },
      ),
    ];
    final List<PlacedGraha> strongThird = _inNextSign(
      chart,
      moonSign,
      Graha.moon,
      except: <Graha>{l, k},
      strongOnly: true,
    );
    return <_Clause>[
      _Clause(
        l != Graha.moon && k != Graha.moon,
        const Bi(
          'the Moon is itself one of the two lords.',
          'चंद्र स्वयं दोनों स्वामियों में से एक है।',
        ),
      ),
      _Clause(
        applying(l, k),
        Bi(
          'the lagna lord ${grahaBi(l).en} and the lord of ${houseBi(h).en}, '
              '${grahaBi(k).en}, are not in Itthasala.',
          'लग्नेश ${grahaBi(l).hi} और ${houseBi(h).hi} के स्वामी ${grahaBi(k).hi} '
              'में इत्थशाल नहीं है।',
        ),
      ),
      _Clause(
        moonPlain && moonUnaspected && moonAlone,
        Bi(
          '${_where(chart, Graha.moon).en} is not “unqualified”: it is '
              '${notPlain.en}.',
          '${_where(chart, Graha.moon).hi} चंद्र “योग्यता-रहित” नहीं है: वह '
              '${notPlain.hi} है।',
        ),
      ),
      _Clause(
        moon.degreesInSign >= 29.0,
        Bi(
          '${_where(chart, Graha.moon).en} is not at 29° or more.',
          '${_where(chart, Graha.moon).hi} चंद्र 29° या उससे ऊपर नहीं है।',
        ),
      ),
      _Clause(
        withLord.any((PlacedGraha p) => p.graha == l || p.graha == k) &&
            strongThird.isNotEmpty,
        Bi(
          'on entering ${rashiBi((moonSign + 1) % 12).en} the Moon would not '
              'meet one of the two lords and a strong third graha together.',
          '${rashiBi((moonSign + 1) % 12).hi} में प्रवेश पर चंद्र एक साथ दोनों '
              'स्वामियों में से एक और किसी बली तीसरे ग्रह से नहीं मिलेगा।',
        ),
      ),
    ];
  });

  return Matbhed(
    key: 'tajika_gairi_kamboola',
    topic: const Bi('Gairi-kamboola', 'गैरी-कम्बूल'),
    whyTheyDiffer: const Bi(
      'Both readings have the Moon at the end of its sign, about to meet a '
          'graha in the next. They differ on what the Moon must be like '
          'before that, and on what it must meet.',
      'दोनों पाठों में चंद्र अपनी राशि के अंत पर है और अगली राशि के किसी ग्रह से '
          'मिलने वाला है। फ़र्क यह है कि उससे पहले चंद्र कैसा हो, और वह किससे मिले।',
    ),
    defaultReason: _hayanaratnaMainSource,
    views: <Mat>[
      Mat(
        isDefault: true,
        holds: hayanaratna.houses.isNotEmpty,
        position: const Bi(
          'The lagna lord and the matter’s lord are in Itthasala; the Moon '
              'stands in a sign neither of them aspects, in the last degree of '
              'its sign, and will on entering the next sign join a graha '
              'standing there.',
          'लग्नेश और कार्येश में इत्थशाल है; चंद्र ऐसी राशि में है जिसे उन दोनों में '
              'से कोई नहीं देखता, अपनी राशि के अंतिम अंश में, और अगली राशि में '
              'प्रवेश कर वहाँ बैठे किसी ग्रह से मिलेगा।',
        ),
        holder: Bi(
          'Yadava’s Tajikayogasudhanidhi 6.25-26 and the Tajikalamkara, '
              'quoted in Hayanaratna 3.9, with a worked case from the Samjnatantra '
              '(2.58-60); ${_hayanaratnaEn.en}',
          'यादव का ताजिकयोगसुधानिधि 6.25-26 और ताजिकालंकार, जो हायनरत्न 3.9 में '
              'उद्धृत हैं, संज्ञातंत्र (2.58-60) के एक उदाहरण सहित; '
              '${_hayanaratnaEn.hi}',
        ),
        reasoning: const Bi(
          'The Moon carries the light, and here it has no standing and no '
              'meeting of its own; it is passed on to the graha it is about to '
              'join. If that graha is at home or exalted in the sign, the result '
              'equals a Kamboola; if not, it is read as evil.',
          'चंद्र प्रकाश ले जाता है, और यहाँ उसका अपना न कोई बल है न कोई मिलन; वह '
              'उस ग्रह तक पहुँचा दिया जाता है जिससे वह मिलने वाला है। यदि वह ग्रह उस '
              'राशि में अपने घर या उच्च में है तो फल कम्बूल के बराबर है; नहीं तो अशुभ '
              'पढ़ा जाता है।',
        ),
        result: hayanaratna.houses.isNotEmpty
            ? _formsFor(hayanaratna.houses, favourable!)
            : _doesNotForm(hayanaratna.nearMiss),
      ),
      Mat(
        holds: charak.houses.isNotEmpty,
        position: const Bi(
          'The lagna lord and the matter’s lord are in Itthasala; the Moon is '
              '“unqualified” (neither exalted nor debilitated, unaspected and '
              'not joined, not in its own division) at 29° or more, and on '
              'entering the next sign meets one of the two lords and also a '
              'strong third graha.',
          'लग्नेश और कार्येश में इत्थशाल है; चंद्र “योग्यता-रहित” है (न उच्च, न नीच, '
              'न दृष्ट, न युक्त, अपने विभाग में नहीं) 29° या अधिक पर, और अगली राशि '
              'में प्रवेश पर दोनों स्वामियों में से एक से और साथ ही किसी बली तीसरे ग्रह '
              'से मिलता है।',
        ),
        holder: _charakViaSdk,
        reasoning: const Bi(
          'Charak asks more of the Moon and of what it meets. The same '
              'transcription notes that, read literally, a Moon with no '
              'standing at all is almost never found.',
          'चरक चंद्र से और जिससे वह मिलता है उससे अधिक माँगते हैं। वही नोट्स '
              'बताते हैं कि अक्षरशः पढ़ने पर बिल्कुल बल-रहित चंद्र लगभग कभी नहीं मिलता।',
        ),
        result: charak.houses.isNotEmpty
            ? _formsFor(
                charak.houses,
                Bi(
                  'The Moon, ${_where(chart, Graha.moon).en}, meets a lord '
                      'and a strong third graha on entering '
                      '${rashiBi((moonSign + 1) % 12).en}.',
                  'चंद्र, ${_where(chart, Graha.moon).hi}, '
                      '${rashiBi((moonSign + 1) % 12).hi} में प्रवेश पर एक स्वामी और '
                      'एक बली तीसरे ग्रह से मिलता है।',
                ),
              )
            : _doesNotForm(charak.nearMiss),
      ),
    ],
  );
}

Matbhed _tambiraMatbhed(Kundli chart, TajikaReport report) {
  bool applying(Graha a, Graha b) {
    final TajikaAspect? t = report.aspectBetween(a, b);
    return t != null && t.isApplying;
  }

  Bi twoLords(int h, Graha l, Graha k) => Bi(
    'the lagna lord ${grahaBi(l).en} and the lord of ${houseBi(h).en}, '
        '${grahaBi(k).en},',
    'लग्नेश ${grahaBi(l).hi} और ${houseBi(h).hi} के स्वामी ${grahaBi(k).hi}',
  );

  String? giverEn;
  String? giverHi;
  final ({List<int> houses, Bi? nearMiss}) hayanaratna = _perMatter(chart, (
    int h,
    Graha l,
    Graha k,
  ) {
    // Either lord may be the one at the sign end.
    Graha? mover;
    List<PlacedGraha> receivers = const <PlacedGraha>[];
    Graha? nearMover;
    for (final Graha m in <Graha>[l, k]) {
      final PlacedGraha p = chart.grahas[m]!;
      if (!_strong(p) || p.degreesInSign < 29.0) continue;
      nearMover ??= m;
      final List<PlacedGraha> r = _inNextSign(
        chart,
        p.rashi.index,
        m,
        strongOnly: true,
      );
      if (r.isNotEmpty) {
        mover = m;
        receivers = r;
        break;
      }
    }
    if (mover != null && receivers.isNotEmpty && giverEn == null) {
      giverEn =
          '${_where(chart, mover).en} is at the end of its sign and will pass '
          'its light on entering ${rashiBi((chart.grahas[mover]!.rashi.index + 1) % 12).en} '
          'to ${grahaBi(receivers.first.graha).en}, strong there at '
          '${degText(receivers.first.degreesInSign)}.';
      giverHi =
          '${_where(chart, mover).hi} अपनी राशि के अंत पर है और '
          '${rashiBi((chart.grahas[mover]!.rashi.index + 1) % 12).hi} में प्रवेश '
          'पर अपना प्रकाश ${grahaBi(receivers.first.graha).hi} को देगा, जो वहाँ '
          '${degText(receivers.first.degreesInSign)} पर बली है।';
    }
    final Bi lords = twoLords(h, l, k);
    return <_Clause>[
      _Clause(
        !applying(l, k),
        Bi(
          '${lords.en} are in Itthasala, so this is not Tambira.',
          '${lords.hi} में इत्थशाल है, इसलिए यह तम्बीर नहीं।',
        ),
      ),
      _Clause(
        nearMover != null || mover != null,
        Bi(
          'neither lord is strong in sign and in the last degree of its sign.',
          'दोनों में से कोई स्वामी बली होकर अपनी राशि के अंतिम अंश में नहीं है।',
        ),
      ),
      _Clause(
        mover != null,
        Bi(
          'no other strong graha stands in the next sign close enough to '
              'receive the light.',
          'अगली राशि में कोई दूसरा बली ग्रह इतना पास नहीं कि प्रकाश ले सके।',
        ),
      ),
    ];
  });

  String? charakEn;
  String? charakHi;
  final ({List<int> houses, Bi? nearMiss}) charak = _perMatter(chart, (
    int h,
    Graha l,
    Graha k,
  ) {
    final PlacedGraha kp = chart.grahas[k]!;
    final List<PlacedGraha> inNext = _inNextSign(chart, kp.rashi.index, k);
    final bool lagnesha = inNext.any((PlacedGraha p) => p.graha == l);
    final List<PlacedGraha> third = _inNextSign(
      chart,
      kp.rashi.index,
      k,
      except: <Graha>{l},
      strongOnly: true,
    );
    final bool all =
        !(report.aspectBetween(l, k) != null) &&
        kp.degreesInSign >= 29.0 &&
        lagnesha &&
        third.isNotEmpty;
    if (all && charakEn == null) {
      charakEn =
          '${grahaBi(k).en} (${_where(chart, k).en}) will on entering the '
          'next sign join the lagna lord ${grahaBi(l).en} and the strong '
          '${grahaBi(third.first.graha).en}.';
      charakHi =
          '${_where(chart, k).hi} ${grahaBi(k).hi} अगली राशि में प्रवेश पर '
          'लग्नेश ${grahaBi(l).hi} और बली ${grahaBi(third.first.graha).hi} से '
          'मिलेगा।';
    }
    final Bi lords = twoLords(h, l, k);
    return <_Clause>[
      _Clause(
        report.aspectBetween(l, k) == null,
        Bi('${lords.en} are in aspect.', '${lords.hi} में दृष्टि है।'),
      ),
      _Clause(
        kp.degreesInSign >= 29.0,
        Bi(
          'the matter’s lord, ${_where(chart, k).en}, is not at the end of its '
              'sign.',
          'कार्येश, ${_where(chart, k).hi}, अपनी राशि के अंत पर नहीं है।',
        ),
      ),
      _Clause(
        lagnesha,
        Bi(
          'the lagna lord does not stand in the next sign within reach of '
              'the matter’s lord.',
          'लग्नेश अगली राशि में कार्येश की पहुँच के भीतर नहीं है।',
        ),
      ),
      _Clause(
        third.isNotEmpty,
        Bi(
          'no other strong graha stands there within reach.',
          'वहाँ पहुँच के भीतर कोई दूसरा बली ग्रह नहीं।',
        ),
      ),
    ];
  });

  return Matbhed(
    key: 'tajika_tambira',
    topic: const Bi('Tambira', 'तम्बीर'),
    whyTheyDiffer: const Bi(
      'In both, the two lords have no Itthasala, and a graha at the end of a '
          'sign passes its light on in the next sign. They differ on who may '
          'pass it and to whom.',
      'दोनों में दोनों स्वामियों में इत्थशाल नहीं है, और राशि के अंत पर बैठा ग्रह '
          'अगली राशि में अपना प्रकाश आगे देता है। फ़र्क यह है कि कौन दे सकता है और '
          'किसे।',
    ),
    defaultReason: Bi(
      '${_hayanaratnaMainSource.en} Hayanaratna’s own worked case has the slower '
          'Saturn giving its light to the faster Jupiter, which Gansten’s '
          'note doubts; this computation lets either lord pass the light to any '
          'strong graha, whichever is faster.',
      '${_hayanaratnaMainSource.hi} हायनरत्न के अपने उदाहरण में मंद शनि तेज़ गुरु '
          'को प्रकाश देता है, जिस पर गैन्स्टन की टिप्पणी को संदेह है; यहाँ कोई भी '
          'स्वामी किसी भी बली ग्रह को प्रकाश दे सकता है, चाहे वह तेज़ हो या मंद।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        holds: hayanaratna.houses.isNotEmpty,
        position: const Bi(
          'The two lords have no Itthasala. One of them, strong and in the last '
              'degree of its sign, passes its light on entering the next sign '
              'to a different strong graha standing there within reach.',
          'दोनों स्वामियों में इत्थशाल नहीं। उनमें से एक, बली और अपनी राशि के '
              'अंतिम अंश में, अगली राशि में प्रवेश पर वहाँ पहुँच के भीतर बैठे किसी '
              'दूसरे बली ग्रह को प्रकाश देता है।',
        ),
        holder: Bi(
          'The Hayanasindhu, as quoted in Hayanaratna 3.14; the same account in '
              '${_wikisourceNeelakanthi.en}',
          'हायनसिंधु, जैसा हायनरत्न 3.14 में उद्धृत है; यही वर्णन '
              '${_wikisourceNeelakanthi.hi} में',
        ),
        reasoning: const Bi(
          'No light passes between the lords directly, so it travels through a '
              'strong third graha: the matter is carried through by a go-between '
              'that is itself well placed.',
          'दोनों स्वामियों के बीच सीधे प्रकाश नहीं जाता, इसलिए वह किसी बली तीसरे '
              'ग्रह से होकर जाता है: काम एक ऐसे बिचौलिये से पूरा होता है जो स्वयं '
              'अच्छी स्थिति में है।',
        ),
        result: hayanaratna.houses.isNotEmpty
            ? _formsFor(hayanaratna.houses, Bi(giverEn ?? '', giverHi ?? ''))
            : _doesNotForm(hayanaratna.nearMiss),
      ),
      Mat(
        holds: charak.houses.isNotEmpty,
        position: const Bi(
          'The two lords are not in aspect. The matter’s lord, at the end of '
              'its sign, joins both the lagna lord and another strong graha '
              'when it enters the next sign.',
          'दोनों स्वामियों में दृष्टि नहीं। कार्येश, अपनी राशि के अंत पर, अगली राशि '
              'में प्रवेश पर लग्नेश और किसी और बली ग्रह दोनों से मिलता है।',
        ),
        holder: _charakViaSdk,
        reasoning: const Bi(
          'It is stricter: the mover must be the matter’s lord, and it must '
              'meet the lagna lord as well as a strong third graha.',
          'यह कड़ा है: चलने वाला कार्येश ही हो, और वह लग्नेश से भी मिले तथा किसी '
              'बली तीसरे ग्रह से भी।',
        ),
        result: charak.houses.isNotEmpty
            ? _formsFor(charak.houses, Bi(charakEn ?? '', charakHi ?? ''))
            : _doesNotForm(charak.nearMiss),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Kuttha: strength by time, and the rest of the list
// ---------------------------------------------------------------------------

/// Strength by time (kala-bala) out of 60, by the measures Hayanaratna 2.6
/// gives (Samarasimha and the Tajikamuktavali): the Moon and Mars by their
/// distance from the Sun, Venus by hers, Jupiter and Saturn by the watch of the
/// night, and the male grahas by day and the female by night from the Lagna's
/// distance from the Sun. The largest that applies is taken; the text gives no
/// threshold, so "possessed of" is read here as above zero.
double kalaBala(Kundli chart, Graha graha) {
  final double sun = chart.grahas[Graha.sun]!.siderealLongitude;
  final double lon = chart.grahas[graha]!.siderealLongitude;
  final double elongation = angleDiff(lon, sun).abs();
  double best = 0;
  void take(double v) {
    if (v > best) best = v;
  }

  switch (graha) {
    case Graha.moon:
    case Graha.mars:
      take((elongation / 3.0).clamp(0.0, 60.0));
    case Graha.venus:
      take((elongation * 6.0 / 5.0).clamp(0.0, 60.0));
    case Graha.jupiter:
    case Graha.saturn:
      take(_watchStrength(chart));
    default:
      break;
  }
  // Male grahas by day, female by night, from the Lagna's distance from the Sun.
  final double signs = norm360(chart.ascendant - sun) / 30.0;
  const Set<Graha> male = <Graha>{Graha.sun, Graha.mars, Graha.jupiter};
  const Set<Graha> female = <Graha>{Graha.moon, Graha.venus};
  if (male.contains(graha)) {
    if (signs <= 3) {
      take(20.0 * signs);
    } else if (signs <= 6) {
      take(20.0 * (6.0 - signs));
    }
  } else if (female.contains(graha)) {
    if (signs >= 6 && signs <= 9) {
      take(20.0 * (signs - 6.0));
    } else if (signs > 9) {
      take(20.0 * (12.0 - signs));
    }
  }
  return best;
}

/// The Jupiter-and-Saturn strength of the watches: nothing by day or before
/// midnight, rising from midnight to a full 60 at the end of the third watch,
/// and falling to nothing at sunrise.
double _watchStrength(Kundli chart) {
  final GeoPlace place = chart.birth.place;
  final double t = chart.instant.julianDayUt;
  final double midnight = Instant.fromLocal(
    DateTime(
      chart.birth.localDateTime.year,
      chart.birth.localDateTime.month,
      chart.birth.localDateTime.day,
    ),
    chart.birth.utcOffset,
  ).julianDayUt;
  RiseSet at(double from) => findRiseSet(Graha.sun, from, place);
  final RiseSet today = at(midnight);
  final RiseSet yesterday = at(midnight - 1.0);
  final RiseSet tomorrow = at(midnight + 1.0);
  double? start;
  double? end;
  if (today.rise != null && t < today.rise!) {
    start = yesterday.set;
    end = today.rise;
  } else if (today.set != null && t >= today.set!) {
    start = today.set;
    end = tomorrow.rise;
  }
  if (start == null || end == null || end <= start) return 0;
  final double night = end - start;
  final double mid = start + night / 2.0;
  final double watch = night / 4.0;
  if (t < mid) return 0;
  if (t - mid <= watch) return 60.0 * (t - mid) / watch;
  return 60.0 * (end - t) / watch;
}

/// True when [graha] is joined by, or in Tajika aspect with, a graha for which
/// [kind] holds.
bool _touchedBy(
  Kundli chart,
  TajikaReport report,
  Graha graha,
  bool Function(Graha) kind,
) {
  final int sign = chart.grahas[graha]!.rashi.index;
  for (final Graha other in tajikaGrahas) {
    if (other == graha || !kind(other)) continue;
    if (chart.grahas[other]!.rashi.index == sign) return true;
    if (report.aspectBetween(graha, other) != null) return true;
  }
  return false;
}

Matbhed _kutthaMatbhed(Kundli chart, TajikaReport report) {
  final int lagnaSign = chart.lagnaRashi.index;
  bool benefic(Graha g) => isBenefic(chart, g);

  final List<Graha> byHayanaratna = <Graha>[];
  final Map<Graha, double> time = <Graha, double>{
    for (final Graha g in tajikaGrahas) g: kalaBala(chart, g),
  };
  for (final Graha g in tajikaGrahas) {
    final PlacedGraha p = chart.grahas[g]!;
    final bool onLagna =
        signAspectOf(signDistance(p.rashi.index, lagnaSign)) != null;
    if (_strong(p) &&
        _kendra(p.house) &&
        onLagna &&
        _touchedBy(chart, report, g, benefic) &&
        !_touchedBy(chart, report, g, (Graha o) => !benefic(o)) &&
        !p.isCombust &&
        !p.isRetrograde &&
        time[g]! > 0) {
      byHayanaratna.add(g);
    }
  }

  final List<int> byCharak = <int>[];
  final Graha lagnesha = houseLord(chart, 1);
  bool charakOk(Graha g) {
    final PlacedGraha p = chart.grahas[g]!;
    return _strong(p) &&
        _kendraOrPanaphara(p.house) &&
        _touchedBy(chart, report, g, benefic) &&
        !_touchedBy(chart, report, g, (Graha o) => !benefic(o));
  }

  for (int h = 2; h <= 12; h++) {
    final Graha k = houseLord(chart, h);
    if (k == lagnesha) continue;
    if (charakOk(lagnesha) && charakOk(k)) byCharak.add(h);
  }

  Bi names(List<Graha> list) => _join(list.map(grahaBi));
  return Matbhed(
    key: 'tajika_kuttha',
    topic: const Bi('Kuttha', 'कुत्थ'),
    whyTheyDiffer: const Bi(
      'The books define Kuttha by different lists. Hayanaratna’s list is long '
          'and ends with “strength by time”, for which the book itself gives '
          'several measures and no threshold. Charak’s, as transcribed, is '
          'short and about the two lords.',
      'ग्रंथ कुत्थ को अलग-अलग सूचियों से बताते हैं। हायनरत्न की सूची लंबी है और '
          '“काल-बल” पर खत्म होती है, जिसके लिए पुस्तक कई मापदंड देती है पर कोई सीमा '
          'नहीं। चरक की, जैसी नोट्स में है, छोटी है और दोनों स्वामियों के बारे में।',
    ),
    defaultReason: Bi(
      '${_hayanaratnaMainSource.en} Where it gives no threshold for strength '
          'by time, this reads “possessed of” as above zero by any measure that '
          'applies to the graha; Mercury has none of the measures, so it cannot '
          'pass.',
      '${_hayanaratnaMainSource.hi} जहाँ वह काल-बल की कोई सीमा नहीं देती, यहाँ '
          '“से युक्त” का अर्थ ग्रह पर लागू किसी भी मापदंड से शून्य से अधिक लिया गया '
          'है; बुध पर इनमें से कोई मापदंड लागू नहीं, इसलिए वह पास नहीं हो सकता।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        holds: byHayanaratna.isNotEmpty,
        position: const Bi(
          'A graha is Kuttha when it is strong in sign, in a kendra, joined to '
              'or aspecting the Lagna, joined to or aspected by a benefic, free '
              'of malefic conjunction and aspect, risen (not combust), direct, '
              'and possessed of strength by time.',
          'ग्रह कुत्थ है जब वह राशि में बली हो, केंद्र में हो, लग्न से युत या लग्न '
              'को देखता हो, शुभ ग्रह से युत या दृष्ट हो, पाप ग्रह की युति और दृष्टि से '
              'मुक्त हो, उदित (अस्त नहीं) हो, मार्गी हो, और काल-बल से युक्त हो।',
        ),
        holder: Bi(
          'Tajikabhushana 4.29a, quoted in Hayanaratna 3.15, with the measures of '
              'strength by time from Hayanaratna 2.6; ${_hayanaratnaEn.en}',
          'ताजिकभूषण 4.29a, जो हायनरत्न 3.15 में उद्धृत है, काल-बल के मापदंड '
              'हायनरत्न 2.6 से; ${_hayanaratnaEn.hi}',
        ),
        reasoning: const Bi(
          'A graha that has every mark of strength together (place, company, '
              'light, motion and time) gives its results in full.',
          'जिस ग्रह में बल के सब लक्षण साथ हों (स्थान, संगति, प्रकाश, गति और '
              'समय) वह अपना फल पूरा देता है।',
        ),
        result: byHayanaratna.isNotEmpty
            ? Bi(
                'Kuttha: ${names(byHayanaratna).en}.',
                'कुत्थ: ${names(byHayanaratna).hi}।',
              )
            : const Bi(
                'No graha meets every mark this year.',
                'इस वर्ष कोई ग्रह सभी लक्षण पूरे नहीं करता।',
              ),
      ),
      Mat(
        holds: byCharak.isNotEmpty,
        position: const Bi(
          'The lagna lord and the matter’s lord are both strong in sign, each '
              'in a kendra or a panaphara, each aspected by a benefic and by no '
              'malefic.',
          'लग्नेश और कार्येश दोनों राशि में बली हों, हर एक केंद्र या पणफर में हो, '
              'हर एक को शुभ ग्रह देखता हो और कोई पाप ग्रह नहीं।',
        ),
        holder: _charakViaSdk,
        reasoning: Bi(
          'It judges the pair of lords for a matter and does not ask for the '
              'time, risen or direct marks; the transcription reads those as '
              'alternatives, not requirements. “Powerful” is read here as strong '
              'in sign, which is our reading.',
          'यह किसी विषय के दोनों स्वामियों को परखता है और समय, उदित या मार्गी के '
              'लक्षण नहीं माँगता; नोट्स उन्हें विकल्प मानते हैं, शर्त नहीं। '
              '“बलवान” का अर्थ यहाँ राशि में बली लिया गया है, जो हमारा पाठ है।',
        ),
        result: byCharak.isNotEmpty
            ? Bi(
                'Kuttha for the matters of ${housesBi(byCharak).en}.',
                '${housesBi(byCharak).hi} के विषयों के लिए कुत्थ।',
              )
            : const Bi(
                'No matter has both lords so placed this year.',
                'इस वर्ष किसी विषय के दोनों स्वामी ऐसे स्थित नहीं।',
              ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Durapha
// ---------------------------------------------------------------------------

/// Why [g] is Durapha by the list of Tajikabhushana 4.30 (and, for the Moon,
/// Samjnatantra 2.73-74), as far as the chart can say. Empty when it is not.
/// The last mark of the list, "in the mouth or tail of Rahu", is not computed
/// because the text read does not define mouth and tail.
List<Bi> _duraphaReasons(Kundli chart, TajikaReport report, Graha g) {
  final PlacedGraha p = chart.grahas[g]!;
  final List<Bi> why = <Bi>[];
  if (p.isCombust) why.add(const Bi('combust', 'अस्त'));
  if (p.isRetrograde) why.add(const Bi('retrograde', 'वक्री'));
  if (_touchedBy(chart, report, g, (Graha o) => !isBenefic(chart, o))) {
    why.add(
      const Bi('joined or aspected by a malefic', 'पाप ग्रह से युत या दृष्ट'),
    );
  }
  if (_trika(p.house)) {
    why.add(Bi('in ${houseBi(p.house).en}', '${houseBi(p.house).hi} में'));
  }
  final List<int> own = grahaInfo(g).ownSigns;
  if (own.any((int s) => (s + 6) % 12 == p.rashi.index)) {
    why.add(
      const Bi('in the 7th sign from its own', 'अपनी राशि से सातवीं राशि में'),
    );
  }
  for (final Graha o in tajikaGrahas) {
    if (o == g) continue;
    final TajikaAspect? t = report.aspectBetween(g, o);
    if (t != null &&
        t.isApplying &&
        chart.grahas[o]!.dignity == Dignity.debilitated) {
      why.add(
        Bi(
          'in Itthasala with the debilitated ${grahaBi(o).en}',
          'नीच ${grahaBi(o).hi} से इत्थशाल में',
        ),
      );
    }
  }
  if (g == Graha.moon) {
    final PlacedGraha sun = chart.grahas[Graha.sun]!;
    if ((p.rashi.index - sun.rashi.index + 12) % 12 == 11) {
      why.add(
        const Bi('in the 12th sign from the Sun', 'सूर्य से बारहवीं राशि में'),
      );
    }
    final Graha lord = rashiInfo(p.rashi).lord;
    if (lord != Graha.moon && report.aspectBetween(Graha.moon, lord) == null) {
      why.add(
        const Bi(
          'not aspected by the lord of its sign',
          'अपनी राशि के स्वामी से दृष्ट नहीं',
        ),
      );
    }
    if (report.aspectsOf(Graha.moon).isEmpty && !_strong(p)) {
      why.add(
        const Bi(
          'aspected by no one and without dignity',
          'किसी से दृष्ट नहीं और बल-रहित',
        ),
      );
    }
    final bool waning =
        norm360(p.siderealLongitude - sun.siderealLongitude) > 180.0;
    if (waning || p.degreesInSign >= 29.0) {
      why.add(
        Bi(
          waning ? 'waning' : 'at the end of its sign',
          waning ? 'घटता हुआ' : 'राशि के अंत पर',
        ),
      );
    }
    final Graha harsh = waning ? Graha.saturn : Graha.mars;
    final TajikaAspect? t = report.aspectBetween(Graha.moon, harsh);
    final bool sameSign = chart.grahas[harsh]!.rashi.index == p.rashi.index;
    if (sameSign || (t != null && t.nature == AspectNature.inimical)) {
      why.add(
        Bi(
          'in a harsh aspect from ${grahaBi(harsh).en}',
          '${grahaBi(harsh).hi} की कठोर दृष्टि में',
        ),
      );
    }
  }
  return why;
}

Matbhed _duraphaMatbhed(
  Kundli chart,
  TajikaReport report,
  Map<Graha, PanchaVargiyaBala> bala,
) {
  final Map<Graha, List<Bi>> byHayanaratna = <Graha, List<Bi>>{
    for (final Graha g in tajikaGrahas)
      if (_duraphaReasons(chart, report, g).isNotEmpty)
        g: _duraphaReasons(chart, report, g),
  };
  final List<int> byCharak = <int>[];
  final Graha lagnesha = houseLord(chart, 1);
  bool charakWeak(Graha g) {
    final PlacedGraha p = chart.grahas[g]!;
    return bala[g]!.vishwa < 10.0 &&
        (_trika(p.house) || p.isCombust || p.isRetrograde);
  }

  for (int h = 2; h <= 12; h++) {
    final Graha k = houseLord(chart, h);
    if (k == lagnesha) continue;
    if (charakWeak(lagnesha) && charakWeak(k)) byCharak.add(h);
  }
  final Bi weakNames = _join(
    byHayanaratna.entries.map(
      (MapEntry<Graha, List<Bi>> e) => Bi(
        '${grahaBi(e.key).en} (${e.value.map((Bi b) => b.en).join('; ')})',
        '${grahaBi(e.key).hi} (${e.value.map((Bi b) => b.hi).join('; ')})',
      ),
    ),
    and: '; ',
  );
  return Matbhed(
    key: 'tajika_durapha',
    topic: const Bi('Durapha', 'दुरुफ़'),
    whyTheyDiffer: const Bi(
      'Hayanaratna lists many marks of a weak graha, any one of which is '
          'enough, and one of them (aspect by a malefic) is met by almost every '
          'graha. Charak, as transcribed, asks that both lords of a matter are '
          'weak and badly placed.',
      'हायनरत्न दुर्बल ग्रह के कई लक्षण गिनाता है, जिनमें से कोई एक काफ़ी है, और '
          'उनमें से एक (पाप ग्रह की दृष्टि) लगभग हर ग्रह पर लागू होता है। चरक, जैसी '
          'नोट्स में है, चाहते हैं कि किसी विषय के दोनों स्वामी दुर्बल और बुरी '
          'स्थिति में हों।',
    ),
    defaultReason: Bi(
      '${_hayanaratnaMainSource.en} Its last mark, “in the mouth or tail of '
          'Rahu”, is not computed: the book gives no definition of mouth and '
          'tail.',
      '${_hayanaratnaMainSource.hi} उसका अंतिम लक्षण, “राहु के मुख या पूँछ में”, '
          'नहीं गिना गया: पुस्तक मुख और पूँछ की कोई परिभाषा नहीं देती।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        holds: byHayanaratna.isNotEmpty,
        position: const Bi(
          'A graha is Durapha if it is combust, retrograde, joined or aspected '
              'by a malefic, in the 6th, 8th or 12th, in the 7th sign from its '
              'own, or in Itthasala with a fallen graha. The Moon has further '
              'marks of its own.',
          'ग्रह दुरुफ़ है यदि वह अस्त हो, वक्री हो, पाप ग्रह से युत या दृष्ट हो, 6, 8 '
              'या 12वें भाव में हो, अपनी राशि से सातवीं राशि में हो, या नीच ग्रह से '
              'इत्थशाल में हो। चंद्र के अपने कुछ और लक्षण भी हैं।',
        ),
        holder: Bi(
          'Tajikabhushana 4.30, quoted in Hayanaratna 3.16, and for the Moon '
              'the Samjnatantra 2.73-74 list given there; ${_hayanaratnaEn.en}',
          'ताजिकभूषण 4.30, जो हायनरत्न 3.16 में उद्धृत है, और चंद्र के लिए वहीं '
              'दी गई संज्ञातंत्र 2.73-74 की सूची; ${_hayanaratnaEn.hi}',
        ),
        reasoning: const Bi(
          'Each mark takes away a graha’s ability to carry a matter through, '
              'so any one is enough to call it Durapha.',
          'हर लक्षण ग्रह की काम को पूरा कराने की क्षमता घटाता है, इसलिए कोई एक भी '
              'उसे दुरुफ़ कहने के लिए काफ़ी है।',
        ),
        result: byHayanaratna.isNotEmpty
            ? Bi('Durapha: ${weakNames.en}.', 'दुरुफ़: ${weakNames.hi}।')
            : const Bi(
                'No graha carries any of these marks this year.',
                'इस वर्ष किसी ग्रह में इनमें से कोई लक्षण नहीं।',
              ),
      ),
      Mat(
        holds: byCharak.isNotEmpty,
        position: const Bi(
          'The lagna lord and the matter’s lord are both weak (under 10 vishwa '
              'of five-fold strength), and each is in the 6th, 8th or 12th, '
              'combust or retrograde.',
          'लग्नेश और कार्येश दोनों दुर्बल हों (पंचवर्गीय बल 10 विश्वा से कम), और '
              'हर एक 6, 8 या 12वें भाव में, अस्त या वक्री हो।',
        ),
        holder: _charakViaSdk,
        reasoning: const Bi(
          'It reads the yoga for the pair of lords only, and wants both to be '
              'weak and afflicted. The transcription’s author notes that the '
              'book does not mention Rahu’s mouth or tail. “Weak” is read here '
              'as under 10 vishwa, which is our reading.',
          'यह योग केवल दोनों स्वामियों की जोड़ी के लिए पढ़ता है, और दोनों का दुर्बल '
              'और पीड़ित होना चाहता है। नोट्स के लेखक बताते हैं कि पुस्तक में राहु '
              'के मुख या पूँछ का ज़िक्र नहीं। “दुर्बल” का अर्थ यहाँ 10 विश्वा से कम '
              'लिया गया है, जो हमारा पाठ है।',
        ),
        result: byCharak.isNotEmpty
            ? Bi(
                'Durapha for the matters of ${housesBi(byCharak).en}.',
                '${housesBi(byCharak).hi} के विषयों के लिए दुरुफ़।',
              )
            : const Bi(
                'No matter has both lords so weak and placed this year.',
                'इस वर्ष किसी विषय के दोनों स्वामी इतने दुर्बल और ऐसे स्थित नहीं।',
              ),
      ),
    ],
  );
}

/// Every disagreement of the Tajika part, worked out on the year chart
/// [chart] for the aspects in [report].
List<Matbhed> computeTajikaMatbhed(
  Kundli chart,
  Map<Graha, PanchaVargiyaBala> bala,
  TajikaReport report,
) => <Matbhed>[
  _orbMatbhed(chart),
  _ishrafaMatbhed(chart),
  _gairiKamboolaMatbhed(chart, report),
  _tambiraMatbhed(chart, report),
  _kutthaMatbhed(chart, report),
  _duraphaMatbhed(chart, report, bala),
];

/// What the Tajika part still does not compute, with the reason.
const List<LeftOut> tajikaLeftOut = <LeftOut>[
  LeftOut(
    key: 'rahu_mouth_tail',
    name: Bi(
      '“In the mouth or tail of Rahu” (a mark of Durapha)',
      '“राहु के मुख या पूँछ में” (दुरुफ़ का एक लक्षण)',
    ),
    reason: Bi(
      'the book that lists it does not say what mouth and tail are, and the '
          'Hindi commentary only calls them the degrees still to go and already '
          'gone, so no longitude can be computed from it without guessing.',
      'जिस पुस्तक में यह सूची है वह नहीं बताती कि मुख और पूँछ क्या हैं, और हिंदी टीका '
          'बस इन्हें बचे हुए और बीत चुके अंश कहती है, इसलिए बिना अनुमान के इससे कोई '
          'देशांतर नहीं निकलता।',
    ),
  ),
];
