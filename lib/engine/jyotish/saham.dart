import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'rashi.dart';
import 'shadbala.dart' show isBenefic;
import 'tajika_aspects.dart';
import 'tajika_bala.dart';
import 'tajika_common.dart';

/// Sahams, the sensitive points of Tajika.
///
/// A saham is a point of the zodiac fixed by a formula of the form A - B + C:
/// the arc from B to A, laid off from C. There are two variants of most
/// formulas, one for a chart cast by day and one by night, and at night A and
/// B usually trade places.
///
/// The formulas follow Balabhadra's Hayanaratna, ch. 4 (which cites the
/// Samjnatantra of Tajika Neelakanthi for the Fortune saham and gives the
/// rest in its own line), cross-checked against Dr. Shanker Adawal's
/// Encyclopedia of Vedic Astrology: Tajik Shastra and Annual Horoscopy, the
/// table in Jagannatha Hora and PyJHora. A formula goes in only if the
/// sources agree on it, or if the difference is one this file can name and
/// has chosen a side of; where they disagree on something that would change
/// the longitude, the saham is left out (see docs/ENGINE.md for the list).
///
/// Whole-chart rules, all from Hayanaratna 4.2:
///  * "Where no addition is stated, the ascendant is added."
///  * If the ascendant does not lie in the arc from B forward to A, one sign
///    (30 degrees) is added. Balabhadra argues the rule holds for every saham,
///    not only Fortune. (JHora tests the third term, C, instead of the
///    ascendant for sahams where C is not the ascendant.)
///  * A house point is the lagna degree repeated through the signs, so that
///    the sign of "the ninth house" is the whole-sign ninth.
enum SahamId {
  punya,
  vidya,
  yasha,
  mahatmya,
  asha,
  samartha,
  bhratri,
  gaurava,
  pitri,
  rajya,
  matri,
  putra,
  jeeva,
  karma,
  roga,
  kali,
  paradesha,
  artha,
  karyasiddhi,
  jadya,
  labha,
  bandhana,
  mrityu,
  shatru,
  jalapatana,
}

/// How a saham's lord and the grahas around the point leave it.
enum SahamTone { supported, mixed, strained }

class _Term {
  const _Term(this.name, this.longitude);

  final Bi name;
  final double longitude;
}

class _Formula {
  const _Formula(this.a, this.b, this.c);

  final _Term a;
  final _Term b;
  final _Term c;

  Bi get text => Bi(
    '${a.name.en} − ${b.name.en} + ${c.name.en}',
    '${a.name.hi} − ${b.name.hi} + ${c.name.hi}',
  );
}

class _Ctx {
  _Ctx(this.chart, this.done);

  final Kundli chart;
  final Map<SahamId, double> done;

  double get lagnaLon => chart.ascendant;

  _Term g(Graha graha) =>
      _Term(grahaBi(graha), chart.grahas[graha]!.siderealLongitude);

  _Term get lagna => _Term(const Bi('Lagna', 'लग्न'), chart.ascendant);

  _Term saham(SahamId id, Bi name) => _Term(name, done[id] ?? 0);

  Graha get lagnaLord => houseLord(chart, 1);

  _Term get lagnaLordTerm => _Term(
    const Bi('lagna lord', 'लग्नेश'),
    chart.grahas[lagnaLord]!.siderealLongitude,
  );

  _Term house(int h) => _Term(
    Bi('${_enOrdinal(h)} house', '${_hiOrdinal(h)} भाव'),
    housePoint(chart, h),
  );

  _Term houseLordTerm(int h) => _Term(
    Bi('${_enOrdinal(h)} lord', '${_hiOrdinal(h)}ेश'),
    chart.grahas[houseLord(chart, h)]!.siderealLongitude,
  );
}

String _enOrdinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

String _hiOrdinal(int n) => const <String>[
  'प्रथम',
  'द्वितीय',
  'तृतीय',
  'चतुर्थ',
  'पंचम',
  'षष्ठ',
  'सप्तम',
  'अष्टम',
  'नवम',
  'दशम',
  'एकादश',
  'द्वादश',
][n - 1];

typedef _Build = _Formula Function(_Ctx c, bool day);

class _Spec {
  const _Spec({
    required this.id,
    required this.name,
    required this.build,
    this.governs,
    this.note,
  });

