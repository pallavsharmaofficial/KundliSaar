import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'ashtakavarga.dart';
import 'bilingual.dart';
import 'chart.dart';
import 'dasha.dart';
import 'graha_data.dart';
import 'rashi.dart';
import 'remedies.dart';
import 'shadbala.dart';
import 'transits.dart';
import 'yogas.dart';

export 'bilingual.dart' show Bi;

/// Phaladesh: what the chart says a time of life is likely to be about.
///
/// The tradition's own order of reading is kept. The dasha promises and the
/// transit delivers, so the periods come first and the transits are read
/// against them; a period is never read alone, so every reading looks at the
/// one before it, the one after it and the period that contains it.
///
/// Nothing here is a lookup table of finished prose. Each reading is put
/// together from rules: what the lord rules from this lagna, where it stands,
/// in what dignity, how strong shadbala and ashtakavarga find it, what
/// company and aspects it keeps, and whether it is a benefic or malefic for
/// this particular lagna. The vocabulary tables below hold only what the
/// houses and grahas signify; the sentences are assembled from rule results.
///
/// What is classical and what is ours:
///  * Which houses a graha rules, which house it sits in, kendra and trikona
///    strengthening a lord, 6/8/12 afflicting it, an own or exalted sign
///    protecting it, a lord in the 12th from its house weakening the house,
///    neecha bhanga, viparita raja yoga, the antardasha lord counted from the
///    mahadasha lord, and the friend/neutral/enemy table are the tradition's.
///  * The numeric weights that turn those rules into a tone (supportive,
///    mixed, demanding) are this app's own convention, and so is the wording.
///    The rules are those commonly taught in the Parashari tradition; where
///    schools differ the text says so or hedges, the weights come from no
///    verse, and no verse is quoted for anything.
///
/// Every house, graha, period and transit also says how strongly the chart
/// itself points at the reading ([Indication]): a count of the chart factors
/// that agree, with the ones that agree and the ones that do not listed. That
/// is this app's own convention, not a classical measure and not a probability,
/// and no reading carries a chance of any event. Every house, period and
/// transit says what tends to come up in the areas of life it concerns, as a
/// tendency and never as an event, and every finding that is strained carries
/// the remedies the tradition commonly prescribes for the graha concerned
/// (see remedies.dart): a mantra, a fast, giving, a deity and one plain act,
/// never anything that has to be bought.
///
/// The app does not predict death, illness, pregnancy, examinations, legal
/// outcomes or investment returns. Where a classical rule touches those
/// houses, the reading speaks only of the area of life (daily work, change,
/// partnership, expense) and never of an event. A difficult period is
/// described by what it asks of the person.

/// What a reading looks like from outside: a headline, and the chart factors
/// it was derived from, so the screen can always answer "why this".
abstract interface class PhalaReading {
  Bi get headline;

  /// The chart factors this reading was derived from.
  List<Bi> get basis;

  /// Every piece of text in the reading, for tests and for read-aloud.
  Iterable<Bi> get texts;
}

/// How comfortably a period or house is placed, as the rules weigh it. A
/// demanding tone is a statement about effort, never about misfortune.
enum Tone { supportive, mixed, demanding }

/// A graha's character for one particular lagna, as opposed to its natural
/// character: Saturn is a natural malefic but the yogakaraka of Taurus.
enum FunctionalNature { yogakaraka, benefic, mixed, malefic }

// ---------------------------------------------------------------------------
// Strength of indication
// ---------------------------------------------------------------------------
//
// Every reading says how strongly the chart itself points at it. This is NOT
// the chance of anything happening: nobody can validate such a number and the
// app does not pretend to one. What can be counted and checked is how many
// separate facts of the chart point the same way as the reading, and which
// ones point the other way. That count, with the facts listed, is the band.
//
// The scale is this app's own convention. It is not a classical measure and it
// is not a probability. The factors are separate facts of the chart, not
// statistically independent measurements (dignity feeds shadbala, and the
// sarvashtakavarga is the sum of the other ashtakavargas), so even the
// strongest band is a stronger pointer and never a promise.

/// Which kind of chart fact a factor is read from.
enum FactorKind {
  placement,
  dignity,
  nature,
  shadbala,
  ashtakavarga,
  aspects,
  company,
  occupants,
  condition,
  yoga,
  relief,
  period,
  transit,
}

/// One fact of the chart that points to a matter going with support or to it
/// asking effort.
class IndicatorFactor {
  const IndicatorFactor({
    required this.kind,
    required this.text,
    required this.eases,
    required this.firm,
    this.grahas = const <Graha>[],
  });

  final FactorKind kind;
  final Bi text;

  /// True when the fact points to the matter going with support, false when
  /// it points to the matter asking effort.
  final bool eases;

  /// A firm factor is a plainly measured, weighty fact: a sign of exaltation
  /// or fall, a kendra or a difficult house, shadbala against its minimum,
  /// five bindus or three. A light one is a mild nudge: a friend's sign, the
  /// company a graha keeps. Whether a fact is firm or light is this app's own
  /// convention.
  final bool firm;

  /// The grahas the fact is about. Remedies are made for these.
  final List<Graha> grahas;
}

/// The bands of the scale. [mixed] is not a rung between the others: it is
/// what a reading that says "support and effort go together" gets, because
/// such a reading has no single direction to be strong in.
enum IndicationBand { strong, moderate, weak, mixed }

/// The scale, named honestly. Shown wherever a band is shown.
const Bi indicationScaleNote = Bi(
  'How to read the band: it counts how many separate chart factors agree with the reading. This is the app’s own convention. It is not a classical measure, and it is not a probability of anything happening. The factors overlap a little (dignity feeds shadbala, and the sarvashtakavarga sums the rest), so even a strong band is only a stronger pointer, never a promise.',
  'इस पट्टी को कैसे पढ़ें: यह गिनती है कि कुंडली के कितने अलग-अलग कारक इस फल से सहमत हैं। यह इस ऐप की अपनी गिनती है। यह कोई शास्त्रीय माप नहीं है, और यह किसी बात के होने की संभावना भी नहीं है। कारक आपस में थोड़े जुड़े हुए हैं (स्थिति का असर षड्बल में भी गिना जाता है, और सर्वाष्टकवर्ग बाक़ी का जोड़ है), इसलिए प्रबल संकेत भी बस एक मज़बूत इशारा है, वादा नहीं।',
);

/// How strongly the chart points at one reading, with the factors behind it.
///
/// The scale (this app's own convention):
///  * strong: at least four factors agree, at most one disagrees, and at least
///    two of those that agree are firm;
///  * moderate: at least three agree and they outnumber those that disagree
///    by two or more;
///  * weak: anything less, including every reading that rests on one or two
///    factors;
///  * mixed: for a reading that itself says support and effort go together,
///    the split is shown as it stands.
class Indication {
  const Indication._({
    required this.direction,
    required this.band,
    required this.agreeing,
    required this.disagreeing,
  });

  /// Builds the indication for a reading whose tone is [tone] from the
  /// factors the chart gives. A factor that takes no side is simply not in
  /// the list, so every factor given counts.
  factory Indication(Tone tone, List<IndicatorFactor> factors) {
    final List<IndicatorFactor> ease = <IndicatorFactor>[
      for (final IndicatorFactor f in factors)
        if (f.eases) f,
    ];
    final List<IndicatorFactor> effort = <IndicatorFactor>[
      for (final IndicatorFactor f in factors)
        if (!f.eases) f,
    ];
    final List<IndicatorFactor> agree = tone == Tone.demanding ? effort : ease;
    final List<IndicatorFactor> disagree = tone == Tone.demanding
        ? ease
        : effort;
    final int a = agree.length;
    final int d = disagree.length;
    final int firmAgree = agree.where((IndicatorFactor f) => f.firm).length;
    final IndicationBand band = tone == Tone.mixed
        ? IndicationBand.mixed
        : (a >= 4 && d <= 1 && firmAgree >= 2
              ? IndicationBand.strong
              : (a >= 3 && a - d >= 2
                    ? IndicationBand.moderate
                    : IndicationBand.weak));
    return Indication._(
      direction: tone,
      band: band,
      agreeing: List<IndicatorFactor>.unmodifiable(agree),
      disagreeing: List<IndicatorFactor>.unmodifiable(disagree),
    );
  }

  /// The tone of the reading the factors are weighed against.
  final Tone direction;
  final IndicationBand band;

  /// The factors that agree with the reading. For a mixed reading, the ones
  /// that point to support.
  final List<IndicatorFactor> agreeing;

  /// The factors that point the other way. For a mixed reading, the ones that
  /// point to effort.
  final List<IndicatorFactor> disagreeing;

  /// How many factors took a side. The count is exactly the factors listed.
  int get total => agreeing.length + disagreeing.length;

  int get firmAgreeing => agreeing.where((IndicatorFactor f) => f.firm).length;

  Bi get label => switch (band) {
    IndicationBand.strong => const Bi('Strong indication', 'प्रबल संकेत'),
    IndicationBand.moderate => const Bi('Moderate indication', 'मध्यम संकेत'),
    IndicationBand.weak => const Bi('Weak indication', 'हल्का संकेत'),
    IndicationBand.mixed => const Bi('Mixed indication', 'मिला-जुला संकेत'),
  };

  /// "4 of 5 factors agree".
  Bi get count {
    final int a = agreeing.length;
    if (band == IndicationBand.mixed) {
      final int d = disagreeing.length;
      return Bi(
        '$a ${a == 1 ? 'factor points' : 'factors point'} to support, $d to effort',
        '$a कारक सहारे की ओर, $d मेहनत की ओर',
      );
    }
    return Bi(
      '$a of $total ${total == 1 ? 'factor agrees' : 'factors agree'}',
      '$total में से $a कारक सहमत',
    );
  }

  /// The band and the count together: "Strong indication — 4 of 5 factors
  /// agree".
  Bi get summary =>
      Bi('${label.en} — ${count.en}', '${label.hi} — ${count.hi}');

  /// A plain warning when the reading rests on too little, or null when it
  /// does not.
  Bi? get caution {
    final int a = agreeing.length;
    final int d = disagreeing.length;
    if (total == 0) {
      return const Bi(
        'No chart factor takes a side here, so nothing but the app’s own weighing stands behind this reading.',
        'यहाँ कुंडली का कोई कारक किसी तरफ़ नहीं झुकता, इसलिए इस फल के पीछे सिर्फ़ ऐप का अपना तौल है।',
      );
    }
    final bool single = band == IndicationBand.mixed ? total == 1 : a == 1;
    if (band == IndicationBand.mixed && !single) return null;
    if (single) {
      final bool firm =
          (band == IndicationBand.mixed
                  ? <IndicatorFactor>[...agreeing, ...disagreeing]
                  : agreeing)
              .first
              .firm;
      return Bi(
        'This reading rests on a single factor${firm ? '' : ', and a light one'}. Treat it as a hint, not as something settled.',
        'यह फल सिर्फ़ एक कारक पर टिका है${firm ? '' : ', और वह भी हल्का'}। इसे इशारा भर समझें, पक्की बात नहीं।',
      );
    }
    if (a == 0) {
      return const Bi(
        'No factor agrees with this reading; it rests on the app’s own weighing alone.',
        'कोई भी कारक इस फल से सहमत नहीं है; यह सिर्फ़ ऐप के अपने तौल पर टिका है।',
      );
    }
    if (d >= a) {
      return const Bi(
        'As many factors disagree as agree, so the chart does not settle this one.',
        'जितने कारक सहमत हैं उतने ही असहमत भी हैं, इसलिए कुंडली इस बात को तय नहीं करती।',
      );
    }
    if (a == 2 && band == IndicationBand.weak) {
      return const Bi(
        'Only two factors agree, so hold this lightly.',
        'सिर्फ़ दो कारक सहमत हैं, इसलिए इसे हल्के में लें।',
      );
    }
    return null;
  }

  /// The heading over the factors that agree.
  Bi get agreeHeading => switch (direction) {
    Tone.supportive => const Bi(
      'Factors that agree (pointing to support)',
      'सहमत कारक (सहारे की ओर)',
    ),
    Tone.demanding => const Bi(
      'Factors that agree (pointing to effort)',
      'सहमत कारक (मेहनत की ओर)',
    ),
    Tone.mixed => const Bi(
      'Factors pointing to support',
      'सहारे की ओर इशारा करने वाले कारक',
    ),
  };

  /// The heading over the factors that point the other way.
  Bi get disagreeHeading => switch (direction) {
    Tone.supportive => const Bi(
      'Factors that disagree (pointing to effort)',
      'असहमत कारक (मेहनत की ओर)',
    ),
    Tone.demanding => const Bi(
      'Factors that disagree (pointing to support)',
      'असहमत कारक (सहारे की ओर)',
    ),
    Tone.mixed => const Bi(
      'Factors pointing to effort',
      'मेहनत की ओर इशारा करने वाले कारक',
    ),
  };

  /// Every text of the indication, for tests and read-aloud. The scale note
  /// is not here: it is shown beside the band and tested on its own.
  Iterable<Bi> get texts => <Bi>[
    summary,
    ?caution,
    agreeHeading,
    disagreeHeading,
    for (final IndicatorFactor f in agreeing) f.text,
    for (final IndicatorFactor f in disagreeing) f.text,
  ];
}

/// A reading that carries a strength band, what tends to come up and the
/// remedies for what it finds strained.
abstract interface class IndicatedReading implements PhalaReading {
  /// How strongly the chart points at the reading, with the factors behind it.
  Indication get indication;

  /// The areas of life and what tends to come up in them. Phrased as
  /// tendencies and as what the time asks of the person, never as an event.
  /// Null only for a reading of a single graha, which has its own wording.
  Bi? get tends;

  /// The remedies for what the reading finds strained. Empty when nothing is.
  List<Remedy> get remedies;
}

/// Makes the remedies for the pressing factors of a reading: one for each
/// graha they concern, the one with the most weight first, at most [limit].
/// The remedy says which graha it is for and which facts press on it. When no
/// pressing factor names a graha, the remedy goes to [fallback] with
/// [fallbackReason], so a strained reading never goes without one.
List<Remedy> _remediesFor(
  List<IndicatorFactor> factors, {
  required int limit,
  required Graha fallback,
  required Bi fallbackReason,
  Graha? prefer,
}) {
  final Map<Graha, List<IndicatorFactor>> by = <Graha, List<IndicatorFactor>>{};
  for (final IndicatorFactor f in factors) {
    if (f.eases) continue;
    for (final Graha g in f.grahas) {
      by.putIfAbsent(g, () => <IndicatorFactor>[]).add(f);
    }
  }
  if (by.isEmpty) {
    return <Remedy>[
      _remedy(fallback, <Bi>[fallbackReason]),
    ];
  }
  double weight(List<IndicatorFactor> fs) => fs.fold<double>(
    0,
    (double sum, IndicatorFactor f) => sum + (f.firm ? 2 : 1),
  );
  final List<MapEntry<Graha, List<IndicatorFactor>>> order = by.entries
      .toList();
  final Map<Graha, int> seen = <Graha, int>{
    for (int i = 0; i < order.length; i++) order[i].key: i,
  };
  order.sort((
    MapEntry<Graha, List<IndicatorFactor>> a,
    MapEntry<Graha, List<IndicatorFactor>> b,
  ) {
    if (prefer != null && (a.key == prefer) != (b.key == prefer)) {
      return a.key == prefer ? -1 : 1;
    }
    final int byWeight = weight(b.value).compareTo(weight(a.value));
    return byWeight != 0 ? byWeight : seen[a.key]!.compareTo(seen[b.key]!);
  });
  return <Remedy>[
    for (final MapEntry<Graha, List<IndicatorFactor>> e in order.take(limit))
      _remedy(
        e.key,
        (List<IndicatorFactor>.of(e.value)..sort(
              (IndicatorFactor a, IndicatorFactor b) =>
                  (b.firm ? 1 : 0).compareTo(a.firm ? 1 : 0),
            ))
            .take(3)
            .map((IndicatorFactor f) => f.text)
            .toList(),
      ),
  ];
}

Remedy _remedy(Graha g, List<Bi> reasons) {
  final Bi me = _graha(g);
  return Remedy(
    graha: g,
    addresses: Bi(
      'This remedy is for ${me.en}. What presses on it: ${reasons.map((Bi r) => r.en).join('; ')}.',
      'यह उपाय ${me.hi} के लिए है। कारण: ${reasons.map((Bi r) => r.hi).join('; ')}।',
    ),
  );
}

String _closed(String s, String stop) {
  final String t = s.trim();
  if (t.isEmpty) return t;
  const String enders = '.।!?';
  return enders.contains(t[t.length - 1]) ? t : '$t$stop';
}

/// The remedy for an adverse yoga, through one of the grahas that make it.
Remedy _yogaRemedy(YogaFinding y, Graha through) {
  final Bi me = _graha(through);
  return Remedy(
    graha: through,
    addresses: Bi(
      'This remedy is for ${y.nameEnglish}. ${_closed(y.ruleEnglish, '.')} It works through ${me.en}.',
      'यह उपाय ${y.nameHindi} के लिए है। ${_closed(y.ruleHindi, '।')} यह ${me.hi} के ज़रिए किया जाता है।',
    ),
  );
}

// ---------------------------------------------------------------------------
// Small language helpers
// ---------------------------------------------------------------------------

String _listEn(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

String _listHi(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} और ${items.last}';
}

Bi _items(List<Bi> parts) => Bi(
  _listEn(parts.map((Bi p) => p.en).toList()),
  _listHi(parts.map((Bi p) => p.hi).toList()),
);

Bi _cat(Iterable<Bi> parts, [String separator = ' ']) => Bi(
  parts.map((Bi p) => p.en).join(separator),
  parts.map((Bi p) => p.hi).join(separator),
);

Bi _graha(Graha g) => Bi(grahaInfo(g).english, grahaInfo(g).hindi);
Bi _sign(Rashi r) => Bi(rashiInfo(r).english, rashiInfo(r).hindi);
Bi _grahas(List<Graha> gs) => _items(gs.map(_graha).toList());

const List<String> _ordEn = <String>[
  '',
  '1st',
  '2nd',
  '3rd',
  '4th',
  '5th',
  '6th',
  '7th',
  '8th',
  '9th',
  '10th',
  '11th',
  '12th',
];

/// Hindi ordinals before a masculine noun in the oblique, as in "सातवें भाव में".
const List<String> _ordHiOblique = <String>[
  '',
  'पहले',
  'दूसरे',
  'तीसरे',
  'चौथे',
  'पाँचवें',
  'छठे',
  'सातवें',
  'आठवें',
  'नौवें',
  'दसवें',
  'ग्यारहवें',
  'बारहवें',
];

/// Hindi ordinals in the direct case, as in "सातवाँ भाव".
const List<String> _ordHiDirect = <String>[
  '',
  'पहला',
  'दूसरा',
  'तीसरा',
  'चौथा',
  'पाँचवाँ',
  'छठा',
  'सातवाँ',
  'आठवाँ',
  'नौवाँ',
  'दसवाँ',
  'ग्यारहवाँ',
  'बारहवाँ',
];

/// "the 7th house" / "सातवें भाव" (oblique: add में, का, से).
Bi _houseObl(int h) => Bi('the ${_ordEn[h]} house', '${_ordHiOblique[h]} भाव');

/// "the 7th house" / "सातवाँ भाव" (direct case).
Bi _houseDir(int h) => Bi('the ${_ordEn[h]} house', '${_ordHiDirect[h]} भाव');

Bi _housesObl(List<int> hs) {
  if (hs.length == 1) return _houseObl(hs.first);
  return Bi(
    'the ${_listEn(hs.map((int h) => _ordEn[h]).toList())} houses',
    '${_listHi(hs.map((int h) => _ordHiOblique[h]).toList())} भाव',
  );
}

/// "the 4th place from Mars" / "मंगल से चौथे स्थान पर".
Bi _placeFrom(int count, Graha from) => Bi(
  'the ${_ordEn[count]} place from ${grahaInfo(from).english}',
  '${grahaInfo(from).hindi} से ${_ordHiOblique[count]} स्थान पर',
);

const List<String> _monthsEn = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthsHi = <String>[
  'जनवरी',
  'फ़रवरी',
  'मार्च',
  'अप्रैल',
  'मई',
  'जून',
  'जुलाई',
  'अगस्त',
  'सितंबर',
  'अक्टूबर',
  'नवंबर',
  'दिसंबर',
];

/// A calendar date as the person would write it, in the zone they were born
/// in: "14 Aug 2031" or "14 अगस्त 2031".
Bi phalaDate(DateTime utc, Duration offset) {
  final DateTime local = utc.add(offset);
  return Bi(
    '${local.day} ${_monthsEn[local.month - 1]} ${local.year}',
    '${local.day} ${_monthsHi[local.month - 1]} ${local.year}',
  );
}

// ---------------------------------------------------------------------------
// What the houses and the grahas signify
// ---------------------------------------------------------------------------

/// The twelve departments of life, one per bhava. [LifeArea.index] + 1 is the
/// house, so a window's area is simply the house its lords point to.
enum LifeArea {
  self,
  wealth,
  effort,
  home,
  learning,
  service,
  partnership,
  change,
  fortune,
  work,
  gains,
  release;

  int get house => index + 1;

  /// The full name of the house's department, as the Houses screen shows it.
  Bi get title => _areaTitles[index];

  /// A plainer name for headlines and chips about a stretch of time. A dated
  /// window headlined with the bare name of a sensitive house would read as a
  /// forecast of an event, so these name the part of life that is in focus.
  Bi get periodTitle => _periodTitles[index];

  /// What the house is read for, in a sentence fragment.
  Bi get themes => _houseThemes[index];

  /// What a house under strain, or in full strength, asks of the person.
  Bi get asks => _houseAsks[index];
}

const List<Bi> _areaTitles = <Bi>[
  Bi('Self and direction', 'व्यक्तित्व और जीवन की दिशा'),
  Bi('Wealth, family and speech', 'धन, कुटुंब और वाणी'),
  Bi('Effort and courage', 'पराक्रम और प्रयास'),
  Bi('Home and inner peace', 'घर और मन की शांति'),
  Bi('Learning, children and creativity', 'विद्या, संतान और सृजन'),
  Bi('Service, debts and rivals', 'सेवा, ऋण और प्रतिस्पर्धा'),
  Bi('Partnership and marriage', 'साझेदारी और विवाह'),
  Bi('Change and the hidden', 'परिवर्तन और गूढ़ विषय'),
  Bi('Fortune, teachers and dharma', 'भाग्य, गुरुजन और धर्म'),
  Bi('Work and standing', 'कर्म और प्रतिष्ठा'),
  Bi('Gains and friends', 'लाभ और मित्र'),
  Bi('Expense, solitude and release', 'व्यय, एकांत और मुक्ति'),
];

const List<Bi> _periodTitles = <Bi>[
  Bi('Self and direction', 'व्यक्तित्व और जीवन की दिशा'),
  Bi('Wealth, family and speech', 'धन, कुटुंब और वाणी'),
  Bi('Effort and courage', 'पराक्रम और प्रयास'),
  Bi('Home and inner peace', 'घर और मन की शांति'),
  Bi('Learning and creative work', 'विद्या और सृजनात्मक कार्य'),
  Bi('Daily work and obligations', 'दैनिक कार्य और दायित्व'),
  Bi('Partnership and close commitments', 'साझेदारी और निकट के संबंध'),
  Bi('Change and shared resources', 'परिवर्तन और साझा संसाधन'),
  Bi('Fortune, teachers and dharma', 'भाग्य, गुरुजन और धर्म'),
  Bi('Work and standing', 'कर्म और प्रतिष्ठा'),
  Bi('Gains and friends', 'लाभ और मित्र'),
  Bi('Expense, solitude and rest', 'व्यय, एकांत और विश्राम'),
];

const List<Bi> _houseThemes = <Bi>[
  Bi(
    'temperament, self-image and the direction of the life',
    'स्वभाव, आत्म-छवि और जीवन की दिशा',
  ),
  Bi('money kept, family and speech', 'संचित धन, कुटुंब और वाणी'),
  Bi(
    'effort, courage, skills, siblings and short journeys',
    'पराक्रम, कौशल, भाई-बहन और छोटी यात्रा',
  ),
  Bi(
    'home, the mother, land and peace of mind',
    'घर, माता, भूमि और मन की शांति',
  ),
  Bi(
    'learning, children and creative work',
    'विद्या, संतान और सृजनात्मक कार्य',
  ),
  Bi(
    'daily work, service, debts and rivals',
    'दैनिक कार्य, सेवा, ऋण और प्रतिस्पर्धा',
  ),
  Bi(
    'partnership, marriage and dealings with others',
    'साझेदारी, विवाह और दूसरों से व्यवहार',
  ),
  Bi(
    'change and transformation, shared resources, research and hidden matters',
    'परिवर्तन, साझा संसाधन, शोध और गूढ़ विषय',
  ),
  Bi(
    'fortune, dharma, teachers, the father and long journeys',
    'भाग्य, धर्म, गुरुजन, पिता और लंबी यात्रा',
  ),
  Bi('work, standing and public life', 'कर्म, प्रतिष्ठा और सार्वजनिक जीवन'),
  Bi(
    'gains, income, friends and the fulfilment of hopes',
    'लाभ, आय, मित्र और इच्छाओं की पूर्ति',
  ),
  Bi(
    'expense, solitude, foreign lands and release',
    'व्यय, एकांत, विदेश और मुक्ति',
  ),
];

