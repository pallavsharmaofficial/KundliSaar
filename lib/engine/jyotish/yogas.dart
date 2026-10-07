import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';

// =============================================================================
// Yogas and doshas.
//
// Every finding in this file obeys the same house rules as the answer engine:
//
//  * it names the chart factors it was read from, in both languages;
//  * a dosha never stands alone: it carries a classical cancellation when the
//    chart satisfies one, and otherwise says what the tradition asks of the
//    person in that stretch of life, never a verdict;
//  * it states what the factor governs as an area of life and a disposition.
//    It never predicts an event, a date, a death, an illness, a pregnancy, an
//    exam, a court outcome or an investment return;
//  * a citation is given only where the condition was checked against the text
//    itself. Where a combination comes from later or popular practice the
//    finding says so instead of borrowing a classical name.
//
// Texts checked while writing this file (the Sanskrit of each verse was read,
// not a summary of it): Brihat Parashara Hora Shastra chapter 35 (the Nabhasa
// yogas), chapter 36 (Gajakesari, Amalakirti, Parvata, Kahala, Chamara, Lakshmi,
// Kalanidhi), chapter 37 (Adhi, Sunapha, Anapha, Duradhara, Kemadruma) and
// chapter 74 (Sudarshana Chakra). The combinations credited to B. V. Raman's
// "Three Hundred Important Combinations" were cross-checked against the
// PyJHora implementation (GitHub, naturalstupid/PyJHora), whose docstrings cite
// that book. Where the two disagreed, the more widely published reading is used
// and the disagreement is noted beside the rule.
// =============================================================================

/// Which shelf of the library a finding belongs to, so a screen can group them.
enum YogaFamily {
  general,
  rajaDhana,
  vipreetRaja,
  chandra,
  surya,
  nabhasa,
  dosha,
}

extension YogaFamilyTitle on YogaFamily {
  String get english => switch (this) {
    YogaFamily.general => 'Classical yogas',
    YogaFamily.rajaDhana => 'Raja and Dhana yogas',
    YogaFamily.vipreetRaja => 'Vipreet Raja yogas',
    YogaFamily.chandra => 'Moon yogas',
    YogaFamily.surya => 'Sun yogas',
    YogaFamily.nabhasa => 'Nabhasa yogas',
    YogaFamily.dosha => 'Doshas',
  };

  String get hindi => switch (this) {
    YogaFamily.general => 'शास्त्रीय योग',
    YogaFamily.rajaDhana => 'राज और धन योग',
    YogaFamily.vipreetRaja => 'विपरीत राजयोग',
    YogaFamily.chandra => 'चंद्र योग',
    YogaFamily.surya => 'सूर्य योग',
    YogaFamily.nabhasa => 'नाभस योग',
    YogaFamily.dosha => 'दोष',
  };
}

/// A yoga or dosha the chart actually carries, with the rule that fired.
class YogaFinding {
  const YogaFinding({
    required this.key,
    required this.nameEnglish,
    required this.nameHindi,
    required this.isDosha,
    required this.ruleEnglish,
    required this.ruleHindi,
    required this.meaningEnglish,
    required this.meaningHindi,
    this.cancellationEnglish,
    this.cancellationHindi,
    this.family = YogaFamily.general,
    this.sourceEnglish,
    this.sourceHindi,
    this.factorsEnglish = const <String>[],
    this.factorsHindi = const <String>[],
    this.mitigationEnglish,
    this.mitigationHindi,
  });

  final String key;
  final String nameEnglish;
  final String nameHindi;
  final bool isDosha;

  /// The condition in the chart that produced this finding.
  final String ruleEnglish;
  final String ruleHindi;
  final String meaningEnglish;
  final String meaningHindi;

  /// What classical texts say weakens or cancels it, when something does.
  final String? cancellationEnglish;
  final String? cancellationHindi;

  /// The shelf of the library this belongs to.
  final YogaFamily family;

  /// Where the condition comes from, and how far to trust the attribution.
  final String? sourceEnglish;
  final String? sourceHindi;

  /// The individual chart factors the finding was read from, one short line
  /// each ("Jupiter: Sagittarius, house 5"), in both languages.
  final List<String> factorsEnglish;
  final List<String> factorsHindi;

  /// For an adverse finding with no classical cancellation in this chart: what
  /// the tradition asks of the person, or how practitioners soften it. It is a
  /// way of living with the factor, never a verdict.
  final String? mitigationEnglish;
  final String? mitigationHindi;

  bool get isCancelled => cancellationEnglish != null;

  /// True when an adverse finding carries either a cancellation or a
  /// mitigation, which is the rule every dosha has to meet.
  bool get hasRelief =>
      cancellationEnglish != null || mitigationEnglish != null;
}

const List<int> _kendras = <int>[1, 4, 7, 10];
const List<int> _trikonas = <int>[1, 5, 9];
const List<int> _dusthanas = <int>[6, 8, 12];

int _houseFrom(int fromSign, int ofSign) => ((ofSign - fromSign + 12) % 12) + 1;

// -----------------------------------------------------------------------------
// Language helpers.
// -----------------------------------------------------------------------------

/// A statement in both languages.
class _T {
  const _T(this.en, this.hi);

  final String en;
  final String hi;
}