  final SahamId id;
  final Bi name;
  final _Build build;

  /// What the tradition says the point governs. Null where the app makes no
  /// reading of it.
  final Bi? governs;

  /// A note on a textual variant, shown beside the formula.
  final Bi? note;
}

_Formula _swap(bool day, _Term a, _Term b, _Term c) =>
    day ? _Formula(a, b, c) : _Formula(b, a, c);

const Bi _punyaName = Bi('Punya saham', 'पुण्य सहम');

/// The saham formulas. The comment above each gives the day formula and the
/// night one.
final List<_Spec> _specs = <_Spec>[
  // Punya (fortune). Day: Moon - Sun + Lagna. Night: Sun - Moon + Lagna.
  // Neelakanthi, Samjnatantra 3.5, as quoted by Hayanaratna 4.2.
  _Spec(
    id: SahamId.punya,
    name: const Bi('Punya', 'पुण्य'),
    governs: const Bi(
      'fortune, merit and the general support behind the year',
      'भाग्य, पुण्य और वर्ष का सामान्य सहारा',
    ),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.moon), c.g(Graha.sun), c.lagna),
  ),
  // Vidya (learning). Day: Sun - Moon + Lagna. Night: Moon - Sun + Lagna.
  // The reverse of Punya (Hayanaratna 4.3, "Teacher and Learning").
  _Spec(
    id: SahamId.vidya,
    name: const Bi('Vidya', 'विद्या'),
    governs: const Bi('learning and skill', 'विद्या और कौशल'),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.sun), c.g(Graha.moon), c.lagna),
  ),
  // Yasha (renown). Day: Jupiter - Punya + Lagna. Night: Punya - Jupiter +
  // Lagna.
  _Spec(
    id: SahamId.yasha,
    name: const Bi('Yasha', 'यश'),
    governs: const Bi('renown and public regard', 'यश और लोक में सम्मान'),
    build: (_Ctx c, bool day) => _swap(
      day,
      c.g(Graha.jupiter),
      c.saham(SahamId.punya, _punyaName),
      c.lagna,
    ),
  ),
  // Mahatmya (greatness). Day: Punya - Mars + Lagna. Night: Mars - Punya +
  // Lagna.
  _Spec(
    id: SahamId.mahatmya,
    name: const Bi('Mahatmya', 'महात्म्य'),
    governs: const Bi(
      'standing and greatness of character',
      'प्रतिष्ठा और व्यक्तित्व की महानता',
    ),
    build: (_Ctx c, bool day) => _swap(
      day,
      c.saham(SahamId.punya, _punyaName),
      c.g(Graha.mars),
      c.lagna,
    ),
  ),
  // Asha (hope). Day: Saturn - Venus + Lagna. Night: Venus - Saturn + Lagna.
  // Hayanaratna 4.3 and Adawal agree; JHora and PyJHora subtract Mars instead
  // of Venus.
  _Spec(
    id: SahamId.asha,
    name: const Bi('Asha', 'आशा'),
    governs: const Bi('hopes and wishes', 'आशाएँ और इच्छाएँ'),
    note: const Bi(
      'Hayanaratna and Adawal subtract Venus; JHora and PyJHora subtract '
          'Mars. This app follows the first two.',
      'हायनरत्न और अडावल शुक्र घटाते हैं; JHora और PyJHora मंगल। यह ऐप पहले '
          'दोनों का अनुसरण करता है।',
    ),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.saturn), c.g(Graha.venus), c.lagna),
  ),
  // Samartha (ability). Day: Mars - Lagna lord + Lagna. Night: Lagna lord -
  // Mars + Lagna. If Mars is the lagna lord, Jupiter stands in for Mars.
  _Spec(
    id: SahamId.samartha,
    name: const Bi('Samartha', 'सामर्थ्य'),
    governs: const Bi(
      'capacity to carry undertakings through',
      'कार्य को निभाने की सामर्थ्य',
    ),
    note: const Bi(
      'When Mars itself is the lagna lord, Jupiter takes its place (all '
          'sources agree on the substitution; they differ on whether the '
          'night reversal then holds, and this app keeps it).',
      'जब मंगल स्वयं लग्नेश हो तो उसकी जगह गुरु लिया जाता है (प्रतिस्थापन पर '
          'सब एकमत हैं; तब रात्रि का उलटाव लागू होता है या नहीं, इस पर मतभेद है, '
          'यह ऐप उसे रखता है)।',
    ),
    build: (_Ctx c, bool day) => _swap(
      day,
      c.g(c.lagnaLord == Graha.mars ? Graha.jupiter : Graha.mars),
      c.lagnaLordTerm,
      c.lagna,
    ),
  ),
  // Bhratri (brothers). Jupiter - Saturn + Lagna, day and night alike.
  _Spec(
    id: SahamId.bhratri,
    name: const Bi('Bhratri', 'भ्रातृ'),
    governs: const Bi(
      'brothers and sisters, and what is shared with them',
      'भाई-बहन और उनसे जुड़ी बातें',
    ),
    build: (_Ctx c, bool day) =>
        _Formula(c.g(Graha.jupiter), c.g(Graha.saturn), c.lagna),
  ),
  // Gaurava (honour). Day: Jupiter - Moon + Sun. Night: Jupiter - Sun + Moon.
  // (The same sum as Sun - Moon + Jupiter by day, as Adawal and JHora write it.)
  _Spec(
    id: SahamId.gaurava,
    name: const Bi('Gaurava', 'गौरव'),
    governs: const Bi('honour and dignity', 'मान और गरिमा'),
    build: (_Ctx c, bool day) => day
        ? _Formula(c.g(Graha.jupiter), c.g(Graha.moon), c.g(Graha.sun))
        : _Formula(c.g(Graha.jupiter), c.g(Graha.sun), c.g(Graha.moon)),
  ),
  // Pitri (father). Day: Saturn - Sun + Lagna. Night: Sun - Saturn + Lagna.
  _Spec(
    id: SahamId.pitri,
    name: const Bi('Pitri', 'पितृ'),
    governs: const Bi('the father and paternal matters', 'पिता और पैतृक बातें'),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.saturn), c.g(Graha.sun), c.lagna),
  ),
  // Rajya (dominion). The same formula as Pitri (Hayanaratna 4.3).
  _Spec(
    id: SahamId.rajya,
    name: const Bi('Rajya', 'राज्य'),
    governs: const Bi(
      'authority and dealings with those in power',
      'अधिकार और सत्ताधारियों से व्यवहार',
    ),
    note: const Bi(
      'The same formula as the Pitri saham, so the two fall on one point.',
      'पितृ सहम का ही सूत्र है, इसलिए दोनों एक ही बिंदु पर पड़ते हैं।',
    ),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.saturn), c.g(Graha.sun), c.lagna),
  ),
  // Matri (mother). Day: Moon - Venus + Lagna. Night: Venus - Moon + Lagna.
  _Spec(
    id: SahamId.matri,
    name: const Bi('Matri', 'मातृ'),
    governs: const Bi(
      'the mother and maternal matters',
      'माता और मातृपक्ष की बातें',
    ),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.moon), c.g(Graha.venus), c.lagna),
  ),
  // Putra (children). Jupiter - Moon + Lagna, day and night alike.
  _Spec(
    id: SahamId.putra,
    name: const Bi('Putra', 'पुत्र'),
    governs: const Bi(
      'children and what one nurtures',
      'संतान और जिसे हम पालते-पोसते हैं',
    ),
    build: (_Ctx c, bool day) =>
        _Formula(c.g(Graha.jupiter), c.g(Graha.moon), c.lagna),
  ),
  // Jeeva (life). Day: Saturn - Jupiter + Lagna. Night: Jupiter - Saturn +
  // Lagna. Computed; not interpreted (see [Saham.isInterpreted]).
  _Spec(
    id: SahamId.jeeva,
    name: const Bi('Jeeva', 'जीव'),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.saturn), c.g(Graha.jupiter), c.lagna),
  ),
  // Karma (work). Day: Mars - Mercury + Lagna. Night: Mercury - Mars + Lagna.
  _Spec(
    id: SahamId.karma,
    name: const Bi('Karma', 'कर्म'),
    governs: const Bi('work and action', 'कर्म और व्यवसाय'),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.mars), c.g(Graha.mercury), c.lagna),
  ),
  // Roga. Lagna - Moon + Lagna, day and night alike (Hayanaratna 4.3;
  // JHora; PyJHora). Computed because the system computes it; the app makes
  // no reading of it.
  _Spec(
    id: SahamId.roga,
    name: const Bi('Roga', 'रोग'),
    note: const Bi(
      'Adawal writes this formula with one sign added at the end; the other '
          'sources do not. The point is shown, not read.',
      'अडावल इस सूत्र के अंत में एक राशि जोड़ते हैं; अन्य स्रोत नहीं। बिंदु '
          'दिखाया जाता है, पढ़ा नहीं जाता।',
    ),
    build: (_Ctx c, bool day) => _Formula(c.lagna, c.g(Graha.moon), c.lagna),
  ),
  // Kali (strife). Day: Jupiter - Mars + Lagna. Night: Mars - Jupiter +
  // Lagna.
  _Spec(
    id: SahamId.kali,
    name: const Bi('Kali', 'कलि'),
    governs: const Bi(
      'friction and quarrels, which ask for patience',
      'कलह और विवाद, जिनमें धैर्य चाहिए',
    ),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.jupiter), c.g(Graha.mars), c.lagna),
  ),
  // Paradesha (foreign lands). 9th house - 9th lord + Lagna, day and night
  // alike.
  _Spec(
    id: SahamId.paradesha,
    name: const Bi('Paradesha', 'परदेश'),
    governs: const Bi(
      'foreign lands and distant places',
      'विदेश और दूर के स्थान',
    ),
    build: (_Ctx c, bool day) =>
        _Formula(c.house(9), c.houseLordTerm(9), c.lagna),
  ),
  // Artha (money). 2nd house - 2nd lord + Lagna, day and night alike.
  _Spec(
    id: SahamId.artha,
    name: const Bi('Artha', 'अर्थ'),
    governs: const Bi('money matters and resources', 'धन और संसाधन'),
    build: (_Ctx c, bool day) =>
        _Formula(c.house(2), c.houseLordTerm(2), c.lagna),
  ),
  // Karyasiddhi (success in undertakings). Day: Saturn - Sun + lord of the
  // Sun's sign. Night: Saturn - Moon + lord of the Moon's sign.
  _Spec(
    id: SahamId.karyasiddhi,
    name: const Bi('Karyasiddhi', 'कार्यसिद्धि'),
    governs: const Bi(
      'how smoothly undertakings carry through',
      'कार्यों का सहज निभना',
    ),
    build: (_Ctx c, bool day) {
      final Graha luminary = day ? Graha.sun : Graha.moon;
      final Graha lord = rashiInfo(c.chart.grahas[luminary]!.rashi).lord;
      return _Formula(
        c.g(Graha.saturn),
        c.g(luminary),
        _Term(
          day
              ? const Bi('lord of the Sun’s sign', 'सूर्य राशि का स्वामी')
              : const Bi('lord of the Moon’s sign', 'चंद्र राशि का स्वामी'),
          c.chart.grahas[lord]!.siderealLongitude,
        ),
      );
    },
  ),
  // Jadya (dullness). Day: Mars - Saturn + Mercury. Night: Saturn - Mars +
  // Mercury.
  _Spec(
    id: SahamId.jadya,
    name: const Bi('Jadya', 'जाड्य'),
    governs: const Bi(
      'inertia and dullness, which ask for a deliberate push',
      'जड़ता और सुस्ती, जिसमें सोचा-समझा प्रयास चाहिए',
    ),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.mars), c.g(Graha.saturn), c.g(Graha.mercury)),
  ),
  // Labha (gains). 11th house - 11th lord + Lagna, day and night alike.
  _Spec(
    id: SahamId.labha,
    name: const Bi('Labha', 'लाभ'),
    governs: const Bi(
      'gains and what comes to you through your undertakings',
      'लाभ और कार्यों से जो आता है',
    ),
    build: (_Ctx c, bool day) =>
        _Formula(c.house(11), c.houseLordTerm(11), c.lagna),
  ),
  // Bandhana (restraint). Day: Punya - Saturn + Lagna. Night: Saturn - Punya +
  // Lagna.
  _Spec(
    id: SahamId.bandhana,
    name: const Bi('Bandhana', 'बंधन'),
    governs: const Bi(
      'constraint, commitment and what binds',
      'बंधन, प्रतिबद्धता और जो बाँधता है',
    ),
    build: (_Ctx c, bool day) => _swap(
      day,
      c.saham(SahamId.punya, _punyaName),
      c.g(Graha.saturn),
      c.lagna,
    ),
  ),
  // Mrityu. 8th house - Moon + Saturn, day and night alike (Hayanaratna 4.3;
  // Adawal). Computed because the system computes it; the app makes no
  // reading of it.
  _Spec(
    id: SahamId.mrityu,
    name: const Bi('Mrityu', 'मृत्यु'),
    note: const Bi(
      'JHora and PyJHora add the lagna instead of Saturn; Hayanaratna and '
          'Adawal add Saturn, which this app follows. The point is shown, not '
          'read.',
      'JHora और PyJHora शनि की जगह लग्न जोड़ते हैं; हायनरत्न और अडावल शनि '
          'जोड़ते हैं, जिसका यह ऐप अनुसरण करता है। बिंदु दिखाया जाता है, पढ़ा नहीं '
          'जाता।',
    ),
    build: (_Ctx c, bool day) =>
        _Formula(c.house(8), c.g(Graha.moon), c.g(Graha.saturn)),
  ),
  // Shatru (enemy). Day: Mars - Saturn + Lagna. Night: Saturn - Mars + Lagna.
  _Spec(
    id: SahamId.shatru,
    name: const Bi('Shatru', 'शत्रु'),
    governs: const Bi('rivals and opposition', 'प्रतिद्वंद्वी और विरोध'),
    build: (_Ctx c, bool day) =>
        _swap(day, c.g(Graha.mars), c.g(Graha.saturn), c.lagna),
  ),
  // Jalapatana. Day: Cancer 15 degrees - Saturn + Lagna. Night: Saturn -
  // Cancer 15 degrees + Lagna. Hayanaratna 4.3 gives this formula as
  // "travel by water" (jaladhvan); JHora calls it Jalapatana, which is the
  // name the app keeps, and the reading stays with journeys over water.
  _Spec(
    id: SahamId.jalapatana,
    name: const Bi('Jalapatana', 'जलपतन'),
    governs: const Bi('journeys over water', 'जल मार्ग की यात्राएँ'),
    note: const Bi(
      'Hayanaratna gives this formula as "travel by water"; JHora names it '
          'Jalapatana. The app reads it only for journeys over water.',
      'हायनरत्न यह सूत्र "जल मार्ग की यात्रा" के रूप में देता है; JHora इसे '
          'जलपतन कहता है। ऐप इसे केवल जल मार्ग की यात्राओं के लिए पढ़ता है।',
    ),
    build: (_Ctx c, bool day) => _swap(
      day,
      _Term(const Bi('Cancer 15°', 'कर्क 15°'), 105.0),
      c.g(Graha.saturn),
      c.lagna,
    ),
  ),
];