/// Written as a bare-infinitive list in English and an oblique-infinitive
/// list in Hindi, so both fit "it asks you to ..." and "की माँग करता है".
const List<Bi> _houseAsks = <Bi>[
  Bi(
    'look after your own energy and routines and act on your own judgement',
    'अपनी ऊर्जा और दिनचर्या का ध्यान रखने और अपने विवेक से काम लेने',
  ),
  Bi(
    'keep accounts honest, speak carefully and tend your family ties',
    'हिसाब साफ़ रखने, सोच-समझकर बोलने और परिवार के रिश्ते सँभालने',
  ),
  Bi(
    'put steady effort of your own into what you want, and keep the peace with siblings and neighbours',
    'जो चाहिए उसके लिए स्वयं निरंतर प्रयास करने और भाई-बहनों व पड़ोसियों से सौहार्द रखने',
  ),
  Bi(
    'make your home and your inner calm a priority',
    'अपने घर और मन की शांति को प्राथमिकता देने',
  ),
  Bi(
    'study patiently, practise what you create and give time to the young',
    'धैर्य से पढ़ने, अपनी रचनात्मकता का अभ्यास करने और बच्चों को समय देने',
  ),
  Bi(
    'work regularly, keep your obligations in order and deal fairly with competition',
    'नियमित काम करने, अपने दायित्व सुव्यवस्थित रखने और प्रतिस्पर्धा में निष्पक्ष रहने',
  ),
  Bi(
    'deal honestly with partners and listen more than you speak',
    'साझेदारों से ईमानदारी से पेश आने और बोलने से अधिक सुनने',
  ),
  Bi(
    'meet change calmly and keep shared money and promises transparent',
    'बदलाव को शांति से लेने और साझा धन व वचनों में पारदर्शिता रखने',
  ),
  Bi(
    'stay teachable and honour your teachers and elders',
    'सीखने की विनम्रता रखने और गुरुजनों व बड़ों का सम्मान करने',
  ),
  Bi(
    'work patiently and consistently without chasing recognition',
    'मान-सम्मान के पीछे भागे बिना धैर्य और निरंतरता से काम करने',
  ),
  Bi(
    'choose your friends and goals with care and be patient for gains',
    'मित्रों और लक्ष्यों को सोच-समझकर चुनने और लाभ के लिए धैर्य रखने',
  ),
  Bi(
    'keep expenses measured and make room for quiet and rest',
    'खर्च संतुलित रखने और शांति व विश्राम के लिए जगह बनाने',
  ),
];

/// What each graha stands for, as a sentence fragment.
const Map<Graha, Bi> _grahaThemes = <Graha, Bi>{
  Graha.sun: Bi(
    'authority, the father, self-confidence and recognition',
    'अधिकार, पिता, आत्मविश्वास और मान-सम्मान',
  ),
  Graha.moon: Bi(
    'the mind, the mother, feeling and the home',
    'मन, माता, भावना और घर',
  ),
  Graha.mars: Bi(
    'drive, courage, land and siblings',
    'ऊर्जा, साहस, भूमि और भाई-बहन',
  ),
  Graha.mercury: Bi(
    'speech, intellect, trade and paperwork',
    'वाणी, बुद्धि, व्यापार और काग़ज़ी काम',
  ),
  Graha.jupiter: Bi(
    'wisdom, teachers, children and counsel',
    'ज्ञान, गुरुजन, संतान और परामर्श',
  ),
  Graha.venus: Bi(
    'relationships, comfort, art and the means for a pleasant life',
    'संबंध, सुख-सुविधा, कला और सुखद जीवन के साधन',
  ),
  Graha.saturn: Bi(
    'work, discipline, patience and what is built slowly',
    'कर्म, अनुशासन, धैर्य और टिकाऊ निर्माण',
  ),
  Graha.rahu: Bi(
    'ambition, the foreign and the unfamiliar, and restlessness',
    'महत्वाकांक्षा, विदेश, अज्ञात का आकर्षण और बेचैनी',
  ),
  Graha.ketu: Bi(
    'detachment, research, inwardness and letting go',
    'वैराग्य, शोध, अंतर्मुखता और त्याग',
  ),
};

/// What a period of each graha asks of the person, bare infinitive in English
/// and oblique infinitive in Hindi.
const Map<Graha, Bi> _grahaAsks = <Graha, Bi>{
  Graha.sun: Bi(
    'carry responsibility without needing applause and deal honestly with authority',
    'बिना वाहवाही की चाह के ज़िम्मेदारी निभाने और अधिकारियों से ईमानदारी से पेश आने',
  ),
  Graha.moon: Bi(
    'look after your inner steadiness and your closest people, and keep regular routines',
    'मन की स्थिरता और अपनों का ध्यान रखने और दिनचर्या नियमित रखने',
  ),
  Graha.mars: Bi(
    'give your energy a clear outlet, keep your temper in check and finish what you start',
    'अपनी ऊर्जा को सही दिशा देने, क्रोध पर संयम रखने और शुरू किया काम पूरा करने',
  ),
  Graha.mercury: Bi(
    'keep your words and paperwork exact and learn something new on purpose',
    'बात और काग़ज़ात में सटीक रहने और जान-बूझकर कुछ नया सीखने',
  ),
  Graha.jupiter: Bi(
    'stay teachable and generous and not take good fortune for granted',
    'सीखने की विनम्रता और उदारता बनाए रखने और अच्छे समय को हल्के में न लेने',
  ),
  Graha.venus: Bi(
    'keep relationships honest and your spending measured',
    'संबंधों में सच्चाई और खर्च में संतुलन रखने',
  ),
  Graha.saturn: Bi(
    'be patient, work regularly and keep your commitments',
    'धैर्य रखने, नियमित काम करने और वचन निभाने',
  ),
  Graha.rahu: Bi(
    'stay grounded while ambition runs ahead and check what is real before you commit',
    'महत्वाकांक्षा के आगे दौड़ने पर भी पाँव ज़मीन पर रखने और वचन देने से पहले सच्चाई परखने',
  ),
  Graha.ketu: Bi(
    'simplify, let go of what no longer serves and go deeper rather than wider',
    'जीवन सरल करने, जो अब काम का नहीं उसे छोड़ने और विस्तार से अधिक गहराई चुनने',
  ),
};

Bi _toneWords(Tone tone) => switch (tone) {
  Tone.supportive => const Bi(
    'the period supports it',
    'समय इसमें साथ देता है',
  ),
  Tone.mixed => const Bi(
    'support and effort alternate',
    'सहारा और परिश्रम साथ-साथ चलते हैं',
  ),
  Tone.demanding => const Bi('it asks for patience', 'यहाँ धैर्य की माँग है'),
};

Bi _natureLabel(FunctionalNature n) => switch (n) {
  FunctionalNature.yogakaraka => const Bi('a yogakaraka', 'योगकारक'),
  FunctionalNature.benefic => const Bi(
    'a functional benefic',
    'शुभ फल देने वाला ग्रह',
  ),
  FunctionalNature.mixed => const Bi(
    'of mixed character',
    'मिला-जुला फल देने वाला ग्रह',
  ),
  FunctionalNature.malefic => const Bi(
    'a functional malefic',
    'अशुभ फल देने वाला ग्रह',
  ),
};

/// How the sign a graha stands in relates to it, as a noun phrase that follows
/// "which is".
Bi _dignityPhrase(Dignity d) => switch (d) {
  Dignity.exalted => const Bi('its exaltation sign', 'उसकी उच्च राशि'),
  Dignity.moolatrikona => const Bi(
    'its moolatrikona sign',
    'उसकी मूलत्रिकोण राशि',
  ),
  Dignity.own => const Bi('its own sign', 'उसकी अपनी राशि'),
  Dignity.friend => const Bi('a friend’s sign', 'मित्र ग्रह की राशि'),
  Dignity.neutral => const Bi('a neutral sign', 'सम ग्रह की राशि'),
  Dignity.enemy => const Bi('an enemy’s sign', 'शत्रु ग्रह की राशि'),
  Dignity.debilitated => const Bi('its sign of fall', 'उसकी नीच राशि'),
};

/// The same, for a sentence whose subject is the graha itself: "in its own
/// sign", "अपनी राशि में".
Bi _ownSignPhrase(Dignity d) => switch (d) {
  Dignity.exalted => const Bi('its exaltation sign', 'अपनी उच्च राशि'),
  Dignity.moolatrikona => const Bi(
    'its moolatrikona sign',
    'अपनी मूलत्रिकोण राशि',
  ),
  _ => const Bi('its own sign', 'अपनी राशि'),
};

bool _isStrongDignity(Dignity d) =>
    d == Dignity.own || d == Dignity.exalted || d == Dignity.moolatrikona;

const List<int> _kendras = <int>[1, 4, 7, 10];
const List<int> _trikonas = <int>[1, 5, 9];
const List<int> _dusthanas = <int>[6, 8, 12];

/// Houses where malefic grahas are read as doing well, because they grow with
/// effort.
const List<int> _upachayas = <int>[3, 6, 10, 11];

int _houseFromSign(int fromSign, int ofSign) =>
    ((ofSign - fromSign + 12) % 12) + 1;

// ---------------------------------------------------------------------------
// The facts a reading is built from
// ---------------------------------------------------------------------------

Bi _dignityWord(Dignity d) => switch (d) {
  Dignity.exalted => const Bi('exalted', 'उच्च'),
  Dignity.moolatrikona => const Bi('moolatrikona', 'मूलत्रिकोण'),
  Dignity.own => const Bi('own sign', 'स्वराशि'),
  Dignity.friend => const Bi('friend’s sign', 'मित्र राशि'),
  Dignity.neutral => const Bi('neutral sign', 'सम राशि'),
  Dignity.enemy => const Bi('enemy’s sign', 'शत्रु राशि'),
  Dignity.debilitated => const Bi('debilitated', 'नीच'),
};

List<int> _ruledHouses(Kundli k, Graha g) => <int>[
  for (int h = 1; h <= 12; h++)
    if (rashiInfo(Rashi.values[k.signOfHouse(h)]).lord == g) h,
];

/// Grahas that cast a full aspect on [sign], the seventh for all of them and
/// the special aspects of Mars, Jupiter and Saturn. A graha does not aspect
/// the sign it stands in; that is conjunction, read separately.
List<Graha> _aspectorsOf(
  Kundli k,
  int sign, {
  Graha? except,
  bool nodes = true,
}) => <Graha>[
  for (final Graha g in Graha.values)
    if (g != except &&
        (nodes || (g != Graha.rahu && g != Graha.ketu)) &&
        k.grahas[g]!.rashi.index != sign &&
        aspectStrength(g, k.grahas[g]!.rashi.index, sign) >= 60)
      g,
];

/// Jupiter's glance is read as protective while Jupiter is itself in fair
/// condition: not in its sign of fall and not combust.
bool _jupiterProtects(Kundli k) {
  final PlacedGraha j = k.grahas[Graha.jupiter]!;
  return j.dignity != Dignity.debilitated && !j.isCombust;
}

/// Natural benefic or malefic, taking the nodes as malefic.
bool _isBenefic(Kundli k, Graha g) => isBenefic(k, g);

FunctionalNature _natureFromRuled(Kundli k, Graha g, List<int> ruled) {
  if (ruled.isEmpty) return FunctionalNature.mixed;
  final bool naturalBenefic = _isBenefic(k, g);
  final bool kendra = ruled.any(<int>[4, 7, 10].contains);
  final bool trikona = ruled.any(<int>[5, 9].contains);
  if (kendra && trikona) return FunctionalNature.yogakaraka;
  // The lagna lord, and any trikona lord, is auspicious whatever else it owns.
  if (ruled.contains(1) || trikona) return FunctionalNature.benefic;
  final bool luminary = g == Graha.sun || g == Graha.moon;
  double s = 0;
  for (final int h in ruled) {
    switch (h) {
      case 4:
      case 7:
      case 10:
        // A malefic that owns a kendra loses its sting; a benefic that owns
        // only kendras loses some of its goodness.
        if (!naturalBenefic) s += 1;
      case 3:
      case 11:
        s -= 1;
      case 6:
        s -= 2;
      case 8:
        if (!luminary) s -= 2;
      case 12:
        if (!luminary) s -= 1;
    }
  }
  if (s >= 2) return FunctionalNature.benefic;
  if (s <= -1) return FunctionalNature.malefic;
  return FunctionalNature.mixed;
}

Bi _natureWhy(Kundli k, Graha g, List<int> ruled, FunctionalNature nature) {
  final Bi me = _graha(g);
  final Bi lagna = _sign(k.lagnaRashi);
  final Bi houses = _housesObl(ruled);
  switch (nature) {
    case FunctionalNature.yogakaraka:
      final List<int> kendra = ruled.where(<int>[4, 7, 10].contains).toList();
      final List<int> trikona = ruled.where(<int>[5, 9].contains).toList();
      return Bi(
        '${me.en} rules both a kendra (${_housesObl(kendra).en}) and a trikona (${_housesObl(trikona).en}), the pairing the tradition calls a yogakaraka. For a ${lagna.en} lagna it is the most helpful graha.',
        '${me.hi} केंद्र (${_housesObl(kendra).hi}) और त्रिकोण (${_housesObl(trikona).hi}) दोनों का स्वामी है; परंपरा इस जोड़ी को योगकारक कहती है। ${lagna.hi} लग्न के लिए यह सबसे सहायक ग्रह है।',
      );
    case FunctionalNature.benefic:
      final List<int> tempering = ruled.where(<int>[6, 8].contains).toList();
      final Bi tempers = tempering.isEmpty
          ? const Bi('', '')
          : Bi(
              ' It also rules ${_housesObl(tempering).en}, which tempers this.',
              ' यह ${_housesObl(tempering).hi} का भी स्वामी है, जिससे यह शुभता कुछ संतुलित होती है।',
            );
      if (ruled.contains(1)) {
        return Bi(
          '${me.en} is the lagna lord, which the tradition counts as helpful whatever else it rules.${tempers.en}',
          '${me.hi} लग्न का स्वामी है; परंपरा इसे, अन्य भावों के स्वामित्व के बावजूद, सहायक मानती है।${tempers.hi}',
        );
      }
      final Bi trikona = _housesObl(ruled.where(<int>[5, 9].contains).toList());
      return Bi(
        '${me.en} rules ${trikona.en}, a trikona, and the tradition counts a trikona lord as auspicious for the lagna.${tempers.en}',
        '${me.hi} ${trikona.hi} (त्रिकोण) का स्वामी है, और त्रिकोण का स्वामी लग्न के लिए शुभ माना जाता है।${tempers.hi}',
      );
    case FunctionalNature.mixed:
      if (ruled.isEmpty) {
        return Bi(
          '${me.en} rules no house of its own here, so it is read through the sign it stands in.',
          '${me.hi} का यहाँ अपना कोई भाव नहीं है, इसलिए इसका फल उस राशि के अनुसार देखा जाता है जिसमें यह बैठा है।',
        );
      }
      final List<int> kendras = ruled.where(<int>[4, 7, 10].contains).toList();
      final bool allKendras = kendras.length == ruled.length;
      final Bi kendraEn = Bi(
        allKendras
            ? 'it rules only kendras (${houses.en})'
            : 'it rules ${houses.en}, including a kendra',
        '${houses.hi} का स्वामी है${ruled.length == 1 ? ', जो केंद्र है' : (allKendras ? ', जो सभी केंद्र हैं' : ', जिनमें केंद्र भी शामिल है')}',
      );
      if (_isBenefic(k, g) && kendras.isNotEmpty) {
        return Bi(
          '${me.en} is a natural benefic, but ${kendraEn.en}, and the tradition holds that a benefic that owns a kendra loses some of its goodness (kendradhipati), so it reads as mixed.',
          '${me.hi} स्वभाव से शुभ ग्रह है, पर ${kendraEn.hi}; परंपरा मानती है कि केंद्र का स्वामी बनने पर शुभ ग्रह की शुभता कुछ घट जाती है (केंद्राधिपति), इसलिए इसका फल मिला-जुला माना जाता है।',
        );
      }
      if (kendras.isNotEmpty) {
        return Bi(
          '${me.en} is a natural malefic, but ${kendraEn.en}, which the tradition holds softens a malefic, so it reads as mixed.',
          '${me.hi} स्वभाव से क्रूर (अशुभ) ग्रह है, पर ${kendraEn.hi}; परंपरा मानती है कि केंद्र का स्वामित्व क्रूर ग्रह की कठोरता घटाता है, इसलिए इसका फल मिला-जुला माना जाता है।',
        );
      }
      return Bi(
        '${me.en}’s lordship of ${houses.en} neither helps nor presses strongly, so its results read as mixed.',
        '${houses.hi} का स्वामी होना न विशेष सहायक है, न विशेष बाधक, इसलिए ${me.hi} का फल मिला-जुला माना जाता है।',
      );
    case FunctionalNature.malefic:
      final bool luminary = g == Graha.sun || g == Graha.moon;
      final Bi hard = _housesObl(
        ruled
            .where(
              luminary
                  ? <int>[3, 6, 11].contains
                  : <int>[3, 6, 8, 11, 12].contains,
            )
            .toList(),
      );
      return Bi(
        'Most schools count the lords of the 3rd, 6th, 8th and 11th, and more mildly the 12th, as functional malefics, with the 8th and 12th excepted for the Sun and Moon. ${me.en} rules ${hard.en}, so for a ${lagna.en} lagna it reads as one. That describes what the graha asks of you, not what will happen to you.',
        'अधिकांश परंपराएँ तीसरे, छठे, आठवें और ग्यारहवें भाव के स्वामियों को, और कुछ हल्के रूप में बारहवें के स्वामी को भी, अशुभ फलदायी मानती हैं; सूर्य और चंद्र के लिए आठवाँ और बारहवाँ अपवाद हैं। ${me.hi} ${hard.hi} का स्वामी है, इसलिए ${lagna.hi} लग्न के लिए यह इसी श्रेणी में आता है। यह इस बारे में है कि यह ग्रह आपसे क्या अपेक्षा रखता है, इस बारे में नहीं कि आपके साथ क्या होगा।',
      );
  }
}

/// Neecha bhanga: a debilitated graha whose fall is cancelled because the lord
/// of the sign it fell in, or the lord of the sign where it would be exalted,
/// stands in a kendra from the lagna or from the Moon. The texts give several
/// such conditions; these two are the ones that can be checked from a chart.
Bi? _neechaBhanga(Kundli k, Graha g) {
  final PlacedGraha p = k.grahas[g]!;
  if (p.dignity != Dignity.debilitated) return null;
  final double? exaltation = grahaInfo(g).exaltationDegree;
  if (exaltation == null) return null;
  final Graha fallLord = rashiInfo(p.rashi).lord;
  final Graha exaltLord = rashiInfo(
    Rashi.values[(exaltation / 30).floor() % 12],
  ).lord;
  for (final (Graha, bool) c in <(Graha, bool)>[
    (fallLord, true),
    (exaltLord, false),
  ]) {
    final Graha cand = c.$1;
    if (cand == g) continue;
    final int sign = k.grahas[cand]!.rashi.index;
    final bool fromLagna = _kendras.contains(
      _houseFromSign(k.lagnaRashi.index, sign),
    );
    final bool fromMoon = _kendras.contains(
      _houseFromSign(k.moonRashi.index, sign),
    );
    if (!fromLagna && !fromMoon) continue;
    final Bi me = _graha(g);
    final Bi lord = _graha(cand);
    final Bi sourceEn = c.$2
        ? Bi(
            'the sign where ${me.en} falls',
            'जिस राशि में ${me.hi} नीच है, उसका स्वामी',
          )
        : Bi(
            'the sign where ${me.en} is exalted',
            'जिस राशि में ${me.hi} उच्च होता है, उसका स्वामी',
          );
    return Bi(
      'Neecha bhanga: ${lord.en}, lord of ${sourceEn.en}, stands in a kendra from the ${fromLagna ? 'lagna' : 'Moon'}, which the tradition reads as cancelling the fall.',
      'नीच भंग: ${sourceEn.hi} ${lord.hi} ${fromLagna ? 'लग्न' : 'चंद्र'} से केंद्र में है; परंपरा इसे नीचत्व का भंग मानती है।',
    );
  }
  return null;
}

/// Viparita raja yoga: the lord of the 6th, 8th or 12th standing in one of
/// those houses, which the schools that use it read as the hardship of the
/// house being turned to the person's use. The stricter schools ask for more
/// than this (a lord that owns only difficult houses, standing apart from
/// other lords), so the text says "in the schools that use it".
Bi? _viparita(Graha g, List<int> ruled, int house) {
  final List<int> hard = ruled.where(_dusthanas.contains).toList();
  if (hard.isEmpty || !_dusthanas.contains(house)) return null;
  final Bi me = _graha(g);
  return Bi(
    'Viparita raja yoga: ${me.en} rules ${_housesObl(hard).en} and stands in ${_houseObl(house).en}. In the schools that use it, a lord of a difficult house standing in a difficult house is read as the strain of that house being turned to use.',
    'विपरीत राजयोग: ${me.hi} ${_housesObl(hard).hi} का स्वामी होकर ${_houseObl(house).hi} में स्थित है। जिन परंपराओं में यह योग माना जाता है, उनमें दुःस्थान का स्वामी दुःस्थान में हो तो उस भाव की कठिनाई काम में आ जाती है।',
  );
}

/// Everything the rules know about one graha in one chart: where it is, what
/// it rules, how strong it is, and what it is worth for this lagna.
class GrahaStanding {
  const GrahaStanding({
    required this.graha,
    required this.placed,
    required this.ruled,
    required this.reader,
    required this.nature,
    required this.natureWhy,
    required this.bala,
    required this.ownBindus,
    required this.signBindus,
    required this.companions,
    required this.aspectedBy,
    required this.neechaBhanga,
    required this.viparita,
    required this.score,
    required this.tone,
    required this.relief,
    required this.basis,
  });

  final Graha graha;
  final PlacedGraha placed;

  /// Houses it rules from the lagna. Empty for Rahu and Ketu.
  final List<int> ruled;

  /// The graha whose houses speak for it: itself, or for the nodes the lord of
  /// the sign they stand in.
  final Graha reader;
  final FunctionalNature nature;
  final Bi natureWhy;

  /// Null for Rahu and Ketu, for which shadbala is not defined.
  final BalaBreakdown? bala;

  /// Bindus in its own bhinnashtakavarga for the sign it stands in. Null for
  /// the nodes.
  final int? ownBindus;

  /// Sarvashtakavarga bindus in the sign it stands in.
  final int signBindus;
  final List<Graha> companions;
  final List<Graha> aspectedBy;
  final Bi? neechaBhanga;
  final Bi? viparita;

  /// The rules' weighing of how well it can deliver. A convention of this app.
  final double score;
  final Tone tone;

  /// What eases whatever strain was found, or null when nothing is strained.
  final Bi? relief;
  final List<Bi> basis;

  /// Houses that speak for it: its own, or the reader's for the nodes.
  List<int> houses(PhalaContext ctx) =>
      ruled.isNotEmpty ? ruled : ctx.standing[reader]!.ruled;
}

/// The chart, its strengths and every graha's standing, computed once and
/// shared by all the readings.
class PhalaContext {
  PhalaContext._(
    this.kundli,
    this.bala,
    this.ashtakavarga,
    this.yogas,
    this.standing,
  );

  factory PhalaContext(Kundli kundli, {Map<Graha, BalaBreakdown>? bala}) {
    final Map<Graha, BalaBreakdown> strengths = bala ?? computeShadbala(kundli);
    final AshtakavargaResult av = computeAshtakavarga(kundli);
    final List<YogaFinding> yogas = findYogas(kundli);
    return PhalaContext._(
      kundli,
      strengths,
      av,
      yogas,
      _buildStandings(kundli, strengths, av),
    );
  }

  final Kundli kundli;
  final Map<Graha, BalaBreakdown> bala;
  final AshtakavargaResult ashtakavarga;
  final List<YogaFinding> yogas;
  final Map<Graha, GrahaStanding> standing;

  /// Each yoga of the chart with the grahas that make it, in the order the
  /// remedies are made.
  late final List<({YogaFinding yoga, Set<Graha> grahas})> yogaMembers =
      <({YogaFinding yoga, Set<Graha> grahas})>[
        for (final YogaFinding y in yogas)
          (yoga: y, grahas: _yogaGrahas(kundli, y)),
      ];

  /// The chart factors each graha's own standing gives, worked out once and
  /// shared by the graha reading and by every period that graha rules.
  late final Map<Graha, List<IndicatorFactor>> grahaFactors =
      <Graha, List<IndicatorFactor>>{
        for (final Graha g in Graha.values)
          g: _grahaFactors(this, standing[g]!),
      };

  GrahaStanding of(Graha g) => standing[g]!;
  Duration get zone => kundli.birth.utcOffset;
  Bi get lagnaName => _sign(kundli.lagnaRashi);
}

double _houseWeight(int house) {
  if (<int>[1, 4, 5, 7, 9, 10].contains(house)) return 1.5;
  if (house == 2 || house == 11) return 1.0;
  if (house == 3) return 0.5;
  return -1.5; // 6, 8, 12
}