const List<String> _hiOrdinal = <String>[
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

String _enOrd(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

String _gEn(Graha g) => grahaInfo(g).english;
String _gHi(Graha g) => grahaInfo(g).hindi;
String _sEn(int sign) => rashiInfo(Rashi.values[sign % 12]).english;
String _sHi(int sign) => rashiInfo(Rashi.values[sign % 12]).hindi;

String _listEn(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

String _listHi(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} और ${parts.last}';
}

/// Joins statements into one sentence-per-statement paragraph.
_T _join(List<_T> parts) => _T(
  parts.map((_T t) => t.en.trim()).where((String t) => t.isNotEmpty).join(' '),
  parts.map((_T t) => t.hi.trim()).where((String t) => t.isNotEmpty).join(' '),
);

/// "stands" for one graha, "stand" for several.
String _stands(List<Graha> list) => list.length == 1 ? 'stands' : 'stand';

// -----------------------------------------------------------------------------
// The chart as the rules see it.
// -----------------------------------------------------------------------------

/// Parashari full aspects, as house distances counted inclusively. Every graha
/// sees the seventh; Mars adds the fourth and eighth, Jupiter the fifth and
/// ninth, Saturn the third and tenth. Rahu and Ketu are given no aspects here:
/// the texts that name them disagree, and no rule in this file needs them.
const Map<Graha, List<int>> _aspectDistances = <Graha, List<int>>{
  Graha.sun: <int>[7],
  Graha.moon: <int>[7],
  Graha.mars: <int>[4, 7, 8],
  Graha.mercury: <int>[7],
  Graha.jupiter: <int>[5, 7, 9],
  Graha.venus: <int>[7],
  Graha.saturn: <int>[3, 7, 10],
};

const List<Graha> _seven = <Graha>[
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

/// The five tara grahas, the only ones the Sun-flank and Moon-flank yogas count.
const List<Graha> _tara = <Graha>[
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

class _Ctx {
  _Ctx(this.k) : g = k.grahas;

  final Kundli k;
  final Map<Graha, PlacedGraha> g;

  int sign(Graha x) => g[x]!.rashi.index;
  int house(Graha x) => g[x]!.house;
  int get lagnaSign => k.lagnaRashi.index;
  int get moonSign => sign(Graha.moon);
  int get sunSign => sign(Graha.sun);

  Graha lordOfSign(int s) => rashiInfo(Rashi.values[s % 12]).lord;
  Graha lordOfHouse(int h) => lordOfSign(k.signOfHouse(h));

  int houseFromSign(int from, int to) => _houseFrom(from, to);
  int houseFromGraha(Graha from, Graha x) => _houseFrom(sign(from), sign(x));

  /// Own sign, exaltation or moolatrikona: the reading of "strong" used for the
  /// lagna lord and the like throughout this file. It is a stand-in for the
  /// texts' "balin" (strong), which the classics leave to the reader; shadbala
  /// would be the fuller test but costs too much to run on every screen build.
  bool strong(Graha x) {
    final Dignity d = g[x]!.dignity;
    return d == Dignity.own ||
        d == Dignity.exalted ||
        d == Dignity.moolatrikona;
  }

  bool inOwnOrExalted(Graha x) {
    final Dignity d = g[x]!.dignity;
    return d == Dignity.own ||
        d == Dignity.exalted ||
        d == Dignity.moolatrikona;
  }

  /// Elongation of the Moon from the Sun is under 180: the bright half.
  bool get waxingMoon =>
      norm360(
        g[Graha.moon]!.siderealLongitude - g[Graha.sun]!.siderealLongitude,
      ) <
      180.0;

  bool mercuryAfflicted() {
    final int s = sign(Graha.mercury);
    return <Graha>[
      Graha.mars,
      Graha.saturn,
      Graha.rahu,
      Graha.ketu,
    ].any((Graha x) => sign(x) == s);
  }

  /// Natural benefic: Jupiter and Venus always; the Moon in its bright half;
  /// Mercury unless it stands with Mars, Saturn, Rahu or Ketu. (Mercury beside
  /// the Sun is not counted as afflicted: it is never far from the Sun.)
  bool benefic(Graha x) => switch (x) {
    Graha.jupiter || Graha.venus => true,
    Graha.moon => waxingMoon,
    Graha.mercury => !mercuryAfflicted(),
    _ => false,
  };

  /// Natural malefic: everything that is not a benefic by the rule above.
  bool malefic(Graha x) => !benefic(x);

  /// The narrower sets used for the Nabhasa Dala, Vajra and Yava yogas, which
  /// are only ever stated for the seven grahas. The Moon is left out of both so
  /// that a chart is reported only when the yoga holds however the Moon is
  /// counted, and Mercury counts as a benefic only when it is unafflicted.
  bool nabhasaBenefic(Graha x) =>
      x == Graha.jupiter ||
      x == Graha.venus ||
      (x == Graha.mercury && !mercuryAfflicted());

  bool nabhasaMalefic(Graha x) =>
      x == Graha.sun || x == Graha.mars || x == Graha.saturn;

  /// Does [from] cast a full aspect on [toSign]?
  bool aspectsSign(Graha from, int toSign) {
    final List<int>? distances = _aspectDistances[from];
    if (distances == null) return false;
    return distances.contains(_houseFrom(sign(from), toSign));
  }

  bool aspects(Graha from, Graha to) => aspectsSign(from, sign(to));

  bool together(Graha a, Graha b) => sign(a) == sign(b);

  List<Graha> grahasInSign(int s, {List<Graha>? among}) =>
      (among ?? Graha.values)
          .where((Graha x) => sign(x) == s)
          .toList(growable: false);

  /// "Mars: Aries, house 3" as a factor line.
  _T factor(Graha x) => _T(
    '${_gEn(x)}: ${_sEn(sign(x))}, house ${house(x)}',
    '${_gHi(x)}: ${_sHi(sign(x))}, ${_hiOrdinal[house(x)]} भाव में',
  );

  /// "The 4th lord (Moon): Cancer, house 4".
  _T lordFactor(int h) {
    final Graha l = lordOfHouse(h);
    return _T(
      'Lord of the ${_enOrd(h)} (${_gEn(l)}): ${_sEn(sign(l))}, house ${house(l)}',
      '${_hiOrdinal[h]} भाव के स्वामी (${_gHi(l)}): ${_sHi(sign(l))}, ${_hiOrdinal[house(l)]} भाव में',
    );
  }
}

YogaFinding _make({
  required String key,
  required YogaFamily family,
  required _T name,
  required _T rule,
  required _T meaning,
  required _T source,
  required List<_T> factors,
  bool dosha = false,
  _T? cancellation,
  _T? mitigation,
}) => YogaFinding(
  key: key,
  family: family,
  nameEnglish: name.en,
  nameHindi: name.hi,
  isDosha: dosha,
  ruleEnglish: rule.en,
  ruleHindi: rule.hi,
  meaningEnglish: meaning.en,
  meaningHindi: meaning.hi,
  sourceEnglish: source.en,
  sourceHindi: source.hi,
  factorsEnglish: factors.map((_T t) => t.en).toList(growable: false),
  factorsHindi: factors.map((_T t) => t.hi).toList(growable: false),
  cancellationEnglish: cancellation?.en,
  cancellationHindi: cancellation?.hi,
  mitigationEnglish: mitigation?.en,
  mitigationHindi: mitigation?.hi,
);

const _T _fromPopular = _T(
  'A later, popular combination. It is not one of the yogas I could find in Parashara’s own yoga chapters, so it is given here as practice, not as a verse.',
  'यह बाद की परंपरा में प्रचलित योग है। पराशर के अपने योग-अध्यायों में मुझे यह नहीं मिला, इसलिए इसे श्लोक नहीं, परंपरागत व्यवहार के रूप में दिया गया है।',
);

/// Natural benefic or malefic by the rule the yoga library uses: Jupiter and
/// Venus always; the Moon in its bright half; Mercury unless it stands with
/// Mars, Saturn, Rahu or Ketu. Rahu, Ketu, the Sun, Mars and Saturn never.
bool isNaturallyBenefic(Kundli kundli, Graha graha) =>
    _Ctx(kundli).benefic(graha);

/// Parashari full aspect: does [from] cast an aspect on [toSign]? Rahu and
/// Ketu cast none here.
bool grahaAspectsSign(Kundli kundli, Graha from, int toSign) =>
    _Ctx(kundli).aspectsSign(from, toSign);

/// Every yoga and dosha the chart carries.
///
/// The first eleven kinds (Mangal dosha, Kaal Sarpa, Gaja Kesari, Budhaditya,
/// the five Mahapurusha yogas, Raja yoga and Kemadruma) keep their keys and
/// their detection rules exactly as they were; the library that follows them
/// is additive.
List<YogaFinding> findYogas(Kundli kundli) {
  final _Ctx c = _Ctx(kundli);
  return <YogaFinding>[
    ..._originalFindings(kundli, c),
    ..._vipreetRajaYogas(c),
    ..._chandraYogas(c),
    ..._suryaYogas(c),
    ..._shakataYoga(c),
    ..._dhanaYogas(c),
    ..._greaterYogas(c),
    ..._nabhasaYogas(c),
    ..._doshas(c),
  ];
}

// -----------------------------------------------------------------------------
// The original eleven kinds.
// -----------------------------------------------------------------------------

List<YogaFinding> _originalFindings(Kundli kundli, _Ctx c) {
  final List<YogaFinding> out = <YogaFinding>[];
  final Map<Graha, PlacedGraha> g = kundli.grahas;

  // Mangal (Kuja) dosha.
  final int marsHouse = g[Graha.mars]!.house;
  final int marsFromMoon = _houseFrom(
    g[Graha.moon]!.rashi.index,
    g[Graha.mars]!.rashi.index,
  );
  if (<int>[1, 2, 4, 7, 8, 12].contains(marsHouse) ||
      <int>[1, 2, 4, 7, 8, 12].contains(marsFromMoon)) {
    final Dignity dignity = g[Graha.mars]!.dignity;
    final bool strongMars =
        dignity == Dignity.own ||
        dignity == Dignity.exalted ||
        dignity == Dignity.moolatrikona;
    final bool jupiterWith =
        g[Graha.jupiter]!.rashi.index == g[Graha.mars]!.rashi.index;
    final bool cancelled = strongMars || jupiterWith;
    out.add(
      YogaFinding(
        key: 'mangal_dosha',
        family: YogaFamily.dosha,
        nameEnglish: 'Mangal dosha',
        nameHindi: 'मंगल दोष',
        isDosha: true,
        ruleEnglish:
            'Mars stands in house $marsHouse from the lagna and house $marsFromMoon from the Moon.',
        ruleHindi:
            'मंगल लग्न से $marsHouseवें और चंद्र से $marsFromMoonवें भाव में है।',
        meaningEnglish:
            'Classically read as friction in marriage and a hot temper early in life. It is extremely common and it is not a verdict on anyone.',
        meaningHindi:
            'परंपरा में इसे विवाह में टकराव और उग्र स्वभाव से जोड़ा गया है। यह बहुत आम है और किसी पर फैसला नहीं है।',
        cancellationEnglish: strongMars
            ? 'Mars is in its own or exalted sign, which the texts treat as cancelling the dosha.'
            : (jupiterWith
                  ? 'Jupiter sits with Mars, which the texts treat as cancelling the dosha.'
                  : null),
        cancellationHindi: strongMars
            ? 'मंगल अपनी राशि या उच्च में है, जिसे शास्त्र दोष का भंग मानते हैं।'
            : (jupiterWith
                  ? 'गुरु मंगल के साथ है, जिसे शास्त्र दोष का भंग मानते हैं।'
                  : null),
        sourceEnglish:
            'The marriage-matching rule of houses 1, 2, 4, 7, 8 and 12 from the lagna and from the Moon. It is long-standing practice; it is not one of the yogas I could verify in Parashara’s own yoga chapters.',
        sourceHindi:
            'विवाह-मिलान का नियम: लग्न और चंद्र से 1, 2, 4, 7, 8 और 12वें भाव। यह पुरानी परंपरा है; पराशर के अपने योग-अध्यायों में मुझे यह नहीं मिला।',
        factorsEnglish: <String>[
          'Mars: ${_sEn(c.sign(Graha.mars))}, house $marsHouse from the lagna',
          'Mars: house $marsFromMoon from the Moon',
        ],
        factorsHindi: <String>[
          'मंगल: ${_sHi(c.sign(Graha.mars))}, लग्न से $marsHouseवें भाव में',
          'मंगल: चंद्र से $marsFromMoonवें भाव में',
        ],
        mitigationEnglish: cancelled
            ? null
            : 'In matching, this condition is weighed by setting both charts side by side, and when both partners carry it the tradition reads the two as balancing each other. It asks for patience in speech more than anything else.',
        mitigationHindi: cancelled
            ? null
            : 'मिलान में इसे दोनों कुंडलियों को साथ रखकर तौला जाता है, और जब दोनों में हो तो परंपरा दोनों को एक-दूसरे का संतुलन मानती है। यह मुख्यतः वाणी में धैर्य माँगता है।',
      ),
    );
  }

  // Kaal Sarpa: every graha between Rahu and Ketu.
  final double rahu = g[Graha.rahu]!.siderealLongitude;
  final double ketu = g[Graha.ketu]!.siderealLongitude;
  final Iterable<PlacedGraha> others = g.values.where(
    (PlacedGraha p) => p.graha != Graha.rahu && p.graha != Graha.ketu,
  );
  final bool allOneSide = others.every(
    (PlacedGraha p) =>
        norm360(p.siderealLongitude - rahu) < norm360(ketu - rahu),
  );
  final bool allOtherSide = others.every(
    (PlacedGraha p) =>
        norm360(p.siderealLongitude - ketu) < norm360(rahu - ketu),
  );
  if (allOneSide || allOtherSide) {
    out.add(
      YogaFinding(
        key: 'kaal_sarpa',
        family: YogaFamily.dosha,
        nameEnglish: 'Kaal Sarpa yoga',
        nameHindi: 'कालसर्प योग',
        isDosha: true,
        ruleEnglish: 'All seven grahas fall on one side of the Rahu-Ketu axis.',
        ruleHindi: 'सातों ग्रह राहु-केतु अक्ष के एक ही ओर हैं।',
        meaningEnglish:
            'Read as a life of concentrated effort with delays before results. Many well-known charts carry it.',
        meaningHindi:
            'इसे परिश्रम और विलंब के बाद फल मिलने के रूप में पढ़ा जाता है।',
        sourceEnglish:
            'Not a yoga that Parashara names; it belongs to later practice and is now very popular.',
        sourceHindi:
            'पराशर इस योग का नाम नहीं लेते; यह बाद की परंपरा का योग है और आज बहुत प्रचलित है।',
        factorsEnglish: <String>[
          'Rahu: ${_sEn(c.sign(Graha.rahu))}, house ${c.house(Graha.rahu)}',
          'Ketu: ${_sEn(c.sign(Graha.ketu))}, house ${c.house(Graha.ketu)}',
        ],
        factorsHindi: <String>[
          'राहु: ${_sHi(c.sign(Graha.rahu))}, ${_hiOrdinal[c.house(Graha.rahu)]} भाव में',
          'केतु: ${_sHi(c.sign(Graha.ketu))}, ${_hiOrdinal[c.house(Graha.ketu)]} भाव में',
        ],
        mitigationEnglish:
            'Practitioners themselves call it partial when even one graha falls outside the Rahu-Ketu arc. What it asks for is steady, unhurried effort: the tradition reads results as arriving later, not as failing to arrive.',
        mitigationHindi:
            'जानकार स्वयं इसे तब आंशिक कहते हैं जब एक भी ग्रह राहु-केतु की चाप से बाहर हो। यह धैर्य और निरंतर प्रयास माँगता है: परंपरा परिणाम के आने में देर मानती है, उसके न आने की बात नहीं।',
      ),
    );
  }

  // Gaja Kesari: Jupiter in a kendra from the Moon.
  final int jupiterFromMoon = _houseFrom(
    g[Graha.moon]!.rashi.index,
    g[Graha.jupiter]!.rashi.index,
  );
  if (_kendras.contains(jupiterFromMoon)) {
    out.add(
      YogaFinding(
        key: 'gaja_kesari',
        family: YogaFamily.general,
        nameEnglish: 'Gaja Kesari yoga',
        nameHindi: 'गजकेसरी योग',
        isDosha: false,
        ruleEnglish: 'Jupiter stands in house $jupiterFromMoon from the Moon.',
        ruleHindi: 'गुरु चंद्र से $jupiterFromMoonवें भाव में है।',
        meaningEnglish:
            'Read as steady respect, good judgement and support from elders.',
        meaningHindi: 'इसे सम्मान, विवेक और बड़ों के सहयोग से जोड़ा जाता है।',
        sourceEnglish:
            'BPHS 36.3 gives the full condition: Jupiter in a kendra from the lagna or the Moon, joined or aspected by a benefic, and not debilitated, combust or in an enemy sign. This finding applies the shorter form most printed kundlis use, Jupiter in a kendra from the Moon.',
        sourceHindi:
            'बृहत्पाराशर 36.3 में पूरी शर्त है: गुरु लग्न या चंद्र से केंद्र में, शुभ ग्रह की युति या दृष्टि सहित, और नीच, अस्त या शत्रु राशि में न हो। यहाँ अधिकांश छपी कुंडलियों वाला संक्षिप्त रूप लिया गया है: गुरु चंद्र से केंद्र में।',
        factorsEnglish: <String>[
          'Jupiter: ${_sEn(c.sign(Graha.jupiter))}, house $jupiterFromMoon from the Moon',
          'Moon: ${_sEn(c.moonSign)}',
        ],
        factorsHindi: <String>[
          'गुरु: ${_sHi(c.sign(Graha.jupiter))}, चंद्र से $jupiterFromMoonवें भाव में',
          'चंद्र: ${_sHi(c.moonSign)}',
        ],
      ),
    );
  }

  // Budhaditya: Sun and Mercury in one sign.
  if (g[Graha.sun]!.rashi == g[Graha.mercury]!.rashi) {
    out.add(
      YogaFinding(
        key: 'budhaditya',
        family: YogaFamily.general,
        nameEnglish: 'Budhaditya yoga',
        nameHindi: 'बुधादित्य योग',
        isDosha: false,
        ruleEnglish:
            'Sun and Mercury share ${rashiInfo(g[Graha.sun]!.rashi).english}.',
        ruleHindi:
            'सूर्य और बुध दोनों ${rashiInfo(g[Graha.sun]!.rashi).hindi} राशि में हैं।',
        meaningEnglish:
            'Read as clear speech, quick learning and administrative skill.',
        meaningHindi:
            'इसे स्पष्ट वाणी, तीव्र बुद्धि और प्रबंधन कौशल से जोड़ा जाता है।',
        sourceEnglish:
            'B. V. Raman, Three Hundred Important Combinations (Budha-Aditya, also called Nipuna yoga).',
        sourceHindi:
            'बी. वी. रमन, थ्री हंड्रेड इम्पॉर्टेंट कॉम्बिनेशन्स (बुधादित्य, जिसे निपुण योग भी कहते हैं)।',
        factorsEnglish: <String>[
          'Sun: ${_sEn(c.sunSign)}, house ${c.house(Graha.sun)}',
          'Mercury: ${_sEn(c.sign(Graha.mercury))}, house ${c.house(Graha.mercury)}',
        ],
        factorsHindi: <String>[
          'सूर्य: ${_sHi(c.sunSign)}, ${_hiOrdinal[c.house(Graha.sun)]} भाव में',
          'बुध: ${_sHi(c.sign(Graha.mercury))}, ${_hiOrdinal[c.house(Graha.mercury)]} भाव में',
        ],
      ),
    );
  }

  // Panch Mahapurusha yogas.
  const Map<Graha, List<String>> mahapurusha = <Graha, List<String>>{
    Graha.mars: <String>['Ruchaka', 'रुचक'],
    Graha.mercury: <String>['Bhadra', 'भद्र'],
    Graha.jupiter: <String>['Hamsa', 'हंस'],
    Graha.venus: <String>['Malavya', 'मालव्य'],
    Graha.saturn: <String>['Shasha', 'शश'],
  };
  for (final MapEntry<Graha, List<String>> entry in mahapurusha.entries) {
    final PlacedGraha p = g[entry.key]!;
    final bool strong =
        p.dignity == Dignity.own ||
        p.dignity == Dignity.exalted ||
        p.dignity == Dignity.moolatrikona;
    if (strong && _kendras.contains(p.house)) {
      out.add(
        YogaFinding(
          key: 'mahapurusha_${entry.key.name}',
          family: YogaFamily.general,
          nameEnglish: '${entry.value[0]} yoga',
          nameHindi: '${entry.value[1]} योग',
          isDosha: false,
          ruleEnglish:
              '${grahaInfo(entry.key).english} is strong in ${rashiInfo(p.rashi).english} and stands in kendra house ${p.house}.',
          ruleHindi:
              '${grahaInfo(entry.key).hindi} ${rashiInfo(p.rashi).hindi} राशि में बली है और ${p.house}वें केंद्र भाव में है।',
          meaningEnglish:
              'One of the five Mahapurusha yogas, read as a marked strength of character in that planet’s area of life.',
          meaningHindi:
              'पंच महापुरुष योगों में से एक, जो उस ग्रह के क्षेत्र में विशेष बल देता है।',
          sourceEnglish:
              'The Pancha Mahapurusha yogas, as set out in B. V. Raman, Three Hundred Important Combinations: Mars, Mercury, Jupiter, Venus or Saturn in its own or exaltation sign and in a kendra from the lagna.',
          sourceHindi:
              'पंच महापुरुष योग (बी. वी. रमन के अनुसार): मंगल, बुध, गुरु, शुक्र या शनि अपनी या उच्च राशि में और लग्न से केंद्र में।',
          factorsEnglish: <String>[
            '${grahaInfo(entry.key).english}: ${rashiInfo(p.rashi).english}, house ${p.house}, ${p.dignity.name}',
          ],
          factorsHindi: <String>[
            '${grahaInfo(entry.key).hindi}: ${rashiInfo(p.rashi).hindi}, ${_hiOrdinal[p.house]} भाव में',
          ],
        ),
      );
    }
  }

  // Raja yoga: a kendra lord and a trikona lord sharing a sign.
  for (final int kendra in _kendras) {
    for (final int trikona in _trikonas) {
      if (kendra == trikona) continue;
      final Graha kendraLord = rashiInfo(
        Rashi.values[kundli.signOfHouse(kendra)],
      ).lord;
      final Graha trikonaLord = rashiInfo(
        Rashi.values[kundli.signOfHouse(trikona)],
      ).lord;
      if (kendraLord == trikonaLord) continue;
      if (g[kendraLord]!.rashi == g[trikonaLord]!.rashi) {
        out.add(
          YogaFinding(
            key: 'raja_yoga_${kendra}_$trikona',
            family: YogaFamily.rajaDhana,
            nameEnglish: 'Raja yoga',
            nameHindi: 'राजयोग',
            isDosha: false,
            ruleEnglish:
                'The lord of house $kendra (${grahaInfo(kendraLord).english}) and the lord of house $trikona (${grahaInfo(trikonaLord).english}) sit together.',
            ruleHindi:
                '$kendraवें भाव का स्वामी (${grahaInfo(kendraLord).hindi}) और $trikonaवें भाव का स्वामी (${grahaInfo(trikonaLord).hindi}) एक साथ हैं।',
            meaningEnglish:
                'A classical combination for rise in standing through one’s own work.',
            meaningHindi: 'अपने कार्य से प्रतिष्ठा बढ़ने का शास्त्रीय योग।',
            sourceEnglish:
                'The basic Raja-yoga principle of the Parashari school: a kendra lord joined with a trikona lord.',
            sourceHindi:
                'पाराशरी परंपरा का मूल राजयोग-सिद्धांत: केंद्र स्वामी और त्रिकोण स्वामी की युति।',
            factorsEnglish: <String>[
              '${_gEn(kendraLord)}: lord of house $kendra, ${_sEn(c.sign(kendraLord))}',
              '${_gEn(trikonaLord)}: lord of house $trikona, ${_sEn(c.sign(trikonaLord))}',
            ],
            factorsHindi: <String>[
              '${_gHi(kendraLord)}: $kendraवें भाव का स्वामी, ${_sHi(c.sign(kendraLord))}',
              '${_gHi(trikonaLord)}: $trikonaवें भाव का स्वामी, ${_sHi(c.sign(trikonaLord))}',
            ],
          ),
        );
      }
    }
  }

  // Kemadruma: the Moon with no graha in the 2nd or 12th from it.
  final int moonSign = g[Graha.moon]!.rashi.index;
  final bool neighbours = g.values.any(
    (PlacedGraha p) =>
        p.graha != Graha.moon &&
        p.graha != Graha.rahu &&
        p.graha != Graha.ketu &&
        (p.rashi.index == (moonSign + 1) % 12 ||
            p.rashi.index == (moonSign + 11) % 12 ||
            p.rashi.index == moonSign),
  );
  if (!neighbours) {
    // BPHS 37.11 makes the yoga require that no graha other than the Moon
    // stands in a kendra from the lagna. Where one does, the text itself says
    // the yoga does not form, which is the classical cancellation.
    final List<Graha> inKendra = _seven
        .where((Graha x) => x != Graha.moon && _kendras.contains(c.house(x)))
        .toList(growable: false);
    final bool cancelled = inKendra.isNotEmpty;
    out.add(
      YogaFinding(
        key: 'kemadruma',
        family: YogaFamily.chandra,
        nameEnglish: 'Kemadruma yoga',
        nameHindi: 'केमद्रुम योग',
        isDosha: true,
        ruleEnglish:
            'No graha stands with the Moon or in the signs on either side of it.',
        ruleHindi:
            'चंद्र के साथ या उसके दोनों ओर की राशियों में कोई ग्रह नहीं है।',
        meaningEnglish:
            'Read as having to build support for oneself rather than inheriting it. Kendra placements of other grahas are said to relieve it.',
        meaningHindi: 'इसे अपना आधार खुद बनाने के रूप में पढ़ा जाता है।',
        sourceEnglish:
            'BPHS 37.11: no graha other than the Sun beside the Moon, and no graha other than the Moon in a kendra from the lagna. This finding applies the first clause and counts the Sun as company, the more cautious reading; the second clause is what cancels it. Sunapha, Anapha and Duradhara (BPHS 37.7) are its opposites.',
        sourceHindi:
            'बृहत्पाराशर 37.11: चंद्र के पास सूर्य के सिवा कोई ग्रह नहीं, और लग्न से केंद्र में चंद्र के सिवा कोई ग्रह नहीं। यहाँ पहली शर्त लगाई गई है और सूर्य को साथी माना गया है, जो सावधान पाठ है; दूसरी शर्त ही इसे भंग करती है। सुनफा, अनफा और दुरुधरा (37.7) इसके विपरीत हैं।',
        factorsEnglish: <String>[
          'Moon: ${_sEn(moonSign)}, house ${c.house(Graha.moon)}',
          'Signs ${_sEn((moonSign + 11) % 12)} and ${_sEn((moonSign + 1) % 12)} beside the Moon hold no graha',
          if (cancelled)
            'Kendra from the lagna: ${_listEn(inKendra.map((Graha x) => '${_gEn(x)} (house ${c.house(x)})').toList())}',
        ],
        factorsHindi: <String>[
          'चंद्र: ${_sHi(moonSign)}, ${_hiOrdinal[c.house(Graha.moon)]} भाव में',
          'चंद्र के दोनों ओर की राशियाँ ${_sHi((moonSign + 11) % 12)} और ${_sHi((moonSign + 1) % 12)} में कोई ग्रह नहीं',
          if (cancelled)
            'लग्न से केंद्र में: ${_listHi(inKendra.map((Graha x) => '${_gHi(x)} (${_hiOrdinal[c.house(x)]} भाव में)').toList())}',
        ],
        cancellationEnglish: cancelled
            ? '${_listEn(inKendra.map(_gEn).toList())} ${_stands(inKendra)} in a kendra from the lagna. BPHS 37.11 makes Kemadruma require that no graha other than the Moon does, so the yoga is cancelled.'
            : null,
        cancellationHindi: cancelled
            ? '${_listHi(inKendra.map(_gHi).toList())} लग्न से केंद्र में हैं। बृहत्पाराशर 37.11 के अनुसार केमद्रुम तभी बनता है जब चंद्र के सिवा कोई ग्रह केंद्र में न हो, इसलिए यह योग भंग है।'
            : null,
        mitigationEnglish: cancelled
            ? null
            : 'Support does not come through the Moon’s company here, so the tradition reads it as a call to build one’s own circle, routine and footing rather than wait for them to arrive. It is a statement about the Moon’s neighbours, not about the life.',
        mitigationHindi: cancelled
            ? null
            : 'यहाँ सहारा चंद्र के साथियों से नहीं आता, इसलिए परंपरा इसे अपना दायरा, दिनचर्या और आधार स्वयं बनाने के आह्वान की तरह पढ़ती है। यह चंद्र के पड़ोस के बारे में कथन है, पूरे जीवन के बारे में नहीं।',
      ),
    );
  }

  return out;
}

// -----------------------------------------------------------------------------
// Vipreet Raja yogas: Harsha, Sarala, Vimala.
// -----------------------------------------------------------------------------

/// Condition: the lord of the 6th, 8th or 12th house stands in the 6th, 8th or
/// 12th house (any of the three, not only its own). Harsha is the 6th lord,
/// Sarala the 8th, Vimala the 12th.
///
/// Source: B. V. Raman, Three Hundred Important Combinations (PyJHora, which
/// cites the same numbered entries, narrows the rule to "the lord stands in its
/// own house"; the wider reading is the more widely published and is used here).
List<YogaFinding> _vipreetRajaYogas(_Ctx c) {
  final List<YogaFinding> out = <YogaFinding>[];
  final List<(int, String, _T, _T, _T)> table = <(int, String, _T, _T, _T)>[
    (
      6,
      'harsha',
      const _T('Harsha yoga', 'हर्ष योग'),
      const _T(
        'the 6th house (effort against obstacles, daily work, service and debts)',
        'छठे भाव (बाधाओं से जूझना, दैनिक कार्य, सेवा और ऋण)',
      ),
      const _T(
        'The tradition reads strength in exactly that area: a steady way of meeting opposition and of keeping the daily routine in order.',
        'परंपरा इसे उसी क्षेत्र में बल मानती है: विरोध का धैर्य से सामना करना और दिनचर्या को सँभाले रखना।',
      ),
    ),
    (
      8,
      'sarala',
      const _T('Sarala yoga', 'सरल योग'),
      const _T(
        'the 8th house (sudden change, what is hidden, shared resources and research)',
        'आठवें भाव (अचानक बदलाव, छिपी बातें, साझा संसाधन और शोध)',
      ),
      const _T(
        'The tradition reads resilience in that area: composure when life changes course and a taste for depth in inquiry.',
        'परंपरा इसे उसी क्षेत्र में दृढ़ता मानती है: जीवन की दिशा बदलने पर संयम और गहराई से खोजने की रुचि।',
      ),
    ),
    (
      12,
      'vimala',
      const _T('Vimala yoga', 'विमल योग'),
      const _T(
        'the 12th house (expenses, retreat, letting go and distant places)',
        'बारहवें भाव (व्यय, एकांत, त्याग और दूर के स्थान)',
      ),
      const _T(
        'The tradition reads a clean hand in that area: restraint with outlay, freedom from needless entanglement and a liking for quiet.',
        'परंपरा इसे उसी क्षेत्र में निर्मलता मानती है: व्यय में संयम, अनावश्यक उलझनों से मुक्ति और शांति के प्रति रुचि।',
      ),
    ),
  ];
  for (final (int, String, _T, _T, _T) row in table) {
    final int h = row.$1;
    final Graha lord = c.lordOfHouse(h);
    final int where = c.house(lord);
    if (!_dusthanas.contains(where)) continue;
    out.add(
      _make(
        key: row.$2,
        family: YogaFamily.vipreetRaja,
        name: row.$3,
        rule: _T(
          'The lord of the ${_enOrd(h)} house (${_gEn(lord)}) stands in the ${_enOrd(where)} house, in ${_sEn(c.sign(lord))}.',
          '${_hiOrdinal[h]} भाव के स्वामी (${_gHi(lord)}) ${_hiOrdinal[where]} भाव में, ${_sHi(c.sign(lord))} राशि में हैं।',
        ),
        meaning: _T(
          'A Vipreet Raja yoga: a difficult house is held by its own lord inside another difficult house, which the tradition turns into strength. It concerns ${row.$4.en}. ${row.$5.en} It is a consoling combination, not a promise.',
          'विपरीत राजयोग: कठिन भाव का स्वामी स्वयं किसी दूसरे कठिन भाव में है, जिसे परंपरा बल में बदल देती है। यह ${row.$4.hi} से जुड़ा है। ${row.$5.hi} यह ढाढ़स देने वाला योग है, वादा नहीं।',
        ),
        source: const _T(
          'B. V. Raman, Three Hundred Important Combinations (Harsha, Sarala and Vimala): the lord of the 6th, 8th or 12th house placed in the 6th, 8th or 12th.',
          'बी. वी. रमन, थ्री हंड्रेड इम्पॉर्टेंट कॉम्बिनेशन्स (हर्ष, सरल, विमल): 6, 8 या 12वें भाव का स्वामी 6, 8 या 12वें भाव में।',
        ),
        factors: <_T>[c.lordFactor(h)],
      ),
    );
  }
  return out;
}

// -----------------------------------------------------------------------------
// Moon yogas: Sunapha, Anapha, Duradhara.
// -----------------------------------------------------------------------------

/// Condition (BPHS 37.7): a graha other than the Sun stands in the 2nd from the
/// Moon (Sunapha), in the 12th from the Moon (Anapha), or in both (Duradhara).
/// The three are read as mutually exclusive, in the order the verse lists them.
/// Rahu and Ketu are not counted, which is the standing practice; the Moon
/// itself cannot be its own neighbour.
List<YogaFinding> _chandraYogas(_Ctx c) {
  final int second = (c.moonSign + 1) % 12;
  final int twelfth = (c.moonSign + 11) % 12;
  final List<Graha> inSecond = c.grahasInSign(second, among: _tara);
  final List<Graha> inTwelfth = c.grahasInSign(twelfth, among: _tara);
  if (inSecond.isEmpty && inTwelfth.isEmpty) return const <YogaFinding>[];

  final List<_T> factors = <_T>[
    _T(
      'Moon: ${_sEn(c.moonSign)}, house ${c.house(Graha.moon)}',
      'चंद्र: ${_sHi(c.moonSign)}, ${_hiOrdinal[c.house(Graha.moon)]} भाव में',
    ),
    if (inSecond.isNotEmpty)
      _T(
        '2nd from the Moon (${_sEn(second)}): ${_listEn(inSecond.map(_gEn).toList())}',
        'चंद्र से दूसरे (${_sHi(second)}): ${_listHi(inSecond.map(_gHi).toList())}',
      ),
    if (inTwelfth.isNotEmpty)
      _T(
        '12th from the Moon (${_sEn(twelfth)}): ${_listEn(inTwelfth.map(_gEn).toList())}',
        'चंद्र से बारहवें (${_sHi(twelfth)}): ${_listHi(inTwelfth.map(_gHi).toList())}',
      ),
  ];

  const _T kemadruma = _T(
    'Because a graha stands beside the Moon, Kemadruma cannot form.',
    'चंद्र के पास ग्रह होने से केमद्रुम नहीं बन सकता।',
  );

  final String keySuffix;
  final _T name;
  final _T rule;
  final _T meaning;
  final _T source;
  if (inSecond.isNotEmpty && inTwelfth.isNotEmpty) {
    keySuffix = 'duradhara';
    name = const _T('Duradhara yoga', 'दुरुधरा योग');
    rule = _T(
      '${_listEn(inSecond.map(_gEn).toList())} ${_stands(inSecond)} in the 2nd and ${_listEn(inTwelfth.map(_gEn).toList())} in the 12th from the Moon.',
      'चंद्र से दूसरे में ${_listHi(inSecond.map(_gHi).toList())} और बारहवें में ${_listHi(inTwelfth.map(_gHi).toList())} हैं।',
    );
    meaning = const _T(
      'Grahas on both sides of the Moon: the mind is supported from before and behind. BPHS 37.10 reads generosity, a comfortable household and good helpers around the person. ',
      'चंद्र के दोनों ओर ग्रह हैं: मन को आगे और पीछे दोनों ओर से सहारा है। बृहत्पाराशर 37.10 इसे उदारता, सुखी गृहस्थी और अच्छे सहायकों से जोड़ता है। ',
    );
    source = const _T(
      'BPHS 37.7 (definition) and 37.10 (reading).',
      'बृहत्पाराशर 37.7 (परिभाषा) और 37.10 (फल)।',
    );
  } else if (inSecond.isNotEmpty) {
    keySuffix = 'sunapha';
    name = const _T('Sunapha yoga', 'सुनफा योग');
    rule = _T(
      '${_listEn(inSecond.map(_gEn).toList())} ${_stands(inSecond)} in the 2nd from the Moon, in ${_sEn(second)}.',
      'चंद्र से दूसरे भाव में, ${_sHi(second)} राशि में, ${_listHi(inSecond.map(_gHi).toList())} हैं।',
    );
    meaning = const _T(
      'A graha ahead of the Moon: BPHS 37.8 reads intelligence, a good name and means earned by one’s own effort rather than inherited. ',
      'चंद्र के आगे ग्रह है: बृहत्पाराशर 37.8 इसे बुद्धि, अच्छे नाम और विरासत से नहीं बल्कि अपने परिश्रम से कमाए साधनों से जोड़ता है। ',
    );
    source = const _T(
      'BPHS 37.7 (definition) and 37.8 (reading).',
      'बृहत्पाराशर 37.7 (परिभाषा) और 37.8 (फल)।',
    );
  } else {
    keySuffix = 'anapha';
    name = const _T('Anapha yoga', 'अनफा योग');
    rule = _T(
      '${_listEn(inTwelfth.map(_gEn).toList())} ${_stands(inTwelfth)} in the 12th from the Moon, in ${_sEn(twelfth)}.',
      'चंद्र से बारहवें भाव में, ${_sHi(twelfth)} राशि में, ${_listHi(inTwelfth.map(_gHi).toList())} हैं।',
    );
    meaning = const _T(
      'A graha behind the Moon: BPHS 37.9 reads a gracious, well-regarded manner and ease in the comforts of life. ',
      'चंद्र के पीछे ग्रह है: बृहत्पाराशर 37.9 इसे शालीन, सम्मानित स्वभाव और जीवन के सुखों में सहजता से जोड़ता है। ',
    );
    source = const _T(
      'BPHS 37.7 (definition) and 37.9 (reading).',
      'बृहत्पाराशर 37.7 (परिभाषा) और 37.9 (फल)।',
    );
  }
  return <YogaFinding>[
    _make(
      key: keySuffix,
      family: YogaFamily.chandra,
      name: name,
      rule: rule,
      meaning: _join(<_T>[meaning, kemadruma]),
      source: source,
      factors: factors,
    ),
  ];
}

// -----------------------------------------------------------------------------
// Sun yogas: Vesi, Vasi, Ubhayachari.
// -----------------------------------------------------------------------------

/// Condition: Mars, Mercury, Jupiter, Venus or Saturn in the 2nd from the Sun
/// and none of them in the 12th (Vesi); in the 12th and none in the 2nd (Vasi);
/// in both (Ubhayachari). The Moon, Rahu and Ketu do not make or unmake these
/// yogas. Source: B. V. Raman, Three Hundred Important Combinations. The result
/// lines of Vesi and Vasi differ from book to book, so only the area each side
/// of the Sun stands for is given, read from what the 2nd and 12th houses mean.
List<YogaFinding> _suryaYogas(_Ctx c) {
  final int second = (c.sunSign + 1) % 12;
  final int twelfth = (c.sunSign + 11) % 12;
  final List<Graha> inSecond = c.grahasInSign(second, among: _tara);
  final List<Graha> inTwelfth = c.grahasInSign(twelfth, among: _tara);
  if (inSecond.isEmpty && inTwelfth.isEmpty) return const <YogaFinding>[];

  final List<_T> factors = <_T>[
    _T(
      'Sun: ${_sEn(c.sunSign)}, house ${c.house(Graha.sun)}',
      'सूर्य: ${_sHi(c.sunSign)}, ${_hiOrdinal[c.house(Graha.sun)]} भाव में',
    ),
    if (inSecond.isNotEmpty)
      _T(
        '2nd from the Sun (${_sEn(second)}): ${_listEn(inSecond.map(_gEn).toList())}',
        'सूर्य से दूसरे (${_sHi(second)}): ${_listHi(inSecond.map(_gHi).toList())}',
      ),
    if (inTwelfth.isNotEmpty)
      _T(
        '12th from the Sun (${_sEn(twelfth)}): ${_listEn(inTwelfth.map(_gEn).toList())}',
        'सूर्य से बारहवें (${_sHi(twelfth)}): ${_listHi(inTwelfth.map(_gHi).toList())}',
      ),
  ];
  const _T source = _T(
    'B. V. Raman, Three Hundred Important Combinations: a graha other than the Moon in the 2nd, the 12th, or both, from the Sun.',
    'बी. वी. रमन, थ्री हंड्रेड इम्पॉर्टेंट कॉम्बिनेशन्स: सूर्य से दूसरे, बारहवें या दोनों भावों में चंद्र के सिवा कोई ग्रह।',
  );
  const _T caveat = _T(
    ' Books differ on the exact results of this yoga, so only the area is stated.',
    ' इस योग के फल पर ग्रंथों में मतभेद है, इसलिए केवल क्षेत्र बताया गया है।',
  );

  if (inSecond.isNotEmpty && inTwelfth.isNotEmpty) {
    return <YogaFinding>[
      _make(
        key: 'ubhayachari',
        family: YogaFamily.surya,
        name: const _T('Ubhayachari yoga', 'उभयचारी योग'),
        rule: _T(
          '${_listEn(inSecond.map(_gEn).toList())} ${_stands(inSecond)} in the 2nd and ${_listEn(inTwelfth.map(_gEn).toList())} in the 12th from the Sun.',
          'सूर्य से दूसरे में ${_listHi(inSecond.map(_gHi).toList())} और बारहवें में ${_listHi(inTwelfth.map(_gHi).toList())} हैं।',
        ),
        meaning: _join(<_T>[
          const _T(
            'Grahas on both sides of the Sun: the self is accompanied from what lies ahead of it (speech, means) and from what lies behind it (effort, outlay). It is read as a well-supported sense of self.',
            'सूर्य के दोनों ओर ग्रह हैं: आत्म के आगे (वाणी, साधन) और पीछे (प्रयास, व्यय) दोनों ओर साथ है। इसे सुदृढ़ आत्मबल की तरह पढ़ा जाता है।',
          ),
          caveat,
        ]),
        source: source,
        factors: factors,
      ),
    ];
  }
  if (inSecond.isNotEmpty) {
    return <YogaFinding>[
      _make(
        key: 'vesi',
        family: YogaFamily.surya,
        name: const _T('Vesi yoga', 'वेशि योग'),
        rule: _T(
          '${_listEn(inSecond.map(_gEn).toList())} ${_stands(inSecond)} in the 2nd from the Sun, in ${_sEn(second)}, and none stands in the 12th.',
          'सूर्य से दूसरे भाव में, ${_sHi(second)} राशि में, ${_listHi(inSecond.map(_gHi).toList())} हैं और बारहवें में कोई नहीं है।',
        ),
        meaning: _join(<_T>[
          const _T(
            'A graha ahead of the Sun, in the house of speech and what one holds: the self-expression of the Sun is accompanied by the resources of that graha.',
            'सूर्य के आगे, वाणी और संचय के भाव में, ग्रह है: सूर्य की आत्म-अभिव्यक्ति के साथ उस ग्रह के साधन हैं।',
          ),
          caveat,
        ]),
        source: source,
        factors: factors,
      ),
    ];
  }
  return <YogaFinding>[
    _make(
      key: 'vasi',
      family: YogaFamily.surya,
      name: const _T('Vasi yoga', 'वाशि योग'),
      rule: _T(
        '${_listEn(inTwelfth.map(_gEn).toList())} ${_stands(inTwelfth)} in the 12th from the Sun, in ${_sEn(twelfth)}, and none stands in the 2nd.',
        'सूर्य से बारहवें भाव में, ${_sHi(twelfth)} राशि में, ${_listHi(inTwelfth.map(_gHi).toList())} हैं और दूसरे में कोई नहीं है।',
      ),
      meaning: _join(<_T>[
        const _T(
          'A graha behind the Sun, in the house of outlay and letting go: the self-expression of the Sun is accompanied by the giving side of that graha.',
          'सूर्य के पीछे, व्यय और त्याग के भाव में, ग्रह है: सूर्य की आत्म-अभिव्यक्ति के साथ उस ग्रह का देने वाला पक्ष है।',
        ),
        caveat,
      ]),
      source: source,
      factors: factors,
    ),
  ];
}

// -----------------------------------------------------------------------------
// Shakata yoga (Moon from Jupiter).
// -----------------------------------------------------------------------------

/// Condition: the Moon stands in the 6th, 8th or 12th from Jupiter. Cancelled
/// when the Moon is in a kendra from the lagna, or in its own or exaltation
/// sign. Source: B. V. Raman, Three Hundred Important Combinations, and the
/// Phaladeepika tradition behind it. This is a different yoga from the Nabhasa
/// Shakata (all grahas in the 1st and 7th), which carries the key
/// `nabhasa_shakata`.
List<YogaFinding> _shakataYoga(_Ctx c) {
  final int fromJupiter = c.houseFromGraha(Graha.jupiter, Graha.moon);
  if (!_dusthanas.contains(fromJupiter)) return const <YogaFinding>[];

  final bool kendraFromLagna = _kendras.contains(c.house(Graha.moon));
  final Dignity moonDignity = c.g[Graha.moon]!.dignity;
  final bool moonStrong =
      moonDignity == Dignity.own ||
      moonDignity == Dignity.exalted ||
      moonDignity == Dignity.moolatrikona;
  _T? cancellation;
  if (kendraFromLagna) {
    cancellation = _T(
      'The Moon stands in a kendra from the lagna (house ${c.house(Graha.moon)}). The texts say Shakata does not arise then, even with the Moon ${_enOrd(fromJupiter)} from Jupiter.',
      'चंद्र लग्न से केंद्र (${_hiOrdinal[c.house(Graha.moon)]} भाव) में है। शास्त्र कहते हैं कि तब चंद्र के गुरु से ${_hiOrdinal[fromJupiter]} भाव में होने पर भी शकट योग नहीं बनता।',
    );
  } else if (moonStrong) {
    cancellation = _T(
      'The Moon is in ${_sEn(c.moonSign)}, its own or exaltation sign, which the texts treat as cancelling Shakata.',
      'चंद्र ${_sHi(c.moonSign)} में है, जो उसकी अपनी या उच्च राशि है; शास्त्र इसे शकट का भंग मानते हैं।',
    );
  }
  return <YogaFinding>[
    _make(
      key: 'shakata_chandra',
      family: YogaFamily.chandra,
      dosha: true,
      name: const _T(
        'Shakata yoga (Moon from Jupiter)',
        'शकट योग (गुरु से चंद्र)',
      ),
      rule: _T(
        'The Moon (${_sEn(c.moonSign)}) stands in the ${_enOrd(fromJupiter)} house from Jupiter (${_sEn(c.sign(Graha.jupiter))}).',
        'चंद्र (${_sHi(c.moonSign)}) गुरु (${_sHi(c.sign(Graha.jupiter))}) से ${_hiOrdinal[fromJupiter]} भाव में है।',
      ),
      meaning: const _T(
        'Shakata means a cart: the tradition reads a pattern of standing and means that rises and falls in phases, like the turning of a wheel. It is read as a rhythm, not as a loss.',
        'शकट का अर्थ गाड़ी है: परंपरा इसे प्रतिष्ठा और साधनों के चरणों में चढ़ने-उतरने की लय की तरह पढ़ती है, जैसे पहिया घूमता है। यह हानि नहीं, एक लय है।',
      ),
      source: const _T(
        'B. V. Raman, Three Hundred Important Combinations, and the Phaladeepika tradition: the Moon in the 6th, 8th or 12th from Jupiter, cancelled by a kendra Moon.',
        'बी. वी. रमन, थ्री हंड्रेड इम्पॉर्टेंट कॉम्बिनेशन्स, और फलदीपिका परंपरा: चंद्र गुरु से 6, 8 या 12वें भाव में; केंद्रस्थ चंद्र से भंग।',
      ),
      factors: <_T>[c.factor(Graha.moon), c.factor(Graha.jupiter)],
      cancellation: cancellation,
      mitigation: cancellation != null
          ? null
          : const _T(
              'It asks for steady habits through the phases, so that the good stretches are not spent in haste and the lean ones are met without alarm.',
              'यह चरणों के बीच स्थिर आदतें माँगता है, ताकि अच्छे दौर जल्दबाज़ी में न बीतें और कठिन दौर बिना घबराहट के निभें।',
            ),
    ),
  ];
}

// -----------------------------------------------------------------------------
// Dhana yoga and Daridra yoga: the lords of the 2nd and the 11th.
// -----------------------------------------------------------------------------

/// Dhana yoga, in the plain Parashari form: the lords of the 2nd (what is kept)
/// and the 11th (what comes in) are joined in one sign, in mutual aspect, or in
/// exchange of signs. BPHS chapter 41 lists many wealth yogas; this 2nd-11th
/// formulation is the standard one of later Parashari manuals and is not a
/// single BPHS verse I could verify, so it is credited to the school, not a
/// verse. Daridra yoga is read here in its strict form: the lords of both the
/// 2nd and the 11th stand in the 6th, 8th or 12th (many manuals need only the
/// 11th lord there; BPHS chapter 42 gives different, longer combinations that
/// involve the maraka lords and are not used).
List<YogaFinding> _dhanaYogas(_Ctx c) {
  final List<YogaFinding> out = <YogaFinding>[];
  final Graha l2 = c.lordOfHouse(2);
  final Graha l11 = c.lordOfHouse(11);
  if (l2 == l11) return out;

  final bool conjunct = c.together(l2, l11);
  final bool mutualAspect = c.aspects(l2, l11) && c.aspects(l11, l2);
  final bool exchange =
      c.lordOfSign(c.sign(l2)) == l11 && c.lordOfSign(c.sign(l11)) == l2;
  if (conjunct || mutualAspect || exchange) {
    final String howEn = conjunct
        ? 'are joined in ${_sEn(c.sign(l2))}'
        : (exchange ? 'exchange signs' : 'aspect each other');
    final String howHi = conjunct
        ? '${_sHi(c.sign(l2))} में एक साथ हैं'
        : (exchange ? 'आपस में राशि बदले हुए हैं' : 'एक-दूसरे को देखते हैं');
    out.add(
      _make(
        key: 'dhana_2_11',
        family: YogaFamily.rajaDhana,
        name: const _T('Dhana yoga', 'धन योग'),
        rule: _T(
          'The lord of the 2nd (${_gEn(l2)}) and the lord of the 11th (${_gEn(l11)}) $howEn.',
          'दूसरे भाव के स्वामी (${_gHi(l2)}) और ग्यारहवें भाव के स्वामी (${_gHi(l11)}) $howHi।',
        ),
        meaning: const _T(
          'The house of what is kept and the house of what comes in are tied through their lords. The tradition reads income and savings supporting each other, through steady work and orderly habits. It says nothing about amounts.',
          'जो बचता है उसका भाव और जो आता है उसका भाव उनके स्वामियों से जुड़े हैं। परंपरा इसे आय और संचय के एक-दूसरे को सहारा देने के रूप में पढ़ती है, जो नियमित कार्य और व्यवस्थित आदतों से चलता है। यह राशि के बारे में कुछ नहीं कहता।',
        ),
        source: const _T(
          'The 2nd-and-11th-lord formulation of the Parashari school (BPHS chapter 41 gives many other wealth yogas).',
          'पाराशरी परंपरा का दूसरे-ग्यारहवें भाव के स्वामियों वाला रूप (बृहत्पाराशर अध्याय 41 में और भी धन योग हैं)।',
        ),
        factors: <_T>[c.lordFactor(2), c.lordFactor(11)],
      ),
    );
  }

  final bool bothInDusthana =
      _dusthanas.contains(c.house(l2)) && _dusthanas.contains(c.house(l11));
  if (bothInDusthana) {
    final int jupiterHouse = c.house(Graha.jupiter);
    final bool jupiterHolds =
        c.house(Graha.jupiter) == 2 ||
        c.house(Graha.jupiter) == 11 ||
        <int>[
          2,
          11,
        ].any((int h) => c.aspectsSign(Graha.jupiter, c.k.signOfHouse(h)));
    _T? cancellation;
    if (conjunct) {
      cancellation = _T(
        '${_gEn(l2)} and ${_gEn(l11)} stand together in one house, which is itself the Dhana-yoga condition: the two readings meet each other.',
        '${_gHi(l2)} और ${_gHi(l11)} एक ही भाव में साथ हैं, जो स्वयं धन योग की शर्त है: दोनों पाठ एक-दूसरे को संतुलित करते हैं।',
      );
    } else if (jupiterHolds) {
      cancellation = _T(
        'Jupiter, the natural significator of wealth, occupies or aspects the 2nd or 11th house (Jupiter stands in house $jupiterHouse). The tradition reads the wealth houses as protected by it.',
        'धन का कारक गुरु दूसरे या ग्यारहवें भाव में है या उसे देखता है (गुरु ${_hiOrdinal[jupiterHouse]} भाव में है)। परंपरा इन धन भावों को उससे सुरक्षित मानती है।',
      );
    }
    out.add(
      _make(
        key: 'daridra',
        family: YogaFamily.dosha,
        dosha: true,
        name: const _T('Daridra yoga', 'दरिद्र योग'),
        rule: _T(
          'The lord of the 2nd (${_gEn(l2)}) stands in the ${_enOrd(c.house(l2))} house and the lord of the 11th (${_gEn(l11)}) in the ${_enOrd(c.house(l11))}.',
          'दूसरे भाव के स्वामी (${_gHi(l2)}) ${_hiOrdinal[c.house(l2)]} भाव में और ग्यारहवें के स्वामी (${_gHi(l11)}) ${_hiOrdinal[c.house(l11)]} भाव में हैं।',
        ),
        meaning: const _T(
          'Both lords of the houses of keeping and gaining stand in difficult houses. The tradition reads this as income and savings that come by sustained effort and sometimes after delay, not by ease. It is a statement about the pace of means, never about how much.',
          'संचय और आय दोनों भावों के स्वामी कठिन भावों में हैं। परंपरा इसे ऐसी आय और बचत के रूप में पढ़ती है जो सहजता से नहीं, निरंतर प्रयास से और कभी-कभी देर से आती है। यह साधनों की गति के बारे में है, मात्रा के बारे में कभी नहीं।',
        ),
        source: const _T(
          'Strict reading of the later Parashari manuals: the lords of both the 2nd and the 11th in the 6th, 8th or 12th. Not the longer combinations of BPHS chapter 42.',
          'बाद की पाराशरी पुस्तकों का कठोर पाठ: दूसरे और ग्यारहवें दोनों भावों के स्वामी 6, 8 या 12वें भाव में। बृहत्पाराशर अध्याय 42 की लंबी शर्तें नहीं।',
        ),
        factors: <_T>[c.lordFactor(2), c.lordFactor(11)],
        cancellation: cancellation,
        mitigation: cancellation != null
            ? null
            : const _T(
                'It asks for patience with the pace of income and for keeping accounts in order.',
                'यह आय की गति के साथ धैर्य और हिसाब व्यवस्थित रखने की माँग करता है।',
              ),
      ),
    );
  }
  return out;
}

// -----------------------------------------------------------------------------
// Amala, Chamara, Adhi, Lakshmi, Saraswati, Kalanidhi, Parvata, Kahala.
// -----------------------------------------------------------------------------

List<YogaFinding> _greaterYogas(_Ctx c) {
  final List<YogaFinding> out = <YogaFinding>[];
  // --- Amala (BPHS 36.5, Amalakirti) ---------------------------------------
  // Condition: the 10th from the lagna, or the 10th from the Moon, is occupied
  // by benefics only: at least one benefic and no malefic (Rahu and Ketu count
  // as malefics for this purpose, which is the cautious reading).
  final List<_T> amalaFrom = <_T>[];
  final List<_T> amalaFactors = <_T>[];
  for (final (String, String, int) ref in <(String, String, int)>[
    ('lagna', 'लग्न', c.lagnaSign),
    ('Moon', 'चंद्र', c.moonSign),
  ]) {
    final int tenth = (ref.$3 + 9) % 12;
    final List<Graha> there = Graha.values
        .where(
          (Graha x) =>
              c.sign(x) == tenth && !(ref.$1 == 'Moon' && x == Graha.moon),
        )
        .toList(growable: false);
    if (there.isNotEmpty && there.every(c.benefic)) {
      amalaFrom.add(_T(ref.$1 == 'lagna' ? 'the lagna' : 'the Moon', ref.$2));
      amalaFactors.add(
        _T(
          '10th from the ${ref.$1} (${_sEn(tenth)}): ${_listEn(there.map(_gEn).toList())}',
          '${ref.$2} से दसवाँ (${_sHi(tenth)}): ${_listHi(there.map(_gHi).toList())}',
        ),
      );
    }
  }
  if (amalaFrom.isNotEmpty) {
    out.add(
      _make(
        key: 'amala',
        family: YogaFamily.general,
        name: const _T('Amala yoga', 'अमल योग'),
        rule: _T(
          'Only benefics stand in the 10th from ${amalaFrom.map((_T t) => t.en).join(' and from ')}.',
          '${amalaFrom.map((_T t) => t.hi).join(' और ')} से दसवें भाव में केवल शुभ ग्रह हैं।',
        ),
        meaning: const _T(
          'The 10th house is the house of work and standing, and here it is held by benefics alone. BPHS 36.5 calls it Amalakirti, a stainless name: reputation built cleanly through one’s own work.',
          'दसवाँ भाव कर्म और प्रतिष्ठा का भाव है, और यहाँ उसमें केवल शुभ ग्रह हैं। बृहत्पाराशर 36.5 इसे अमलकीर्ति कहता है, यानी निष्कलंक नाम: अपने कर्म से स्वच्छ प्रतिष्ठा।',
        ),
        source: const _T(
          'BPHS 36.5 (Amalakirti, "joined with benefics alone"); B. V. Raman, Three Hundred Important Combinations (Amala).',
          'बृहत्पाराशर 36.5 (अमलकीर्ति, "केवल शुभ ग्रहों से युक्त"); बी. वी. रमन (अमल योग)।',
        ),
        factors: amalaFactors,
      ),
    );
  }

  // --- Chamara (BPHS 36.11) --------------------------------------------------
  // Either the lagna lord is exalted, in a kendra, and aspected by Jupiter; or
  // two benefics stand together in the lagna, 7th, 9th or 10th house. (PyJHora
  // leaves the lagna out of the second form; the Sanskrit includes it.)
  final Graha lagnaLord = c.lordOfHouse(1);
  final bool lagnaLordRoute =
      lagnaLord != Graha.jupiter &&
      c.g[lagnaLord]!.dignity == Dignity.exalted &&
      _kendras.contains(c.house(lagnaLord)) &&
      c.aspects(Graha.jupiter, lagnaLord);
  int? pairHouse;
  List<Graha> pair = const <Graha>[];
  for (final int h in <int>[1, 7, 9, 10]) {
    final List<Graha> beneficsThere = _seven
        .where((Graha x) => c.house(x) == h && c.benefic(x))
        .toList(growable: false);
    if (beneficsThere.length >= 2) {
      pairHouse = h;
      pair = beneficsThere;
      break;
    }
  }
  if (lagnaLordRoute || pairHouse != null) {
    out.add(
      _make(
        key: 'chamara',
        family: YogaFamily.general,
        name: const _T('Chamara yoga', 'चामर योग'),
        rule: lagnaLordRoute
            ? _T(
                'The lagna lord (${_gEn(lagnaLord)}) is exalted in ${_sEn(c.sign(lagnaLord))}, in kendra house ${c.house(lagnaLord)}, and Jupiter aspects it.',
                'लग्न स्वामी (${_gHi(lagnaLord)}) ${_sHi(c.sign(lagnaLord))} में उच्च का है, ${_hiOrdinal[c.house(lagnaLord)]} केंद्र भाव में, और गुरु उसे देखता है।',
              )
            : _T(
                '${_listEn(pair.map(_gEn).toList())} stand together in the ${_enOrd(pairHouse ?? 1)} house.',
                '${_listHi(pair.map(_gHi).toList())} ${_hiOrdinal[pairHouse ?? 1]} भाव में साथ हैं।',
              ),
        meaning: const _T(
          'Chamara is the royal fan, a sign of honour. The tradition reads dignity in company, fluent speech and a bent for learning. It describes bearing, not rank.',
          'चामर राजकीय पंखा है, सम्मान का चिह्न। परंपरा इसे सभा में गरिमा, प्रवाहमयी वाणी और विद्या की ओर झुकाव से जोड़ती है। यह आचरण की बात है, पद की नहीं।',
        ),
        source: const _T(
          'BPHS 36.11: the lagna lord exalted in a kendra and aspected by Jupiter, or two benefics in the lagna, 7th, 9th or 10th.',
          'बृहत्पाराशर 36.11: लग्न स्वामी उच्च का होकर केंद्र में और गुरु से दृष्ट, अथवा लग्न, 7, 9 या 10वें भाव में दो शुभ ग्रह।',
        ),
        factors: lagnaLordRoute
            ? <_T>[c.factor(lagnaLord), c.factor(Graha.jupiter)]
            : pair.map(c.factor).toList(),
      ),
    );
  }

  // --- Adhi (BPHS 37.5) ------------------------------------------------------
  // Condition: the benefics (Jupiter and Venus always, Mercury when it is not
  // afflicted) all stand in the 6th, 7th or 8th from the Moon. BPHS 37.5 also
  // grades partial cases (leader, minister, commander by strength), which are
  // not reported here: only the complete form is.
  final List<Graha> adhiSet = <Graha>[
    Graha.jupiter,
    Graha.venus,
    if (!c.mercuryAfflicted()) Graha.mercury,
  ];
  if (adhiSet.every(
    (Graha x) => <int>[6, 7, 8].contains(c.houseFromGraha(Graha.moon, x)),
  )) {
    out.add(
      _make(
        key: 'adhi',
        family: YogaFamily.rajaDhana,
        name: const _T('Adhi yoga', 'अधि योग'),
        rule: _T(
          '${_listEn(adhiSet.map(_gEn).toList())} all stand in the 6th, 7th or 8th from the Moon.',
          '${_listHi(adhiSet.map(_gHi).toList())} सभी चंद्र से 6, 7 या 8वें भाव में हैं।',
        ),
        meaning: const _T(
          'The benefics gather around the Moon’s opposite side. BPHS 37.5 reads a position of leadership whose rank follows the strength of the grahas involved: authority exercised with good judgement.',
          'शुभ ग्रह चंद्र के सामने की ओर एकत्र हैं। बृहत्पाराशर 37.5 इसे नेतृत्व की स्थिति से जोड़ता है, जिसका स्तर संबंधित ग्रहों के बल पर निर्भर है: विवेक के साथ चलाया गया अधिकार।',
        ),
        source: const _T(
          'BPHS 37.5 (benefics in the 6th, 7th and 8th from the Moon); the complete form only.',
          'बृहत्पाराशर 37.5 (चंद्र से 6, 7, 8वें भाव में शुभ ग्रह); केवल पूर्ण रूप।',
        ),
        factors: <_T>[
          _T('Moon: ${_sEn(c.moonSign)}', 'चंद्र: ${_sHi(c.moonSign)}'),
          for (final Graha x in adhiSet)
            _T(
              '${_gEn(x)}: house ${c.houseFromGraha(Graha.moon, x)} from the Moon',
              '${_gHi(x)}: चंद्र से ${_hiOrdinal[c.houseFromGraha(Graha.moon, x)]} भाव में',
            ),
        ],
      ),
    );
  }

  // --- Lakshmi (BPHS 36.27) --------------------------------------------------
  // Condition: the 9th lord stands in a kendra in its own, exaltation or
  // moolatrikona sign, and the lagna lord is strong. Phaladeepika says "kendra";
  // Raman says "kendra or trikona". The narrower kendra reading is used.
  final Graha ninth = c.lordOfHouse(9);
  if (ninth != lagnaLord &&
      c.inOwnOrExalted(ninth) &&
      _kendras.contains(c.house(ninth)) &&
      c.strong(lagnaLord)) {
    out.add(
      _make(
        key: 'lakshmi',
        family: YogaFamily.rajaDhana,
        name: const _T('Lakshmi yoga', 'लक्ष्मी योग'),
        rule: _T(
          'The lord of the 9th (${_gEn(ninth)}) is strong in ${_sEn(c.sign(ninth))}, in kendra house ${c.house(ninth)}, and the lagna lord (${_gEn(lagnaLord)}) is strong in ${_sEn(c.sign(lagnaLord))}.',
          '${_hiOrdinal[9]} भाव के स्वामी (${_gHi(ninth)}) ${_sHi(c.sign(ninth))} में बली होकर ${_hiOrdinal[c.house(ninth)]} केंद्र भाव में हैं, और लग्न स्वामी (${_gHi(lagnaLord)}) ${_sHi(c.sign(lagnaLord))} में बली है।',
        ),
        meaning: const _T(
          'The house of fortune and good fortune’s lord are both well seated, with a strong lagna lord behind them. The tradition reads grace, refinement and a life that is well provisioned by its own merit. It names no amount.',
          'भाग्य का भाव और उसका स्वामी दोनों सुस्थित हैं, और पीछे बली लग्न स्वामी है। परंपरा इसे शालीनता, परिष्कार और अपने गुणों से सुसज्जित जीवन के रूप में पढ़ती है। यह कोई राशि नहीं बताता।',
        ),
        source: const _T(
          'BPHS 36.27 (the 9th lord in a kendra, own or exaltation sign, with a strong lagna lord). "Strong" is read as own, exalted or moolatrikona.',
          'बृहत्पाराशर 36.27 (नवम स्वामी केंद्र में, स्व या उच्च राशि में, बली लग्न स्वामी सहित)। "बली" का अर्थ स्व, उच्च या मूलत्रिकोण राशि लिया गया है।',
        ),
        factors: <_T>[c.lordFactor(9), c.lordFactor(1)],
      ),
    );
  }

  // --- Saraswati (B. V. Raman) ----------------------------------------------
  // Condition: Jupiter, Venus and Mercury each in a kendra, a trikona or the
  // 2nd house, and Jupiter in its own, exaltation, moolatrikona or a friend's
  // sign.
  const List<int> saraswatiHouses = <int>[1, 2, 4, 5, 7, 9, 10];
  final Dignity jd = c.g[Graha.jupiter]!.dignity;
  if (<Graha>[
        Graha.jupiter,
        Graha.venus,
        Graha.mercury,
      ].every((Graha x) => saraswatiHouses.contains(c.house(x))) &&
      (jd == Dignity.own ||
          jd == Dignity.exalted ||
          jd == Dignity.moolatrikona ||
          jd == Dignity.friend)) {
    out.add(
      _make(
        key: 'saraswati',
        family: YogaFamily.general,
        name: const _T('Saraswati yoga', 'सरस्वती योग'),
        rule: _T(
          'Jupiter (house ${c.house(Graha.jupiter)}), Venus (house ${c.house(Graha.venus)}) and Mercury (house ${c.house(Graha.mercury)}) all stand in a kendra, a trikona or the 2nd, and Jupiter is in a sign of its own, exaltation or friendship.',
          'गुरु (${_hiOrdinal[c.house(Graha.jupiter)]} भाव), शुक्र (${_hiOrdinal[c.house(Graha.venus)]} भाव) और बुध (${_hiOrdinal[c.house(Graha.mercury)]} भाव) सब केंद्र, त्रिकोण या दूसरे भाव में हैं, और गुरु स्व, उच्च या मित्र राशि में है।',
        ),
        meaning: const _T(
          'The three grahas of learning, art and speech are all well seated. The tradition reads a love of study, a gift for expression and refined tastes. It says nothing about how any course of study will turn out.',
          'विद्या, कला और वाणी के तीनों ग्रह सुस्थित हैं। परंपरा इसे अध्ययन-प्रेम, अभिव्यक्ति की प्रतिभा और परिष्कृत रुचि से जोड़ती है। यह इस बात की चर्चा नहीं करता कि किसी पढ़ाई का नतीजा क्या होगा।',
        ),
        source: const _T(
          'B. V. Raman, Three Hundred Important Combinations (Saraswati yoga).',
          'बी. वी. रमन, थ्री हंड्रेड इम्पॉर्टेंट कॉम्बिनेशन्स (सरस्वती योग)।',
        ),
        factors: <_T>[
          c.factor(Graha.jupiter),
          c.factor(Graha.venus),
          c.factor(Graha.mercury),
        ],
      ),
    );
  }

  // --- Kalanidhi (BPHS 36.31) ------------------------------------------------
  // Condition: Jupiter in the 2nd or 5th house and either joined or aspected by
  // both Mercury and Venus, or standing in a sign of Mercury or Venus.
  if (<int>[2, 5].contains(c.house(Graha.jupiter))) {
    bool linked(Graha x) =>
        c.together(x, Graha.jupiter) || c.aspects(x, Graha.jupiter);
    final bool both = linked(Graha.mercury) && linked(Graha.venus);
    final Graha signLord = c.lordOfSign(c.sign(Graha.jupiter));
    final bool inTheirSign =
        signLord == Graha.mercury || signLord == Graha.venus;
    if (both || inTheirSign) {
      out.add(
        _make(
          key: 'kalanidhi',
          family: YogaFamily.general,
          name: const _T('Kalanidhi yoga', 'कलानिधि योग'),
          rule: _T(
            'Jupiter stands in the ${_enOrd(c.house(Graha.jupiter))} house, in ${_sEn(c.sign(Graha.jupiter))}, ${both ? 'joined or aspected by both Mercury and Venus' : 'in a sign of ${_gEn(signLord)}'}.',
            'गुरु ${_hiOrdinal[c.house(Graha.jupiter)]} भाव में, ${_sHi(c.sign(Graha.jupiter))} राशि में है, ${both ? 'बुध और शुक्र दोनों की युति या दृष्टि सहित' : '${_gHi(signLord)} की राशि में'}।',
          ),
          meaning: const _T(
            'A treasury of arts: Jupiter in the house of speech or of learning, in the company of Mercury and Venus or in a sign of theirs. The tradition reads skill in the arts and letters, and a cultivated mind.',
            'कलाओं का भंडार: गुरु वाणी या विद्या के भाव में है, बुध और शुक्र के साथ या उनकी राशि में। परंपरा इसे कला और साहित्य में कुशलता और संस्कारित मन से जोड़ती है।',
          ),
          source: const _T(
            'BPHS 36.31: Jupiter in the 2nd or 5th, joined or aspected by Mercury and Venus, or in a sign of those two.',
            'बृहत्पाराशर 36.31: गुरु 2 या 5वें भाव में, बुध-शुक्र से युक्त या दृष्ट, अथवा उन दोनों की राशि में।',
          ),
          factors: <_T>[
            c.factor(Graha.jupiter),
            c.factor(Graha.mercury),
            c.factor(Graha.venus),
          ],
        ),
      );
    }
  }

  // --- Parvata (BPHS 36.7) ---------------------------------------------------
  // The verse is terse and the books differ (PyJHora lets kendras stand empty;
  // Raman names the 6th and 8th instead of the 7th and 8th). The strict reading
  // is used: every kendra holds a benefic and no malefic, and the 8th is free
  // of malefics. It is rare by construction.
  final bool parvata =
      _kendras.every((int h) {
        final List<Graha> there = Graha.values
            .where((Graha x) => c.house(x) == h)
            .toList(growable: false);
        return there.any(c.benefic) && !there.any(c.malefic);
      }) &&
      !Graha.values.any((Graha x) => c.house(x) == 8 && c.malefic(x));
  if (parvata) {
    out.add(
      _make(
        key: 'parvata',
        family: YogaFamily.general,
        name: const _T('Parvata yoga', 'पर्वत योग'),
        rule: const _T(
          'Every kendra holds a benefic and no malefic, and the 8th house is free of malefics.',
          'हर केंद्र भाव में शुभ ग्रह है और कोई पाप ग्रह नहीं, तथा आठवाँ भाव पाप ग्रहों से मुक्त है।',
        ),
        meaning: const _T(
          'Parvata is the mountain: the four pillars of the chart are held by benefics. The tradition reads a steady footing, generosity and a respected place among people.',
          'पर्वत यानी पहाड़: कुंडली के चारों स्तंभ शुभ ग्रहों के हाथ में हैं। परंपरा इसे स्थिर आधार, उदारता और लोगों के बीच सम्मानित स्थान से जोड़ती है।',
        ),
        source: const _T(
          'BPHS 36.7, in its strict reading. Books differ on whether kendras may stand empty and on which of the 6th, 7th and 8th must be pure.',
          'बृहत्पाराशर 36.7, कठोर पाठ में। ग्रंथों में मतभेद है कि केंद्र खाली हो सकते हैं या नहीं और 6, 7, 8 में से कौन-सा भाव शुद्ध चाहिए।',
        ),
        factors: <_T>[
          for (final int h in _kendras)
            _T(
              'House $h: ${_listEn(Graha.values.where((Graha x) => c.house(x) == h).map(_gEn).toList())}',
              '${_hiOrdinal[h]} भाव: ${_listHi(Graha.values.where((Graha x) => c.house(x) == h).map(_gHi).toList())}',
            ),
        ],
      ),
    );
  }

  // --- Kahala (BPHS 36.9) ----------------------------------------------------
  // Either the 4th lord and Jupiter stand in mutual kendras (4, 7 or 10 from
  // each other; a conjunction is not counted) with a strong lagna lord, or the
  // 4th lord is in its own or exaltation sign together with the 10th lord.
  final Graha fourth = c.lordOfHouse(4);
  final Graha tenth = c.lordOfHouse(10);
  final int jupiterFromFourth = c.houseFromGraha(fourth, Graha.jupiter);
  final bool routeJupiter =
      fourth != Graha.jupiter &&
      <int>[4, 7, 10].contains(jupiterFromFourth) &&
      c.strong(lagnaLord);
  final bool routeTenth = c.inOwnOrExalted(fourth) && c.together(fourth, tenth);
  if (routeJupiter || routeTenth) {
    out.add(
      _make(
        key: 'kahala',
        family: YogaFamily.general,
        name: const _T('Kahala yoga', 'काहल योग'),
        rule: routeJupiter
            ? _T(
                'The lord of the 4th (${_gEn(fourth)}) and Jupiter stand in mutual kendras, ${_enOrd(jupiterFromFourth)} from each other, and the lagna lord (${_gEn(lagnaLord)}) is strong.',
                'चौथे भाव के स्वामी (${_gHi(fourth)}) और गुरु एक-दूसरे से ${_hiOrdinal[jupiterFromFourth]} केंद्र में हैं, और लग्न स्वामी (${_gHi(lagnaLord)}) बली है।',
              )
            : _T(
                'The lord of the 4th (${_gEn(fourth)}) is in its own or exaltation sign, ${_sEn(c.sign(fourth))}, together with the lord of the 10th (${_gEn(tenth)}).',
                'चौथे भाव के स्वामी (${_gHi(fourth)}) अपनी या उच्च राशि ${_sHi(c.sign(fourth))} में हैं, दसवें भाव के स्वामी (${_gHi(tenth)}) के साथ।',
              ),
        meaning: const _T(
          'Kahala is a war-drum: the tradition reads boldness, a commanding manner and the courage to lead a group. It describes temperament, not conquest.',
          'काहल युद्ध का नगाड़ा है: परंपरा इसे साहस, प्रभावशाली स्वभाव और समूह का नेतृत्व करने के हौसले से जोड़ती है। यह स्वभाव की बात है, विजय की नहीं।',
        ),
        source: const _T(
          'BPHS 36.9: the 4th lord and Jupiter in mutual kendras with a strong lagna lord, or the 4th lord in its own or exaltation sign with the 10th lord. Books also state a 4th-and-9th-lord form; the verse itself is followed here.',
          'बृहत्पाराशर 36.9: चौथे का स्वामी और गुरु परस्पर केंद्र में, बली लग्न स्वामी सहित, अथवा चौथे का स्वामी स्व या उच्च राशि में दसवें के स्वामी के साथ। कुछ पुस्तकों में चौथे-नौवें स्वामी वाला रूप भी है; यहाँ श्लोक का ही पाठ लिया है।',
        ),
        factors: routeJupiter
            ? <_T>[c.lordFactor(4), c.factor(Graha.jupiter), c.lordFactor(1)]
            : <_T>[c.lordFactor(4), c.lordFactor(10)],
      ),
    );
  }

  return out;
}

// -----------------------------------------------------------------------------
// The Nabhasa yogas (BPHS chapter 35).
// -----------------------------------------------------------------------------
//
// Parashara names thirty-two: three Asraya (by the quality of the signs), two
// Dala (benefics or malefics in three kendras), twenty Akriti (by the shape the
// grahas make in the houses) and seven Sankhya (by how many signs they occupy).
// All of them are stated for the seven grahas from the Sun to Saturn; Rahu and
// Ketu are not counted. Thirty-one are implemented. Ardha Chandra is not: it is
// listed in 35.5, but the verse that defines it is missing from the text I
// checked, and the books that give it disagree.
//
// Readings, exactly as the checked verses give them:
//
//  * "Asraya" 35.7 rajju (movable signs), musala (fixed), nala (dual).
//  * "Dala" 35.8: three kendras occupied by benefics (mala) or malefics (sarpa).
//  * "Akriti" 35.9-35.15: see the table below.
//  * "Sankhya" 35.16-35.17: the number of signs occupied. The closing words of
//    35.17 are read, as the English translation at jyotishvidya.com renders
//    them, as: none of these seven operates if another Nabhasa yoga above holds.
//    The Sankhya findings are therefore reported only when no other Nabhasa
//    yoga was found. A consequence worth knowing: a chart with all seven
//    grahas in one sign always satisfies one of the three Asraya yogas, so Gola
//    is never reported, and Yuga is reported only when its two signs differ in
//    quality. Both stay in the table so their readings exist if the rule is
//    ever read more loosely.
//
// How strictly a span is read. BPHS 35.13-35.15 say the grahas are "in" four,
// seven or six houses. Two readings exist: all seven lie somewhere within the
// span, or every house of the span is occupied. A wrong yoga is worse than a
// missing one, so the stricter reading is used for every Akriti yoga that
// names a set of houses: the grahas occupy exactly that set, every house of it
// holding at least one graha. (PyJHora applies the same strictness to the
// seven-house and alternate-house yogas, and the Sanskrit "sarva-kendra-gataih"
// of Kamala points the same way.) A chart a looser astrologer would call Yupa
// or Nauka can therefore be missed here, but is never over-called.

class _NbState {
  _NbState(this.c) {
    for (final Graha x in _seven) {
      final int h = c.house(x);
      byHouse.putIfAbsent(h, () => <Graha>[]).add(x);
      signs.add(c.sign(x));
    }
  }

  final _Ctx c;
  final Map<int, List<Graha>> byHouse = <int, List<Graha>>{};
  final Set<int> signs = <int>{};

  Set<int> get houses => byHouse.keys.toSet();

  bool occupiesExactly(Iterable<int> named) {
    final Set<int> want = named.toSet();
    final Set<int> have = houses;
    return have.length == want.length && have.containsAll(want);
  }
}

class _Nb {
  const _Nb({
    required this.key,
    required this.nameEn,
    required this.nameHi,
    required this.verse,
    required this.resultVerse,
    required this.defEn,
    required this.defHi,
    required this.areaEn,
    required this.areaHi,
    required this.tone,
    required this.test,
    this.asksEn,
    this.asksHi,
  });

  final String key;
  final String nameEn;
  final String nameHi;
  final String verse;
  final String resultVerse;
  final String defEn;
  final String defHi;
  final String areaEn;
  final String areaHi;

  /// 0 favourable, 1 mixed, 2 hard (as the text reads it, not as we state it).
  final int tone;
  final bool Function(_NbState) test;
  final String? asksEn;
  final String? asksHi;
}

const List<String> _areaEn = <String>[
  '',
  'the self',
  'resources and speech',
  'effort and courage',
  'home and inner peace',
  'learning and creativity',
  'service and daily effort',
  'partnership',
  'change and depth',
  'fortune and duty',
  'work and standing',
  'gains and friends',
  'outlay and retreat',
];

const List<String> _areaHi = <String>[
  '',
  'स्वयं',
  'संचय और वाणी',
  'पराक्रम',
  'घर और मन की शांति',
  'विद्या और सृजन',
  'सेवा और दैनिक प्रयास',
  'साझेदारी',
  'परिवर्तन और गहराई',
  'भाग्य और धर्म',
  'कर्म और प्रतिष्ठा',
  'लाभ और मित्र',
  'व्यय और एकांत',
];

bool _allInQuality(_NbState s, Quality q) => _seven.every(
  (Graha x) => rashiInfo(Rashi.values[s.c.sign(x)]).quality == q,
);

bool _threeKendras(_NbState s, bool Function(Graha) kind) =>
    _kendras
        .where((int h) => _seven.any((Graha x) => s.c.house(x) == h && kind(x)))
        .length >=
    3;

bool _inHouse(_NbState s, int h, bool Function(Graha) kind) =>
    _seven.any((Graha x) => s.c.house(x) == h && kind(x));

List<int> _run(int start, int length) => <int>[
  for (int i = 0; i < length; i++) ((start - 1 + i) % 12) + 1,
];

final List<_Nb> _nabhasaTable = <_Nb>[
  // --- Asraya (35.7) -------------------------------------------------------
  _Nb(
    key: 'rajju',
    nameEn: 'Rajju',
    nameHi: 'रज्जु',
    verse: '35.7',
    resultVerse: '35.18',
    defEn: 'All seven grahas stand in movable signs.',
    defHi: 'सातों ग्रह चर राशियों में हैं।',
    areaEn:
        'A chart of movement: initiative, travel, change of place, and a life or livelihood that carries one away from where one began. The edge of it is restlessness.',
    areaHi:
        'गति की कुंडली: पहल, यात्रा, स्थान-परिवर्तन, और ऐसा जीवन या जीविका जो व्यक्ति को शुरुआती स्थान से दूर ले जाए। इसकी धार बेचैनी है।',
    tone: 1,
    test: (_NbState s) => _allInQuality(s, Quality.movable),
  ),
  _Nb(
    key: 'musala',
    nameEn: 'Musala',
    nameHi: 'मुसल',
    verse: '35.7',
    resultVerse: '35.19',
    defEn: 'All seven grahas stand in fixed signs.',
    defHi: 'सातों ग्रह स्थिर राशियों में हैं।',
    areaEn:
        'A chart of steadiness: firmness, persistence, a settled and dignified way of life. The edge of it is obstinacy.',
    areaHi:
        'स्थिरता की कुंडली: दृढ़ता, निरंतरता, टिकाऊ और गरिमामय जीवन-शैली। इसकी धार हठ है।',
    tone: 0,
    test: (_NbState s) => _allInQuality(s, Quality.fixed),
  ),
  _Nb(
    key: 'nala',
    nameEn: 'Nala',
    nameHi: 'नल',
    verse: '35.7',
    resultVerse: '35.20',
    defEn: 'All seven grahas stand in dual signs.',
    defHi: 'सातों ग्रह द्विस्वभाव राशियों में हैं।',
    areaEn:
        'A chart of versatility: skill in many things, adaptability and a readiness to help relatives. The edge of it is scattered attention.',
    areaHi:
        'बहुमुखी प्रतिभा की कुंडली: कई कामों में कुशलता, अनुकूलन और रिश्तेदारों की मदद करने की तत्परता। इसकी धार बिखरा हुआ ध्यान है।',
    tone: 0,
    test: (_NbState s) => _allInQuality(s, Quality.dual),
  ),
  // --- Dala (35.8) ---------------------------------------------------------
  _Nb(
    key: 'mala',
    nameEn: 'Mala',
    nameHi: 'माला',
    verse: '35.8',
    resultVerse: '35.21',
    defEn:
        'Three of the four kendras each hold Jupiter, Venus or an unafflicted Mercury.',
    defHi:
        'चार में से तीन केंद्र भावों में गुरु, शुक्र या अपीड़ित बुध में से कोई एक-एक है।',
    areaEn:
        'The pillars of the chart are held by the gentle grahas: comfort in daily life, pleasant company and a liking for fine things.',
    areaHi:
        'कुंडली के स्तंभ सौम्य ग्रहों के हाथ में हैं: दैनिक जीवन में सुख, सुखद संगति और अच्छी चीज़ों के प्रति रुचि।',
    tone: 0,
    test: (_NbState s) => _threeKendras(s, s.c.nabhasaBenefic),
  ),
  _Nb(
    key: 'sarpa',
    nameEn: 'Sarpa',
    nameHi: 'सर्प (भुजंग)',
    verse: '35.8',
    resultVerse: '35.22',
    defEn: 'Three of the four kendras each hold the Sun, Mars or Saturn.',
    defHi:
        'चार में से तीन केंद्र भावों में सूर्य, मंगल या शनि में से कोई एक-एक है।',
    areaEn:
        'The pillars of the chart (the self, home, partnership and work) are held by the three severe grahas: authority, drive and discipline, carried with some weight.',
    areaHi:
        'कुंडली के स्तंभ (स्वयं, घर, साझेदारी और कर्म) तीन कठोर ग्रहों के हाथ में हैं: अधिकार, ऊर्जा और अनुशासन, कुछ भार के साथ।',
    tone: 2,
    test: (_NbState s) => _threeKendras(s, s.c.nabhasaMalefic),
    asksEn:
        'It asks for deliberate gentleness: warmth, rest and softer speech, so that strength does not harden into severity.',
    asksHi:
        'यह जान-बूझकर कोमलता माँगता है: स्नेह, विश्राम और नरम वाणी, ताकि बल कठोरता में न बदले।',
  ),
  // --- Akriti (35.9-35.15) -------------------------------------------------
  _Nb(
    key: 'gada',
    nameEn: 'Gada',
    nameHi: 'गदा',
    verse: '35.9',
    resultVerse: '35.23',
    defEn:
        'The grahas stand in two adjacent kendras and fill both (1 and 4, 4 and 7, 7 and 10, or 10 and 1).',
    defHi:
        'ग्रह दो आसन्न केंद्रों में हैं और दोनों को भरते हैं (1-4, 4-7, 7-10 या 10-1)।',
    areaEn:
        'The weight of the chart rests on two neighbouring pillars of life, pursued with constant application. The tradition reads industry and a taste for learning and ritual.',
    areaHi:
        'कुंडली का भार जीवन के दो पास-पास के स्तंभों पर है, जिन्हें निरंतर लगन से साधा जाता है। परंपरा इसे उद्यम और विद्या व अनुष्ठान की रुचि से जोड़ती है।',
    tone: 0,
    test: (_NbState s) => <List<int>>[
      <int>[1, 4],
      <int>[4, 7],
      <int>[7, 10],
      <int>[10, 1],
    ].any(s.occupiesExactly),
  ),
  _Nb(
    key: 'nabhasa_shakata',
    nameEn: 'Shakata (Nabhasa)',
    nameHi: 'शकट (नाभस)',
    verse: '35.9',
    resultVerse: '35.24',
    defEn: 'The grahas stand in the 1st and 7th houses only and fill both.',
    defHi: 'ग्रह केवल पहले और सातवें भाव में हैं और दोनों को भरते हैं।',
    areaEn:
        'A life organised around two wheels, the self and the partner. The chart’s weight lies on that one axis.',
    areaHi:
        'दो पहियों, स्वयं और साथी, के इर्द-गिर्द व्यवस्थित जीवन। कुंडली का भार उसी एक धुरी पर है।',
    tone: 2,
    test: (_NbState s) => s.occupiesExactly(<int>[1, 7]),
    asksEn:
        'It asks for balance: giving work, home and friends a place of their own so that the whole life does not ride on one axis.',
    asksHi:
        'यह संतुलन माँगता है: कर्म, घर और मित्रों को अपना स्थान देना, ताकि पूरा जीवन एक ही धुरी पर न टिके।',
  ),
  _Nb(
    key: 'vihaga',
    nameEn: 'Vihaga',
    nameHi: 'विहग',
    verse: '35.9',
    resultVerse: '35.25',
    defEn: 'The grahas stand in the 4th and 10th houses only and fill both.',
    defHi: 'ग्रह केवल चौथे और दसवें भाव में हैं और दोनों को भरते हैं।',
    areaEn:
        'A life between home and work, the two ends of the day. The tradition reads a bird’s roaming temperament, a liking for movement and for errands carried between places.',
    areaHi:
        'घर और कर्म के बीच का जीवन, दिन के दो छोर। परंपरा इसे पक्षी जैसे घुमक्कड़ स्वभाव, गति और स्थानों के बीच संदेश-वाहक के काम की रुचि से जोड़ती है।',
    tone: 1,
    test: (_NbState s) => s.occupiesExactly(<int>[4, 10]),
  ),
  _Nb(
    key: 'shringataka',
    nameEn: 'Shringataka',
    nameHi: 'शृंगाटक',
    verse: '35.10',
    resultVerse: '35.26',
    defEn:
        'The grahas stand in the 1st, 5th and 9th houses and fill all three.',
    defHi: 'ग्रह पहले, पाँचवें और नौवें भाव में हैं और तीनों को भरते हैं।',
    areaEn:
        'The dharma trine holds the whole chart: the self, learning and fortune. The tradition reads a spirited, argumentative nature that holds its ground.',
    areaHi:
        'पूरी कुंडली धर्म त्रिकोण में है: स्वयं, विद्या और भाग्य। परंपरा इसे जोशीले, तर्कप्रिय और अपनी बात पर टिके रहने वाले स्वभाव से जोड़ती है।',
    tone: 1,
    test: (_NbState s) => s.occupiesExactly(<int>[1, 5, 9]),
  ),
  _Nb(
    key: 'hala',
    nameEn: 'Hala',
    nameHi: 'हल',
    verse: '35.10',
    resultVerse: '35.27',
    defEn:
        'The grahas fill one of the three trines that do not include the lagna (2, 6, 10; 3, 7, 11; or 4, 8, 12).',
    defHi:
        'ग्रह उन तीन त्रिकोणों में से एक को भरते हैं जिनमें लग्न नहीं है (2, 6, 10; 3, 7, 11; या 4, 8, 12)।',
    areaEn:
        'The whole chart sits in a trine away from the self, among the houses of means, desire or release. The plough: effort turned to the field.',
    areaHi:
        'पूरी कुंडली स्वयं से दूर किसी त्रिकोण में है, अर्थ, काम या मोक्ष के भावों में। हल: श्रम खेत की ओर मुड़ा हुआ।',
    tone: 2,
    test: (_NbState s) => <List<int>>[
      <int>[2, 6, 10],
      <int>[3, 7, 11],
      <int>[4, 8, 12],
    ].any(s.occupiesExactly),
    asksEn:
        'It asks that the self, the first house, is not forgotten while the effort goes to the field: rest, play and one’s own needs belong in the plan.',
    asksHi:
        'यह माँगता है कि श्रम खेत में लगा रहे तो भी स्वयं, यानी पहला भाव, भुलाया न जाए: विश्राम, खेल और अपनी ज़रूरतें योजना का हिस्सा हैं।',
  ),
  _Nb(
    key: 'vajra',
    nameEn: 'Vajra',
    nameHi: 'वज्र',
    verse: '35.11',
    resultVerse: '35.28',
    defEn:
        'Benefics (Jupiter, Venus, Mercury) stand in the 1st and 7th and malefics (Sun, Mars, Saturn) in the 4th and 10th.',
    defHi:
        'शुभ ग्रह (गुरु, शुक्र, बुध) पहले और सातवें भाव में और पाप ग्रह (सूर्य, मंगल, शनि) चौथे और दसवें भाव में हैं।',
    areaEn:
        'Gentle grahas hold the self and the partner; the severe ones hold home and work. The tradition reads warmth in the personal sphere and a hard, driven public side.',
    areaHi:
        'सौम्य ग्रह स्वयं और साथी को सँभालते हैं; कठोर ग्रह घर और कर्म को। परंपरा इसे निजी क्षेत्र में स्नेह और सार्वजनिक पक्ष में कठोर, उद्यमी स्वभाव से जोड़ती है।',
    tone: 1,
    test: (_NbState s) =>
        _inHouse(s, 1, s.c.nabhasaBenefic) &&
        _inHouse(s, 7, s.c.nabhasaBenefic) &&
        _inHouse(s, 4, s.c.nabhasaMalefic) &&
        _inHouse(s, 10, s.c.nabhasaMalefic),
  ),
  _Nb(
    key: 'yava',
    nameEn: 'Yava',
    nameHi: 'यव',
    verse: '35.11',
    resultVerse: '35.29',
    defEn:
        'Malefics (Sun, Mars, Saturn) stand in the 1st and 7th and benefics (Jupiter, Venus, Mercury) in the 4th and 10th.',
    defHi:
        'पाप ग्रह (सूर्य, मंगल, शनि) पहले और सातवें भाव में और शुभ ग्रह (गुरु, शुक्र, बुध) चौथे और दसवें भाव में हैं।',
    areaEn:
        'The severe grahas hold the self and the partner; the gentle ones hold home and work. The tradition reads observance, discipline in the early years and a generous, settled middle of life.',
    areaHi:
        'कठोर ग्रह स्वयं और साथी को सँभालते हैं; सौम्य ग्रह घर और कर्म को। परंपरा इसे व्रत-नियम, आरंभिक वर्षों के अनुशासन और उदार, स्थिर मध्य-जीवन से जोड़ती है।',
    tone: 0,
    test: (_NbState s) =>
        _inHouse(s, 1, s.c.nabhasaMalefic) &&
        _inHouse(s, 7, s.c.nabhasaMalefic) &&
        _inHouse(s, 4, s.c.nabhasaBenefic) &&
        _inHouse(s, 10, s.c.nabhasaBenefic),
  ),
  _Nb(
    key: 'kamala',
    nameEn: 'Kamala',
    nameHi: 'कमल',
    verse: '35.12',
    resultVerse: '35.30',
    defEn: 'The grahas stand in the four kendras and fill all four.',
    defHi: 'ग्रह चारों केंद्रों में हैं और चारों को भरते हैं।',
    areaEn:
        'All four pillars of the chart, the self, home, partnership and work, hold grahas. The lotus: a life with presence in every main area, and a name that spreads.',
    areaHi:
        'कुंडली के चारों स्तंभ, स्वयं, घर, साझेदारी और कर्म, ग्रहों से भरे हैं। कमल: हर मुख्य क्षेत्र में उपस्थिति वाला जीवन और फैलता हुआ नाम।',
    tone: 0,
    test: (_NbState s) => s.occupiesExactly(_kendras),
  ),
  _Nb(
    key: 'vapi',
    nameEn: 'Vapi',
    nameHi: 'वापी',
    verse: '35.12',
    resultVerse: '35.31',
    defEn:
        'The grahas fill all four succedent houses (2, 5, 8, 11) or all four cadent houses (3, 6, 9, 12) and no others.',
    defHi:
        'ग्रह चारों पणफर भावों (2, 5, 8, 11) या चारों आपोक्लिम भावों (3, 6, 9, 12) को भरते हैं, अन्य को नहीं।',
    areaEn:
        'The chart gathers in the houses of keeping and of effort, away from the four pillars. The reservoir: the tradition reads a gift for storing, managing and tending what is held.',
    areaHi:
        'कुंडली चारों स्तंभों से हटकर संचय और प्रयास के भावों में एकत्र है। जलाशय: परंपरा इसे संग्रह, प्रबंध और जो पास है उसकी देखभाल की प्रतिभा से जोड़ती है।',
    tone: 0,
    test: (_NbState s) =>
        s.occupiesExactly(<int>[2, 5, 8, 11]) ||
        s.occupiesExactly(<int>[3, 6, 9, 12]),
  ),
  _Nb(
    key: 'yupa',
    nameEn: 'Yupa',
    nameHi: 'यूप',
    verse: '35.13',
    resultVerse: '35.32',
    defEn:
        'The grahas fill the four houses from the 1st to the 4th and no others.',
    defHi: 'ग्रह पहले से चौथे तक के चारों भावों को भरते हैं, अन्य को नहीं।',
    areaEn:
        'The whole chart lies in the self, resources, effort and home: an inward, private life. The tradition reads devotion, observance and a seeking of the inner life.',
    areaHi:
        'पूरी कुंडली स्वयं, संचय, पराक्रम और घर में है: भीतर की ओर मुड़ा निजी जीवन। परंपरा इसे भक्ति, व्रत-नियम और अंतर्जीवन की खोज से जोड़ती है।',
    tone: 0,
    test: (_NbState s) => s.occupiesExactly(_run(1, 4)),
  ),
  _Nb(
    key: 'shara',
    nameEn: 'Shara',
    nameHi: 'शर',
    verse: '35.13',
    resultVerse: '35.33',
    defEn:
        'The grahas fill the four houses from the 4th to the 7th and no others.',
    defHi: 'ग्रह चौथे से सातवें तक के चारों भावों को भरते हैं, अन्य को नहीं।',
    areaEn:
        'The chart lies in home, learning, service and partnership. The arrow: effort aimed at a target, with some sharpness in it.',
    areaHi:
        'कुंडली घर, विद्या, सेवा और साझेदारी में है। शर: लक्ष्य पर साधा गया प्रयास, जिसमें कुछ तीखापन है।',
    tone: 2,
    test: (_NbState s) => s.occupiesExactly(_run(4, 4)),
    asksEn:
        'It asks for sharpness to be kept for the work and not turned on people: aim carefully, and let the home be the place where the bow is put down.',
    asksHi:
        'यह माँगता है कि तीखापन काम के लिए रखा जाए, लोगों पर नहीं: सोचकर निशाना साधें, और घर वह जगह हो जहाँ धनुष रखा जाता है।',
  ),
  _Nb(
    key: 'shakti',
    nameEn: 'Shakti',
    nameHi: 'शक्ति',
    verse: '35.13',
    resultVerse: '35.34',
    defEn:
        'The grahas fill the four houses from the 7th to the 10th and no others.',
    defHi: 'ग्रह सातवें से दसवें तक के चारों भावों को भरते हैं, अन्य को नहीं।',
    areaEn:
        'The chart lies in partnership, change, fortune and work: strength turned outward, toward other people and public life. The tradition reads staying power, with an edge of impatience.',
    areaHi:
        'कुंडली साझेदारी, परिवर्तन, भाग्य और कर्म में है: बल बाहर की ओर, दूसरों और सार्वजनिक जीवन की ओर। परंपरा इसे टिकाऊपन से जोड़ती है, जिसकी धार अधीरता है।',
    tone: 1,
    test: (_NbState s) => s.occupiesExactly(_run(7, 4)),
  ),
  _Nb(
    key: 'danda',
    nameEn: 'Danda',
    nameHi: 'दंड',
    verse: '35.13',
    resultVerse: '35.35',
    defEn:
        'The grahas fill the four houses from the 10th to the 1st (10, 11, 12, 1) and no others.',
    defHi:
        'ग्रह दसवें से पहले तक के चारों भावों (10, 11, 12, 1) को भरते हैं, अन्य को नहीं।',
    areaEn:
        'The chart lies in work, gains, outlay and the self. The staff: a life of duty and labour, carried largely alone.',
    areaHi:
        'कुंडली कर्म, लाभ, व्यय और स्वयं में है। दंड: कर्तव्य और श्रम का जीवन, जिसे ज़्यादातर अकेले उठाया जाता है।',
    tone: 2,
    test: (_NbState s) => s.occupiesExactly(_run(10, 4)),
    asksEn:
        'It asks that labour be shared and rest be kept: the circle of family and friends is where the staff can be set down.',
    asksHi:
        'यह माँगता है कि श्रम बाँटा जाए और विश्राम बचाकर रखा जाए: परिवार और मित्रों का दायरा वह जगह है जहाँ दंड नीचे रखा जा सकता है।',
  ),
  _Nb(
    key: 'nauka',
    nameEn: 'Nauka',
    nameHi: 'नौका',
    verse: '35.14',
    resultVerse: '35.36',
    defEn:
        'The grahas fill the seven houses from the 1st to the 7th, every one occupied.',
    defHi:
        'ग्रह पहले से सातवें तक के सातों भावों को भरते हैं, हर भाव में ग्रह है।',
    areaEn:
        'The first seven houses are all occupied: a life lived in the open, among people and exchange. The boat: livelihood tied to carrying and trading across distance.',
    areaHi:
        'पहले सात भाव सब भरे हैं: लोगों और लेन-देन के बीच खुला जीवन। नौका: दूरी के आर-पार ढोने और व्यापार से जुड़ी जीविका।',
    tone: 1,
    test: (_NbState s) => s.occupiesExactly(_run(1, 7)),
  ),
  _Nb(
    key: 'koota',
    nameEn: 'Koota',
    nameHi: 'कूट',
    verse: '35.14',
    resultVerse: '35.37',
    defEn:
        'The grahas fill the seven houses from the 4th to the 10th, every one occupied.',
    defHi:
        'ग्रह चौथे से दसवें तक के सातों भावों को भरते हैं, हर भाव में ग्रह है।',
    areaEn:
        'The chart lies from home round to work, with the self and the closing houses empty. The mountain peak: a guarded, self-contained way of life.',
    areaHi:
        'कुंडली घर से लेकर कर्म तक है, स्वयं और अंतिम भाव खाली हैं। पर्वत-शिखर: सुरक्षित, आत्मनिर्भर जीवन-शैली।',
    tone: 2,
    test: (_NbState s) => s.occupiesExactly(_run(4, 7)),
    asksEn:
        'It asks for openness: letting people in and speaking plainly, so that a well-guarded life does not become a lonely one.',
    asksHi:
        'यह खुलापन माँगता है: लोगों को पास आने देना और सीधी बात कहना, ताकि सुरक्षित जीवन अकेला जीवन न बन जाए।',
  ),
  _Nb(
    key: 'chhatra',
    nameEn: 'Chhatra',
    nameHi: 'छत्र',
    verse: '35.14',
    resultVerse: '35.38',
    defEn:
        'The grahas fill the seven houses from the 7th to the 1st, every one occupied.',
    defHi:
        'ग्रह सातवें से पहले तक के सातों भावों को भरते हैं, हर भाव में ग्रह है।',
    areaEn:
        'The chart runs from partnership round to the self. The umbrella: a sheltering disposition, mindful of relatives and of those who depend on one.',
    areaHi:
        'कुंडली साझेदारी से घूमकर स्वयं तक है। छत्र: आश्रय देने वाला स्वभाव, जो रिश्तेदारों और आश्रितों का ध्यान रखता है।',
    tone: 0,
    test: (_NbState s) => s.occupiesExactly(_run(7, 7)),
  ),
  _Nb(
    key: 'chapa',
    nameEn: 'Chapa',
    nameHi: 'चाप',
    verse: '35.14',
    resultVerse: '35.39',
    defEn:
        'The grahas fill the seven houses from the 10th to the 4th, every one occupied.',
    defHi:
        'ग्रह दसवें से चौथे तक के सातों भावों को भरते हैं, हर भाव में ग्रह है।',
    areaEn:
        'The chart runs from work round to home. The bow: a drawn, tensioned life, with effort in the early years easing toward the middle.',
    areaHi:
        'कुंडली कर्म से घूमकर घर तक है। चाप: खिंचा हुआ, तनाव वाला जीवन, जिसमें आरंभ का श्रम मध्य की ओर हल्का होता है।',
    tone: 1,
    test: (_NbState s) => s.occupiesExactly(_run(10, 7)),
  ),
  _Nb(
    key: 'chakra',
    nameEn: 'Chakra',
    nameHi: 'चक्र',
    verse: '35.15',
    resultVerse: '35.41',
    defEn:
        'The grahas fill the six odd houses from the lagna (1, 3, 5, 7, 9, 11), every one occupied.',
    defHi:
        'ग्रह लग्न से विषम छह भावों (1, 3, 5, 7, 9, 11) को भरते हैं, हर भाव में ग्रह है।',
    areaEn:
        'Every odd house holds a graha: the self, effort, learning, partnership, fortune and gains. The wheel: a life that turns steadily and draws people around it.',
    areaHi:
        'हर विषम भाव में ग्रह है: स्वयं, पराक्रम, विद्या, साझेदारी, भाग्य और लाभ। चक्र: ऐसा जीवन जो निरंतर घूमता है और लोगों को अपने चारों ओर खींचता है।',
    tone: 0,
    test: (_NbState s) => s.occupiesExactly(<int>[1, 3, 5, 7, 9, 11]),
  ),
  _Nb(
    key: 'samudra',
    nameEn: 'Samudra',
    nameHi: 'समुद्र',
    verse: '35.15',
    resultVerse: '35.42',
    defEn:
        'The grahas fill the six even houses from the lagna (2, 4, 6, 8, 10, 12), every one occupied.',
    defHi:
        'ग्रह लग्न से सम छह भावों (2, 4, 6, 8, 10, 12) को भरते हैं, हर भाव में ग्रह है।',
    areaEn:
        'Every even house holds a graha: resources, home, service, depth, work and outlay. The ocean: a deep, full life with a fondness for family and good conduct.',
    areaHi:
        'हर सम भाव में ग्रह है: संचय, घर, सेवा, गहराई, कर्म और व्यय। समुद्र: गहरा, भरा-पूरा जीवन जिसमें परिवार और सदाचार के प्रति लगाव है।',
    tone: 0,
    test: (_NbState s) => s.occupiesExactly(<int>[2, 4, 6, 8, 10, 12]),
  ),
];

/// The Sankhya yogas, by the number of signs the seven grahas occupy.
final Map<int, _Nb> _sankhyaTable = <int, _Nb>{
  7: _Nb(
    key: 'veena',
    nameEn: 'Veena (Vallaki)',
    nameHi: 'वीणा (वल्लकी)',
    verse: '35.17',
    resultVerse: '35.43',
    defEn: 'The seven grahas occupy seven different signs.',
    defHi: 'सातों ग्रह सात अलग-अलग राशियों में हैं।',
    areaEn:
        'Every graha has a sign to itself, so each theme of life is voiced separately. The veena: the tradition reads a taste for music and the arts and a life with many hands to help.',
    areaHi:
        'हर ग्रह की अपनी राशि है, इसलिए जीवन का हर विषय अलग स्वर में बोलता है। वीणा: परंपरा इसे संगीत और कलाओं की रुचि और बहुत से सहायकों वाले जीवन से जोड़ती है।',
    tone: 0,
    test: _never,
  ),
  6: _Nb(
    key: 'dama',
    nameEn: 'Dama (Damini)',
    nameHi: 'दाम (दामिनी)',
    verse: '35.17',
    resultVerse: '35.44',
    defEn: 'The seven grahas occupy six different signs.',
    defHi: 'सातों ग्रह छह अलग-अलग राशियों में हैं।',
    areaEn:
        'The grahas are spread over six signs. The garland: the tradition reads a giving, helpful disposition and a wide reach among people.',
    areaHi:
        'ग्रह छह राशियों में फैले हैं। दाम: परंपरा इसे देने वाले, सहायक स्वभाव और लोगों के बीच व्यापक पहुँच से जोड़ती है।',
    tone: 0,
    test: _never,
  ),
  5: _Nb(
    key: 'pasha',
    nameEn: 'Pasha',
    nameHi: 'पाश',
    verse: '35.17',
    resultVerse: '35.45',
    defEn: 'The seven grahas occupy five different signs.',
    defHi: 'सातों ग्रह पाँच अलग-अलग राशियों में हैं।',
    areaEn:
        'The grahas are gathered in five signs. The noose: many ties and dependants, a busy, talkative life, and skill at work that holds a household together.',
    areaHi:
        'ग्रह पाँच राशियों में जुटे हैं। पाश: बहुत से बंधन और आश्रित, व्यस्त और बातूनी जीवन, और घर-परिवार को बाँधे रखने वाला कार्य-कौशल।',
    tone: 1,
    test: _never,
  ),
  4: _Nb(
    key: 'kedara',
    nameEn: 'Kedara',
    nameHi: 'केदार',
    verse: '35.16',
    resultVerse: '35.46',
    defEn: 'The seven grahas occupy four different signs.',
    defHi: 'सातों ग्रह चार अलग-अलग राशियों में हैं।',
    areaEn:
        'The grahas are gathered in four signs. The field: a life of cultivation and service to many, with steady yield and a changeable temper.',
    areaHi:
        'ग्रह चार राशियों में जुटे हैं। केदार: खेती और बहुतों की सेवा का जीवन, जिसमें उपज स्थिर है और स्वभाव बदलने वाला।',
    tone: 1,
    test: _never,
  ),
  3: _Nb(
    key: 'shoola',
    nameEn: 'Shoola',
    nameHi: 'शूल',
    verse: '35.16',
    resultVerse: '35.47',
    defEn: 'The seven grahas occupy three different signs.',
    defHi: 'सातों ग्रह तीन अलग-अलग राशियों में हैं।',
    areaEn:
        'The grahas are packed into three signs. The spear: a sharp, bold and quick temperament with courage when challenged.',
    areaHi:
        'ग्रह तीन राशियों में सिमटे हैं। शूल: तीखा, निडर और तेज़ स्वभाव, जो चुनौती मिलने पर साहस दिखाता है।',
    tone: 2,
    test: _never,
    asksEn:
        'It asks for the sharpness to be channelled into craft, protection and effort, and for rest between bursts.',
    asksHi:
        'यह माँगता है कि तीखेपन को शिल्प, रक्षा और प्रयास में लगाया जाए, और तेज़ दौर के बीच विश्राम रखा जाए।',
  ),
  2: _Nb(
    key: 'yuga',
    nameEn: 'Yuga',
    nameHi: 'युग',
    verse: '35.16',
    resultVerse: '35.48',
    defEn: 'The seven grahas occupy two signs only.',
    defHi: 'सातों ग्रह केवल दो राशियों में हैं।',
    areaEn:
        'The whole chart is gathered into two signs, so life is organised around two themes. The yoke: depth in those two, and little spread beyond them.',
    areaHi:
        'पूरी कुंडली दो राशियों में सिमटी है, इसलिए जीवन दो विषयों के इर्द-गिर्द है। युग: उन दो में गहराई, और उनसे आगे कम फैलाव।',
    tone: 2,
    test: _never,
    asksEn:
        'It asks for a deliberate widening: other interests, other company and other sources of learning, so the two themes do not become the only rooms in the house.',
    asksHi:
        'यह जान-बूझकर विस्तार माँगता है: दूसरी रुचियाँ, दूसरी संगति और सीखने के दूसरे स्रोत, ताकि दो विषय ही घर के एकमात्र कमरे न बन जाएँ।',
  ),
  1: _Nb(
    key: 'gola',
    nameEn: 'Gola',
    nameHi: 'गोल',
    verse: '35.16',
    resultVerse: '35.49',
    defEn: 'All seven grahas occupy one sign.',
    defHi: 'सातों ग्रह एक ही राशि में हैं।',
    areaEn:
        'The whole chart is gathered into one sign, so one theme colours everything. The sphere: great concentration and force of purpose, with a narrow range of interests.',
    areaHi:
        'पूरी कुंडली एक राशि में सिमटी है, इसलिए एक ही विषय सब कुछ रंग देता है। गोल: अत्यधिक एकाग्रता और उद्देश्य का बल, पर रुचियों का दायरा संकरा।',
    tone: 2,
    test: _never,
    asksEn:
        'It asks for a deliberate widening: seeking other company, other skills and other points of view, and letting the one great theme sit alongside them.',
    asksHi:
        'यह जान-बूझकर विस्तार माँगता है: दूसरी संगति, दूसरे हुनर और दूसरे दृष्टिकोण खोजना, और उस एक बड़े विषय को उनके साथ बैठने देना।',
  ),
};

bool _never(_NbState s) => false;

/// "1st house: Sun, Mercury; 4th house: Moon" in both languages.
_T _spread(_NbState s) {
  final List<int> hs = s.byHouse.keys.toList()..sort();
  return _T(
    hs
        .map(
          (int h) =>
              '${_enOrd(h)} house: ${_listEn(s.byHouse[h]!.map(_gEn).toList())}',
        )
        .join('; '),
    hs
        .map(
          (int h) =>
              '${_hiOrdinal[h]} भाव में ${_listHi(s.byHouse[h]!.map(_gHi).toList())}',
        )
        .join('; '),
  );
}

YogaFinding _nabhasaFinding(_NbState s, _Nb n, {required bool sankhya}) {
  final _T tone = switch (n.tone) {
    0 => _T(
      'BPHS ${n.resultVerse} reads this arrangement favourably.',
      'बृहत्पाराशर ${n.resultVerse} इस रचना को शुभ पढ़ता है।',
    ),
    1 => _T(
      'BPHS ${n.resultVerse} gives this arrangement a mixed reading; only the area and the disposition are stated here.',
      'बृहत्पाराशर ${n.resultVerse} इस रचना को मिश्रित फल देता है; यहाँ केवल क्षेत्र और स्वभाव बताया गया है।',
    ),
    _ => _T(
      'BPHS ${n.resultVerse} gives this arrangement a hard reading. It is not repeated here: a Nabhasa yoga is a broad mould, and what it asks of a person is stated below instead.',
      'बृहत्पाराशर ${n.resultVerse} इस रचना का कठोर फल बताता है। उसे यहाँ दोहराया नहीं गया: नाभस योग एक व्यापक साँचा है, और वह व्यक्ति से क्या माँगता है यह नीचे बताया है।',
    ),
  };
  final bool adverse = n.tone == 2;
  final _T spread = _spread(s);
  final List<int> shown = s.houses.toList()..sort();
  final _T pillars = n.key == 'gada' && shown.length == 2
      ? _T(
          'The two pillars here are ${_areaEn[shown[0]]} and ${_areaEn[shown[1]]}.',
          'यहाँ दो स्तंभ ${_areaHi[shown[0]]} और ${_areaHi[shown[1]]} हैं।',
        )
      : const _T('', '');
  final _T source = sankhya
      ? _T(
          'BPHS ${n.verse} (definition, by the number of signs) and ${n.resultVerse} (reading). Counted only because no Asraya, Dala or Akriti yoga holds in this chart. The condition is Parashara’s; the area-of-life wording is ours.',
          'बृहत्पाराशर ${n.verse} (परिभाषा, राशियों की संख्या से) और ${n.resultVerse} (फल)। इसे इसलिए गिना गया कि इस कुंडली में कोई आश्रय, दल या आकृति योग नहीं है। शर्त पराशर की है; जीवन-क्षेत्र की भाषा हमारी।',
        )
      : _T(
          'BPHS ${n.verse} (definition) and ${n.resultVerse} (reading). The condition is Parashara’s, as read from the Sanskrit; the area-of-life wording is ours.',
          'बृहत्पाराशर ${n.verse} (परिभाषा) और ${n.resultVerse} (फल)। शर्त पराशर की है, संस्कृत पाठ से पढ़ी गई; जीवन-क्षेत्र की भाषा हमारी।',
        );
  return _make(
    key: 'nabhasa_${n.key}'.replaceFirst('nabhasa_nabhasa_', 'nabhasa_'),
    family: YogaFamily.nabhasa,
    dosha: adverse,
    name: _T('${n.nameEn} yoga', '${n.nameHi} योग'),
    rule: _T(
      '${n.defEn} Here: ${spread.en}.',
      '${n.defHi} यहाँ: ${spread.hi}।',
    ),
    meaning: _join(<_T>[
      _T(n.areaEn, n.areaHi),
      if (pillars.en.isNotEmpty) pillars,
      tone,
    ]),
    source: source,
    factors: <_T>[for (final Graha x in _seven) s.c.factor(x)],
    mitigation: adverse ? _T(n.asksEn ?? '', n.asksHi ?? '') : null,
  );
}

List<YogaFinding> _nabhasaYogas(_Ctx c) {
  final _NbState s = _NbState(c);
  final List<YogaFinding> out = <YogaFinding>[];
  for (final _Nb n in _nabhasaTable) {
    if (n.test(s)) out.add(_nabhasaFinding(s, n, sankhya: false));
  }
  if (out.isEmpty) {
    final _Nb? sankhya = _sankhyaTable[s.signs.length];
    if (sankhya != null) {
      out.add(_nabhasaFinding(s, sankhya, sankhya: true));
    }
  }
  return out;
}

// -----------------------------------------------------------------------------
// Doshas from later and popular practice.
// -----------------------------------------------------------------------------
//
// None of the combinations below is one of the yogas I could verify in the
// chapters of the Brihat Parashara Hora Shastra read for this file. They are
// stated as practice, each by its plain placement rule, and each carries the
// softening that practitioners commonly give (Jupiter's company or aspect, or
// the graha being strong). Where nothing softens it in the chart, the finding
// says what the tradition asks of the person.

String _apart(_Ctx c, Graha a, Graha b) => formatDegrees(
  angleDiff(c.g[a]!.siderealLongitude, c.g[b]!.siderealLongitude).abs(),
);

/// Jupiter beside or aspecting [x]: the softening most often named.
bool _jupiterEases(_Ctx c, Graha x) =>
    x != Graha.jupiter &&
    (c.together(Graha.jupiter, x) || c.aspects(Graha.jupiter, x));

List<YogaFinding> _doshas(_Ctx c) {
  final List<YogaFinding> out = <YogaFinding>[];

  // --- Guru Chandal: Jupiter with Rahu -----------------------------------
  if (c.together(Graha.jupiter, Graha.rahu)) {
    final bool eased = c.inOwnOrExalted(Graha.jupiter);
    out.add(
      _make(
        key: 'guru_chandal',
        family: YogaFamily.dosha,
        dosha: true,
        name: const _T('Guru Chandal yoga', 'गुरु चांडाल योग'),
        rule: _T(
          'Jupiter and Rahu stand together in ${_sEn(c.sign(Graha.jupiter))}, house ${c.house(Graha.jupiter)}, ${_apart(c, Graha.jupiter, Graha.rahu)} apart.',
          'गुरु और राहु ${_sHi(c.sign(Graha.jupiter))} राशि में, ${_hiOrdinal[c.house(Graha.jupiter)]} भाव में, साथ हैं, ${_apart(c, Graha.jupiter, Graha.rahu)} के अंतर पर।',
        ),
        meaning: const _T(
          'Jupiter stands for teachers, wisdom and guidance; Rahu for the unconventional, the foreign and the restless. The tradition reads an independent, questioning relation to teachers, received rules and advice, which can also be wisdom that crosses borders.',
          'गुरु शिक्षकों, ज्ञान और मार्गदर्शन का कारक है; राहु अपरंपरागत, विदेशी और बेचैन का। परंपरा इसे शिक्षकों, चले आ रहे नियमों और सलाह के प्रति स्वतंत्र, प्रश्न करने वाले संबंध की तरह पढ़ती है, जो सीमाएँ पार करने वाला ज्ञान भी हो सकता है।',
        ),
        source: _fromPopular,
        factors: <_T>[c.factor(Graha.jupiter), c.factor(Graha.rahu)],
        cancellation: eased
            ? _T(
                'Jupiter is strong in ${_sEn(c.sign(Graha.jupiter))}, its own or exaltation sign, which practitioners read as Jupiter holding Rahu rather than the reverse.',
                'गुरु ${_sHi(c.sign(Graha.jupiter))} में बली है, जो उसकी अपनी या उच्च राशि है; जानकार इसे राहु पर गुरु की पकड़ मानते हैं, उलटा नहीं।',
              )
            : null,
        mitigation: eased
            ? null
            : const _T(
                'It asks for advice to be tested against one’s own conscience, and for finding a teacher one can truly trust rather than a loud one.',
                'यह सलाह को अपने विवेक पर परखने और शोर करने वाले के बजाय सचमुच भरोसेमंद गुरु खोजने की माँग करता है।',
              ),
      ),
    );
  }

  // --- Grahan dosha: Sun or Moon with Rahu or Ketu -------------------------
  for (final (Graha, String, String, _T) lum in <(Graha, String, String, _T)>[
    (
      Graha.sun,
      'grahan_surya',
      'Surya',
      const _T(
        'The Sun stands for the self, confidence and authority, and for the father’s line. With a node it is as in an eclipse: the light is veiled, and self-expression takes more effort.',
        'सूर्य स्वयं, आत्मविश्वास, अधिकार और पिता की परंपरा का कारक है। नोड के साथ यह ग्रहण जैसा है: प्रकाश ढका है, और आत्म-अभिव्यक्ति में अधिक प्रयास लगता है।',
      ),
    ),
    (
      Graha.moon,
      'grahan_chandra',
      'Chandra',
      const _T(
        'The Moon stands for the mind, feeling and the mother’s side. With a node it is as in an eclipse: the light is veiled, and settling the mind asks for more routine.',
        'चंद्र मन, भावना और माता के पक्ष का कारक है। नोड के साथ यह ग्रहण जैसा है: प्रकाश ढका है, और मन को टिकाने के लिए अधिक नियमितता चाहिए।',
      ),
    ),
  ]) {
    final Graha? node = <Graha>[Graha.rahu, Graha.ketu]
        .where((Graha n) => c.together(lum.$1, n))
        .cast<Graha?>()
        .firstWhere((Graha? _) => true, orElse: () => null);
    if (node == null) continue;
    final bool eased = _jupiterEases(c, lum.$1);
    out.add(
      _make(
        key: lum.$2,
        family: YogaFamily.dosha,
        dosha: true,
        name: _T(
          '${lum.$3} Grahan dosha',
          '${lum.$1 == Graha.sun ? 'सूर्य' : 'चंद्र'} ग्रहण दोष',
        ),
        rule: _T(
          '${_gEn(lum.$1)} and ${_gEn(node)} stand together in ${_sEn(c.sign(lum.$1))}, house ${c.house(lum.$1)}, ${_apart(c, lum.$1, node)} apart.',
          '${_gHi(lum.$1)} और ${_gHi(node)} ${_sHi(c.sign(lum.$1))} राशि में, ${_hiOrdinal[c.house(lum.$1)]} भाव में, साथ हैं, ${_apart(c, lum.$1, node)} के अंतर पर।',
        ),
        meaning: lum.$4,
        source: _fromPopular,
        factors: <_T>[c.factor(lum.$1), c.factor(node)],
        cancellation: eased
            ? _T(
                'Jupiter ${c.together(Graha.jupiter, lum.$1) ? 'stands with' : 'aspects'} the ${_gEn(lum.$1)}, which practitioners name as the usual softening of this dosha.',
                'गुरु ${_gHi(lum.$1)} के ${c.together(Graha.jupiter, lum.$1) ? 'साथ है' : 'दृष्टि में है'}, जिसे जानकार इस दोष का सामान्य शमन मानते हैं।',
              )
            : null,
        mitigation: eased
            ? null
            : _T(
                lum.$1 == Graha.sun
                    ? 'It asks for patience in building confidence, and for honouring one’s father and teachers; the tradition recommends steady habits over any dramatic act.'
                    : 'It asks for a regular daily routine, early rest and calm company; the tradition recommends steady habits over any dramatic act.',
                lum.$1 == Graha.sun
                    ? 'यह आत्मविश्वास बनाने में धैर्य और पिता व गुरुजनों के सम्मान की माँग करता है; परंपरा किसी नाटकीय उपाय के बजाय स्थिर आदतें सुझाती है।'
                    : 'यह नियमित दिनचर्या, समय पर विश्राम और शांत संगति की माँग करता है; परंपरा किसी नाटकीय उपाय के बजाय स्थिर आदतें सुझाती है।',
              ),
      ),
    );
  }

  // --- Shrapit dosha: Saturn with Rahu -------------------------------------
  if (c.together(Graha.saturn, Graha.rahu)) {
    final bool saturnStrong = c.inOwnOrExalted(Graha.saturn);
    final bool jupiter = _jupiterEases(c, Graha.saturn);
    _T? cancellation;
    if (saturnStrong) {
      cancellation = _T(
        'Saturn is strong in ${_sEn(c.sign(Graha.saturn))}, its own or exaltation sign, which practitioners read as Saturn’s discipline governing Rahu’s restlessness.',
        'शनि ${_sHi(c.sign(Graha.saturn))} में बली है, जो उसकी अपनी या उच्च राशि है; जानकार इसे राहु की बेचैनी पर शनि के अनुशासन का शासन मानते हैं।',
      );
    } else if (jupiter) {
      cancellation = _T(
        'Jupiter ${c.together(Graha.jupiter, Graha.saturn) ? 'stands with' : 'aspects'} Saturn, which practitioners name as a softening of this dosha.',
        'गुरु शनि के ${c.together(Graha.jupiter, Graha.saturn) ? 'साथ है' : 'दृष्टि में है'}, जिसे जानकार इस दोष का शमन मानते हैं।',
      );
    }
    out.add(
      _make(
        key: 'shrapit',
        family: YogaFamily.dosha,
        dosha: true,
        name: const _T('Shrapit dosha', 'श्रापित दोष'),
        rule: _T(
          'Saturn and Rahu stand together in ${_sEn(c.sign(Graha.saturn))}, house ${c.house(Graha.saturn)}, ${_apart(c, Graha.saturn, Graha.rahu)} apart.',
          'शनि और राहु ${_sHi(c.sign(Graha.saturn))} राशि में, ${_hiOrdinal[c.house(Graha.saturn)]} भाव में, साथ हैं, ${_apart(c, Graha.saturn, Graha.rahu)} के अंतर पर।',
        ),
        meaning: const _T(
          'Saturn’s slow discipline and Rahu’s restlessness in one sign. The name means "cursed", but the tradition’s reading is of delay and of having to try again in the matters of that house. It is read as a call to patience and steady service, never as a curse that is fixed.',
          'शनि का धीमा अनुशासन और राहु की बेचैनी एक राशि में। नाम का अर्थ "शापित" है, पर परंपरा का पाठ उस भाव के विषयों में विलंब और दोबारा प्रयास करने का है। इसे धैर्य और निरंतर सेवा के आह्वान की तरह पढ़ा जाता है, कभी अटल श्राप की तरह नहीं।',
        ),
        source: _fromPopular,
        factors: <_T>[c.factor(Graha.saturn), c.factor(Graha.rahu)],
        cancellation: cancellation,
        mitigation: cancellation != null
            ? null
            : const _T(
                'It asks for patience and for finishing what is begun: the tradition names steady service and keeping promises as the natural counterweight.',
                'यह धैर्य और शुरू किए काम को पूरा करने की माँग करता है: परंपरा निरंतर सेवा और वचन निभाने को इसका स्वाभाविक संतुलन मानती है।',
              ),
      ),
    );
  }

  // --- Pitra dosha: the significators of the father and the forebears -------
  // The Sun and the 9th house (the house of the father and of dharma) touched
  // by Rahu or Ketu: the Sun with a node, a node in the 9th, or the 9th lord
  // with a node. Stated as an obligation toward the line of forebears.
  final Graha ninthLord = c.lordOfHouse(9);
  final List<_T> pitraFactors = <_T>[];
  final List<_T> pitraWhy = <_T>[];
  for (final Graha node in <Graha>[Graha.rahu, Graha.ketu]) {
    if (c.together(Graha.sun, node)) {
      pitraWhy.add(
        _T(
          'the Sun stands with ${_gEn(node)}',
          'सूर्य ${_gHi(node)} के साथ है',
        ),
      );
      pitraFactors
        ..add(c.factor(Graha.sun))
        ..add(c.factor(node));
    }
    if (c.house(node) == 9) {
      pitraWhy.add(
        _T(
          '${_gEn(node)} stands in the 9th house',
          '${_gHi(node)} नौवें भाव में है',
        ),
      );
      pitraFactors.add(c.factor(node));
    }
    if (ninthLord != node && c.together(ninthLord, node)) {
      pitraWhy.add(
        _T(
          'the 9th lord (${_gEn(ninthLord)}) stands with ${_gEn(node)}',
          'नौवें भाव के स्वामी (${_gHi(ninthLord)}) ${_gHi(node)} के साथ हैं',
        ),
      );
      pitraFactors
        ..add(c.lordFactor(9))
        ..add(c.factor(node));
    }
  }
  if (pitraWhy.isNotEmpty) {
    final bool jupiterNinth =
        c.house(Graha.jupiter) == 9 ||
        c.aspectsSign(Graha.jupiter, c.k.signOfHouse(9));
    final bool ninthStrong = c.inOwnOrExalted(ninthLord);
    _T? cancellation;
    if (jupiterNinth) {
      cancellation = _T(
        'Jupiter ${c.house(Graha.jupiter) == 9 ? 'stands in' : 'aspects'} the 9th house. The tradition reads the house of dharma and elders as protected by Jupiter.',
        'गुरु नौवें भाव में ${c.house(Graha.jupiter) == 9 ? 'है' : 'दृष्टि डालता है'}। परंपरा धर्म और बड़ों के भाव को गुरु से सुरक्षित मानती है।',
      );
    } else if (ninthStrong) {
      cancellation = _T(
        'The 9th lord (${_gEn(ninthLord)}) is strong in ${_sEn(c.sign(ninthLord))}, its own or exaltation sign, which the tradition reads as the house of dharma holding its own.',
        'नौवें भाव के स्वामी (${_gHi(ninthLord)}) ${_sHi(c.sign(ninthLord))} में बली हैं, जो उनकी अपनी या उच्च राशि है; परंपरा इसे धर्म के भाव का अपने स्थान पर टिके रहना मानती है।',
      );
    }
    out.add(
      _make(
        key: 'pitra_dosha',
        family: YogaFamily.dosha,
        dosha: true,
        name: const _T('Pitra dosha', 'पितृ दोष'),
        rule: _T(
          'The Sun and the 9th house, the classical significators of the father and the line of dharma, are touched by a node: ${_listEn(pitraWhy.map((_T t) => t.en).toList())}.',
          'पिता और धर्म-परंपरा के शास्त्रीय कारक, सूर्य और नौवाँ भाव, नोड से स्पर्शित हैं: ${_listHi(pitraWhy.map((_T t) => t.hi).toList())}।',
        ),
        meaning: const _T(
          'The Sun and the 9th house stand for the father, the forebears and the line of duty. When Rahu or Ketu touches them the tradition reads an obligation toward that line: an invitation to honour elders and ancestors and to tend the family’s dharma. A large share of charts carry one of these touches. It is a statement about duty and gratitude, not about fault, and not about anything that will happen.',
          'सूर्य और नौवाँ भाव पिता, पूर्वजों और कर्तव्य की परंपरा के कारक हैं। जब राहु या केतु उन्हें छूते हैं तो परंपरा इसे उस परंपरा के प्रति दायित्व की तरह पढ़ती है: बड़ों और पूर्वजों का सम्मान करने और परिवार के धर्म को सँभालने का निमंत्रण। बड़ी संख्या में कुंडलियों में ऐसा कोई स्पर्श होता है। यह कर्तव्य और कृतज्ञता की बात है, दोष की नहीं, और आगे होने वाली किसी घटना की भी नहीं।',
        ),
        source: _fromPopular,
        factors: pitraFactors,
        cancellation: cancellation,
        mitigation: cancellation != null
            ? null
            : const _T(
                'The tradition’s own answer is gratitude in practice: remembering forebears on the days set aside for them with water, a lamp and a meal shared, and looking after elders while they are with us. It asks nothing frightening of anyone.',
                'परंपरा का अपना उत्तर कृतज्ञता का आचरण है: पूर्वजों के लिए तय तिथियों पर जल, दीप और भोजन के साथ उन्हें स्मरण करना, और बड़ों की उनके जीवनकाल में सेवा करना। यह किसी से भी डरने जैसा कुछ नहीं माँगता।',
              ),
      ),
    );
  }

  // --- Angarak yoga: Mars with Rahu ------------------------------------------
  if (c.together(Graha.mars, Graha.rahu)) {
    final bool marsStrong = c.inOwnOrExalted(Graha.mars);
    final bool jupiter = _jupiterEases(c, Graha.mars);
    _T? cancellation;
    if (marsStrong) {
      cancellation = _T(
        'Mars is strong in ${_sEn(c.sign(Graha.mars))}, its own or exaltation sign, which practitioners read as Mars keeping command of its own drive.',
        'मंगल ${_sHi(c.sign(Graha.mars))} में बली है, जो उसकी अपनी या उच्च राशि है; जानकार इसे मंगल का अपनी ऊर्जा पर नियंत्रण मानते हैं।',
      );
    } else if (jupiter) {
      cancellation = _T(
        'Jupiter ${c.together(Graha.jupiter, Graha.mars) ? 'stands with' : 'aspects'} Mars, which practitioners name as a softening of this yoga.',
        'गुरु मंगल के ${c.together(Graha.jupiter, Graha.mars) ? 'साथ है' : 'दृष्टि में है'}, जिसे जानकार इस योग का शमन मानते हैं।',
      );
    }
    out.add(
      _make(
        key: 'angarak',
        family: YogaFamily.dosha,
        dosha: true,
        name: const _T('Angarak yoga', 'अंगारक योग'),
        rule: _T(
          'Mars and Rahu stand together in ${_sEn(c.sign(Graha.mars))}, house ${c.house(Graha.mars)}, ${_apart(c, Graha.mars, Graha.rahu)} apart.',
          'मंगल और राहु ${_sHi(c.sign(Graha.mars))} राशि में, ${_hiOrdinal[c.house(Graha.mars)]} भाव में, साथ हैं, ${_apart(c, Graha.mars, Graha.rahu)} के अंतर पर।',
        ),
        meaning: const _T(
          'Mars’s courage and temper joined to Rahu’s restlessness: a hot, impulsive energy. The tradition reads a need to channel courage and to pause before acting. It is about temperament, not about any event.',
          'मंगल का साहस और क्रोध राहु की बेचैनी के साथ: तप्त, आवेगी ऊर्जा। परंपरा इसे साहस को दिशा देने और कार्य से पहले ठहरने की ज़रूरत की तरह पढ़ती है। यह स्वभाव की बात है, किसी घटना की नहीं।',
        ),
        source: _fromPopular,
        factors: <_T>[c.factor(Graha.mars), c.factor(Graha.rahu)],
        cancellation: cancellation,
        mitigation: cancellation != null
            ? null
            : const _T(
                'It asks for a pause before acting on a first impulse, and for a steady outlet for energy, such as sport or craft.',
                'यह पहले आवेग पर कार्य करने से पहले ठहरने और ऊर्जा के लिए स्थिर माध्यम, जैसे खेल या शिल्प, की माँग करता है।',
              ),
      ),
    );
  }

  // --- Vish yoga (also called Punarphoo): the Moon with Saturn ---------------
  // Sources differ on Punarphoo: some give it as the same Moon-Saturn
  // conjunction, others as a mutual aspect. Only the conjunction, on which
  // they agree, is read, under both names.
  if (c.together(Graha.moon, Graha.saturn)) {
    final bool moonStrong = c.inOwnOrExalted(Graha.moon);
    final bool saturnStrong = c.inOwnOrExalted(Graha.saturn);
    final bool jupiter = _jupiterEases(c, Graha.moon);
    _T? cancellation;
    if (jupiter) {
      cancellation = _T(
        'Jupiter ${c.together(Graha.jupiter, Graha.moon) ? 'stands with' : 'aspects'} the Moon, which practitioners call the strongest softening of this yoga.',
        'गुरु चंद्र के ${c.together(Graha.jupiter, Graha.moon) ? 'साथ है' : 'दृष्टि में है'}, जिसे जानकार इस योग का सबसे प्रबल शमन कहते हैं।',
      );
    } else if (moonStrong) {
      cancellation = _T(
        'The Moon is strong in ${_sEn(c.moonSign)}, its own or exaltation sign, which practitioners read as the mind holding its own against Saturn’s weight.',
        'चंद्र ${_sHi(c.moonSign)} में बली है, जो उसकी अपनी या उच्च राशि है; जानकार इसे शनि के भार के सामने मन का टिके रहना मानते हैं।',
      );
    } else if (saturnStrong) {
      cancellation = _T(
        'Saturn is strong in ${_sEn(c.moonSign)}, its own or exaltation sign, which practitioners read as Saturn’s discipline steadying the mind.',
        'शनि ${_sHi(c.moonSign)} में बली है, जो उसकी अपनी या उच्च राशि है; जानकार इसे शनि का अनुशासन मन को स्थिर करना मानते हैं।',
      );
    }
    out.add(
      _make(
        key: 'vish_yoga',
        family: YogaFamily.dosha,
        dosha: true,
        name: const _T('Vish yoga (Punarphoo)', 'विष योग (पुनर्फू)'),
        rule: _T(
          'The Moon and Saturn stand together in ${_sEn(c.moonSign)}, house ${c.house(Graha.moon)}, ${_apart(c, Graha.moon, Graha.saturn)} apart.',
          'चंद्र और शनि ${_sHi(c.moonSign)} राशि में, ${_hiOrdinal[c.house(Graha.moon)]} भाव में, साथ हैं, ${_apart(c, Graha.moon, Graha.saturn)} के अंतर पर।',
        ),
        meaning: const _T(
          'The Moon stands for the mind and feeling, Saturn for discipline and weight. The tradition reads a serious, restrained inner life and feelings that settle slowly, and, under the name Punarphoo, matters that are often settled at a second attempt. It is read as depth and seriousness, not as gloom.',
          'चंद्र मन और भावना का कारक है, शनि अनुशासन और भार का। परंपरा इसे गंभीर, संयमित भीतरी जीवन और धीरे-धीरे टिकने वाली भावनाओं की तरह पढ़ती है, और पुनर्फू नाम से उन कामों के रूप में जो अक्सर दूसरे प्रयास में तय होते हैं। इसे गहराई और गंभीरता की तरह पढ़ा जाता है, उदासी की तरह नहीं।',
        ),
        source: _fromPopular,
        factors: <_T>[c.factor(Graha.moon), c.factor(Graha.saturn)],
        cancellation: cancellation,
        mitigation: cancellation != null
            ? null
            : const _T(
                'It asks for regular routines, honest talk with someone trusted, and patience with oneself; the tradition counts Saturn’s steadiness as the gift inside the weight.',
                'यह नियमित दिनचर्या, किसी भरोसेमंद से खुलकर बात और अपने प्रति धैर्य की माँग करता है; परंपरा शनि की स्थिरता को उस भार के भीतर का उपहार मानती है।',
              ),
      ),
    );
  }

  return out;
}

/// Where Saturn's seven-and-a-half year passage stands today.
class SadeSati {
  const SadeSati({
    required this.isRunning,
    required this.phase,
    required this.detail,
    required this.detailHindi,
  });

  final bool isRunning;

  /// 1, 2 or 3 while running; 0 otherwise.
  final int phase;
  final String detail;
  final String detailHindi;
}

SadeSati sadeSatiStatus(Kundli kundli, DateTime moment) {
  final Instant now = Instant.fromUtc(moment.toUtc());
  final double saturn = norm360(
    positionOf(Graha.saturn, now).tropicalLongitude - kundli.ayanamsaValue,
  );
  final int saturnSign = (saturn / 30).floor() % 12;
  final int moonSign = kundli.moonRashi.index;
  final int distance = (saturnSign - moonSign + 12) % 12;
  if (distance == 11 || distance == 0 || distance == 1) {
    final int phase = distance == 11 ? 1 : (distance == 0 ? 2 : 3);
    return SadeSati(
      isRunning: true,
      phase: phase,
      detail:
          'Saturn is in ${rashiInfo(Rashi.values[saturnSign]).english}, which is phase $phase of Sade Sati for a ${rashiInfo(Rashi.values[moonSign]).english} Moon.',
      detailHindi:
          'शनि ${rashiInfo(Rashi.values[saturnSign]).hindi} राशि में हैं, यह साढ़ेसाती का $phaseरा चरण है।',
    );
  }
  return SadeSati(
    isRunning: false,
    phase: 0,
    detail:
        'Saturn is in ${rashiInfo(Rashi.values[saturnSign]).english}; Sade Sati is not running.',
    detailHindi:
        'शनि ${rashiInfo(Rashi.values[saturnSign]).hindi} राशि में हैं; साढ़ेसाती नहीं चल रही।',
  );
}