/// The sahams the app computes but never interprets, whatever the chart.
const Set<SahamId> uninterpretedSahams = <SahamId>{
  SahamId.roga,
  SahamId.mrityu,
  SahamId.jeeva,
};

double _sahamLongitude(_Formula f, double lagnaLon) {
  final double arc = norm360(f.a.longitude - f.b.longitude);
  final double toLagna = norm360(lagnaLon - f.b.longitude);
  double value = f.a.longitude - f.b.longitude + f.c.longitude;
  // One sign is added when the ascendant is not in the arc from B to A.
  if (toLagna > arc) value += 30.0;
  return norm360(value);
}

/// One saham as it stands in the year chart.
class Saham {
  const Saham({
    required this.id,
    required this.name,
    required this.longitude,
    required this.sign,
    required this.degreeInSign,
    required this.house,
    required this.lord,
    required this.lordPlaced,
    required this.lordVishwa,
    required this.isDay,
    required this.formulaDay,
    required this.formulaNight,
    required this.formulaUsed,
    required this.reversesAtNight,
    required this.governs,
    required this.tone,
    required this.reading,
    required this.clauses,
    required this.factors,
    required this.note,
    required this.sunFromJd,
    required this.sunToJd,
  });

  final SahamId id;

  /// "Punya saham" / "पुण्य सहम".
  final Bi name;