Tone _toneOf(double score) {
  if (score >= 3.0) return Tone.supportive;
  if (score <= 0.0) return Tone.demanding;
  return Tone.mixed;
}

Map<Graha, GrahaStanding> _buildStandings(
  Kundli k,
  Map<Graha, BalaBreakdown> bala,
  AshtakavargaResult av,
) {
  final Map<Graha, List<int>> ruled = <Graha, List<int>>{
    for (final Graha g in Graha.values) g: _ruledHouses(k, g),
  };
  final Map<Graha, FunctionalNature> nature = <Graha, FunctionalNature>{
    for (final Graha g in Graha.values)
      if (g != Graha.rahu && g != Graha.ketu)
        g: _natureFromRuled(k, g, ruled[g]!),
  };
  // The nodes own no sign. The tradition reads them through the lord of the
  // sign they stand in.
  final Map<Graha, Graha> reader = <Graha, Graha>{
    for (final Graha g in Graha.values) g: g,
    for (final Graha g in <Graha>[Graha.rahu, Graha.ketu])
      g: rashiInfo(k.grahas[g]!.rashi).lord,
  };
  for (final Graha g in <Graha>[Graha.rahu, Graha.ketu]) {
    final FunctionalNature of = nature[reader[g]!]!;
    nature[g] = of;
  }

  final Bi lagna = _sign(k.lagnaRashi);
  final Map<Graha, GrahaStanding> out = <Graha, GrahaStanding>{};
  for (final Graha g in Graha.values) {
    final PlacedGraha p = k.grahas[g]!;
    final bool isNode = g == Graha.rahu || g == Graha.ketu;
    final List<int> mine = ruled[g]!;
    final Graha who = reader[g]!;
    final FunctionalNature nat = nature[g]!;
    final BalaBreakdown? strength = bala[g];
    final int? own = isNode ? null : av.charts[g]?.bindus[p.rashi.index];
    final int sav = av.sarva[p.rashi.index];
    final List<Graha> company = <Graha>[
      for (final PlacedGraha o in k.grahas.values)
        if (o.graha != g && o.rashi == p.rashi) o.graha,
    ];
    // Rahu and Ketu are each other's seventh; whether the nodes aspect at all
    // is a question of school, so a node is not read as aspected by a node.
    final List<Graha> aspects = _aspectorsOf(
      k,
      p.rashi.index,
      except: g,
      nodes: !isNode,
    );
    final bool jupiterKind = _jupiterProtects(k);
    final bool naturalMalefic = !_isBenefic(k, g);
    // Natural malefics thrive in the upachaya houses, the 6th among them, and
    // Ketu in the 12th is the tradition's placement of release.
    final bool easyPlace =
        (naturalMalefic && (p.house == 6 || p.house == 3)) ||
        (g == Graha.ketu && p.house == 12);
    final Bi? bhanga = _neechaBhanga(k, g);
    final Bi? viparita = _viparita(g, isNode ? <int>[] : mine, p.house);

    // The weighing. Directions are the tradition's; sizes are ours.
    double s = switch (nat) {
      FunctionalNature.yogakaraka => 3,
      FunctionalNature.benefic => 2,
      FunctionalNature.mixed => 0,
      FunctionalNature.malefic => -2,
    };
    s += easyPlace ? (p.house == 12 ? 0.0 : 1.0) : _houseWeight(p.house);
    if (viparita != null) s += 2;
    s += switch (p.dignity) {
      Dignity.exalted || Dignity.moolatrikona || Dignity.own => 2,
      Dignity.friend => 0.5,
      Dignity.neutral => 0,
      Dignity.enemy => -1,
      Dignity.debilitated => bhanga != null ? 0 : -2,
    };
    if (p.isCombust) s -= 1;
    if (strength != null) {
      if (strength.ratio >= 1.0) s += 1;
      if (strength.ratio < 0.8) s -= 1;
    }
    if (own != null) {
      if (own >= 5) s += 1;
      if (own <= 3) s -= 1;
    }
    if (sav >= 30) s += 0.5;
    if (sav <= 24) s -= 0.5;
    double companyScore = 0;
    for (final Graha c in company) {
      companyScore += _isBenefic(k, c) ? 0.5 : -0.5;
    }
    s += companyScore.clamp(-1.0, 1.0);
    if (g != Graha.jupiter && aspects.contains(Graha.jupiter) && jupiterKind) {
      s += 0.5;
    }

    // Whether anything is strained, and what eases it.
    final bool strained =
        p.dignity == Dignity.debilitated ||
        p.dignity == Dignity.enemy ||
        p.isCombust ||
        (_dusthanas.contains(p.house) && !easyPlace) ||
        (strength != null && !strength.isStrong) ||
        (own != null && own <= 3) ||
        (nat == FunctionalNature.malefic);
    final List<Bi> eases = <Bi>[];
    if (bhanga != null) eases.add(bhanga);
    if (viparita != null) eases.add(viparita);
    if (_isStrongDignity(p.dignity) &&
        (_dusthanas.contains(p.house) || p.isCombust)) {
      final Bi me = _graha(g);
      eases.add(
        Bi(
          '${me.en} stands in ${_ownSignPhrase(p.dignity).en}, and the tradition holds that an own or exalted sign protects a graha even in a hard place.',
          '${me.hi} ${_ownSignPhrase(p.dignity).hi} में है, और परंपरा मानती है कि स्वराशि या उच्च राशि कठिन स्थान में भी ग्रह की रक्षा करती है।',
        ),
      );
    }
    if (g != Graha.jupiter && aspects.contains(Graha.jupiter) && jupiterKind) {
      eases.add(
        const Bi(
          'Jupiter aspects it, and Jupiter’s glance is read as protective.',
          'गुरु की दृष्टि इस पर है, और गुरु की दृष्टि को रक्षक माना जाता है।',
        ),
      );
    }
    if (strength != null && strength.isStrong && strained) {
      eases.add(
        Bi(
          'Its shadbala of ${strength.totalRupas.toStringAsFixed(1)} rupas clears the ${strength.requiredRupas} it needs, so it can still deliver.',
          'इसका षड्बल ${strength.totalRupas.toStringAsFixed(1)} रूप है, जो आवश्यक ${strength.requiredRupas} से अधिक है, इसलिए यह फल दे सकता है।',
        ),
      );
    }
    if (own != null && own >= 5 && strained) {
      eases.add(
        Bi(
          'It holds $own bindus in its own ashtakavarga for this sign, and five or more is read as full delivery.',
          'भिन्नाष्टकवर्ग में इस राशि के लिए इसके $own बिंदु हैं, और पाँच या अधिक बिंदु पूर्ण फल का संकेत माने जाते हैं।',
        ),
      );
    }
    if (strained && company.any((Graha c) => _isBenefic(k, c))) {
      eases.add(
        Bi(
          'The company of ${_grahas(company.where((Graha c) => _isBenefic(k, c)).toList()).en} is read as relief.',
          '${_grahas(company.where((Graha c) => _isBenefic(k, c)).toList()).hi} का साथ राहत देने वाला माना जाता है।',
        ),
      );
    }
    Bi? relief;
    if (strained) {
      relief = eases.isNotEmpty
          ? Bi(
              eases.map((Bi e) => e.en).join(' '),
              eases.map((Bi e) => e.hi).join(' '),
            )
          : const Bi(
              'The usual reliefs are Jupiter’s aspect, an own or exalted sign, a good ashtakavarga count and a viparita placement. None of them is present in this chart, so read this as a place for steady effort, not as a verdict.',
              'राहत के सामान्य आधार हैं गुरु की दृष्टि, स्वराशि या उच्च राशि, अच्छा अष्टकवर्ग और विपरीत राजयोग। इस कुंडली में इनमें से कोई भी मौजूद नहीं है, इसलिए इसे निरंतर प्रयास का स्थान समझें, कोई अंतिम फ़ैसला नहीं।',
            );
    }

    final Bi me = _graha(g);
    final List<Bi> basis = <Bi>[
      Bi(
        '${me.en}: ${_sign(p.rashi).en}, ${_ordEn[p.house]} house${isNode && p.dignity != Dignity.exalted && p.dignity != Dignity.debilitated ? '' : ', ${_dignityWord(p.dignity).en}'}',
        '${me.hi}: ${_sign(p.rashi).hi} राशि, ${_ordHiDirect[p.house]} भाव${isNode && p.dignity != Dignity.exalted && p.dignity != Dignity.debilitated ? '' : ', ${_dignityWord(p.dignity).hi}'}',
      ),
      if (!isNode)
        Bi(
          'Rules the ${_listEn(mine.map((int h) => _ordEn[h]).toList())} house${mine.length > 1 ? 's' : ''} from the ${lagna.en} lagna',
          '${lagna.hi} लग्न से ${_listHi(mine.map((int h) => _ordHiOblique[h]).toList())} भाव का स्वामी',
        )
      else
        Bi(
          'Owns no sign: read through ${_graha(who).en}, lord of the sign it stands in',
          'अपनी कोई राशि नहीं: जिस राशि में बैठा है उसके स्वामी ${_graha(who).hi} के अनुसार देखा जाता है',
        ),
      Bi(
        'For a ${lagna.en} lagna: ${_natureLabel(nat).en}',
        '${lagna.hi} लग्न के लिए: ${_natureLabel(nat).hi}',
      ),
      if (strength != null)
        Bi(
          'Shadbala ${strength.totalRupas.toStringAsFixed(1)} rupas, needs ${strength.requiredRupas}',
          'षड्बल ${strength.totalRupas.toStringAsFixed(1)} रूप, आवश्यक ${strength.requiredRupas}',
        ),
      if (own != null)
        Bi(
          'Ashtakavarga: $own bindus in its own chart, $sav in the sign',
          'भिन्नाष्टकवर्ग: $own बिंदु; सर्वाष्टकवर्ग: राशि में कुल $sav बिंदु',
        )
      else
        Bi(
          'Sarvashtakavarga: $sav bindus in the sign',
          'सर्वाष्टकवर्ग: राशि में $sav बिंदु',
        ),
      if (p.isCombust)
        const Bi('Combust, too near the Sun', 'सूर्य के अत्यंत निकट, अस्त'),
      if (p.isRetrograde) const Bi('Retrograde', 'वक्री'),
      if (company.isNotEmpty)
        Bi(
          'Conjunct ${_grahas(company).en}',
          '${_grahas(company).hi} के साथ युति',
        ),
      if (aspects.isNotEmpty)
        Bi(
          'Aspected by ${_grahas(aspects).en}',
          '${_grahas(aspects).hi} की दृष्टि',
        ),
    ];

    out[g] = GrahaStanding(
      graha: g,
      placed: p,
      ruled: mine,
      reader: who,
      nature: nat,
      natureWhy: isNode
          ? Bi(
              'For a ${lagna.en} lagna ${_graha(who).en} is ${_natureLabel(nat).en}, and ${me.en} gives its results in that spirit.',
              '${lagna.hi} लग्न के लिए ${_graha(who).hi} ${_natureLabel(nat).hi} है, और ${me.hi} उसी के अनुरूप फल देता है।',
            )
          : _natureWhy(k, g, mine, nat),
      bala: strength,
      ownBindus: own,
      signBindus: sav,
      companions: company,
      aspectedBy: aspects,
      neechaBhanga: bhanga,
      viparita: viparita,
      score: s,
      tone: _toneOf(s),
      relief: relief,
      basis: basis,
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// The chart factors behind a band
// ---------------------------------------------------------------------------

Bi _placeLabel(int house) => switch (house) {
  1 => const Bi('a kendra and a trikona', 'केंद्र और त्रिकोण'),
  4 || 7 || 10 => const Bi('a kendra', 'केंद्र'),
  5 || 9 => const Bi('a trikona', 'त्रिकोण'),
  2 || 11 => const Bi('a house of means', 'साधनों का भाव'),
  3 => const Bi('a house of effort', 'प्रयास का भाव'),
  _ => const Bi('a difficult place', 'कठिन स्थान'),
};

/// "Saturn is in its own sign, Capricorn".
Bi _dignityFactor(Graha g, PlacedGraha p) {
  final Bi me = _graha(g);
  final Bi sign = _sign(p.rashi);
  final (String, String) how = switch (p.dignity) {
    Dignity.exalted => ('its exaltation sign', 'उच्च राशि'),
    Dignity.moolatrikona => ('its moolatrikona sign', 'मूलत्रिकोण राशि'),
    Dignity.own => ('its own sign', 'अपनी राशि'),
    Dignity.friend => ('a friend’s sign', 'मित्र की राशि'),
    Dignity.neutral => ('a neutral sign', 'सम राशि'),
    Dignity.enemy => ('an enemy’s sign', 'शत्रु की राशि'),
    Dignity.debilitated => ('its sign of fall', 'नीच राशि'),
  };
  return Bi(
    '${me.en} is in ${how.$1}, ${sign.en}',
    '${me.hi} ${how.$2} (${sign.hi}) में है',
  );
}

/// The shadbala reading as a factor, or null when it takes no side (it is not
/// worked out for the nodes). [possessiveEn] reads "Saturn’s" or "The lord’s".
IndicatorFactor? _shadbalaFactor(
  BalaBreakdown? b,
  String possessiveEn,
  String nameHi,
  List<Graha> who, {
  required bool allowFirm,
}) {
  if (b == null) return null;
  final String rupas = b.totalRupas.toStringAsFixed(1);
  if (b.ratio >= 1.0) {
    return IndicatorFactor(
      kind: FactorKind.shadbala,
      eases: true,
      firm: allowFirm,
      grahas: who,
      text: Bi(
        '$possessiveEn shadbala is $rupas rupas, above the ${b.requiredRupas} it needs',
        '$nameHi का षड्बल $rupas रूप है, जो ज़रूरी ${b.requiredRupas} से ऊपर है',
      ),
    );
  }
  return IndicatorFactor(
    kind: FactorKind.shadbala,
    eases: false,
    firm: allowFirm && b.ratio < 0.8,
    grahas: who,
    text: Bi(
      '$possessiveEn shadbala is $rupas rupas, under the ${b.requiredRupas} it needs',
      '$nameHi का षड्बल $rupas रूप है, जो ज़रूरी ${b.requiredRupas} से कम है',
    ),
  );
}

/// Turns counts of kind and hard influences into a vote: null when they
/// cancel, otherwise which way and how firmly.
({bool eases, bool firm})? _netVote(int ease, int hard) {
  final int net = ease - hard;
  if (net == 0) return null;
  return (eases: net > 0, firm: net.abs() >= 2);
}

/// A yoga by its name and the grahas that make it, so that the same fact
/// found through two routes is counted once.
String _yogaSignature(({YogaFinding yoga, Set<Graha> grahas}) m) =>
    '${m.yoga.nameEnglish}:${(m.grahas.map((Graha g) => g.index).toList()..sort()).join(',')}';

/// The factors a graha's own standing gives, shared by the graha reading and
/// by the periods it rules. A fact that takes no side is not a factor, and a
/// graha that is merely not afflicted is not counted as supported.
List<IndicatorFactor> _grahaFactors(PhalaContext ctx, GrahaStanding st) {
  final Kundli k = ctx.kundli;
  final Graha g = st.graha;
  final PlacedGraha p = st.placed;
  final bool isNode = g == Graha.rahu || g == Graha.ketu;
  final Bi me = _graha(g);
  final Bi lagna = ctx.lagnaName;
  final List<Graha> who = <Graha>[g];
  final List<IndicatorFactor> out = <IndicatorFactor>[];
  void add(FactorKind kind, bool eases, bool firm, Bi text) => out.add(
    IndicatorFactor(
      kind: kind,
      text: text,
      eases: eases,
      firm: firm,
      grahas: who,
    ),
  );

  // Dignity. The friendships of the nodes are disputed between schools, so
  // for them only exaltation and fall count.
  switch (p.dignity) {
    case Dignity.exalted:
    case Dignity.moolatrikona:
    case Dignity.own:
      add(FactorKind.dignity, true, true, _dignityFactor(g, p));
    case Dignity.friend:
      if (!isNode) add(FactorKind.dignity, true, false, _dignityFactor(g, p));
    case Dignity.neutral:
      break;
    case Dignity.enemy:
      if (!isNode) add(FactorKind.dignity, false, false, _dignityFactor(g, p));
    case Dignity.debilitated:
      add(FactorKind.dignity, false, true, _dignityFactor(g, p));
      if (st.neechaBhanga != null) {
        add(
          FactorKind.relief,
          true,
          true,
          Bi(
            'Neecha bhanga: the fall of ${me.en} is cancelled',
            'नीच भंग: ${me.hi} का नीचत्व भंग हुआ है',
          ),
        );
      }
  }

  // What the graha is worth for this lagna.
  final Bi natureLabel = _natureLabel(st.nature);
  final Bi natureText = isNode
      ? Bi(
          '${me.en} gives its results through ${_graha(st.reader).en}, which is ${natureLabel.en} for the ${lagna.en} lagna',
          '${me.hi} का फल ${_graha(st.reader).hi} के अनुसार मिलता है, जो ${lagna.hi} लग्न के लिए ${natureLabel.hi} है',
        )
      : Bi(
          'For the ${lagna.en} lagna ${me.en} is ${natureLabel.en}',
          '${lagna.hi} लग्न के लिए ${me.hi} ${natureLabel.hi} है',
        );
  switch (st.nature) {
    case FunctionalNature.yogakaraka:
    case FunctionalNature.benefic:
      add(FactorKind.nature, true, !isNode, natureText);
    case FunctionalNature.malefic:
      add(FactorKind.nature, false, !isNode, natureText);
    case FunctionalNature.mixed:
      break;
  }

  // The house it stands in.
  final int h = p.house;
  final bool naturalMalefic = !_isBenefic(k, g);
  final bool easyPlace =
      (naturalMalefic && (h == 6 || h == 3)) || (g == Graha.ketu && h == 12);
  final Bi stands = Bi(
    '${me.en} stands in ${_houseObl(h).en}, ${_placeLabel(h).en}',
    '${me.hi} ${_houseObl(h).hi} में है, जो ${_placeLabel(h).hi} है',
  );
  if (easyPlace) {
    if (h != 12) {
      add(
        FactorKind.placement,
        true,
        false,
        Bi(
          '${me.en}, a natural malefic, stands in ${_houseObl(h).en}, a house that grows with effort and where malefics do well',
          '${me.hi}, स्वभाव से क्रूर ग्रह, ${_houseObl(h).hi} में है, जो परिश्रम से बढ़ने वाला भाव है और जहाँ क्रूर ग्रह अच्छा फल देते हैं',
        ),
      );
    }
  } else if (_kendras.contains(h) || _trikonas.contains(h)) {
    add(FactorKind.placement, true, true, stands);
  } else if (h == 2 || h == 11) {
    add(FactorKind.placement, true, false, stands);
  } else if (_dusthanas.contains(h)) {
    add(FactorKind.placement, false, true, stands);
  }
  if (st.viparita != null) {
    add(
      FactorKind.relief,
      true,
      true,
      Bi(
        'Viparita raja yoga: ${me.en}, lord of a difficult house, stands in a difficult house',
        'विपरीत राजयोग: कठिन भाव का स्वामी ${me.hi} कठिन भाव में है',
      ),
    );
  }

  // Strength, by shadbala and by ashtakavarga.
  final IndicatorFactor? bala = _shadbalaFactor(
    st.bala,
    '${me.en}’s',
    me.hi,
    who,
    allowFirm: true,
  );
  if (bala != null) out.add(bala);
  final int? own = st.ownBindus;
  final int sav = st.signBindus;
  if (own != null && own >= 5) {
    add(
      FactorKind.ashtakavarga,
      true,
      true,
      Bi(
        '${me.en} holds $own bindus in its own ashtakavarga for this sign (five or more is a full count)',
        'इस राशि में ${me.hi} के अपने अष्टकवर्ग के $own बिंदु हैं (पाँच या अधिक पूरी गिनती है)',
      ),
    );
  } else if (own != null && own <= 3) {
    add(
      FactorKind.ashtakavarga,
      false,
      true,
      Bi(
        '${me.en} holds only $own bindus in its own ashtakavarga for this sign (three or fewer is thin)',
        'इस राशि में ${me.hi} के अपने अष्टकवर्ग के सिर्फ़ $own बिंदु हैं (तीन या उससे कम हल्की गिनती है)',
      ),
    );
  } else if (sav >= 30) {
    add(
      FactorKind.ashtakavarga,
      true,
      false,
      Bi(
        'The sign ${me.en} stands in holds $sav sarvashtakavarga bindus, a strong count',
        'जिस राशि में ${me.hi} है उसमें सर्वाष्टकवर्ग के $sav बिंदु हैं, जो अच्छी गिनती है',
      ),
    );
  } else if (sav <= 24) {
    add(
      FactorKind.ashtakavarga,
      false,
      false,
      Bi(
        'The sign ${me.en} stands in holds only $sav sarvashtakavarga bindus, a light count',
        'जिस राशि में ${me.hi} है उसमें सर्वाष्टकवर्ग के सिर्फ़ $sav बिंदु हैं, जो कम गिनती है',
      ),
    );
  }

  if (p.isCombust) {
    add(
      FactorKind.condition,
      false,
      true,
      Bi(
        '${me.en} is combust, too near the Sun',
        '${me.hi} सूर्य के बहुत पास होने से अस्त है',
      ),
    );
  }

  // Company and aspects, each netted into one factor.
  final List<Graha> kindCompany = st.companions
      .where((Graha c) => _isBenefic(k, c))
      .toList();
  final List<Graha> hardCompany = st.companions
      .where((Graha c) => !_isBenefic(k, c))
      .toList();
  final ({bool eases, bool firm})? company = _netVote(
    kindCompany.length,
    hardCompany.length,
  );
  if (company != null) {
    final List<Graha> side = company.eases ? kindCompany : hardCompany;
    add(
      FactorKind.company,
      company.eases,
      company.firm,
      company.eases
          ? Bi(
              '${me.en} keeps the company of ${_grahas(side).en}, which supports it',
              '${me.hi} के साथ ${_grahas(side).hi} हैं, जो इसे सहारा देते हैं',
            )
          : Bi(
              '${me.en} keeps the company of ${_grahas(side).en}, which presses on it',
              '${me.hi} के साथ ${_grahas(side).hi} हैं, जो इस पर दबाव डालते हैं',
            ),
    );
  }
  final bool jupiterGlance =
      g != Graha.jupiter &&
      st.aspectedBy.contains(Graha.jupiter) &&
      _jupiterProtects(k);
  final List<Graha> kindAspects = st.aspectedBy
      .where((Graha a) => a != Graha.jupiter && _isBenefic(k, a))
      .toList();
  final List<Graha> hardAspects = st.aspectedBy
      .where((Graha a) => !_isBenefic(k, a))
      .toList();
  final ({bool eases, bool firm})? glance = _netVote(
    (jupiterGlance ? 2 : 0) + kindAspects.length,
    hardAspects.length,
  );
  if (glance != null) {
    final List<Graha> side = glance.eases
        ? <Graha>[if (jupiterGlance) Graha.jupiter, ...kindAspects]
        : hardAspects;
    add(
      FactorKind.aspects,
      glance.eases,
      glance.firm,
      glance.eases
          ? Bi(
              '${me.en} is looked at by ${_grahas(side).en}, a kind glance',
              '${me.hi} पर ${_grahas(side).hi} की शुभ दृष्टि है',
            )
          : Bi(
              '${me.en} is looked at by ${_grahas(side).en}, a hard glance',
              '${me.hi} पर ${_grahas(side).hi} की कठोर दृष्टि है',
            ),
    );
  }

  // The yogas it takes part in. A dosha that the chart itself cancels takes
  // no side. Two findings of one name made by the same grahas (a raja yoga
  // reached through two pairs of houses) are one fact of the chart.
  final Set<String> seenYogas = <String>{};
  for (final ({YogaFinding yoga, Set<Graha> grahas}) m in ctx.yogaMembers) {
    if (!m.grahas.contains(g)) continue;
    final YogaFinding y = m.yoga;
    if (!seenYogas.add(_yogaSignature(m))) continue;
    if (!y.isDosha) {
      final bool major =
          y.key.startsWith('mahapurusha_') ||
          y.key.startsWith('raja_yoga_') ||
          y.key == 'gaja_kesari';
      add(
        FactorKind.yoga,
        true,
        major,
        Bi(
          '${me.en} takes part in ${y.nameEnglish}',
          '${me.hi} ${y.nameHindi} में शामिल है',
        ),
      );
    } else if (!y.isCancelled) {
      add(
        FactorKind.yoga,
        false,
        false,
        Bi(
          '${me.en} takes part in ${y.nameEnglish}, which the tradition reads as asking for effort',
          '${me.hi} ${y.nameHindi} में शामिल है, जिसे परंपरा मेहनत माँगने वाला मानती है',
        ),
      );
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// What tends to come up
// ---------------------------------------------------------------------------

/// What tends to come up when a house is the one in focus. Tendencies and the
/// questions a time puts to the person, never an event.
const List<Bi> _houseTends = <Bi>[
  Bi(
    'Questions of who you are and which way you are heading tend to come up: how you carry yourself, where you put your energy, and whether the path you are on feels like your own.',
    'आप कौन हैं और किस ओर जा रहे हैं, इस तरह के सवाल अक्सर सामने आते हैं: आप खुद को कैसे पेश करते हैं, अपनी ऊर्जा कहाँ लगाते हैं, और जिस राह पर हैं वह अपनी लगती है या नहीं।',
  ),
  Bi(
    'Questions of money kept and spent, of family and of how you speak tend to come up: the household accounts, what the family expects, and the weight your words carry at home.',
    'पैसे की बचत और खर्च, परिवार और आपकी बोली से जुड़े सवाल अक्सर सामने आते हैं: घर का हिसाब, परिवार की उम्मीदें, और घर में आपकी बात का वज़न।',
  ),
  Bi(
    'Questions of effort and initiative tend to come up: starting things yourself, building a skill, and dealings with brothers, sisters, neighbours and short trips.',
    'मेहनत और पहल से जुड़े सवाल अक्सर सामने आते हैं: कोई काम खुद शुरू करना, कोई हुनर निखारना, और भाई-बहनों, पड़ोसियों और छोटी यात्राओं की बातें।',
  ),
  Bi(
    'Questions of home and peace of mind tend to come up: where you live, how settled you feel, and your mother or the elders of the house.',
    'घर और मन की शांति से जुड़े सवाल अक्सर सामने आते हैं: आप कहाँ रहते हैं, कितना ठहराव महसूस करते हैं, और माँ या घर के बड़े।',
  ),
  Bi(
    'Questions of learning, creative work and children tend to come up: what you are studying or making, and whom you are teaching or guiding.',
    'पढ़ाई, रचनात्मक काम और बच्चों से जुड़े सवाल अक्सर सामने आते हैं: आप क्या सीख या बना रहे हैं, और किसे सिखा या राह दिखा रहे हैं।',
  ),
  Bi(
    'Questions of daily work, obligations and competition tend to come up: routines, the load of work, helping others, and keeping your dues in order.',
    'रोज़ के काम, ज़िम्मेदारियों और होड़ से जुड़े सवाल अक्सर सामने आते हैं: दिनचर्या, काम का बोझ, दूसरों की मदद, और अपने लेन-देन का हिसाब।',
  ),
  Bi(
    'Questions of partnership and close commitments tend to come up: how you and the people closest to you deal with each other, and the agreements between you.',
    'साझेदारी और क़रीबी रिश्तों से जुड़े सवाल अक्सर सामने आते हैं: आप और आपके सबसे क़रीबी लोग एक-दूसरे से कैसे पेश आते हैं, और आपके बीच के वादे और समझौते।',
  ),
  Bi(
    'Questions of change, shared resources and what is kept out of sight tend to come up: money held jointly, matters that need looking into, and things that are ready to be let go.',
    'बदलाव, साझे संसाधनों और छिपी बातों से जुड़े सवाल अक्सर सामने आते हैं: साझा पैसा, जिन बातों की तह तक जाना है, और जो छोड़ने का वक़्त आ गया है।',
  ),
  Bi(
    'Questions of purpose, guidance and long journeys tend to come up: what you believe in, the teachers and elders you turn to, and the father or father figures in your life.',
    'जीवन के मक़सद, मार्गदर्शन और लंबी यात्राओं से जुड़े सवाल अक्सर सामने आते हैं: आप किस पर भरोसा करते हैं, किन गुरुओं और बड़ों की सुनते हैं, और पिता या पिता जैसे लोग।',
  ),
  Bi(
    'Questions of work, responsibility and standing tend to come up: the role you hold, how others see your work, and what you are building over the years.',
    'काम, ज़िम्मेदारी और साख से जुड़े सवाल अक्सर सामने आते हैं: आप किस भूमिका में हैं, लोग आपके काम को कैसे देखते हैं, और आप बरसों में क्या खड़ा कर रहे हैं।',
  ),
  Bi(
    'Questions of income, friends and hopes tend to come up: who is in your circle, what you are working towards, and how steadily the fruit of your effort comes in.',
    'आमदनी, दोस्तों और उम्मीदों से जुड़े सवाल अक्सर सामने आते हैं: आपके दायरे में कौन है, आप किस ओर बढ़ रहे हैं, और मेहनत का फल कितनी स्थिरता से आता है।',
  ),
  Bi(
    'Questions of expense, rest and time alone tend to come up: where your money and energy go, the need for quiet, and places far from home.',
    'ख़र्च, आराम और अकेले बिताए समय से जुड़े सवाल अक्सर सामने आते हैं: आपका पैसा और ऊर्जा कहाँ जाती है, शांति की ज़रूरत, और घर से दूर की जगहें।',
  ),
];

/// How a slow transit tends to colour the area of life it passes through.
const Map<Graha, Bi> _transitTends = <Graha, Bi>{
  Graha.saturn: Bi(
    'A Saturn transit tends to put the area it touches under slow, steady pressure to organise things and take responsibility.',
    'शनि का गोचर जिस क्षेत्र को छूता है, वहाँ धीरे-धीरे व्यवस्था बनाने और ज़िम्मेदारी उठाने का दबाव अक्सर बना रहता है।',
  ),
  Graha.jupiter: Bi(
    'A Jupiter transit tends to widen the area it touches: more room to learn and grow, and more help from teachers and elders, where effort is put in.',
    'गुरु का गोचर जिस क्षेत्र को छूता है, उसे अक्सर फैलाता है: सीखने और बढ़ने की ज़्यादा जगह, और गुरुजनों व बड़ों की ज़्यादा मदद, बशर्ते मेहनत की जाए।',
  ),
  Graha.rahu: Bi(
    'A Rahu transit tends to make the area it touches feel urgent and unfamiliar: a bigger appetite, a pull toward the new, and a need to check what is real before committing.',
    'राहु का गोचर जिस क्षेत्र को छूता है, उसे अक्सर जल्दबाज़ी और अनजानेपन से भर देता है: ज़्यादा की भूख, नए की ओर खिंचाव, और वादा करने से पहले सच्चाई जाँचने की ज़रूरत।',
  ),
  Graha.ketu: Bi(
    'A Ketu transit tends to loosen the hold of the area it touches: a pull to simplify, to go deeper rather than wider, and to let go of what has run its course.',
    'केतु का गोचर जिस क्षेत्र को छूता है, उसकी पकड़ अक्सर ढीली करता है: सरल करने का मन, फैलाव से ज़्यादा गहराई चुनने का मन, और जो बात पूरी हो चुकी उसे छोड़ने का मन।',
  ),
};

/// How the tone of a reading colours the tendency.
Bi _toneTends(Tone tone) => switch (tone) {
  Tone.supportive => const Bi(
    'With the chart backing it, such matters tend to move with less friction.',
    'कुंडली का साथ होने से ऐसी बातें अक्सर कम रुकावट के साथ आगे बढ़ती हैं।',
  ),
  Tone.mixed => const Bi(
    'Such matters tend to bring some ease and some effort together.',
    'ऐसी बातों में अक्सर थोड़ी आसानी और थोड़ी मेहनत साथ-साथ चलती है।',
  ),
  Tone.demanding => const Bi(
    'Such matters tend to need more deliberate handling, taken one step at a time.',
    'ऐसी बातों को अक्सर ज़्यादा सोच-समझकर, एक-एक क़दम करके सँभालना पड़ता है।',
  ),
};

/// The sign a graha is in, as one of its own, its exaltation or its fall; null
/// when it is none of these (and always null for the nodes, whose own signs
/// the schools do not agree on).
Dignity? _signDignity(Graha g, Rashi sign) {
  if (g == Graha.rahu || g == Graha.ketu) return null;
  final GrahaInfo info = grahaInfo(g);
  if (info.ownSigns.contains(sign.index)) return Dignity.own;
  final double? exalt = info.exaltationDegree;
  if (exalt == null) return null;
  final int exaltSign = (exalt / 30).floor() % 12;
  if (sign.index == exaltSign) return Dignity.exalted;
  if (sign.index == (exaltSign + 6) % 12) return Dignity.debilitated;
  return null;
}

// ---------------------------------------------------------------------------
// Sentences shared by the house, graha and period readings
// ---------------------------------------------------------------------------

Bi _houseToneWords(Tone tone) => switch (tone) {
  Tone.supportive => const Bi('well supported', 'मज़बूत सहारा'),
  Tone.mixed => const Bi('mixed support', 'मिला-जुला सहारा'),
  Tone.demanding => const Bi('asks for effort', 'परिश्रम की माँग'),
};

/// "From your Aries lagna, Mars rules the 1st and 8th houses (...)."
Bi _lordshipSentence(PhalaContext ctx, GrahaStanding st) {
  final Bi me = _graha(st.graha);
  final Bi lagna = ctx.lagnaName;
  if (st.ruled.isEmpty) {
    final GrahaStanding reader = ctx.of(st.reader);
    final Bi who = _graha(st.reader);
    final Bi houses = _housesObl(reader.ruled);
    return Bi(
      '${me.en} owns no sign, so the tradition reads it through ${who.en}, the lord of the sign it stands in, and ${who.en} rules ${houses.en} from your ${lagna.en} lagna.',
      '${me.hi} की अपनी कोई राशि नहीं है, इसलिए परंपरा इसे उस राशि के स्वामी ${who.hi} के अनुसार देखती है जिसमें यह बैठा है; आपके ${lagna.hi} लग्न से ${who.hi} ${houses.hi} का स्वामी है।',
    );
  }
  final Bi houses = _housesObl(st.ruled);
  final Bi areas = Bi(
    st.ruled.map((int h) => LifeArea.values[h - 1].periodTitle.en).join('; '),
    st.ruled.map((int h) => LifeArea.values[h - 1].periodTitle.hi).join('; '),
  );
  return Bi(
    'From your ${lagna.en} lagna, ${me.en} rules ${houses.en} (${areas.en}).',
    'आपके ${lagna.hi} लग्न से ${me.hi} ${houses.hi} का स्वामी है (${areas.hi})।',
  );
}

/// Where a graha stands, in what sign and dignity.
Bi _placementSentence(GrahaStanding st) {
  final PlacedGraha p = st.placed;
  final Bi me = _graha(st.graha);
  final LifeArea area = LifeArea.values[p.house - 1];
  final bool isNode = st.graha == Graha.rahu || st.graha == Graha.ketu;
  final bool showDignity =
      !isNode ||
      p.dignity == Dignity.exalted ||
      p.dignity == Dignity.debilitated;
  final Bi sign = _sign(p.rashi);
  final Bi dignity = _dignityPhrase(p.dignity);
  return Bi(
    '${me.en} stands in ${_houseObl(p.house).en} (${area.periodTitle.en}), in ${sign.en}${showDignity ? ', ${dignity.en}' : ''}.',
    '${me.hi} ${_houseObl(p.house).hi} (${area.periodTitle.hi}) में, ${sign.hi} राशि में स्थित है${showDignity ? ', जो ${dignity.hi} है' : ''}।',
  );
}

/// What the dignity does to the graha's ability to deliver.
Bi? _dignityEffect(GrahaStanding st) {
  final Bi me = _graha(st.graha);
  switch (st.placed.dignity) {
    case Dignity.exalted:
      return Bi(
        'In its exaltation sign ${me.en} can deliver what it signifies at full strength.',
        'उच्च राशि में ${me.hi} अपने विषयों का फल पूरे बल से दे सकता है।',
      );
    case Dignity.moolatrikona:
    case Dignity.own:
      return Bi(
        'In a sign of its own ${me.en} is at home and protects what it rules.',
        'अपनी राशि में ${me.hi} सहज रहता है और जिन भावों का स्वामी है, उनकी रक्षा करता है।',
      );
    case Dignity.friend:
      return const Bi(
        'A friendly sign supports it.',
        'मित्र राशि इसे सहारा देती है।',
      );
    case Dignity.neutral:
      return st.graha == Graha.rahu || st.graha == Graha.ketu
          ? null
          : const Bi(
              'A neutral sign neither helps nor hinders it.',
              'सम राशि न सहायक है न बाधक।',
            );
    case Dignity.enemy:
      return const Bi(
        'An enemy’s sign makes it work harder for the same result.',
        'शत्रु की राशि में इसे उसी फल के लिए अधिक परिश्रम करना पड़ता है।',
      );
    case Dignity.debilitated:
      return Bi(
        'In its sign of fall its results need more effort and time.${st.neechaBhanga != null ? ' ${st.neechaBhanga!.en}' : ''}',
        'नीच राशि में इसके फल के लिए अधिक प्रयास और समय लगता है।${st.neechaBhanga != null ? ' ${st.neechaBhanga!.hi}' : ''}',
      );
  }
}

Bi? _conditionSentence(GrahaStanding st) {
  final Bi me = _graha(st.graha);
  final List<Bi> parts = <Bi>[
    if (st.placed.isCombust)
      Bi(
        'It is combust, too close to the Sun, so its matters come through dimmed and need conscious effort.',
        '${me.hi} सूर्य के अत्यंत निकट होने से अस्त है, इसलिए इसके विषय धुँधले पड़ते हैं और सचेत प्रयास माँगते हैं।',
      ),
    if (st.placed.isRetrograde)
      Bi(
        'It is retrograde. Retrograde grahas are counted strong in motion-strength (chesta bala), and many astrologers also read their matters as worked out inwardly before they show outside.',
        '${me.hi} वक्री है। वक्री ग्रह को चेष्टा-बल में बलवान गिना जाता है, और अनेक ज्योतिषी मानते हैं कि उसके विषय पहले भीतर सुलझते हैं और फिर बाहर दिखते हैं।',
      ),
  ];
  return parts.isEmpty ? null : _cat(parts);
}

Bi? _companySentence(PhalaContext ctx, GrahaStanding st) {
  final Kundli k = ctx.kundli;
  final List<Graha> kind = st.companions
      .where((Graha c) => _isBenefic(k, c))
      .toList();
  final List<Graha> hard = st.companions
      .where((Graha c) => !_isBenefic(k, c))
      .toList();
  final List<Bi> parts = <Bi>[];
  if (kind.isNotEmpty) {
    parts.add(
      Bi(
        'The company of ${_grahas(kind).en} supports it.',
        '${_grahas(kind).hi} का साथ इसे सहारा देता है।',
      ),
    );
  }
  if (hard.isNotEmpty) {
    parts.add(
      Bi(
        'The company of ${_grahas(hard).en} puts pressure on it.',
        '${_grahas(hard).hi} का साथ इस पर दबाव डालता है।',
      ),
    );
  }
  if (st.graha != Graha.jupiter &&
      st.aspectedBy.contains(Graha.jupiter) &&
      _jupiterProtects(k)) {
    parts.add(
      const Bi(
        'Jupiter’s aspect falls on it and is read as protective.',
        'गुरु की दृष्टि इस पर पड़ती है और रक्षक मानी जाती है।',
      ),
    );
  }
  final List<Graha> otherKind = st.aspectedBy
      .where((Graha a) => a != Graha.jupiter && _isBenefic(k, a))
      .toList();
  final List<Graha> otherHard = st.aspectedBy
      .where((Graha a) => !_isBenefic(k, a))
      .toList();
  if (otherKind.isNotEmpty) {
    parts.add(
      Bi(
        '${_grahas(otherKind).en} aspect${otherKind.length == 1 ? 's' : ''} it kindly.',
        '${_grahas(otherKind).hi} की दृष्टि इस पर शुभ रूप से पड़ती है।',
      ),
    );
  }
  if (otherHard.isNotEmpty) {
    parts.add(
      Bi(
        '${_grahas(otherHard).en} aspect${otherHard.length == 1 ? 's' : ''} it and ask${otherHard.length == 1 ? 's' : ''} for effort.',
        '${_grahas(otherHard).hi} की दृष्टि इस पर पड़ती है और परिश्रम माँगती है।',
      ),
    );
  }
  return parts.isEmpty ? null : _cat(parts);
}

Bi _strengthSentence(GrahaStanding st) {
  final Bi me = _graha(st.graha);
  final BalaBreakdown? b = st.bala;
  if (b == null || st.ownBindus == null) {
    return Bi(
      'Shadbala is not worked out for ${me.en}; the sign it stands in carries ${st.signBindus} sarvashtakavarga bindus.',
      '${me.hi} के लिए षड्बल की गणना नहीं होती; जिस राशि में यह बैठा है, उसमें सर्वाष्टकवर्ग के ${st.signBindus} बिंदु हैं।',
    );
  }
  final String rupas = b.totalRupas.toStringAsFixed(1);
  final Bi shadbala = b.isStrong
      ? Bi(
          'Its shadbala of $rupas rupas clears the ${b.requiredRupas} it needs, so it can deliver what it signifies.',
          'इसका षड्बल $rupas रूप है, जो आवश्यक ${b.requiredRupas} से अधिक है, इसलिए यह अपने विषयों का फल दे सकता है।',
        )
      : Bi(
          'Its shadbala of $rupas rupas is under the ${b.requiredRupas} it needs, so it may need more effort and time.',
          'इसका षड्बल $rupas रूप है, जो आवश्यक ${b.requiredRupas} से कम है, इसलिए फल के लिए अधिक प्रयास और समय लग सकता है।',
        );
  final int own = st.ownBindus!;
  final Bi count = own >= 5
      ? const Bi('That is a full count.', 'यह पूरी गिनती है।')
      : (own <= 3
            ? const Bi(
                'That is a thin count, so it asks for more effort.',
                'यह कम गिनती है, इसलिए अधिक प्रयास माँगती है।',
              )
            : const Bi('That is an average count.', 'यह औसत गिनती है।'));
  final Bi bindus = Bi(
    'In its own ashtakavarga it holds $own bindus in this sign (five or more reads as full delivery, three or fewer as thin). ${count.en} The sign itself carries ${st.signBindus} sarvashtakavarga bindus.',
    'भिन्नाष्टकवर्ग में इस राशि के लिए इसके $own बिंदु हैं (पाँच या अधिक बिंदु पूर्ण फल का और तीन या कम बिंदु क्षीण फल का संकेत माने जाते हैं)। ${count.hi} इस राशि में सर्वाष्टकवर्ग के ${st.signBindus} बिंदु हैं।',
  );
  return _cat(<Bi>[shadbala, bindus]);
}

/// A yoga or dosha a graha takes part in, as the graha reading shows it, with
/// the remedies when the chart carries it uncancelled.
class YogaNote {
  const YogaNote({
    required this.key,
    required this.text,
    required this.isAdverse,
    required this.remedies,
  });

  final String key;
  final Bi text;

  /// A dosha the chart does not itself cancel.
  final bool isAdverse;

  /// At least one when [isAdverse], empty otherwise.
  final List<Remedy> remedies;

  Iterable<Bi> get texts => <Bi>[text, ...remedyTexts(remedies)];
}

/// The yogas of [yogas] this graha takes part in, each with its cancellation
/// when the chart carries one, and its remedies when it carries none.
List<YogaNote> _yogaNotes(PhalaContext ctx, Graha g) {
  final List<YogaNote> out = <YogaNote>[];
  for (final ({YogaFinding yoga, Set<Graha> grahas}) m in ctx.yogaMembers) {
    if (!m.grahas.contains(g)) continue;
    final YogaFinding y = m.yoga;
    final StringBuffer en = StringBuffer(
      '${y.nameEnglish}: ${y.meaningEnglish}',
    );
    final StringBuffer hi = StringBuffer('${y.nameHindi}: ${y.meaningHindi}');
    if (y.isDosha) {
      if (y.isCancelled) {
        en.write(' ${y.cancellationEnglish}');
        hi.write(' ${y.cancellationHindi}');
      } else if (y.key == 'kaal_sarpa') {
        // Not a yoga of the Parashari texts: a later addition whose weight
        // practitioners dispute, so no classical cancellation is claimed.
        en.write(
          ' It is not a named yoga of the classical Parashari texts, and practitioners differ on how much weight it deserves.',
        );
        hi.write(
          ' यह शास्त्रीय पराशरी ग्रंथों का नामित योग नहीं है, और ज्योतिषी इसे कितना महत्व दें, इस पर एकमत नहीं हैं।',
        );
      } else {
        en.write(' The tradition also describes several ways it is cancelled.');
        hi.write(' परंपरा इसके भंग होने के कई प्रकार भी बताती है।');
      }
    }
    final bool adverse = y.isDosha && !y.isCancelled;
    out.add(
      YogaNote(
        key: y.key,
        text: Bi(en.toString(), hi.toString()),
        isAdverse: adverse,
        remedies: adverse
            ? <Remedy>[
                for (final Graha through in m.grahas.take(2))
                  _yogaRemedy(y, through),
              ]
            : const <Remedy>[],
      ),
    );
  }
  return out;
}

/// The grahas that make a yoga, the one the remedy is about first. Only the
/// yogas phaladesh shows in a graha's reading are listed.
Set<Graha> _yogaGrahas(Kundli k, YogaFinding y) {
  final String key = y.key;
  Graha lordOf(int house) => rashiInfo(Rashi.values[k.signOfHouse(house)]).lord;
  bool together(Graha a, Graha b) => k.grahas[a]!.rashi == k.grahas[b]!.rashi;
  Graha? nodeWith(Graha g) {
    for (final Graha node in <Graha>[Graha.rahu, Graha.ketu]) {
      if (together(g, node)) return node;
    }
    return null;
  }

  if (key == 'mangal_dosha') return <Graha>{Graha.mars};
  if (key == 'kaal_sarpa') return <Graha>{Graha.rahu, Graha.ketu};
  if (key == 'gaja_kesari') return <Graha>{Graha.jupiter, Graha.moon};
  if (key == 'budhaditya') return <Graha>{Graha.sun, Graha.mercury};
  if (key == 'kemadruma') return <Graha>{Graha.moon};
  if (key == 'shakata_chandra') return <Graha>{Graha.moon, Graha.jupiter};
  if (key == 'daridra') return <Graha>{lordOf(2), lordOf(11)};
  if (key == 'guru_chandal') return <Graha>{Graha.jupiter, Graha.rahu};
  if (key == 'shrapit') return <Graha>{Graha.saturn, Graha.rahu};
  if (key == 'angarak') return <Graha>{Graha.mars, Graha.rahu};
  if (key == 'vish_yoga') return <Graha>{Graha.moon, Graha.saturn};
  if (key == 'grahan_surya' || key == 'grahan_chandra') {
    final Graha lum = key == 'grahan_surya' ? Graha.sun : Graha.moon;
    final Graha? node = nodeWith(lum);
    return <Graha>{lum, ?node};
  }
  if (key == 'pitra_dosha') {
    final Graha ninth = lordOf(9);
    return <Graha>{
      Graha.sun,
      for (final Graha node in <Graha>[Graha.rahu, Graha.ketu])
        if (together(Graha.sun, node) ||
            k.grahas[node]!.house == 9 ||
            (ninth != node && together(ninth, node)))
          node,
    };
  }
  if (key.startsWith('mahapurusha_')) {
    final String name = key.substring('mahapurusha_'.length);
    return Graha.values.where((Graha g) => g.name == name).toSet();
  }
  if (key.startsWith('raja_yoga_')) {
    final List<String> parts = key.split('_');
    final int kendra = int.parse(parts[2]);
    final int trikona = int.parse(parts[3]);
    return <Graha>{lordOf(kendra), lordOf(trikona)};
  }
  return <Graha>{};
}

/// What kind of thing is being asked of the person: Hindi agrees with it.
enum _Subject { house, graha, period, transit }

/// What a house, a graha, a period or a transit asks, framed by how well it is
/// placed. A hard tone says what the time asks of the person, never what will
/// befall them.
Bi _asksSentence(Bi asks, Tone tone, _Subject subject) {
  final (String, String, bool) noun = switch (subject) {
    _Subject.house => ('house', 'भाव', false),
    _Subject.graha => ('graha', 'ग्रह', false),
    _Subject.period => ('period', 'अवधि', true),
    _Subject.transit => ('transit', 'गोचर', false),
  };
  switch (tone) {
    case Tone.supportive:
      return switch (subject) {
        _Subject.house => Bi(
          'Its support is strong; you get the most from it by choosing to ${asks.en}.',
          'इसका सहारा मज़बूत है; ${asks.hi} से इसका पूरा लाभ मिलता है।',
        ),
        _Subject.graha => Bi(
          'A good way to use it is to ${asks.en}.',
          'इसका अच्छा उपयोग ${asks.hi} में है।',
        ),
        _ => Bi(
          'The chart backs this, and it is a good time to ${asks.en}.',
          'कुंडली इसका साथ देती है, और यह ${asks.hi} का अच्छा समय है।',
        ),
      };
    case Tone.mixed:
      return Bi(
        'Support and effort go together here; it asks you to ${asks.en}.',
        'यहाँ सहारा और परिश्रम साथ चलते हैं; इसमें ${asks.hi} की माँग रहती है।',
      );
    case Tone.demanding:
      return Bi(
        'This ${noun.$1} calls for a good deal of effort: it asks you to ${asks.en}. The tradition reads that as work to be done, not as a verdict.',
        'यह ${noun.$2} सामान्य से अधिक प्रयास ${noun.$3 ? 'माँगती' : 'माँगता'} है: इसमें ${asks.hi} की अपेक्षा रहती है। परंपरा इसे करने योग्य काम मानती है, कोई अंतिम फ़ैसला नहीं।',
      );
  }
}

// ---------------------------------------------------------------------------
// Bhava phala
// ---------------------------------------------------------------------------

/// One house of the chart, read from its sign, its lord, its occupants and the
/// aspects it receives.
class BhavaReading implements IndicatedReading {
  const BhavaReading({
    required this.house,
    required this.sign,
    required this.lord,
    required this.lordHouse,
    required this.lordSign,
    required this.lordDignity,
    required this.lordCombust,
    required this.lordRetrograde,
    required this.occupants,
    required this.aspectedBy,
    required this.signBindus,
    required this.area,
    required this.tone,
    required this.score,
    required this.headline,
    required this.reading,
    required this.asks,
    required this.relief,
    required this.indication,
    required this.tends,
    required this.remedies,
    required this.basis,
  });

  final int house;
  final Rashi sign;
  final Graha lord;
  final int lordHouse;
  final Rashi lordSign;
  final Dignity lordDignity;
  final bool lordCombust;
  final bool lordRetrograde;
  final List<Graha> occupants;
  final List<Graha> aspectedBy;
  final int signBindus;
  final LifeArea area;
  final Tone tone;
  final double score;

  @override
  final Bi headline;

  /// The house read through its lord, occupants and aspects.
  final Bi reading;

  /// What the house asks of the person, framed by its tone.
  final Bi asks;

  /// What eases any strain found in the house, or null if none was found.
  final Bi? relief;

  /// How strongly the chart points at this house's tone, with the factors.
  @override
  final Indication indication;

  /// What tends to come up when this house is the one in focus.
  @override
  final Bi tends;

  /// The remedies for what strains the house. Empty when nothing does.
  @override
  final List<Remedy> remedies;

  @override
  final List<Bi> basis;

  @override
  Iterable<Bi> get texts => <Bi>[
    headline,
    reading,
    tends,
    asks,
    ?relief,
    ...indication.texts,
    ...remedyTexts(remedies),
    ...basis,
  ];
}

double _lordHouseWeight(int house) {
  if (<int>[1, 4, 5, 7, 9, 10].contains(house)) return 2.0;
  if (house == 2 || house == 11) return 1.0;
  if (house == 3) return 0.5;
  return -2.0;
}

/// How a sign's sarvashtakavarga count reads, in words that describe the count
/// and do not pass a verdict on the person.
Bi _sarvaWords(int bindus) {
  if (bindus >= 34) return const Bi('very strong', 'बहुत बलवान');
  if (bindus >= 30) return const Bi('strong', 'बलवान');
  if (bindus >= 25) return const Bi('average', 'सामान्य');
  return const Bi('on the lighter side', 'अपेक्षाकृत कम बल');
}

BhavaReading _bhava(PhalaContext ctx, int h) {
  final Kundli k = ctx.kundli;
  final Rashi sign = Rashi.values[k.signOfHouse(h)];
  final Graha lord = rashiInfo(sign).lord;
  final GrahaStanding ls = ctx.of(lord);
  final PlacedGraha lp = ls.placed;
  final LifeArea area = LifeArea.values[h - 1];
  final LifeArea lordArea = LifeArea.values[lp.house - 1];
  final List<Graha> occupants =
      k.grahasInHouse(h).map((PlacedGraha p) => p.graha).toList()
        ..sort((Graha a, Graha b) => a.index.compareTo(b.index));
  final List<Graha> aspects = _aspectorsOf(k, sign.index);
  final int sav = ctx.ashtakavarga.sarva[sign.index];
  final bool upachaya = _upachayas.contains(h);
  final int twelfthFromHouse = ((h + 10) % 12) + 1;
  final bool lordInTwelfth = lp.house == twelfthFromHouse && lp.house != h;
  final Bi me = _graha(lord);

  // The weighing.
  double s = _lordHouseWeight(lp.house);
  final bool protects = _isStrongDignity(lp.dignity);
  s += switch (lp.dignity) {
    Dignity.exalted || Dignity.moolatrikona || Dignity.own => 2,
    Dignity.friend => 0.5,
    Dignity.neutral => 0,
    Dignity.enemy => -1,
    Dignity.debilitated => ls.neechaBhanga != null ? 0 : -2,
  };
  if (lordInTwelfth) s -= 2;
  if (lp.isCombust) s -= 1;
  final bool viparita = _dusthanas.contains(h) && _dusthanas.contains(lp.house);
  if (viparita) s += 2.5;
  double occupantScore = 0;
  for (final Graha o in occupants) {
    if (_isBenefic(k, o)) {
      occupantScore += 1;
    } else {
      occupantScore += upachaya ? 1 : -1;
    }
  }
  s += occupantScore.clamp(-2.0, 2.0);
  double aspectScore = 0;
  for (final Graha a in aspects) {
    if (a == Graha.jupiter) {
      if (_jupiterProtects(k)) aspectScore += 1;
    } else if (_isBenefic(k, a)) {
      aspectScore += 0.5;
    } else if (!upachaya) {
      aspectScore -= 0.5;
    }
  }
  s += aspectScore.clamp(-1.5, 2.0);
  if (sav >= 34) {
    s += 1.5;
  } else if (sav >= 30) {
    s += 1;
  } else if (sav <= 24) {
    s -= 1;
  }
  final BalaBreakdown? lb = ls.bala;
  if (lb != null) {
    if (lb.ratio >= 1.0) s += 0.5;
    if (lb.ratio < 0.8) s -= 0.5;
  }
  final Tone tone = s >= 3.5
      ? Tone.supportive
      : (s <= 0.0 ? Tone.demanding : Tone.mixed);

  // The reading, one rule at a time.
  final List<Bi> parts = <Bi>[
    Bi(
      'The ${_ordEn[h]} house (${area.themes.en}) falls in ${_sign(sign).en}, whose lord is ${me.en}.',
      '${_houseDir(h).hi} (${area.themes.hi}) ${_sign(sign).hi} राशि में पड़ता है, जिसका स्वामी ${me.hi} है।',
    ),
    if (lp.house == h)
      Bi(
        '${me.en} stands in the house itself, in ${_sign(lp.rashi).en}, which keeps its matters close at hand.',
        '${me.hi} स्वयं इसी भाव में, ${_sign(lp.rashi).hi} राशि में स्थित है, जिससे इसके विषय पास ही रहते हैं।',
      )
    else
      Bi(
        '${me.en} stands in ${_houseObl(lp.house).en} (${lordArea.periodTitle.en}), in ${_sign(lp.rashi).en}, ${_dignityPhrase(lp.dignity).en}. So the matters of this house are worked out through ${lordArea.themes.en}.',
        '${me.hi} ${_houseObl(lp.house).hi} (${lordArea.periodTitle.hi}) में, ${_sign(lp.rashi).hi} राशि में है, जो ${_dignityPhrase(lp.dignity).hi} है। इसलिए इस भाव के विषयों का फल ${lordArea.themes.hi} से जुड़े क्षेत्र में दिखाई देता है।',
      ),
  ];
  final bool strong =
      _kendras.contains(lp.house) || _trikonas.contains(lp.house);
  if (strong) {
    parts.add(
      _dusthanas.contains(h)
          ? const Bi(
              'A lord in a kendra or trikona strengthens its house; for a house of effort like this one that means its matters are active and need handling well.',
              'केंद्र या त्रिकोण में बैठा स्वामी अपने भाव को बल देता है; इस जैसे प्रयास के भाव में इसका अर्थ है कि इसके विषय सक्रिय रहते हैं और उन्हें ठीक से सँभालना पड़ता है।',
            )
          : const Bi(
              'A lord in a kendra or trikona strengthens its house.',
              'केंद्र या त्रिकोण में बैठा स्वामी अपने भाव को बल देता है।',
            ),
    );
  } else if (_dusthanas.contains(lp.house)) {
    parts.add(
      const Bi(
        'A lord in the 6th, 8th or 12th strains its house, so its matters ask for more effort.',
        'छठे, आठवें या बारहवें भाव में बैठा स्वामी अपने भाव पर दबाव डालता है, इसलिए इसके विषय अधिक प्रयास माँगते हैं।',
      ),
    );
  } else if (lp.house == 2 || lp.house == 11) {
    parts.add(
      const Bi(
        'The 2nd and the 11th are houses of means, so a lord standing there has resources to draw on.',
        'दूसरा और ग्यारहवाँ भाव साधनों से जुड़े भाव हैं, इसलिए वहाँ बैठे स्वामी के पास सहारे के लिए संसाधन रहते हैं।',
      ),
    );
  }
  if (protects) {
    parts.add(
      const Bi(
        'A lord in its own or exaltation sign protects the house.',
        'स्वराशि या उच्च राशि में बैठा स्वामी भाव की रक्षा करता है।',
      ),
    );
  }
  if (lp.dignity == Dignity.debilitated) {
    parts.add(
      Bi(
        'A lord in its sign of fall weakens its house unless the fall is cancelled.${ls.neechaBhanga != null ? ' ${ls.neechaBhanga!.en}' : ''}',
        'नीच राशि में बैठा स्वामी अपने भाव को कमज़ोर करता है, जब तक उसका नीचत्व भंग न हो।${ls.neechaBhanga != null ? ' ${ls.neechaBhanga!.hi}' : ''}',
      ),
    );
  }
  if (lordInTwelfth) {
    parts.add(
      Bi(
        'The lord stands in the 12th from its own house, which many astrologers read as weakening the house: the energy of its matters tends to flow elsewhere, so they ask for deliberate attention.${strong ? ' This pulls against the strengthening above.' : ''}',
        'स्वामी अपने भाव से बारहवें स्थान पर है; अनेक ज्योतिषी इसे भाव को क्षीण करने वाली स्थिति मानते हैं, जिसमें इस भाव के विषयों की ऊर्जा कहीं और बहती है और उन पर सोच-समझकर ध्यान देना पड़ता है।${strong ? ' यह ऊपर बताए बल के विपरीत खिंचती है।' : ''}',
      ),
    );
  }
  if (lp.isCombust) {
    parts.add(
      const Bi(
        'The lord is combust, so the matters of the house come through dimmed.',
        'स्वामी अस्त है, इसलिए भाव के विषय धुँधले पड़ते हैं।',
      ),
    );
  }
  if (lp.isRetrograde) {
    parts.add(
      const Bi(
        'The lord is retrograde, which many astrologers read as these matters being worked out inwardly before they show.',
        'स्वामी वक्री है, जिसे अनेक ज्योतिषी इस रूप में पढ़ते हैं कि ये विषय बाहर दिखने से पहले भीतर सुलझते हैं।',
      ),
    );
  }
  if (occupants.isEmpty) {
    parts.add(
      const Bi(
        'No graha stands in the house, so it is read from its lord alone.',
        'इस भाव में कोई ग्रह नहीं है, इसलिए इसे केवल इसके स्वामी से पढ़ा जाता है।',
      ),
    );
  } else {
    final List<Graha> kind = occupants
        .where((Graha o) => _isBenefic(k, o))
        .toList();
    final List<Graha> hard = occupants
        .where((Graha o) => !_isBenefic(k, o))
        .toList();
    if (kind.isNotEmpty) {
      parts.add(
        Bi(
          '${_grahas(kind).en} in the house ${kind.length == 1 ? 'supports' : 'support'} its matters.',
          'भाव में ${kind.length == 1 ? 'बैठा' : 'बैठे'} ${_grahas(kind).hi} इसके विषयों को सहारा ${kind.length == 1 ? 'देता है' : 'देते हैं'}।',
        ),
      );
    }
    if (hard.isNotEmpty) {
      parts.add(
        upachaya
            ? Bi(
                '${_grahas(hard).en} here ${hard.length == 1 ? 'does' : 'do'} well, since this is a house that grows with effort.',
                'यहाँ ${_grahas(hard).hi} अच्छे फल ${hard.length == 1 ? 'देता है' : 'देते हैं'}, क्योंकि यह उपचय भाव है, जो परिश्रम से बढ़ता है।',
              )
            : Bi(
                '${_grahas(hard).en} in the house ${hard.length == 1 ? 'presses' : 'press'} on its matters.',
                'भाव में ${hard.length == 1 ? 'बैठा' : 'बैठे'} ${_grahas(hard).hi} इसके विषयों पर दबाव ${hard.length == 1 ? 'डालता है' : 'डालते हैं'}।',
              ),
      );
    }
  }
  if (aspects.isNotEmpty) {
    final List<Graha> kind = aspects
        .where((Graha a) => _isBenefic(k, a))
        .toList();
    final List<Graha> hard = aspects
        .where((Graha a) => !_isBenefic(k, a))
        .toList();
    if (aspects.contains(Graha.jupiter) && _jupiterProtects(k)) {
      parts.add(
        const Bi(
          'Jupiter’s aspect falls on the house and is read as protective.',
          'गुरु की दृष्टि इस भाव पर पड़ती है और रक्षक मानी जाती है।',
        ),
      );
    }
    final List<Graha> otherKind = kind
        .where((Graha a) => a != Graha.jupiter)
        .toList();
    if (otherKind.isNotEmpty) {
      parts.add(
        Bi(
          '${_grahas(otherKind).en} aspect${otherKind.length == 1 ? 's' : ''} it kindly.',
          '${_grahas(otherKind).hi} की दृष्टि इस पर शुभ रूप से पड़ती है।',
        ),
      );
    }
    if (hard.isNotEmpty && !upachaya) {
      parts.add(
        Bi(
          '${_grahas(hard).en} aspect${hard.length == 1 ? 's' : ''} it and ask${hard.length == 1 ? 's' : ''} for effort.',
          '${_grahas(hard).hi} की दृष्टि इस पर पड़ती है और परिश्रम माँगती है।',
        ),
      );
    }
  }
  parts.add(
    Bi(
      'The sign carries $sav sarvashtakavarga bindus: ${_sarvaWords(sav).en}.',
      'राशि में सर्वाष्टकवर्ग के $sav बिंदु हैं: ${_sarvaWords(sav).hi}।',
    ),
  );

  // Relief: afflictions are named, and so is what classically eases them.
  final bool strained =
      _dusthanas.contains(lp.house) ||
      lordInTwelfth ||
      lp.dignity == Dignity.debilitated ||
      lp.isCombust ||
      occupants.any((Graha o) => !_isBenefic(k, o) && !upachaya) ||
      sav <= 24;
  Bi? relief;
  if (strained) {
    final List<Bi> eases = <Bi>[];
    if (ls.neechaBhanga != null) eases.add(ls.neechaBhanga!);
    if (viparita) {
      eases.add(
        Bi(
          'Viparita raja yoga: the lord of a difficult house stands in a difficult house, which the schools that use it read as the strain of ${_houseObl(h).en} being turned to use.',
          'विपरीत राजयोग: दुःस्थान का स्वामी दुःस्थान में है, जिसे यह योग मानने वाली परंपराएँ ${_houseObl(h).hi} की कठिनाई के काम में आ जाने का संकेत मानती हैं।',
        ),
      );
    }
    if (protects && (_dusthanas.contains(lp.house) || lp.isCombust)) {
      eases.add(
        Bi(
          '${me.en} stands in ${_ownSignPhrase(lp.dignity).en}, which protects a lord even in a hard place.',
          '${me.hi} ${_ownSignPhrase(lp.dignity).hi} में है, जो कठिन स्थान में भी स्वामी की रक्षा करती है।',
        ),
      );
    }
    if (aspects.contains(Graha.jupiter) && _jupiterProtects(k)) {
      eases.add(
        const Bi('Jupiter aspects the house.', 'गुरु की दृष्टि भाव पर है।'),
      );
    }
    if (occupants.any((Graha o) => _isBenefic(k, o))) {
      eases.add(
        Bi(
          '${_grahas(occupants.where((Graha o) => _isBenefic(k, o)).toList()).en} in the house is read as relief.',
          'भाव में बैठे ${_grahas(occupants.where((Graha o) => _isBenefic(k, o)).toList()).hi} को राहत देने वाला माना जाता है।',
        ),
      );
    }
    if (sav >= 30) {
      eases.add(
        Bi(
          'The sign’s $sav bindus give the house a good base.',
          'राशि के $sav बिंदु भाव को अच्छा आधार देते हैं।',
        ),
      );
    }
    if (lb != null && lb.isStrong) {
      eases.add(
        Bi(
          'The lord’s shadbala clears its minimum.',
          'स्वामी का षड्बल आवश्यक न्यूनतम से अधिक है।',
        ),
      );
    }
    relief = eases.isNotEmpty
        ? Bi(
            eases.map((Bi e) => e.en).join(' '),
            eases.map((Bi e) => e.hi).join(' '),
          )
        : const Bi(
            'The usual reliefs are Jupiter’s aspect, a lord in its own or exalted sign, a good ashtakavarga count and a viparita placement. None of them is present here, so read this as a part of life that asks steady effort, not as a verdict.',
            'राहत के सामान्य आधार हैं गुरु की दृष्टि, स्वराशि या उच्च राशि में बैठा स्वामी, अच्छा अष्टकवर्ग और विपरीत राजयोग। यहाँ इनमें से कोई भी मौजूद नहीं है, इसलिए इसे जीवन का वह क्षेत्र समझें जो निरंतर प्रयास माँगता है, कोई अंतिम फ़ैसला नहीं।',
          );
  }

  // The chart factors behind the band. A fact that takes no side is not a
  // factor; an empty house or an unaspected one is simply read from its lord.
  final List<Graha> byLord = <Graha>[lord];
  final List<IndicatorFactor> factors = <IndicatorFactor>[];
  void note(
    FactorKind kind,
    bool eases,
    bool firm,
    Bi text, [
    List<Graha>? who,
  ]) => factors.add(
    IndicatorFactor(
      kind: kind,
      text: text,
      eases: eases,
      firm: firm,
      grahas: who ?? byLord,
    ),
  );
  final Bi lordStands = lp.house == h
      ? Bi(
          '${me.en}, lord of ${_houseObl(h).en}, stands in the house itself, ${_placeLabel(lp.house).en}',
          '${_houseObl(h).hi} का स्वामी ${me.hi} उसी भाव में है, जो ${_placeLabel(lp.house).hi} है',
        )
      : Bi(
          '${me.en}, lord of ${_houseObl(h).en}, stands in ${_houseObl(lp.house).en}, ${_placeLabel(lp.house).en}',
          '${_houseObl(h).hi} का स्वामी ${me.hi} ${_houseObl(lp.house).hi} में है, जो ${_placeLabel(lp.house).hi} है',
        );
  if (_kendras.contains(lp.house) || _trikonas.contains(lp.house)) {
    note(FactorKind.placement, true, true, lordStands);
  } else if (lp.house == 2 || lp.house == 11) {
    note(FactorKind.placement, true, false, lordStands);
  } else if (_dusthanas.contains(lp.house)) {
    note(FactorKind.placement, false, true, lordStands);
  }
  if (lordInTwelfth) {
    note(
      FactorKind.placement,
      false,
      true,
      Bi(
        '${me.en} stands in the 12th from its own house, which many astrologers read as weakening the house',
        '${me.hi} अपने भाव से बारहवें स्थान पर है, जिसे अनेक ज्योतिषी भाव को कमज़ोर करने वाला मानते हैं',
      ),
    );
  }
  switch (lp.dignity) {
    case Dignity.exalted:
    case Dignity.moolatrikona:
    case Dignity.own:
      note(FactorKind.dignity, true, true, _dignityFactor(lord, lp));
    case Dignity.friend:
      note(FactorKind.dignity, true, false, _dignityFactor(lord, lp));
    case Dignity.neutral:
      break;
    case Dignity.enemy:
      note(FactorKind.dignity, false, false, _dignityFactor(lord, lp));
    case Dignity.debilitated:
      note(FactorKind.dignity, false, true, _dignityFactor(lord, lp));
      if (ls.neechaBhanga != null) {
        note(
          FactorKind.relief,
          true,
          true,
          Bi(
            'Neecha bhanga: the fall of ${me.en} is cancelled',
            'नीच भंग: ${me.hi} का नीचत्व भंग हुआ है',
          ),
        );
      }
  }
  if (lp.isCombust) {
    note(
      FactorKind.condition,
      false,
      true,
      Bi(
        '${me.en}, the lord, is combust, too near the Sun',
        'स्वामी ${me.hi} सूर्य के बहुत पास होने से अस्त है',
      ),
    );
  }
  if (viparita) {
    note(
      FactorKind.relief,
      true,
      true,
      Bi(
        'Viparita raja yoga: the lord of ${_houseObl(h).en}, a difficult house, stands in a difficult house',
        'विपरीत राजयोग: कठिन भाव (${_houseObl(h).hi}) का स्वामी कठिन भाव में है',
      ),
    );
  }
  final List<Graha> kindOcc = occupants
      .where((Graha o) => _isBenefic(k, o) || upachaya)
      .toList();
  final List<Graha> hardOcc = occupants
      .where((Graha o) => !_isBenefic(k, o) && !upachaya)
      .toList();
  final ({bool eases, bool firm})? occVote = _netVote(
    kindOcc.length,
    hardOcc.length,
  );
  if (occVote != null) {
    note(
      FactorKind.occupants,
      occVote.eases,
      occVote.firm,
      occVote.eases
          ? Bi(
              '${_grahas(kindOcc).en} in the house ${kindOcc.length == 1 ? 'supports' : 'support'} its matters',
              'भाव में बैठे ${_grahas(kindOcc).hi} इसके विषयों को सहारा देते हैं',
            )
          : Bi(
              '${_grahas(hardOcc).en} in the house ${hardOcc.length == 1 ? 'presses' : 'press'} on its matters',
              'भाव में बैठे ${_grahas(hardOcc).hi} इसके विषयों पर दबाव डालते हैं',
            ),
      occVote.eases ? byLord : hardOcc,
    );
  }
  final bool jupiterGlance =
      aspects.contains(Graha.jupiter) && _jupiterProtects(k);
  final List<Graha> kindAsp = aspects
      .where((Graha a) => a != Graha.jupiter && _isBenefic(k, a))
      .toList();
  final List<Graha> hardAsp = aspects
      .where((Graha a) => !_isBenefic(k, a) && !upachaya)
      .toList();
  final ({bool eases, bool firm})? aspVote = _netVote(
    (jupiterGlance ? 2 : 0) + kindAsp.length,
    hardAsp.length,
  );
  if (aspVote != null) {
    final List<Graha> side = aspVote.eases
        ? <Graha>[if (jupiterGlance) Graha.jupiter, ...kindAsp]
        : hardAsp;
    note(
      FactorKind.aspects,
      aspVote.eases,
      aspVote.firm,
      aspVote.eases
          ? Bi(
              'The house is looked at by ${_grahas(side).en}, a kind glance',
              'भाव पर ${_grahas(side).hi} की शुभ दृष्टि है',
            )
          : Bi(
              'The house is looked at by ${_grahas(side).en}, a hard glance',
              'भाव पर ${_grahas(side).hi} की कठोर दृष्टि है',
            ),
      aspVote.eases ? byLord : hardAsp,
    );
  }
  if (sav >= 30) {
    note(
      FactorKind.ashtakavarga,
      true,
      true,
      Bi(
        'The sign carries $sav sarvashtakavarga bindus, ${_sarvaWords(sav).en}',
        'राशि में सर्वाष्टकवर्ग के $sav बिंदु हैं: ${_sarvaWords(sav).hi}',
      ),
    );
  } else if (sav <= 24) {
    note(
      FactorKind.ashtakavarga,
      false,
      true,
      Bi(
        'The sign carries only $sav sarvashtakavarga bindus, ${_sarvaWords(sav).en}',
        'राशि में सर्वाष्टकवर्ग के सिर्फ़ $sav बिंदु हैं: ${_sarvaWords(sav).hi}',
      ),
    );
  }
  final IndicatorFactor? lordBala = _shadbalaFactor(
    lb,
    'The lord’s',
    'स्वामी',
    byLord,
    allowFirm: true,
  );
  if (lordBala != null) factors.add(lordBala);
  final Set<String> seenYogas = <String>{};
  for (final ({YogaFinding yoga, Set<Graha> grahas}) m in ctx.yogaMembers) {
    if (!m.grahas.contains(lord)) continue;
    final YogaFinding y = m.yoga;
    if (!seenYogas.add(_yogaSignature(m))) continue;
    if (!y.isDosha) {
      note(
        FactorKind.yoga,
        true,
        false,
        Bi(
          'The lord ${me.en} takes part in ${y.nameEnglish}',
          'स्वामी ${me.hi} ${y.nameHindi} में शामिल है',
        ),
      );
    } else if (!y.isCancelled) {
      note(
        FactorKind.yoga,
        false,
        false,
        Bi(
          'The lord ${me.en} takes part in ${y.nameEnglish}, which the tradition reads as asking for effort',
          'स्वामी ${me.hi} ${y.nameHindi} में शामिल है, जिसे परंपरा मेहनत माँगने वाला मानती है',
        ),
      );
    }
  }
  final Indication indication = Indication(tone, factors);
  final List<Remedy> remedies = relief != null || tone == Tone.demanding
      ? _remediesFor(
          factors,
          limit: 3,
          prefer: lord,
          fallback: lord,
          fallbackReason: Bi(
            'The rules weigh ${_houseObl(h).en} as asking for effort, and ${me.en} is its lord',
            'नियम ${_houseObl(h).hi} को मेहनत माँगने वाला तौलते हैं, और ${me.hi} इसका स्वामी है',
          ),
        )
      : const <Remedy>[];

  // What tends to come up in this house, as a tendency and never an event.
  final List<Graha> voices = occupants.take(2).toList();
  final Bi tends = _cat(<Bi>[
    _houseTends[h - 1],
    if (voices.isNotEmpty)
      Bi(
        'With ${_grahas(occupants).en} here, ${_items(voices.map((Graha o) => _grahaThemes[o]!).toList()).en} tend to colour these matters.',
        'यहाँ ${_grahas(occupants).hi} के होने से ${_items(voices.map((Graha o) => _grahaThemes[o]!).toList()).hi} की बातें इन मामलों पर रंग चढ़ाती हैं।',
      ),
    lp.house == h
        ? const Bi(
            'With its lord in the house itself, these matters tend to stay close at hand.',
            'स्वामी उसी भाव में होने से ये मामले अक्सर पास ही रहते हैं।',
          )
        : Bi(
            'With its lord in ${_lower(lordArea.periodTitle.en)}, these matters tend to be tied up with that part of life.',
            'स्वामी ${lordArea.periodTitle.hi} में होने से ये मामले अक्सर जीवन के उस हिस्से से जुड़े रहते हैं।',
          ),
    _toneTends(tone),
  ]);

  final Bi lagna = ctx.lagnaName;
  return BhavaReading(
    house: h,
    sign: sign,
    lord: lord,
    lordHouse: lp.house,
    lordSign: lp.rashi,
    lordDignity: lp.dignity,
    lordCombust: lp.isCombust,
    lordRetrograde: lp.isRetrograde,
    occupants: occupants,
    aspectedBy: aspects,
    signBindus: sav,
    area: area,
    tone: tone,
    score: s,
    headline: Bi(
      '${_ordEn[h]} house · ${area.title.en}: ${_houseToneWords(tone).en}',
      '${_ordHiDirect[h]} भाव · ${area.title.hi}: ${_houseToneWords(tone).hi}',
    ),
    reading: _cat(parts),
    asks: _asksSentence(area.asks, tone, _Subject.house),
    relief: relief,
    indication: indication,
    tends: tends,
    remedies: remedies,
    basis: <Bi>[
      Bi(
        '${_ordEn[h]} house: ${_sign(sign).en}, lord ${me.en} (lagna ${lagna.en})',
        '${_ordHiDirect[h]} भाव: ${_sign(sign).hi}, स्वामी ${me.hi} (लग्न ${lagna.hi})',
      ),
      ...ls.basis.take(1),
      Bi(
        'Lord’s place from the house: ${_ordEn[((lp.house - h + 12) % 12) + 1]}',
        'भाव से स्वामी की स्थिति: ${_ordHiDirect[((lp.house - h + 12) % 12) + 1]}',
      ),
      if (occupants.isNotEmpty)
        Bi(
          'Occupants: ${_grahas(occupants).en}',
          'भाव में स्थित: ${_grahas(occupants).hi}',
        ),
      if (aspects.isNotEmpty)
        Bi(
          'Aspected by: ${_grahas(aspects).en}',
          'दृष्टि: ${_grahas(aspects).hi}',
        ),
      Bi('Sarvashtakavarga: $sav bindus', 'सर्वाष्टकवर्ग: $sav बिंदु'),
      if (lb != null)
        Bi(
          'Lord’s shadbala: ${lb.totalRupas.toStringAsFixed(1)} rupas (needs ${lb.requiredRupas})',
          'स्वामी का षड्बल: ${lb.totalRupas.toStringAsFixed(1)} रूप (आवश्यक ${lb.requiredRupas})',
        ),
    ],
  );
}

/// All twelve houses.
List<BhavaReading> bhavaPhala(PhalaContext ctx) => <BhavaReading>[
  for (int h = 1; h <= 12; h++) _bhava(ctx, h),
];

// ---------------------------------------------------------------------------
// Graha phala
// ---------------------------------------------------------------------------

/// One graha in its sign and house, modulated by dignity, combustion,
/// retrogression and the company it keeps.
class GrahaReading implements IndicatedReading {
  const GrahaReading({
    required this.graha,
    required this.house,
    required this.sign,
    required this.dignity,
    required this.isCombust,
    required this.isRetrograde,
    required this.ruled,
    required this.nature,
    required this.companions,
    required this.aspectedBy,
    required this.yogas,
    required this.yogaNotes,
    required this.tone,
    required this.score,
    required this.headline,
    required this.reading,
    required this.asks,
    required this.relief,
    required this.indication,
    required this.remedies,
    required this.basis,
  });

  final Graha graha;
  final int house;
  final Rashi sign;
  final Dignity dignity;
  final bool isCombust;
  final bool isRetrograde;
  final List<int> ruled;
  final FunctionalNature nature;
  final List<Graha> companions;
  final List<Graha> aspectedBy;

  /// The yogas and doshas this graha takes part in, with their cancellations.
  final List<Bi> yogas;

  /// The same, with the remedies for each dosha the chart does not cancel.
  final List<YogaNote> yogaNotes;
  final Tone tone;
  final double score;

  @override
  final Bi headline;
  final Bi reading;
  final Bi asks;
  final Bi? relief;

  /// How strongly the chart points at this graha's tone, with the factors.
  @override
  final Indication indication;

  /// The graha's own reading carries no separate "what tends to come up": it
  /// signifies what it signifies, and the houses and periods say where that
  /// shows.
  @override
  Bi? get tends => null;

  /// The remedies for what strains this graha. Empty when nothing does.
  @override
  final List<Remedy> remedies;

  @override
  final List<Bi> basis;

  @override
  Iterable<Bi> get texts => <Bi>[
    headline,
    reading,
    asks,
    ?relief,
    ...indication.texts,
    ...remedyTexts(remedies),
    for (final YogaNote y in yogaNotes) ...y.texts,
    ...basis,
  ];
}

GrahaReading _grahaReading(PhalaContext ctx, Graha g) {
  final GrahaStanding st = ctx.of(g);
  final PlacedGraha p = st.placed;
  final Bi me = _graha(g);
  final LifeArea area = LifeArea.values[p.house - 1];
  final Bi sign = _sign(p.rashi);

  final List<IndicatorFactor> factors = ctx.grahaFactors[g]!;
  final List<YogaNote> notes = _yogaNotes(ctx, g);
  final Bi placed = _placementSentence(st);
  final List<Bi> parts = <Bi>[
    Bi(
      '${me.en} signifies ${_grahaThemes[g]!.en}.',
      '${me.hi} ${_grahaThemes[g]!.hi} का कारक है।',
    ),
    Bi(
      '${placed.en} So those matters work themselves out through ${area.themes.en}.',
      '${placed.hi} इसलिए इन विषयों का असर ${area.themes.hi} से जुड़े क्षेत्र में दिखाई देता है।',
    ),
    _lordshipSentence(ctx, st),
    st.natureWhy,
    ?_dignityEffect(st),
    ?_conditionSentence(st),
    ?_companySentence(ctx, st),
    _strengthSentence(st),
  ];

  return GrahaReading(
    graha: g,
    house: p.house,
    sign: p.rashi,
    dignity: p.dignity,
    isCombust: p.isCombust,
    isRetrograde: p.isRetrograde,
    ruled: st.ruled,
    nature: st.nature,
    companions: st.companions,
    aspectedBy: st.aspectedBy,
    yogas: <Bi>[for (final YogaNote y in notes) y.text],
    yogaNotes: notes,
    tone: st.tone,
    score: st.score,
    headline: Bi(
      '${me.en} in ${sign.en}, ${_ordEn[p.house]} house: ${_houseToneWords(st.tone).en}',
      '${me.hi} ${sign.hi} राशि में, ${_ordHiDirect[p.house]} भाव: ${_houseToneWords(st.tone).hi}',
    ),
    reading: _cat(parts),
    asks: _asksSentence(_grahaAsks[g]!, st.tone, _Subject.graha),
    relief: st.relief,
    indication: Indication(st.tone, factors),
    remedies: st.relief != null || st.tone == Tone.demanding
        ? _remediesFor(
            factors,
            limit: 1,
            fallback: g,
            fallbackReason: Bi(
              'The rules weigh ${me.en} as asking for effort in this chart',
              'नियम इस कुंडली में ${me.hi} को मेहनत माँगने वाला तौलते हैं',
            ),
          )
        : const <Remedy>[],
    basis: st.basis,
  );
}

/// All nine grahas.
List<GrahaReading> grahaPhala(PhalaContext ctx) => <GrahaReading>[
  for (final Graha g in Graha.values) _grahaReading(ctx, g),
];

// ---------------------------------------------------------------------------
// Dasha phala
// ---------------------------------------------------------------------------

/// Friend, neutral or enemy, taking the natural friendship both ways. Two
/// friends, or a friend and a neutral, are friends; two enemies, or an enemy
/// and a neutral, are enemies; a friend and an enemy cancel to neutral. A
/// graha is its own friend. Schools differ about the nodes, so the table
/// treats them as neutral. Taking the table both ways is this app's way of
/// reading a one-way friendship; the temporary friendship of Parashara's
/// compound relation is not added.
Relation mutualRelation(Graha a, Graha b) {
  if (a == b) return Relation.friend;
  final Relation x = relationBetween(a, b);
  final Relation y = relationBetween(b, a);
  if (x == y) return x;
  if (x == Relation.neutral) return y;
  if (y == Relation.neutral) return x;
  return Relation.neutral;
}

Bi _relationClause(
  Graha inner,
  Graha outer,
  Relation r,
  Bi innerWord,
  Bi outerWord, {
  bool contrast = false,
}) {
  final Bi a = _graha(inner);
  final Bi b = _graha(outer);
  final bool node =
      inner == Graha.rahu ||
      inner == Graha.ketu ||
      outer == Graha.rahu ||
      outer == Graha.ketu;
  final String caveatEn = node
      ? ' Schools differ about the friendships of Rahu and Ketu, so this is counted as neutral and the placement is left to speak.'
      : '';
  final String caveatHi = node
      ? ' राहु और केतु की मित्रता के बारे में परंपराएँ एकमत नहीं हैं, इसलिए इसे सम माना गया है और फल ग्रह की स्थिति के आधार पर ही देखा जाता है।'
      : '';
  final String evenEn = contrast ? 'Even so, ' : '';
  final String evenHi = contrast ? 'फिर भी, ' : '';
  switch (r) {
    case Relation.friend:
      return Bi(
        '$evenEn${contrast ? '${a.en} and ${b.en}' : '${a.en} and ${b.en}'} are natural friends, so the two work together.',
        '$evenHi${a.hi} और ${b.hi} नैसर्गिक मित्र हैं, इसलिए दोनों साथ चलते हैं।',
      );
    case Relation.neutral:
      return Bi(
        '$evenEn${a.en} and ${b.en} are neutral to each other, so each goes its own way.$caveatEn',
        '$evenHi${a.hi} और ${b.hi} परस्पर सम हैं, इसलिए दोनों अपनी-अपनी राह चलते हैं।$caveatHi',
      );
    case Relation.enemy:
      return Bi(
        '$evenEn${a.en} and ${b.en} are natural enemies, so ${innerWord.en} pulls against ${outerWord.en} and has to be managed.',
        '$evenHi${a.hi} और ${b.hi} नैसर्गिक शत्रु हैं, इसलिए ${innerWord.hi} ${outerWord.hi} के विपरीत खिंचती है और उसे सँभालना पड़ता है।',
      );
  }
}

enum _Band { easy, gain, effort, hard }

_Band _bandOf(int place) {
  if (<int>[1, 4, 5, 7, 9, 10].contains(place)) return _Band.easy;
  if (place == 2 || place == 11) return _Band.gain;
  if (place == 3) return _Band.effort;
  return _Band.hard;
}

double _bandWeight(_Band b) => switch (b) {
  _Band.easy => 1.0,
  _Band.gain => 0.5,
  _Band.effort => 0.0,
  _Band.hard => -1.5,
};

/// One mahadasha, antardasha or pratyantardasha with its dates and its reading.
class PeriodReading implements IndicatedReading {
  const PeriodReading({
    required this.level,
    required this.lord,
    required this.parentLord,
    required this.grandparentLord,
    required this.startJdUt,
    required this.endJdUt,
    required this.nature,
    required this.tone,
    required this.score,
    required this.areas,
    required this.placeFromParent,
    required this.relation,
    required this.headline,
    required this.lead,
    required this.summary,
    required this.promise,
    required this.modifier,
    required this.context,
    required this.asks,
    required this.relief,
    required this.indication,
    required this.tends,
    required this.remedies,
    required this.basis,
    required this.children,
  });

  /// 1 = mahadasha, 2 = antardasha, 3 = pratyantardasha.
  final int level;
  final Graha lord;

  /// The lord of the period that contains this one, for levels 2 and 3.
  final Graha? parentLord;
  final Graha? grandparentLord;
  final double startJdUt;
  final double endJdUt;
  final FunctionalNature nature;
  final Tone tone;
  final double score;

  /// The departments of life this period concentrates on, strongest first.
  final List<LifeArea> areas;

  /// Where this lord stands counted from the lord of the containing period
  /// (1 to 12), the classical modifier. Null for a mahadasha.
  final int? placeFromParent;

  /// Friend, neutral or enemy between this lord and the containing one.
  final Relation? relation;

  @override
  final Bi headline;

  /// What the period is about, without what it asks: the part of the summary
  /// that holds for a child as well as an adult.
  final Bi lead;

  /// Two or three sentences for a list or a timeline.
  final Bi summary;

  /// What the lord rules, where it stands and how strong it is.
  final Bi promise;

  /// The classical modifier from the containing period. Null for a mahadasha.
  final Bi? modifier;

  /// The period before and after, and the one that contains this.
  final Bi context;

  /// What the period asks of the person.
  final Bi asks;
  final Bi? relief;

  /// How strongly the chart points at this period's tone, with the factors:
  /// the lord's own standing, and for a sub-period the place of the lord from
  /// the period around it, their friendship and how that period fares.
  @override
  final Indication indication;

  /// What tends to come up in the areas of life this period concentrates on.
  @override
  final Bi tends;

  /// The remedies for a difficult period. Empty when nothing is strained.
  @override
  final List<Remedy> remedies;

  @override
  final List<Bi> basis;
  final List<PeriodReading> children;

  DateTime get start => utcFromJulianDay(startJdUt);
  DateTime get end => utcFromJulianDay(endJdUt);
  LifeArea get area => areas.first;
  double get lengthYears => (endJdUt - startJdUt) / vimshottariYear;

  bool contains(DateTime moment) {
    final double jd = julianDayFromUtc(moment.toUtc());
    return jd >= startJdUt && jd < endJdUt;
  }

  @override
  Iterable<Bi> get texts => <Bi>[
    headline,
    lead,
    summary,
    promise,
    ?modifier,
    context,
    tends,
    asks,
    ?relief,
    ...indication.texts,
    ...remedyTexts(remedies),
    ...basis,
    for (final PeriodReading c in children) ...c.texts,
  ];
}

/// The mahadashas of a chart, each with its antardashas and their
/// pratyantardashas, every one read against the one around it.
class DashaPhala implements PhalaReading {
  const DashaPhala({
    required this.birth,
    required this.mahadashas,
    required this.basis,
  });

  final DateTime birth;
  final List<PeriodReading> mahadashas;

  @override
  final List<Bi> basis;

  @override
  Bi get headline => const Bi('Dasha by dasha', 'दशा-दर-दशा');

  /// The headline and the factors the whole sequence rests on; each period
  /// carries its own texts.
  @override
  Iterable<Bi> get texts => <Bi>[headline, ...basis];

  /// The readings running at [moment], outermost first.
  List<PeriodReading> chainAt(DateTime moment) {
    final List<PeriodReading> chain = <PeriodReading>[];
    List<PeriodReading> level = mahadashas;
    while (true) {
      final Iterable<PeriodReading> match = level.where(
        (PeriodReading p) => p.contains(moment),
      );
      if (match.isEmpty) break;
      chain.add(match.first);
      level = match.first.children;
      if (level.isEmpty) break;
    }
    return chain;
  }
}

List<LifeArea> _areasOf(PhalaContext ctx, Graha lord, {Graha? backdrop}) {
  final Map<int, double> weight = <int, double>{};
  void feed(Graha g, double factor) {
    final GrahaStanding st = ctx.of(g);
    for (final int h in st.houses(ctx)) {
      weight[h] = (weight[h] ?? 0) + (h == 1 ? 0.6 : 1.0) * factor;
    }
    weight[st.placed.house] = (weight[st.placed.house] ?? 0) + 1.5 * factor;
  }

  feed(lord, 1.0);
  if (backdrop != null) feed(backdrop, 0.5);
  final List<int> houses = weight.keys.toList()
    ..sort((int a, int b) {
      final int byWeight = weight[b]!.compareTo(weight[a]!);
      return byWeight != 0 ? byWeight : a.compareTo(b);
    });
  return houses.take(2).map((int h) => LifeArea.values[h - 1]).toList();
}

String _lower(String s) =>
    s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

Bi _focusSentence(PhalaContext ctx, GrahaStanding st, List<LifeArea> areas) {
  final Bi me = _graha(st.graha);
  final int h = st.placed.house;
  final Bi first = areas.first.periodTitle;
  final Bi? second = areas.length > 1 ? areas[1].periodTitle : null;
  final Bi how = st.ruled.isEmpty
      ? Bi(
          '${me.en} acts through the houses of ${_graha(st.reader).en} and stands in ${_houseObl(h).en}.',
          '${me.hi} ${_graha(st.reader).hi} के भावों के अनुसार फल देता है और ${_houseObl(h).hi} में स्थित है।',
        )
      : Bi(
          '${me.en} rules ${_housesObl(st.ruled).en} and stands in ${_houseObl(h).en}.',
          '${me.hi} ${_housesObl(st.ruled).hi} का स्वामी है और ${_houseObl(h).hi} में स्थित है।',
        );
  return Bi(
    'The focus falls on ${_lower(first.en)}${second == null ? '' : ', with ${_lower(second.en)} alongside'}: ${how.en}',
    'ज़ोर ${first.hi} पर रहता है${second == null ? '' : ', और साथ में ${second.hi} भी जुड़े रहते हैं'}: ${how.hi}',
  );
}

class _Names {
  const _Names(this.inner, this.outer);

  final Bi inner;
  final Bi outer;
}

_Names _levelNames(int level) => level == 2
    ? const _Names(
        Bi('the antardasha', 'अंतर्दशा'),
        Bi('the mahadasha', 'महादशा'),
      )
    : const _Names(
        Bi('the pratyantardasha', 'प्रत्यंतर्दशा'),
        Bi('the antardasha', 'अंतर्दशा'),
      );

Bi _levelWord(int level) => switch (level) {
  1 => const Bi('mahadasha', 'महादशा'),
  2 => const Bi('antardasha', 'अंतर्दशा'),
  _ => const Bi('pratyantardasha', 'प्रत्यंतर्दशा'),
};

/// The classical modifier: where the sub-lord stands counted from the lord of
/// the period containing it, and how the two get on.
({Bi text, Bi? relief, double bonus, _Band band, Relation relation})
_modifierFor(PhalaContext ctx, int level, Graha inner, Graha outer) {
  final _Names names = _levelNames(level);
  final Bi a = _graha(inner);
  if (inner == outer) {
    // The same graha twice has no place to be counted from and no friendship
    // to weigh; it is the larger period's own theme in its plainest form.
    return (
      text: Bi(
        'The ${a.en} ${_levelWord(level).en} inside the ${a.en} ${_levelWord(level - 1).en} shows the larger period’s own theme in its plainest form.',
        '${a.hi} की ${_levelWord(level - 1).hi} के भीतर ${a.hi} की ${_levelWord(level).hi} बड़ी अवधि के अपने ही विषय को सबसे सीधे रूप में सामने रखती है।',
      ),
      relief: null,
      bonus: 1.0,
      band: _Band.easy,
      relation: Relation.friend,
    );
  }
  final int place = _houseFromSign(
    ctx.kundli.grahas[outer]!.rashi.index,
    ctx.kundli.grahas[inner]!.rashi.index,
  );
  final _Band band = _bandOf(place);
  final Relation relation = mutualRelation(inner, outer);
  final Bi from = _placeFrom(place, outer);
  final Bi position = switch (band) {
    _Band.easy when place == 1 => Bi(
      '${a.en} and ${_graha(outer).en} stand in the same sign, so ${names.inner.en} and ${names.outer.en} blend their concerns.',
      '${a.hi} और ${_graha(outer).hi} एक ही राशि में हैं, इसलिए ${names.inner.hi} और ${names.outer.hi} के विषय आपस में घुले-मिले रहते हैं।',
    ),
    _Band.easy => Bi(
      '${a.en} stands in ${from.en}, a ${_kendras.contains(place) ? 'kendra' : 'trikona'} position, which the tradition counts as easy: ${names.inner.en} helps bring out what ${names.outer.en} points to.',
      '${a.hi} ${from.hi} है, जो ${_kendras.contains(place) ? 'केंद्र' : 'त्रिकोण'} की स्थिति है; परंपरा इसे सहज मानती है: ${names.outer.hi} जिसका संकेत देती है, ${names.inner.hi} उसे उभारने में मदद करती है।',
    ),
    _Band.gain => Bi(
      '${a.en} stands in ${from.en}, a place of gain counted from there, so ${names.inner.en} backs the main theme with resources.',
      '${a.hi} ${from.hi} है, जो लाभ का स्थान है, इसलिए ${names.inner.hi} मुख्य विषय को साधनों का सहारा देती है।',
    ),
    _Band.effort => Bi(
      '${a.en} stands in ${from.en}, a place of effort, so what ${names.inner.en} brings comes through work rather than ease.',
      '${a.hi} ${from.hi} है, जो प्रयास का स्थान है, इसलिए ${names.inner.hi} का फल सहजता से नहीं, परिश्रम से मिलता है।',
    ),
    _Band.hard => Bi(
      '${a.en} stands in ${from.en}, a difficult position. The tradition reads this as friction between ${names.inner.en} and ${names.outer.en}: they work against the grain of each other and ask for adjustment.',
      '${a.hi} ${from.hi} है, जो कठिन स्थिति है। परंपरा इसे ${names.inner.hi} और ${names.outer.hi} के बीच घर्षण मानती है: दोनों एक-दूसरे के विपरीत चलती हैं और तालमेल माँगती हैं।',
    ),
  };
  final bool contrast =
      ((band == _Band.easy || band == _Band.gain) &&
          relation == Relation.enemy) ||
      (band == _Band.hard && relation == Relation.friend);
  final Bi relationText = _relationClause(
    inner,
    outer,
    relation,
    names.inner,
    names.outer,
    contrast: contrast,
  );

  Bi? relief;
  if (band == _Band.hard) {
    final GrahaStanding st = ctx.of(inner);
    final List<Bi> eases = <Bi>[
      if (relation == Relation.friend)
        const Bi(
          'The two lords are friends, and that friendship softens the friction.',
          'दोनों स्वामी मित्र हैं, और यह मित्रता घर्षण को कम करती है।',
        ),
      if (_isStrongDignity(st.placed.dignity))
        Bi(
          '${a.en} stands in ${_ownSignPhrase(st.placed.dignity).en}, so it is strong enough to hold its own.',
          '${a.hi} ${_ownSignPhrase(st.placed.dignity).hi} में है, इसलिए अपना पक्ष मज़बूती से रख सकता है।',
        ),
      if (st.bala != null && st.bala!.isStrong)
        const Bi(
          'Its shadbala clears its minimum, so it has the strength to hold its own.',
          'इसका षड्बल आवश्यक न्यूनतम से अधिक है, इसलिए यह अपना पक्ष रखने में समर्थ है।',
        ),
    ];
    relief = eases.isNotEmpty
        ? Bi(
            eases.map((Bi e) => e.en).join(' '),
            eases.map((Bi e) => e.hi).join(' '),
          )
        : Bi(
            'The usual reliefs are friendship between the two lords and strength in ${names.inner.en} lord (an own or exalted sign, or shadbala above its minimum). Neither is present here, so this is a stretch for adjusting.',
            'राहत के सामान्य आधार हैं दोनों स्वामियों की मित्रता और ${names.inner.hi} के स्वामी का बल (स्वराशि, उच्च राशि या आवश्यक से अधिक षड्बल)। यहाँ दोनों नहीं हैं, इसलिए यह तालमेल बिठाने का समय है।',
          );
  }
  final double bonus =
      _bandWeight(band) +
      switch (relation) {
        Relation.friend => 1.0,
        Relation.neutral => 0.0,
        Relation.enemy => -1.0,
      };
  return (
    text: _cat(<Bi>[position, relationText]),
    relief: relief,
    bonus: bonus,
    band: band,
    relation: relation,
  );
}

Bi _bandPredicate(_Band b) => switch (b) {
  _Band.easy => const Bi(
    'stands in a position the tradition counts as easy',
    'ऐसे स्थान पर है जिसे परंपरा सहज मानती है',
  ),
  _Band.gain => const Bi('stands in a supportive place', 'सहायक स्थान पर है'),
  _Band.effort => const Bi(
    'stands in a place of effort',
    'प्रयास के स्थान पर है',
  ),
  _Band.hard => const Bi('stands in a difficult place', 'कठिन स्थान पर है'),
};

/// The relation as a closing clause: "the two are friends".
Bi _relationWord(Relation r) => switch (r) {
  Relation.friend => const Bi('friends', 'मित्रता'),
  Relation.neutral => const Bi('neutral', 'सम भाव'),
  Relation.enemy => const Bi('at odds', 'शत्रुता'),
};

/// The relation as the tradition names it, for the list of factors.
Bi _relationBasis(Relation r) => switch (r) {
  Relation.friend => const Bi('natural friends', 'नैसर्गिक मित्र'),
  Relation.neutral => const Bi('neutral', 'सम'),
  Relation.enemy => const Bi('natural enemies', 'नैसर्गिक शत्रु'),
};

/// The period before, the period after and the periods around: no reading
/// stands alone.
Bi _neighbourSentence({
  required DashaPeriod period,
  required Graha? prev,
  required Graha? next,
  required Graha? parent,
  required Graha? grand,
}) {
  final int level = period.level;
  final Graha lord = period.lord;
  final Bi word = _levelWord(level);
  final List<Bi> parts = <Bi>[];
  Bi handover(Graha a, Graha b) {
    return switch (mutualRelation(a, b)) {
      Relation.friend => const Bi('an easy change of theme', 'सहज'),
      Relation.neutral => const Bi('a plain change of theme', 'सीधा-सादा'),
      Relation.enemy => const Bi(
        'a change of gears that asks for adjustment',
        'तालमेल माँगने वाला',
      ),
    };
  }

  if (prev == null) {
    if (level == 1) {
      final String remaining = (period.lengthDays / vimshottariYear)
          .toStringAsFixed(1);
      final String full = vimshottariYears[lord]!.toStringAsFixed(0);
      parts.add(
        Bi(
          'The ${_graha(lord).en} mahadasha was already running at birth, with $remaining of its $full years still to come.',
          '${_graha(lord).hi} की महादशा जन्म के समय पहले से चल रही थी, और उसके $full वर्षों में से $remaining वर्ष शेष थे।',
        ),
      );
    } else {
      parts.add(
        Bi(
          'This ${word.en} was already running at birth.',
          'यह ${word.hi} जन्म के समय पहले से चल रही थी।',
        ),
      );
    }
  } else {
    final Bi h = handover(prev, lord);
    parts.add(
      Bi(
        'It follows the ${_graha(prev).en} ${word.en}, and the move from ${_graha(prev).en} to ${_graha(lord).en} is ${h.en}.',
        'यह ${_graha(prev).hi} की ${word.hi} के बाद आती है, और ${_graha(prev).hi} से ${_graha(lord).hi} की ओर यह बदलाव ${h.hi} है।',
      ),
    );
  }
  if (next == null) {
    parts.add(
      Bi(
        'It is the last ${word.en} shown here.',
        'यह यहाँ दिखाई गई अंतिम ${word.hi} है।',
      ),
    );
  } else {
    final Bi h = handover(lord, next);
    parts.add(
      Bi(
        'It gives way to the ${_graha(next).en} ${word.en}, and that handover is ${h.en}.',
        'इसके बाद ${_graha(next).hi} की ${word.hi} आती है, और यह बदलाव ${h.hi} है।',
      ),
    );
  }
  if (parent != null) {
    final Bi up = _graha(parent);
    if (grand == null) {
      parts.add(
        Bi(
          'It sits inside the ${up.en} mahadasha, whose concerns (${_grahaThemes[parent]!.en}) stay in the background. The dasha sets the theme; this period brings one part of that theme to the front.',
          'यह ${up.hi} की महादशा के भीतर है, जिसके विषय (${_grahaThemes[parent]!.hi}) पृष्ठभूमि में बने रहते हैं। दशा विषय तय करती है; यह अवधि उस विषय के एक भाग को आगे लाती है।',
        ),
      );
    } else {
      parts.add(
        Bi(
          'It sits inside the ${up.en} antardasha of the ${_graha(grand).en} mahadasha, and both stay in the background.',
          'यह ${_graha(grand).hi} की महादशा में ${up.hi} की अंतर्दशा के भीतर है, और दोनों पृष्ठभूमि में बनी रहती हैं।',
        ),
      );
    }
  }
  return _cat(parts);
}

const Map<Ayanamsa, Bi> _ayanamsaNames = <Ayanamsa, Bi>{
  Ayanamsa.lahiri: Bi('Lahiri (Chitrapaksha)', 'लाहिरी (चित्रपक्ष)'),
  Ayanamsa.raman: Bi('Raman', 'रमन'),
  Ayanamsa.krishnamurti: Bi('Krishnamurti', 'कृष्णमूर्ति'),
  Ayanamsa.trueChitra: Bi('True Chitra', 'सत्य चित्रा'),
  Ayanamsa.pushyaPaksha: Bi('Pushya-paksha', 'पुष्य-पक्ष'),
};

/// The chart facts every dated reading rests on: where the count of periods
/// starts and the zodiac it was measured in.
List<Bi> _chartBasis(PhalaContext ctx) {
  final Kundli k = ctx.kundli;
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final DashaPeriod first = k.vimshottari.first;
  final String left = (first.lengthDays / vimshottariYear).toStringAsFixed(1);
  final String full = vimshottariYears[first.lord]!.toStringAsFixed(0);
  final Bi nak = Bi(moon.nakshatra.english, moon.nakshatra.hindi);
  final Bi lord = _graha(first.lord);
  final Bi ayanamsa = _ayanamsaNames[k.ayanamsa]!;
  return <Bi>[
    Bi('Lagna: ${ctx.lagnaName.en}', 'लग्न: ${ctx.lagnaName.hi}'),
    Bi(
      'Moon at birth: ${nak.en}, pada ${moon.pada}, in ${_sign(moon.rashi).en}',
      'जन्म के समय चंद्र: ${nak.hi} नक्षत्र, पाद ${moon.pada}, ${_sign(moon.rashi).hi} राशि में',
    ),
    Bi(
      'The Vimshottari count starts with ${lord.en}, lord of ${nak.en}; $left of its $full years remained at birth',
      'विंशोत्तरी गणना ${nak.hi} के स्वामी ${lord.hi} से आरंभ होती है; जन्म के समय उसके $full वर्षों में से $left वर्ष शेष थे',
    ),
    Bi('Ayanamsa: ${ayanamsa.en}', 'अयनांश: ${ayanamsa.hi}'),
  ];
}

PeriodReading _period(
  PhalaContext ctx,
  DashaPeriod p,
  List<DashaPeriod> ancestors,
  _Neighbours neighbours,
) {
  final int level = p.level;
  final Graha lord = p.lord;
  final GrahaStanding st = ctx.of(lord);
  final Graha? parent = ancestors.isNotEmpty ? ancestors.last.lord : null;
  final Graha? grand = ancestors.length > 1
      ? ancestors[ancestors.length - 2].lord
      : null;
  final GrahaStanding? pst = parent == null ? null : ctx.of(parent);
  final GrahaStanding? gst = grand == null ? null : ctx.of(grand);
  final Kundli k = ctx.kundli;
  final Bi me = _graha(lord);
  final Bi lagna = ctx.lagnaName;
  final bool sameLord = parent == lord;

  final ({Bi text, Bi? relief, double bonus, _Band band, Relation relation})?
  mod = parent == null ? null : _modifierFor(ctx, level, lord, parent);
  final int? place = parent == null
      ? null
      : _houseFromSign(
          k.grahas[parent]!.rashi.index,
          k.grahas[lord]!.rashi.index,
        );

  // The weighing: the lord's own promise, blended with the periods around it.
  double score = st.score;
  if (level == 2) {
    score = 0.55 * st.score + 0.45 * pst!.score + mod!.bonus;
  } else if (level == 3) {
    score = 0.5 * st.score + 0.3 * pst!.score + 0.2 * gst!.score + mod!.bonus;
  }
  final Tone tone = _toneOf(score);
  final List<LifeArea> areas = _areasOf(ctx, lord, backdrop: parent);

  // What the lord promises.
  final Bi natureLine = Bi(
    'For a ${lagna.en} lagna ${me.en} is ${_natureLabel(st.nature).en}.',
    '${lagna.hi} लग्न के लिए ${me.hi} ${_natureLabel(st.nature).hi} है।',
  );
  final List<Bi> promise = <Bi>[
    Bi(
      '${me.en} signifies ${_grahaThemes[lord]!.en}.',
      '${me.hi} ${_grahaThemes[lord]!.hi} का कारक है।',
    ),
    _lordshipSentence(ctx, st),
    _placementSentence(st),
  ];
  if (level == 1) {
    promise.add(st.natureWhy);
    final Bi? company = _companySentence(ctx, st);
    promise.addAll(<Bi>[?_dignityEffect(st), ?_conditionSentence(st)]);
    if (company != null) promise.add(company);
    promise.add(_strengthSentence(st));
  } else if (level == 2) {
    promise.addAll(<Bi>[
      natureLine,
      ?_dignityEffect(st),
      ?_conditionSentence(st),
      _strengthSentence(st),
    ]);
  }

  final Bi focus = _focusSentence(ctx, st, areas);
  final Bi asks = _asksSentence(_grahaAsks[lord]!, tone, _Subject.period);
  final Bi headline = Bi(
    '${areas.first.periodTitle.en} in focus · ${_toneWords(tone).en}',
    '${areas.first.periodTitle.hi} पर ज़ोर · ${_toneWords(tone).hi}',
  );

  final Bi lead;
  if (level == 1) {
    lead = _cat(<Bi>[focus, natureLine]);
  } else {
    final Bi up = _graha(parent!);
    final Bi intro = Bi(
      'Inside the ${up.en} ${level == 2 ? 'mahadasha' : 'antardasha'}, the ${me.en} ${_levelWord(level).en} brings its own concerns forward. ${focus.en}',
      '${up.hi} की ${level == 2 ? 'महादशा' : 'अंतर्दशा'} के भीतर ${me.hi} की ${_levelWord(level).hi} अपने विषयों को आगे लाती है। ${focus.hi}',
    );
    if (sameLord) {
      lead = _cat(<Bi>[intro, mod!.text]);
    } else {
      final Bi pred = _bandPredicate(mod!.band);
      final Bi rel = _relationWord(mod.relation);
      lead = _cat(<Bi>[
        intro,
        Bi(
          'Counted from ${up.en}, ${me.en} ${pred.en}, and the two are ${rel.en}.',
          '${up.hi} से गिनने पर ${me.hi} ${pred.hi}, और दोनों के बीच ${rel.hi} का संबंध है।',
        ),
      ]);
    }
  }
  final Bi summary = _cat(<Bi>[lead, asks]);

  // Why this: the lord's own standing, then the periods around it.
  final List<Bi> basis = <Bi>[
    ...st.basis.take(level == 1 ? st.basis.length : 4),
    if (parent != null) ...<Bi>[
      if (!sameLord) ...<Bi>[
        Bi(
          '${me.en} is the ${_ordEn[place!]} place from ${_graha(parent).en} in the natal chart',
          '${_graha(parent).hi} से ${me.hi} जन्म कुंडली में ${_ordHiOblique[place]} स्थान पर है',
        ),
        Bi(
          '${me.en} and ${_graha(parent).en}: ${_relationBasis(mod!.relation).en}',
          '${me.hi} और ${_graha(parent).hi}: ${_relationBasis(mod.relation).hi}',
        ),
      ],
      Bi(
        'Running inside the ${_graha(parent).en} ${level == 2 ? 'mahadasha' : 'antardasha'}, ${_graha(parent).en} being ${_natureLabel(pst!.nature).en} for a ${lagna.en} lagna',
        '${_graha(parent).hi} की ${level == 2 ? 'महादशा' : 'अंतर्दशा'} के भीतर, जो ${lagna.hi} लग्न के लिए ${_natureLabel(pst.nature).hi} है',
      ),
    ],
    if (level == 1 && neighbours.isFirst(p))
      Bi(
        'The Moon at birth stands in ${k.janmaNakshatra.english}, whose lord starts the Vimshottari count',
        'जन्म के समय चंद्र ${k.janmaNakshatra.hindi} नक्षत्र में है, जिसके स्वामी से विंशोत्तरी गणना आरंभ होती है',
      ),
  ];

  // The chart factors behind the band: the lord's own standing, then, for a
  // sub-period, where it stands from the period around it, how the two get on,
  // and how the period around it fares. Each of those is one fact.
  final List<IndicatorFactor> factors = <IndicatorFactor>[
    ...ctx.grahaFactors[lord]!,
  ];
  if (parent != null && !sameLord) {
    final Bi up = _graha(parent);
    final Bi from = _placeFrom(place!, parent);
    final List<Graha> pair = <Graha>[lord, parent];
    switch (mod!.band) {
      case _Band.easy:
        factors.add(
          IndicatorFactor(
            kind: FactorKind.period,
            eases: true,
            firm: true,
            grahas: pair,
            text: Bi(
              '${me.en} stands in ${from.en}, a position the tradition counts as easy',
              '${me.hi} ${from.hi} है, जिसे परंपरा सहज स्थिति मानती है',
            ),
          ),
        );
      case _Band.gain:
        factors.add(
          IndicatorFactor(
            kind: FactorKind.period,
            eases: true,
            firm: false,
            grahas: pair,
            text: Bi(
              '${me.en} stands in ${from.en}, a place of gain',
              '${me.hi} ${from.hi} है, जो लाभ का स्थान है',
            ),
          ),
        );
      case _Band.effort:
        break;
      case _Band.hard:
        factors.add(
          IndicatorFactor(
            kind: FactorKind.period,
            eases: false,
            firm: true,
            grahas: pair,
            text: Bi(
              '${me.en} stands in ${from.en}, a difficult position',
              '${me.hi} ${from.hi} है, जो कठिन स्थिति है',
            ),
          ),
        );
    }
    if (mod.relation != Relation.neutral) {
      final bool friends = mod.relation == Relation.friend;
      factors.add(
        IndicatorFactor(
          kind: FactorKind.period,
          eases: friends,
          firm: false,
          grahas: pair,
          text: Bi(
            '${me.en} and ${up.en} are ${_relationBasis(mod.relation).en}',
            '${me.hi} और ${up.hi} ${_relationBasis(mod.relation).hi} हैं',
          ),
        ),
      );
    }
  }
  void aroundIt(Graha around, GrahaStanding of, int aroundLevel, bool firm) {
    if (of.tone == Tone.mixed || around == lord) return;
    final bool well = of.tone == Tone.supportive;
    final Bi who = _graha(around);
    final Bi word = _levelWord(aroundLevel);
    factors.add(
      IndicatorFactor(
        kind: FactorKind.period,
        eases: well,
        firm: firm,
        grahas: <Graha>[around],
        text: well
            ? Bi(
                '${who.en}, whose ${word.en} this sits inside, is well placed in this chart',
                '${who.hi}, जिसकी ${word.hi} के भीतर यह है, इस कुंडली में अच्छी स्थिति में है',
              )
            : Bi(
                '${who.en}, whose ${word.en} this sits inside, is under strain in this chart',
                '${who.hi}, जिसकी ${word.hi} के भीतर यह है, इस कुंडली में दबाव में है',
              ),
      ),
    );
  }

  if (parent != null) aroundIt(parent, pst!, level - 1, true);
  if (grand != null && grand != parent) aroundIt(grand, gst!, level - 2, false);
  final Indication indication = Indication(tone, factors);
  final Bi? relief = _combineRelief(st.relief, mod?.relief);
  // A difficult period is one whose tone asks for effort, or one that rubs
  // against the period around it (the lord stands in the 6th, 8th or 12th
  // from that period's lord). A lord that is merely strained in its own right
  // has its remedies in the graha reading.
  final bool difficult =
      tone == Tone.demanding || (mod != null && mod.band == _Band.hard);
  final List<Remedy> remedies = difficult
      ? _remediesFor(
          factors,
          limit: 2,
          prefer: lord,
          fallback: lord,
          fallbackReason: Bi(
            'The rules weigh this ${_levelWord(level).en} as asking for effort, and ${me.en} is its lord',
            'नियम इस ${_levelWord(level).hi} को मेहनत माँगने वाला तौलते हैं, और ${me.hi} इसका स्वामी है',
          ),
        )
      : const <Remedy>[];

  // What tends to come up, as a tendency and never as an event.
  final Bi tends = _cat(<Bi>[
    _houseTends[areas.first.house - 1],
    if (level < 3 && areas.length > 1)
      Bi(
        'Alongside, matters of ${_lower(areas[1].periodTitle.en)} tend to stay in view.',
        'साथ ही ${areas[1].periodTitle.hi} की बातें नज़र में रहती हैं।',
      ),
    if (level < 3)
      Bi(
        '${me.en}’s own concerns, ${_grahaThemes[lord]!.en}, tend to colour all of it.',
        '${me.hi} के अपने विषय, यानी ${_grahaThemes[lord]!.hi}, इस सब पर रंग चढ़ाते हैं।',
      ),
    _toneTends(tone),
  ]);

  final List<PeriodReading> kids = <PeriodReading>[
    for (final DashaPeriod c in p.children)
      _period(ctx, c, <DashaPeriod>[...ancestors, p], neighbours),
  ];

  return PeriodReading(
    level: level,
    lord: lord,
    parentLord: parent,
    grandparentLord: grand,
    startJdUt: p.startJdUt,
    endJdUt: p.endJdUt,
    nature: st.nature,
    tone: tone,
    score: score,
    areas: areas,
    placeFromParent: place,
    relation: mod?.relation,
    headline: headline,
    lead: lead,
    summary: summary,
    promise: _cat(promise),
    modifier: mod?.text,
    context: _neighbourSentence(
      period: p,
      prev: neighbours.before(p),
      next: neighbours.after(p),
      parent: parent,
      grand: grand,
    ),
    asks: asks,
    relief: relief,
    indication: indication,
    tends: tends,
    remedies: remedies,
    basis: basis,
    children: kids,
  );
}

Bi? _combineRelief(Bi? a, Bi? b) {
  if (a == null) return b;
  if (b == null) return a;
  return _cat(<Bi>[a, b]);
}

/// The periods either side of each one at its own level, across the borders
/// of the period that contains it, so that a handover is always read.
class _Neighbours {
  _Neighbours(List<DashaPeriod> tree) {
    void walk(List<DashaPeriod> level) {
      for (final DashaPeriod p in level) {
        _byLevel.putIfAbsent(p.level, () => <DashaPeriod>[]).add(p);
        walk(p.children);
      }
    }

    walk(tree);
    _first = tree.first;
  }

  final Map<int, List<DashaPeriod>> _byLevel = <int, List<DashaPeriod>>{};
  late final DashaPeriod _first;

  bool isFirst(DashaPeriod p) => identical(p, _first);

  Graha? before(DashaPeriod p) {
    final List<DashaPeriod> all = _byLevel[p.level]!;
    final int i = all.indexWhere((DashaPeriod q) => identical(q, p));
    return i > 0 ? all[i - 1].lord : null;
  }

  Graha? after(DashaPeriod p) {
    final List<DashaPeriod> all = _byLevel[p.level]!;
    final int i = all.indexWhere((DashaPeriod q) => identical(q, p));
    return i >= 0 && i < all.length - 1 ? all[i + 1].lord : null;
  }
}

/// Every mahadasha, antardasha and pratyantardasha of the chart, read.
DashaPhala dashaPhala(PhalaContext ctx) {
  final List<DashaPeriod> tree = ctx.kundli.vimshottari;
  final _Neighbours neighbours = _Neighbours(tree);
  return DashaPhala(
    basis: _chartBasis(ctx),
    birth: ctx.kundli.instant.utc,
    mahadashas: <PeriodReading>[
      for (final DashaPeriod maha in tree)
        _period(ctx, maha, const <DashaPeriod>[], neighbours),
    ],
  );
}

// ---------------------------------------------------------------------------
// The life timeline
// ---------------------------------------------------------------------------

/// How far the timeline reads, in years from birth. The last window is the
/// antardasha running at that age, so it can end a little after.
const double lifeHorizonYears = 90;

/// One antardasha of one mahadasha: the dated window the person actually
/// lives in, read against the chapter it belongs to.
class TimelineWindow implements IndicatedReading {
  const TimelineWindow({
    required this.index,
    required this.maha,
    required this.period,
    required this.ageStartYears,
    required this.ageEndYears,
    required this.startsChapter,
    required this.expect,
    required this.tends,
    required this.asks,
  });

  final int index;

  /// The mahadasha this window belongs to.
  final PeriodReading maha;

  /// The antardasha itself, with its pratyantardashas as children.
  final PeriodReading period;
  final double ageStartYears;
  final double ageEndYears;

  /// True for the first window of a mahadasha.
  final bool startsChapter;

  /// What the tradition says to expect in this window.
  final Bi expect;

  /// What tends to come up. For the childhood years it is what the home and
  /// the family around the child carry, not the child's own choices.
  @override
  final Bi tends;

  /// What the window asks of the person. For the childhood years it is what
  /// the family around the child may carry, not a list of adult tasks.
  final Bi asks;

  Graha get mahaLord => maha.lord;
  Graha get antarLord => period.lord;
  DateTime get start => period.start;
  DateTime get end => period.end;

  /// The department of life the window concentrates on.
  LifeArea get area => period.area;
  List<LifeArea> get areas => period.areas;
  Tone get tone => period.tone;
  Bi? get relief => period.relief;

  @override
  Indication get indication => period.indication;

  @override
  List<Remedy> get remedies => period.remedies;

  @override
  Bi get headline => period.headline;

  @override
  List<Bi> get basis => period.basis;

  bool contains(DateTime moment) => period.contains(moment);

  @override
  Iterable<Bi> get texts => <Bi>[
    headline,
    expect,
    tends,
    asks,
    ?relief,
    ...indication.texts,
    ...remedyTexts(remedies),
    ...basis,
  ];
}

/// A mahadasha as a chapter of the timeline, with its windows.
class TimelineChapter {
  const TimelineChapter({required this.maha, required this.windows});

  final PeriodReading maha;
  final List<TimelineWindow> windows;

  DateTime get start => maha.start;
  DateTime get end => maha.end;
}

/// The deliverable: dated windows from birth to about ninety, in order, with no
/// gap and no overlap, each with the lords, a headline, what to expect and the
/// area of life it concentrates on.
class LifeTimeline implements PhalaReading {
  const LifeTimeline({
    required this.birth,
    required this.windows,
    required this.chapters,
    required this.basis,
  });

  final DateTime birth;
  final List<TimelineWindow> windows;
  final List<TimelineChapter> chapters;

  @override
  final List<Bi> basis;

  @override
  Bi get headline =>
      const Bi('Your life in dated windows', 'आपका जीवन, तिथि-बद्ध खंडों में');

  @override
  Iterable<Bi> get texts => <Bi>[headline, ...basis];

  DateTime get end => windows.last.end;

  TimelineWindow? windowAt(DateTime moment) {
    for (final TimelineWindow w in windows) {
      if (w.contains(moment)) return w;
    }
    return null;
  }
}

LifeTimeline lifeTimeline(PhalaContext ctx, DashaPhala dasha) {
  final double birthJd = ctx.kundli.instant.julianDayUt;
  final double horizonJd = birthJd + lifeHorizonYears * vimshottariYear;
  double age(double jd) => (jd - birthJd) / vimshottariYear;

  final List<TimelineWindow> windows = <TimelineWindow>[];
  final List<TimelineChapter> chapters = <TimelineChapter>[];
  for (final PeriodReading maha in dasha.mahadashas) {
    final List<TimelineWindow> mine = <TimelineWindow>[];
    for (final PeriodReading antar in maha.children) {
      if (antar.startJdUt >= horizonJd) break;
      final double from = age(antar.startJdUt);
      final double to = age(antar.endJdUt);
      final bool childhood = from < 16;
      // A child is not asked to keep a temper in check or to deal with
      // authority; for the early years the reading says what the home carries.
      final Bi expect = childhood
          ? _cat(<Bi>[
              antar.lead,
              const Bi(
                'These are childhood years, so many astrologers read such a window through the home and the family around you rather than through your own choices.',
                'ये बचपन के वर्ष हैं, इसलिए अनेक ज्योतिषी ऐसी अवधि को आपके अपने चुनावों से ज़्यादा आपके घर और परिवार की स्थितियों के आधार पर देखते हैं।',
              ),
            ])
          : antar.summary;
      final Bi asks = childhood
          ? const Bi(
              'For a child this theme is mostly carried by the family around them; what it asks is steady care and a regular routine.',
              'बचपन में इस विषय को अधिकतर आसपास का परिवार निभाता है; इसमें स्थिर देखभाल और नियमित दिनचर्या की ज़रूरत रहती है।',
            )
          : antar.asks;
      final Bi tends = childhood
          ? Bi(
              'In these childhood years, matters of ${_lower(antar.area.periodTitle.en)} tend to show up through the home and the family around the child rather than through the child’s own choices. ${_toneTends(antar.tone).en}',
              'बचपन के इन वर्षों में ${antar.area.periodTitle.hi} की बातें बच्चे के अपने चुनावों से ज़्यादा घर और आसपास के परिवार के ज़रिए सामने आती हैं। ${_toneTends(antar.tone).hi}',
            )
          : antar.tends;
      final TimelineWindow window = TimelineWindow(
        index: windows.length,
        maha: maha,
        period: antar,
        ageStartYears: from < 0 ? 0 : from,
        ageEndYears: to,
        startsChapter: mine.isEmpty,
        expect: expect,
        tends: tends,
        asks: asks,
      );
      mine.add(window);
      windows.add(window);
    }
    if (mine.isNotEmpty) {
      chapters.add(TimelineChapter(maha: maha, windows: mine));
    }
  }
  return LifeTimeline(
    basis: <Bi>[
      ..._chartBasis(ctx),
      Bi(
        'Read to age ${lifeHorizonYears.round()}; the last window is the antardasha running then',
        '${lifeHorizonYears.round()} वर्ष की आयु तक पढ़ा गया; अंतिम खंड उस समय चल रही अंतर्दशा है',
      ),
    ],
    birth: ctx.kundli.instant.utc,
    windows: windows,
    chapters: chapters,
  );
}

// ---------------------------------------------------------------------------
// Gochar phala
// ---------------------------------------------------------------------------

/// The slow grahas, whose transits the tradition weighs most. The fast ones
/// change sign too often to date usefully.
const List<Graha> gocharGrahas = <Graha>[
  Graha.saturn,
  Graha.jupiter,
  Graha.rahu,
  Graha.ketu,
];

/// One heavy transit read against the natal chart, with the dates it entered
/// the sign and leaves it.
class GocharReading implements IndicatedReading {
  const GocharReading({
    required this.graha,
    required this.sign,
    required this.houseFromMoon,
    required this.houseFromLagna,
    required this.favourable,
    required this.isRetrograde,
    required this.signBindus,
    required this.ownBindus,
    required this.entered,
    required this.leaves,
    required this.area,
    required this.tone,
    required this.landsOnDasha,
    required this.headline,
    required this.reading,
    required this.asks,
    required this.relief,
    required this.indication,
    required this.tends,
    required this.remedies,
    required this.basis,
  });

  final Graha graha;
  final Rashi sign;
  final int houseFromMoon;
  final int houseFromLagna;

  /// Whether the tradition counts this house from the Moon favourable for it.
  final bool favourable;
  final bool isRetrograde;
  final int signBindus;

  /// Bindus in the graha's own ashtakavarga for this sign; null for the nodes.
  final int? ownBindus;
  final DateTime? entered;

  /// The first moment it stands outside the sign. A retrograde graha can step
  /// back across the line.
  final DateTime? leaves;

  /// The department of life the transit touches, counted from the lagna.
  final LifeArea area;
  final Tone tone;

  /// True when the transit falls on an area the running dasha already
  /// concerns: where the dasha promises, the transit delivers.
  final bool landsOnDasha;

  @override
  final Bi headline;
  final Bi reading;
  final Bi asks;
  final Bi? relief;

  /// How strongly the chart points at this transit's tone, with the factors:
  /// the house from the Moon, the bindus, the sign it passes through and what
  /// the graha is in the natal chart.
  @override
  final Indication indication;

  /// What tends to come up in the area of life the transit touches.
  @override
  final Bi tends;

  /// The remedies for a testing transit. Empty when the transit is not one.
  @override
  final List<Remedy> remedies;

  @override
  final List<Bi> basis;

  @override
  Iterable<Bi> get texts => <Bi>[
    headline,
    reading,
    tends,
    asks,
    ?relief,
    ...indication.texts,
    ...remedyTexts(remedies),
    ...basis,
  ];
}

class GocharPhala implements PhalaReading {
  const GocharPhala({
    required this.moment,
    required this.readings,
    required this.principle,
    required this.running,
    required this.sadeSati,
    required this.basis,
  });

  final DateTime moment;
  final List<GocharReading> readings;

  /// "The dasha promises and the transit delivers", as the frame for reading.
  final Bi principle;

  /// The dasha chain the transits were read against.
  final List<PeriodReading> running;

  /// Saturn's passage over the natal Moon, when it is running.
  final Bi? sadeSati;

  @override
  final List<Bi> basis;

  @override
  Bi get headline => const Bi('Transits now', 'अभी का गोचर');

  @override
  Iterable<Bi> get texts => <Bi>[
    headline,
    principle,
    ?sadeSati,
    ...basis,
    for (final GocharReading r in readings) ...r.texts,
  ];
}

GocharPhala gocharPhala(PhalaContext ctx, DashaPhala dasha, {DateTime? now}) {
  final DateTime moment = (now ?? DateTime.now()).toUtc();
  final Kundli k = ctx.kundli;
  final TransitReport report = computeTransits(k, moment);
  final List<PeriodReading> running = dasha.chainAt(moment);
  final Set<int> dashaHouses = <int>{
    for (final PeriodReading p in running)
      for (final LifeArea a in p.areas) a.house,
  };
  final Duration zone = ctx.zone;
  final Bi lagna = ctx.lagnaName;

  final List<GocharReading> readings = <GocharReading>[];
  for (final Graha g in gocharGrahas) {
    final TransitPosition t = report.positions[g]!;
    final SignStay stay = signStayAt(g, moment, k.ayanamsa);
    final bool favourable = report.isFavourable(g);
    final int? own = g == Graha.rahu || g == Graha.ketu
        ? null
        : ctx.ashtakavarga.charts[g]?.bindus[t.rashi.index];
    final int hm = t.houseFromMoon;
    final int hl = t.houseFromLagna;
    final LifeArea area = LifeArea.values[hl - 1];
    final Bi me = _graha(g);
    final Bi sign = _sign(t.rashi);
    final List<int> good = favourableFromMoon[g]!;
    const List<String> phaseHi = <String>['', 'पहला', 'दूसरा', 'तीसरा'];

    // The tone: the house from the Moon and the bindus are two tests, and
    // when they disagree the reading says so.
    final bool bindusGood = own != null ? own >= 4 : t.bindusInSign >= 30;
    final Tone tone = favourable && bindusGood
        ? Tone.supportive
        : (!favourable && !bindusGood ? Tone.demanding : Tone.mixed);

    final List<Bi> parts = <Bi>[
      Bi(
        '${me.en} is in ${sign.en}${t.isRetrograde ? ' and retrograde' : ''}: the ${_ordEn[hm]} house from your natal Moon and the ${_ordEn[hl]} from the lagna.',
        '${me.hi} ${sign.hi} राशि में है${t.isRetrograde ? ' और वक्री है' : ''}: जन्म चंद्र से ${_ordHiOblique[hm]} भाव में और लग्न से ${_ordHiOblique[hl]} भाव में।',
      ),
    ];
    if (stay.entered != null && stay.leaves != null) {
      final Bi a = phalaDate(stay.entered!, zone);
      final Bi b = phalaDate(stay.leaves!, zone);
      parts.add(
        Bi(
          'It most recently crossed into this sign on ${a.en} and first leaves it on ${b.en}.${t.isRetrograde || g == Graha.saturn || g == Graha.jupiter ? ' A graha that turns retrograde can step back across the line, so the second date is the first time it leaves.' : ''}',
          'यह इस राशि में सबसे हाल में ${a.hi} को आया और ${b.hi} को पहली बार इससे निकलेगा।${t.isRetrograde || g == Graha.saturn || g == Graha.jupiter ? ' वक्री होने वाला ग्रह पिछली राशि में लौट भी सकता है, इसलिए दूसरी तिथि उसके पहली बार इस राशि से निकलने की है।' : ''}',
        ),
      );
    } else if (stay.leaves != null) {
      final Bi b = phalaDate(stay.leaves!, zone);
      parts.add(
        Bi(
          'It has been in this sign for a long while and leaves it on ${b.en}.',
          'यह इस राशि में काफ़ी समय से है और ${b.hi} को निकलेगा।',
        ),
      );
    }
    parts.add(
      Bi(
        'Counting from the Moon, a commonly used table calls ${me.en}’s transit favourable in the ${_listEn(good.map((int h) => _ordEn[h]).toList())} houses; vedha, the obstruction that can cancel that, is not applied here. The ${_ordEn[hm]} is ${favourable ? 'one of them' : 'not among them'}.',
        'चंद्र से गिनने पर प्रचलित तालिका ${me.hi} के गोचर को ${_listHi(good.map((int h) => _ordHiOblique[h]).toList())} भाव में अनुकूल मानती है; वेध, जो इसे निष्फल कर सकता है, यहाँ लागू नहीं किया गया है। ${_ordHiDirect[hm]} भाव ${favourable ? 'उनमें से एक है' : 'उनमें नहीं है'}।',
      ),
    );
    if (own != null) {
      parts.add(
        Bi(
          'In ${me.en}’s own ashtakavarga this sign holds $own bindus (four or more supports a transit, three or fewer is thin), and the sign carries ${t.bindusInSign} sarvashtakavarga bindus.',
          '${me.hi} के भिन्नाष्टकवर्ग में इस राशि के $own बिंदु हैं (चार या अधिक बिंदु गोचर को सहारा देते हैं, तीन या कम बिंदु क्षीण माने जाते हैं), और इस राशि में सर्वाष्टकवर्ग के ${t.bindusInSign} बिंदु हैं।',
        ),
      );
    } else {
      parts.add(
        Bi(
          'The nodes have no ashtakavarga of their own; the sign carries ${t.bindusInSign} sarvashtakavarga bindus, and this app counts 30 or more as good.',
          'राहु और केतु का अपना भिन्नाष्टकवर्ग नहीं होता; इस राशि में सर्वाष्टकवर्ग के ${t.bindusInSign} बिंदु हैं, और यहाँ तीस या अधिक बिंदु अच्छे गिने गए हैं।',
        ),
      );
    }
    parts.add(
      favourable && bindusGood
          ? const Bi(
              'Both tests agree, so this transit is supportive.',
              'दोनों पैमाने एकमत हैं, इसलिए यह गोचर सहायक है।',
            )
          : (!favourable && !bindusGood
                ? const Bi(
                    'Both tests point the same way: this transit asks for effort.',
                    'दोनों पैमाने एक ही ओर संकेत करते हैं: यह गोचर परिश्रम माँगता है।',
                  )
                : (favourable
                      ? const Bi(
                          'The house is a favourable one but the bindus are thin, so the support arrives smaller than it looks.',
                          'भाव अनुकूल है पर बिंदु कम हैं, इसलिए सहारा अपेक्षा से कम मिलता है।',
                        )
                      : const Bi(
                          'The house is a testing one, but the bindus are good, so the pressure is softened.',
                          'भाव चुनौती वाला है, पर बिंदु अच्छे हैं, इसलिए दबाव घटता है।',
                        ))),
    );

    // Saturn carries the long tests the tradition names.
    Bi? reliefText;
    if (g == Graha.saturn) {
      final SadeSatiWindow ss = report.sadeSati;
      if (ss.isRunning) {
        final Bi until = ss.end == null
            ? const Bi('a date not yet found', 'अभी अज्ञात तिथि')
            : phalaDate(ss.end!, zone);
        final Bi phaseEnd = ss.phaseEnd == null
            ? until
            : phalaDate(ss.phaseEnd!, zone);
        parts.add(
          Bi(
            'Sade Sati is running, phase ${ss.phase} of three. This phase ends on ${phaseEnd.en} and the whole passage on ${until.en}. It is counted by sign, while Saturn crosses the 12th, 1st and 2nd from the natal Moon. Traditionally it is seen as a testing stretch; here it is read as a time that asks for work and responsibility, not as punishment.',
            'साढ़ेसाती चल रही है, तीन में से ${phaseHi[ss.phase]} चरण। यह चरण ${phaseEnd.hi} को समाप्त होगा और पूरी साढ़ेसाती ${until.hi} को। इसकी गणना राशि के अनुसार होती है, जब शनि जन्म चंद्र से बारहवें, पहले और दूसरे भाव से गुज़रता है। परंपरा में इसे कसौटी का समय माना गया है; यहाँ इसे ऐसे समय की तरह पढ़ा गया है जो परिश्रम और ज़िम्मेदारी माँगता है, दंड की तरह नहीं।',
          ),
        );
      } else if (hm == 4) {
        parts.add(
          const Bi(
            'Saturn in the 4th from the Moon is popularly called dhaiya, a long stretch that asks for patience in home matters and peace of mind; it passes.',
            'शनि का चंद्र से चौथे भाव में होना लोक में ढैया कहलाता है; यह लंबा समय घर और मन की शांति से जुड़े मामलों में धैर्य माँगता है, और यह बीत जाता है।',
          ),
        );
      } else if (hm == 8) {
        parts.add(
          const Bi(
            'Saturn in the 8th from the Moon is popularly called dhaiya, a long stretch that asks for patience over shared resources and change; it passes.',
            'शनि का चंद्र से आठवें भाव में होना लोक में ढैया कहलाता है; यह लंबा समय साझा संसाधनों और बदलाव के मामलों में धैर्य माँगता है, और यह बीत जाता है।',
          ),
        );
      }
    }
    if (!favourable) {
      reliefText = (own != null && own >= 4)
          ? Bi(
              '${me.en} holds $own bindus in this sign, and four or more is read as softening a testing house.',
              'इस राशि में ${me.hi} के $own बिंदु हैं, और चार या अधिक बिंदु चुनौती वाले भाव को हल्का करते हैं।',
            )
          : const Bi(
              'Many practitioners weigh the running dasha above the transit, so a testing transit is read together with the period it falls in. It stays until the date above and then moves on.',
              'अनेक ज्योतिषी गोचर से अधिक चल रही दशा को महत्व देते हैं, इसलिए चुनौती वाले गोचर को उस अवधि के साथ जोड़कर देखा जाता है जिसमें वह पड़ता है। यह ऊपर बताई गई तिथि तक रहता है, फिर आगे बढ़ जाता है।',
            );
    }

    final bool lands = dashaHouses.contains(hl);
    parts.add(
      lands
          ? Bi(
              'It lands on ${_houseObl(hl).en} (${area.periodTitle.en}), an area the running periods already concern: where the dasha promises, the transit delivers.',
              'यह ${_houseObl(hl).hi} (${area.periodTitle.hi}) में है; यह वही क्षेत्र है जिससे चल रही अवधियाँ पहले से जुड़ी हैं: जहाँ दशा संकेत देती है, वहीं गोचर फल देता है।',
            )
          : Bi(
              'It falls on ${_houseObl(hl).en} (${area.periodTitle.en}), outside the areas the running periods concern, so its effect stays in the background rather than leading.',
              'यह ${_houseObl(hl).hi} (${area.periodTitle.hi}) में है, जो चल रही अवधियों के क्षेत्रों से बाहर है, इसलिए इसका असर पृष्ठभूमि में रहता है, यह अगुआई नहीं करता।',
            ),
    );

    // The chart factors behind the band, one fact each.
    final GrahaStanding natal = ctx.of(g);
    final List<Graha> byGraha = <Graha>[g];
    final List<IndicatorFactor> factors = <IndicatorFactor>[];
    void note(FactorKind kind, bool eases, bool firm, Bi text) => factors.add(
      IndicatorFactor(
        kind: kind,
        text: text,
        eases: eases,
        firm: firm,
        grahas: byGraha,
      ),
    );
    note(
      FactorKind.transit,
      favourable,
      true,
      Bi(
        '${me.en} is in the ${_ordEn[hm]} house from the natal Moon, which the usual table ${favourable ? 'counts favourable' : 'does not count among the favourable houses'}',
        '${me.hi} जन्म चंद्र से ${_ordHiOblique[hm]} भाव में है, जिसे प्रचलित तालिका ${favourable ? 'अनुकूल मानती है' : 'अनुकूल भावों में नहीं गिनती'}',
      ),
    );
    if (own != null) {
      if (own >= 4) {
        note(
          FactorKind.ashtakavarga,
          true,
          true,
          Bi(
            '${me.en} holds $own bindus in its own ashtakavarga for this sign (four or more supports a transit)',
            'इस राशि में ${me.hi} के अपने अष्टकवर्ग के $own बिंदु हैं (चार या अधिक बिंदु गोचर को सहारा देते हैं)',
          ),
        );
      } else {
        note(
          FactorKind.ashtakavarga,
          false,
          true,
          Bi(
            '${me.en} holds only $own bindus in its own ashtakavarga for this sign (three or fewer is thin)',
            'इस राशि में ${me.hi} के अपने अष्टकवर्ग के सिर्फ़ $own बिंदु हैं (तीन या उससे कम हल्की गिनती है)',
          ),
        );
      }
    }
    if (t.bindusInSign >= 30) {
      note(
        FactorKind.ashtakavarga,
        true,
        own == null,
        Bi(
          'The sign carries ${t.bindusInSign} sarvashtakavarga bindus, a strong count',
          'इस राशि में सर्वाष्टकवर्ग के ${t.bindusInSign} बिंदु हैं, जो अच्छी गिनती है',
        ),
      );
    } else if (t.bindusInSign <= 24) {
      note(
        FactorKind.ashtakavarga,
        false,
        own == null,
        Bi(
          'The sign carries only ${t.bindusInSign} sarvashtakavarga bindus, a light count',
          'इस राशि में सर्वाष्टकवर्ग के सिर्फ़ ${t.bindusInSign} बिंदु हैं, जो कम गिनती है',
        ),
      );
    }
    final Dignity? passing = _signDignity(g, t.rashi);
    if (passing != null) {
      note(
        FactorKind.dignity,
        passing != Dignity.debilitated,
        true,
        Bi(
          'In transit ${me.en} passes through ${sign.en}, ${_dignityPhrase(passing).en}',
          'गोचर में ${me.hi} ${sign.hi} से गुज़र रहा है, जो ${_dignityPhrase(passing).hi} है',
        ),
      );
    }
    switch (natal.nature) {
      case FunctionalNature.yogakaraka:
      case FunctionalNature.benefic:
        note(
          FactorKind.nature,
          true,
          false,
          Bi(
            'In the natal chart ${me.en} is ${_natureLabel(natal.nature).en} for the ${lagna.en} lagna',
            'जन्म कुंडली में ${me.hi} ${lagna.hi} लग्न के लिए ${_natureLabel(natal.nature).hi} है',
          ),
        );
      case FunctionalNature.malefic:
        note(
          FactorKind.nature,
          false,
          false,
          Bi(
            'In the natal chart ${me.en} is ${_natureLabel(natal.nature).en} for the ${lagna.en} lagna',
            'जन्म कुंडली में ${me.hi} ${lagna.hi} लग्न के लिए ${_natureLabel(natal.nature).hi} है',
          ),
        );
      case FunctionalNature.mixed:
        break;
    }
    final IndicatorFactor? natalBala = _shadbalaFactor(
      natal.bala,
      '${me.en}’s natal',
      'जन्म कुंडली में ${me.hi}',
      byGraha,
      allowFirm: false,
    );
    if (natalBala != null && (natalBala.eases || natal.bala!.ratio < 0.8)) {
      factors.add(natalBala);
    }
    final Indication indication = Indication(tone, factors);
    final List<Remedy> remedies = !favourable || tone == Tone.demanding
        ? _remediesFor(
            factors,
            limit: 1,
            fallback: g,
            fallbackReason: Bi(
              'The rules weigh this ${me.en} transit as asking for effort',
              'नियम ${me.hi} के इस गोचर को मेहनत माँगने वाला तौलते हैं',
            ),
          )
        : const <Remedy>[];
    final Bi tends = _cat(<Bi>[
      _houseTends[hl - 1],
      _transitTends[g]!,
      _toneTends(tone),
      lands
          ? const Bi(
              'Because the running periods already concern this area, it tends to be at the front rather than in the background.',
              'चल रही अवधियाँ पहले से इसी क्षेत्र से जुड़ी हैं, इसलिए यह क्षेत्र अक्सर पृष्ठभूमि में नहीं, सामने रहता है।',
            )
          : const Bi(
              'Because the running periods concern other areas, this one tends to stay in the background.',
              'चल रही अवधियाँ दूसरे क्षेत्रों से जुड़ी हैं, इसलिए यह क्षेत्र अक्सर पृष्ठभूमि में रहता है।',
            ),
    ]);

    readings.add(
      GocharReading(
        graha: g,
        sign: t.rashi,
        houseFromMoon: hm,
        houseFromLagna: hl,
        favourable: favourable,
        isRetrograde: t.isRetrograde,
        signBindus: t.bindusInSign,
        ownBindus: own,
        entered: stay.entered,
        leaves: stay.leaves,
        area: area,
        tone: tone,
        landsOnDasha: lands,
        headline: Bi(
          '${me.en} in ${sign.en}, ${_ordEn[hm]} from the Moon: ${_houseToneWords(tone).en}',
          '${me.hi} ${sign.hi} राशि में, चंद्र से ${_ordHiOblique[hm]} भाव में: ${_houseToneWords(tone).hi}',
        ),
        reading: _cat(parts),
        asks: _asksSentence(_grahaAsks[g]!, tone, _Subject.transit),
        relief: reliefText,
        indication: indication,
        tends: tends,
        remedies: remedies,
        basis: <Bi>[
          Bi(
            '${me.en} today: ${sign.en}${t.isRetrograde ? ' (retrograde)' : ''}',
            'आज ${me.hi}: ${sign.hi} राशि${t.isRetrograde ? ' (वक्री)' : ''}',
          ),
          Bi(
            'House from natal Moon (${_sign(k.moonRashi).en}): ${_ordEn[hm]}',
            'जन्म चंद्र (${_sign(k.moonRashi).hi}) से भाव: ${_ordHiDirect[hm]}',
          ),
          Bi(
            'House from the ${lagna.en} lagna: ${_ordEn[hl]}',
            '${lagna.hi} लग्न से भाव: ${_ordHiDirect[hl]}',
          ),
          if (own != null)
            Bi(
              'Ashtakavarga: $own bindus own, ${t.bindusInSign} in the sign',
              'भिन्नाष्टकवर्ग: $own बिंदु; सर्वाष्टकवर्ग: राशि में ${t.bindusInSign} बिंदु',
            )
          else
            Bi(
              'Sarvashtakavarga: ${t.bindusInSign} bindus in the sign',
              'सर्वाष्टकवर्ग: राशि में ${t.bindusInSign} बिंदु',
            ),
          if (running.isNotEmpty)
            Bi(
              'Running periods: ${running.map((PeriodReading p) => grahaInfo(p.lord).english).join(' – ')}',
              'चल रही अवधियाँ: ${running.map((PeriodReading p) => grahaInfo(p.lord).hindi).join(' – ')}',
            ),
        ],
      ),
    );
  }

  final SadeSatiWindow ss = report.sadeSati;
  Bi? sadeSati;
  if (ss.isRunning) {
    final Bi until = ss.end == null
        ? const Bi('a date not yet found', 'अभी अज्ञात तिथि')
        : phalaDate(ss.end!, zone);
    sadeSati = Bi(
      'Sade Sati: phase ${ss.phase} of three, until ${until.en}.',
      'साढ़ेसाती: तीन में से ${const <String>['', 'पहला', 'दूसरा', 'तीसरा'][ss.phase]} चरण, ${until.hi} तक।',
    );
  }

  return GocharPhala(
    basis: <Bi>[
      Bi(
        'Positions on ${phalaDate(moment, zone).en}',
        'गोचर की स्थिति ${phalaDate(moment, zone).hi} की',
      ),
      Bi(
        'Natal Moon: ${_sign(k.moonRashi).en}; lagna: ${lagna.en}',
        'जन्म चंद्र: ${_sign(k.moonRashi).hi}; लग्न: ${lagna.hi}',
      ),
      if (running.isNotEmpty)
        Bi(
          'Running periods: ${running.map((PeriodReading p) => grahaInfo(p.lord).english).join(' – ')}',
          'चल रही अवधियाँ: ${running.map((PeriodReading p) => grahaInfo(p.lord).hindi).join(' – ')}',
        ),
    ],
    moment: moment,
    readings: readings,
    principle: const Bi(
      'The dasha promises and the transit delivers. Each transit below is read against the periods running now, and a period is never read alone.',
      'दशा संकेत देती है और गोचर फल देता है। नीचे हर गोचर को अभी चल रही अवधियों के साथ पढ़ा गया है, और कोई अवधि अकेली नहीं पढ़ी जाती।',
    ),
    running: running,
    sadeSati: sadeSati,
  );
}

// ---------------------------------------------------------------------------
// Everything together
// ---------------------------------------------------------------------------

/// The whole of phaladesh for one chart. The heavy work happens once: the
/// context holds shadbala, ashtakavarga and every graha's standing, and the
/// readings are put together from it. Gochar is read separately, because it
/// depends on the moment asked for and needs the ephemeris.
class Phaladesh {
  const Phaladesh({
    required this.context,
    required this.bhavas,
    required this.grahas,
    required this.dasha,
    required this.timeline,
  });

  final PhalaContext context;
  final List<BhavaReading> bhavas;
  final List<GrahaReading> grahas;
  final DashaPhala dasha;
  final LifeTimeline timeline;

  GocharPhala gochar({DateTime? now}) => gocharPhala(context, dasha, now: now);

  /// Every piece of text the chart's readings produce, apart from gochar.
  Iterable<Bi> get texts => <Bi>[
    ...dasha.texts,
    ...timeline.texts,
    for (final BhavaReading b in bhavas) ...b.texts,
    for (final GrahaReading g in grahas) ...g.texts,
    for (final PeriodReading m in dasha.mahadashas) ...m.texts,
    for (final TimelineWindow w in timeline.windows) ...w.texts,
  ];
}

Phaladesh computePhaladesh(Kundli kundli, {Map<Graha, BalaBreakdown>? bala}) {
  final PhalaContext ctx = PhalaContext(kundli, bala: bala);
  final DashaPhala dasha = dashaPhala(ctx);
  return Phaladesh(
    context: ctx,
    bhavas: bhavaPhala(ctx),
    grahas: grahaPhala(ctx),
    dasha: dasha,
    timeline: lifeTimeline(ctx, dasha),
  );
}