  /// Sidereal longitude, [0, 360).
  final double longitude;
  final int sign;
  final double degreeInSign;
  final int house;
  final Graha lord;
  final PlacedGraha lordPlaced;
  final double lordVishwa;
  final bool isDay;
  final Bi formulaDay;
  final Bi formulaNight;
  final Bi formulaUsed;
  final bool reversesAtNight;

  /// What the tradition says the point governs; null where the app makes no
  /// reading.
  final Bi? governs;
  final SahamTone? tone;

  /// The reading, built from the strength and placement of the lord. Null for
  /// the sahams the app computes but does not interpret.
  final Bi? reading;
  final List<Bi> clauses;
  final List<Bi> factors;
  final Bi? note;

  /// When the Sun is in this saham's sign during the year, as UT Julian days:
  /// from the pravesh or its ingress, to its exit or the year's end.
  final double? sunFromJd;
  final double? sunToJd;

  bool get isInterpreted => reading != null;
  Rashi get rashi => Rashi.values[sign];
  DateTime? get sunFromUtc =>
      sunFromJd == null ? null : utcFromJulianDay(sunFromJd!);
  DateTime? get sunToUtc => sunToJd == null ? null : utcFromJulianDay(sunToJd!);
}

Bi _dignityPhrase(Dignity dignity) => switch (dignity) {
  Dignity.exalted => const Bi('exalted', 'उच्च का'),
  Dignity.moolatrikona => const Bi('in its moolatrikona', 'मूलत्रिकोण में'),
  Dignity.own => const Bi('in its own sign', 'स्वराशि में'),
  Dignity.friend => const Bi('in a friend’s sign', 'मित्र राशि में'),
  Dignity.neutral => const Bi('in a neutral sign', 'सम राशि में'),
  Dignity.enemy => const Bi('in an enemy’s sign', 'शत्रु राशि में'),
  Dignity.debilitated => const Bi('debilitated', 'नीच का'),
};

double _dignityScore(Dignity dignity) => switch (dignity) {
  Dignity.exalted || Dignity.moolatrikona || Dignity.own => 1.0,
  Dignity.friend => 0.5,
  Dignity.neutral => 0.0,
  Dignity.enemy => -0.5,
  Dignity.debilitated => -1.0,
};

double _bandScore(PvBand band) => switch (band) {
  PvBand.excellent => 1.0,
  PvBand.middling => 0.5,
  PvBand.weak => -0.5,
  PvBand.powerless => -1.0,
};

/// Finds when the Sun is in [sign] across the year of [grid].
(double?, double?) _sunPassage(YearGrid grid, int sign) {
  bool inSign(double jd) =>
      (grid.lonAt(Graha.sun, jd) / 30.0).floor() % 12 == sign;
  double? from;
  double previous = grid.startJd;
  if (inSign(grid.startJd)) {
    from = grid.startJd;
  } else {
    for (double jd = grid.startJd + 1; jd <= grid.endJd + 1; jd += 1) {
      final double at = jd > grid.endJd ? grid.endJd : jd;
      if (inSign(at)) {
        double lo = previous;
        double hi = at;
        for (int i = 0; i < 40; i++) {
          final double mid = (lo + hi) / 2;
          if (inSign(mid)) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        from = hi;
        break;
      }
      previous = at;
      if (at >= grid.endJd) break;
    }
  }
  if (from == null) return (null, null);
  double? to;
  previous = from;
  for (double jd = from + 1; jd <= grid.endJd + 1; jd += 1) {
    final double at = jd > grid.endJd ? grid.endJd : jd;
    if (!inSign(at)) {
      double lo = previous;
      double hi = at;
      for (int i = 0; i < 40; i++) {
        final double mid = (lo + hi) / 2;
        if (inSign(mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      to = lo;
      break;
    }
    previous = at;
    if (at >= grid.endJd) break;
  }
  return (from, to ?? grid.endJd);
}

/// Computes the sahams of the year chart [chart].
///
/// [isDay] says whether the chart was cast by day, the Sun above the horizon;
/// the caller decides it because it needs the place and the sunrise, which the
/// chart alone does not carry. [grid], when given, adds the Sun's passage
/// through each saham's sign.
List<Saham> computeSahams(
  Kundli chart,
  Map<Graha, PanchaVargiyaBala> bala, {
  required bool isDay,
  YearGrid? grid,
}) {
  final Map<SahamId, double> done = <SahamId, double>{};
  final _Ctx ctx = _Ctx(chart, done);
  final List<Saham> out = <Saham>[];

  for (final _Spec spec in _specs) {
    final _Formula used = spec.build(ctx, isDay);
    final _Formula day = spec.build(ctx, true);
    final _Formula night = spec.build(ctx, false);
    final double longitude = _sahamLongitude(used, ctx.lagnaLon);
    done[spec.id] = longitude;

    final int sign = (longitude / 30.0).floor() % 12;
    final int house = ((sign - chart.lagnaRashi.index + 12) % 12) + 1;
    final Graha lord = rashiInfo(Rashi.values[sign]).lord;
    final PlacedGraha lordPlaced = chart.grahas[lord]!;
    final PanchaVargiyaBala lordBala = bala[lord]!;
    final bool interpreted =
        !uninterpretedSahams.contains(spec.id) && spec.governs != null;

    final List<Bi> clauses = <Bi>[];
    double score = 0;

    // The lord's dignity.
    score += _dignityScore(lordPlaced.dignity);
    clauses.add(
      Bi(
        'The lord ${grahaBi(lord).en} stands '
            '${_dignityPhrase(lordPlaced.dignity).en}.',
        'स्वामी ${grahaBi(lord).hi} ${_dignityPhrase(lordPlaced.dignity).hi} है।',
      ),
    );
    // Its house: 6, 8 and 12 weaken (Hayanaratna 4.6).
    if (const <int>[6, 8, 12].contains(lordPlaced.house)) {
      score -= 1.0;
      clauses.add(
        Bi(
          'It is in ${houseBi(lordPlaced.house).en}, one of the houses that '
              'weaken a lord.',
          'वह ${houseBi(lordPlaced.house).hi} में है, जो स्वामी को दुर्बल '
              'करने वाले भावों में है।',
        ),
      );
    }
    // Its five-fold strength.
    score += _bandScore(lordBala.band);
    clauses.add(
      Bi(
        'Its five-fold strength is ${compactNumber(lordBala.vishwa)} vishwa '
            'of 20, ${pvBandBi(lordBala.band).en}.',
        'इसका पंचवर्गीय बल 20 में से ${compactNumber(lordBala.vishwa)} विश्वा '
            'है, ${pvBandBi(lordBala.band).hi}।',
      ),
    );
    if (lordPlaced.isRetrograde) {
      score -= 0.5;
      clauses.add(const Bi('It is retrograde.', 'वह वक्री है।'));
    }
    if (lordPlaced.isCombust) {
      score -= 0.5;
      clauses.add(const Bi('It is combust.', 'वह अस्त है।'));
    }
    // The point's own house.
    if (const <int>[6, 8, 12].contains(house)) {
      score -= 0.5;
      clauses.add(
        Bi(
          'The point itself falls in ${houseBi(house).en}.',
          'बिंदु स्वयं ${houseBi(house).hi} में पड़ता है।',
        ),
      );
    }
    // Who looks at the point: benefics help, malefics press.
    int helping = 0;
    int pressing = 0;
    for (final Graha g in tajikaGrahas) {
      if (g == lord) continue;
      final int distance = signDistance(chart.grahas[g]!.rashi.index, sign);
      if (signAspectOf(distance) == null) continue;
      if (isBenefic(chart, g)) {
        helping++;
      } else {
        pressing++;
      }
    }
    final double influence = ((helping - pressing) * 0.25).clamp(-0.75, 0.75);
    score += influence;
    clauses.add(
      Bi(
        '$helping benefic and $pressing malefic grahas are in Tajika aspect '
            'with the point’s sign.',
        '$helping शुभ और $pressing क्रूर ग्रह बिंदु की राशि से ताजिक दृष्टि '
            'में हैं।',
      ),
    );

    final SahamTone? tone = interpreted
        ? (score >= 1.0
              ? SahamTone.supported
              : (score <= -1.0 ? SahamTone.strained : SahamTone.mixed))
        : null;

    Bi? reading;
    if (interpreted && tone != null) {
      final Bi toneLine = switch (tone) {
        SahamTone.supported => Bi(
          'With its lord well placed, the tradition reads this point as '
              'supporting ${spec.governs!.en} through the year.',
          'स्वामी के अच्छी स्थिति में होने से परंपरा इस बिंदु को '
              '${spec.governs!.hi} के लिए वर्ष भर सहारा देने वाला पढ़ती है।',
        ),
        SahamTone.mixed => Bi(
          'The signs are mixed, so the tradition reads ${spec.governs!.en} '
              'as needing steady effort.',
          'संकेत मिले-जुले हैं, इसलिए ${spec.governs!.hi} के लिए परंपरा '
              'निरंतर प्रयास की ज़रूरत पढ़ती है।',
        ),
        SahamTone.strained => Bi(
          'With its lord under strain, the tradition reads '
              '${spec.governs!.en} as asking for patience and care.',
          'स्वामी के दबाव में होने से ${spec.governs!.hi} के लिए परंपरा धैर्य '
              'और सावधानी की ज़रूरत पढ़ती है।',
        ),
      };
      reading = joinBi(<Bi>[
        Bi(
          '${spec.name.en} saham falls at ${degText(longitude % 30.0)} '
              '${rashiBi(sign).en}, ${houseBi(house).en}. Its lord '
              '${grahaBi(lord).en} stands in ${rashiBi(lordPlaced.rashi.index).en}, '
              '${houseBi(lordPlaced.house).en}, '
              '${_dignityPhrase(lordPlaced.dignity).en}.',
          '${spec.name.hi} सहम ${rashiBi(sign).hi} ${degText(longitude % 30.0)} '
              'पर, ${houseBi(house).hi} में पड़ता है। इसका स्वामी '
              '${grahaBi(lord).hi} ${rashiBi(lordPlaced.rashi.index).hi} में, '
              '${houseBi(lordPlaced.house).hi} में, '
              '${_dignityPhrase(lordPlaced.dignity).hi} है।',
        ),
        toneLine,
        const Bi(
          'This is a reading of emphasis, not a forecast of any event.',
          'यह ज़ोर का पठन है, किसी घटना की भविष्यवाणी नहीं।',
        ),
      ]);
    }

    final (double?, double?) passage = grid == null
        ? (null, null)
        : _sunPassage(grid, sign);

    final Bi saName = Bi('${spec.name.en} saham', '${spec.name.hi} सहम');
    final List<Bi> factors = <Bi>[
      Bi(
        'Formula: ${(isDay ? day : night).text.en} (${isDay ? 'day' : 'night'} '
            'chart)',
        'सूत्र: ${(isDay ? day : night).text.hi} '
            '(${isDay ? 'दिन' : 'रात्रि'} कुंडली)',
      ),
      Bi(
        'Falls at ${degText(longitude % 30.0)} ${rashiBi(sign).en}, '
            '${houseBi(house).en}; the lord is ${grahaBi(lord).en}',
        '${rashiBi(sign).hi} ${degText(longitude % 30.0)} पर, '
            '${houseBi(house).hi} में; स्वामी ${grahaBi(lord).hi}',
      ),
      Bi(
        'The lord stands in ${rashiBi(lordPlaced.rashi.index).en}, '
            '${houseBi(lordPlaced.house).en}',
        'स्वामी ${rashiBi(lordPlaced.rashi.index).hi} में, '
            '${houseBi(lordPlaced.house).hi} में है',
      ),
      if (interpreted) ...clauses,
    ];

    out.add(
      Saham(
        id: spec.id,
        name: saName,
        longitude: longitude,
        sign: sign,
        degreeInSign: longitude % 30.0,
        house: house,
        lord: lord,
        lordPlaced: lordPlaced,
        lordVishwa: lordBala.vishwa,
        isDay: isDay,
        formulaDay: day.text,
        formulaNight: night.text,
        formulaUsed: (isDay ? day : night).text,
        reversesAtNight: day.text.en != night.text.en,
        governs: interpreted ? spec.governs : null,
        tone: tone,
        reading: reading,
        clauses: interpreted ? clauses : const <Bi>[],
        factors: factors,
        note: spec.note,
        sunFromJd: passage.$1,
        sunToJd: passage.$2,
      ),
    );
  }
  return out;
}
