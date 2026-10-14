import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'mat.dart';
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
/// The formulas follow Balabhadra's Hayanaratna, ch. 4 (which quotes the
/// Samjnatantra of Tajika Neelakanthi for the Fortune saham and gives the
/// rest in its own line), read in Martin Gansten's English translation, and
/// are checked against the code of PyJHora (a port of Jagannatha Hora). Where
/// the two disagree the app does not hide the saham: it computes the point
/// under each position and returns them as a [Matbhed] (see
/// [computeSahamMatbhed] and [extraSignMatbhed]), with the Hayanaratna form
/// the default.
///
/// Whole-chart rules (Hayanaratna 4.2 and 4.3):
///  * "Where no addition is stated, the ascendant is added."
///  * If the ascendant does not lie in the arc from B forward to A, one sign
///    (30 degrees) is added. This is the app's rule, and PyJHora's current
///    code tests the ascendant for most sahams too. Hayanaratna 4.3 itself
///    tests the term that is added where that is not the ascendant, and some
///    authors it reports use no extra sign at all; [extraSignMatbhed] shows all
///    three.
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
  // Hayanaratna 4.3 subtracts Venus; PyJHora (and JHora's recorded values)
  // subtract Mars instead. See [computeSahamMatbhed].
  _Spec(
    id: SahamId.asha,
    name: const Bi('Asha', 'आशा'),
    governs: const Bi('hopes and wishes', 'आशाएँ और इच्छाएँ'),
    note: const Bi(
      'Hayanaratna subtracts Venus; PyJHora subtracts Mars. Both are worked '
          'out under “Two views” below, and this app computes the first.',
      'हायनरत्न शुक्र घटाता है; PyJHora मंगल। दोनों नीचे “दो मत” में गिने गए हैं, '
          'और यह ऐप पहले से गिनता है।',
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
  // (The same sum as Sun - Moon + Jupiter by day, as PyJHora writes it; the
  // two differ only in the term the extra-sign test looks at.)
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
  // PyJHora). Computed because the system computes it; the app makes no
  // reading of it.
  _Spec(
    id: SahamId.roga,
    name: const Bi('Roga', 'रोग'),
    note: const Bi(
      'Hayanaratna and PyJHora give this formula alike. The point is shown, '
          'not read.',
      'हायनरत्न और PyJHora यह सूत्र एक-सा देते हैं। बिंदु दिखाया जाता है, पढ़ा '
          'नहीं जाता।',
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
  // Mrityu. 8th house - Moon + Saturn, day and night alike (Hayanaratna 4.3).
  // PyJHora adds the Lagna instead; see [computeSahamMatbhed]. Computed
  // because the system computes it; the app makes no reading of it.
  _Spec(
    id: SahamId.mrityu,
    name: const Bi('Mrityu', 'मृत्यु'),
    note: const Bi(
      'PyJHora adds the lagna instead of Saturn; Hayanaratna adds Saturn, '
          'which this app follows. Both are worked out under “Two views” '
          'below. The point is shown, not read.',
      'PyJHora शनि की जगह लग्न जोड़ता है; हायनरत्न शनि जोड़ता है, जिसका यह ऐप '
          'अनुसरण करता है। दोनों नीचे “दो मत” में गिने गए हैं। बिंदु दिखाया जाता है, '
          'पढ़ा नहीं जाता।',
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

/// When a saham takes its extra sign. The books do not agree on it; see
/// [extraSignMatbhed].
enum ExtraSignRule {
  /// One sign is added when the ascendant does not lie in the arc from B
  /// forward to A. This is the app's rule.
  lagna,

  /// One sign is added when the term that is added (C) does not lie in that
  /// arc. Where C is the ascendant the two rules are the same.
  addedTerm,

  /// No sign is ever added: the plain arc A - B laid off from C.
  never,
}

double _sahamLongitude(
  _Formula f,
  double lagnaLon, [
  ExtraSignRule rule = ExtraSignRule.lagna,
]) {
  final double arc = norm360(f.a.longitude - f.b.longitude);
  double value = f.a.longitude - f.b.longitude + f.c.longitude;
  switch (rule) {
    case ExtraSignRule.lagna:
      // One sign is added when the ascendant is not in the arc from B to A.
      if (norm360(lagnaLon - f.b.longitude) > arc) value += 30.0;
    case ExtraSignRule.addedTerm:
      if (norm360(f.c.longitude - f.b.longitude) > arc) value += 30.0;
    case ExtraSignRule.never:
      break;
  }
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

// =============================================================================
// Where the books differ: मतभेद on the sahams.
//
// The sahams above are the ones the sources agree on, or differ on in a way
// that this file named and chose a side of. The rest are not dropped. Each
// disputed saham is worked out under every position, with the longitude each
// one gives, and handed back as a [Matbhed] so the screen can show them side
// by side, one marked as the position the app computes by default. None of
// them is interpreted: the tone clauses above are built only for the sahams
// the sources agree on, and Mrityu stays computed and unread.
//
// Every position is worked with the app's usual rule for the extra sign; the
// rule itself is a dispute of its own, shown by [extraSignMatbhed].
//
// What was read, and what was not. Hayanaratna was read in Martin Gansten's
// English translation (the Sanskrit pages could not be opened), PyJHora's
// saham code (version 4.9.3) was read as source, and the JHora values kept in
// PyJHora's test file were checked against the competing formulas for one day
// chart. Dr Shanker Adawal's book could not be reached, so nothing is credited
// to it.
// =============================================================================

const Bi _hayanaratna = Bi(
  'Balabhadra’s Hayanaratna, chapter 4 (the Samjnatantra lines it quotes), '
      'read in Gansten’s English translation; the Sanskrit itself was not seen',
  'बलभद्र का हायनरत्न, अध्याय 4 (उसमें उद्धृत संज्ञातंत्र की पंक्तियाँ), '
      'गैन्स्टन के अंग्रेज़ी अनुवाद में पढ़ा; मूल संस्कृत नहीं देखी गई',
);

const Bi _pyjhora = Bi(
  'PyJHora, the open-source port of Jagannatha Hora (its saham code, version '
      '4.9.3, was read; the JHora values kept in its test file for one day '
      'chart agree with the day form)',
  'PyJHora, जगन्नाथ होरा का ओपन-सोर्स रूप (इसका सहम कोड, संस्करण 4.9.3, पढ़ा '
      'गया; इसकी जाँच-फ़ाइल में एक दिन-कुंडली के JHora वाले मान दिन के सूत्र से '
      'मेल खाते हैं)',
);

const Bi _followsHayanaratna = Bi(
  'The app’s sahams follow Hayanaratna wherever its wording is plain, so its '
      'form is the one computed here; the other is shown beside it.',
  'ऐप के सहम जहाँ हायनरत्न का शब्द साफ़ है वहाँ उसी का अनुसरण करते हैं, इसलिए '
      'यहाँ उसी का रूप गिना गया है; दूसरा रूप उसके बगल में दिखाया है।',
);

const Bi _allTimes = Bi(
  'The text gives this point “at all times”, day and night alike, so the '
      'two terms are not swapped after sunset.',
  'ग्रंथ इस बिंदु को “सदा” यानी दिन-रात दोनों में एक-सा बताता है, इसलिए '
      'सूर्यास्त के बाद दोनों पद आपस में नहीं बदलते।',
);

const Bi _swapsAtNight = Bi(
  'The software applies the table’s usual day-and-night swap to this point as '
      'well, so after sunset the two terms trade places.',
  'सॉफ़्टवेयर तालिका का सामान्य दिन-रात का उलटाव इस बिंदु पर भी लगाता है, '
      'इसलिए सूर्यास्त के बाद दोनों पद आपस में बदल जाते हैं।',
);

const Bi _nightOnlyWhy = Bi(
  'By day the two agree. The only difference is whether the two terms swap '
      'places after sunset.',
  'दिन में दोनों एक हैं। फ़र्क बस इतना है कि सूर्यास्त के बाद दोनों पद आपस में '
      'बदलते हैं या नहीं।',
);

/// One position on a disputed saham.
class _SahamView {
  const _SahamView({
    required this.holder,
    required this.reasoning,
    required this.build,
    this.isDefault = false,
  });

  final Bi holder;
  final Bi reasoning;
  final _Build build;
  final bool isDefault;
}

/// A saham with two or three positions.
class _Dispute {
  const _Dispute({
    required this.key,
    required this.name,
    required this.views,
    required this.defaultReason,
    required this.why,
    this.id,
    this.governs,
    this.nightOnly = false,
  });

  final String key;
  final Bi name;

  /// The id of the saham in the main list, when it is one of those the app
  /// already computes (Asha, Mrityu, Putra); null for the ones that were left
  /// out of it.
  final SahamId? id;
  final List<_SahamView> views;
  final Bi defaultReason;
  final Bi why;
  final Bi? governs;

  /// True when the positions give the same point by day and part only after
  /// sunset.
  final bool nightOnly;
}

_Term _punyaTerm(_Ctx c) => c.saham(SahamId.punya, _punyaName);

_Term _vidyaTerm(_Ctx c) =>
    c.saham(SahamId.vidya, const Bi('Vidya saham', 'विद्या सहम'));

/// The Shastra saham of PyJHora: Jupiter - Saturn + Mercury by day, swapped at
/// night, with the app's rule for the extra sign. It is not one of the sahams
/// in the main list.
_Term _shastraTerm(_Ctx c, bool day) {
  final _Formula f = _swap(
    day,
    c.g(Graha.jupiter),
    c.g(Graha.saturn),
    c.g(Graha.mercury),
  );
  return _Term(
    const Bi('Shastra saham', 'शास्त्र सहम'),
    _sahamLongitude(f, c.lagnaLon),
  );
}

_Term _sixthHouse(_Ctx c) => c.house(6);

final List<_Dispute> _disputes = <_Dispute>[
  // Mitra (friends).
  _Dispute(
    key: 'mitra',
    name: const Bi('Mitra', 'मित्र'),
    governs: const Bi('friends and friendship', 'मित्र और मित्रता'),
    why: const Bi(
      'The books read “teacher” differently: as a point of the chart (the '
          'Learning saham) or as the planet Jupiter.',
      'ग्रंथ “गुरु” को अलग-अलग पढ़ते हैं: एक कुंडली के बिंदु (विद्या सहम) की तरह, '
          'दूसरा ग्रह गुरु की तरह।',
    ),
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts Fortune from “the lot of the teacher”, and names '
              'that lot as Teacher and Learning, the reverse of Fortune. So the '
              'first term is the Vidya saham, not the planet.',
          'पाठ “गुरु के सहम” में से पुण्य घटाता है, और उस सहम को गुरु और विद्या '
              'कहता है, जो पुण्य का उलटा है। इसलिए पहला पद विद्या सहम है, ग्रह नहीं।',
        ),
        build: (_Ctx c, bool day) =>
            _swap(day, _vidyaTerm(c), _punyaTerm(c), c.g(Graha.venus)),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: const Bi(
          'The software reads “guru” as the planet Jupiter. The JHora value '
              'kept in its test file fits the Jupiter form and misses the '
              'Learning form by about a hundred degrees. Why it reads it so is '
              'not stated.',
          'सॉफ़्टवेयर “गुरु” को ग्रह गुरु (बृहस्पति) पढ़ता है। इसकी जाँच-फ़ाइल का '
              'JHora मान गुरु वाले रूप से मिलता है और विद्या वाले रूप से लगभग सौ अंश दूर '
              'रहता है। ऐसा क्यों पढ़ा गया, यह नहीं बताया गया।',
        ),
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.jupiter), _punyaTerm(c), c.g(Graha.venus)),
      ),
    ],
  ),
  // Vanik (trade).
  _Dispute(
    key: 'vanik',
    name: const Bi('Vanik', 'वणिक'),
    governs: const Bi('trade and dealings', 'व्यापार और लेन-देन'),
    nightOnly: true,
    why: _nightOnlyWhy,
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: _allTimes,
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.moon), c.g(Graha.mercury), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: const Bi(
          'The software swaps the two terms after sunset. Its test file also '
              'holds a night-born sample chart whose Vanik value agrees with '
              'the swapped form.',
          'सॉफ़्टवेयर सूर्यास्त के बाद दोनों पद बदल देता है। इसकी जाँच-फ़ाइल में '
              'रात में जन्मी एक उदाहरण कुंडली भी है जिसका वणिक मान बदले हुए रूप से '
              'मिलता है।',
        ),
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.moon), c.g(Graha.mercury), c.lagna),
      ),
    ],
  ),
  // Vivaha (marriage): three forms.
  _Dispute(
    key: 'vivaha',
    name: const Bi('Vivaha', 'विवाह'),
    governs: const Bi(
      'marriage and partnership matters',
      'विवाह और साझेदारी के विषय',
    ),
    why: const Bi(
      'Hayanaratna and PyJHora agree on Venus minus Saturn by day and differ '
          'on the swap after sunset. A third form, Venus minus Jupiter, is '
          'printed on a popular website that names no book.',
      'हायनरत्न और PyJHora दिन में शुक्र घटा शनि पर एक हैं और सूर्यास्त के बाद के '
          'उलटाव पर अलग। तीसरा रूप, शुक्र घटा गुरु, एक लोकप्रिय वेबसाइट पर छपा है '
          'जो कोई पुस्तक नहीं बताती।',
    ),
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: _allTimes,
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.venus), c.g(Graha.saturn), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: _swapsAtNight,
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.venus), c.g(Graha.saturn), c.lagna),
      ),
      _SahamView(
        holder: const Bi(
          'A form printed on the website astrosutras.in, which names no book; '
              'its source could not be traced',
          'astrosutras.in वेबसाइट पर छपा रूप, जो कोई पुस्तक नहीं बताती; इसका '
              'स्रोत खोजा नहीं जा सका',
        ),
        reasoning: const Bi(
          'It subtracts Jupiter, the planet of marriage in the popular '
              'reading, instead of Saturn. No reason is given, and no day-night '
              'rule, so here it is worked the same by day and night.',
          'यह शनि की जगह गुरु घटाता है, जो प्रचलित पाठ में विवाह का ग्रह है। कोई '
              'कारण नहीं दिया गया, न दिन-रात का नियम, इसलिए यहाँ इसे दिन और रात दोनों '
              'में एक-सा गिना गया है।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.venus), c.g(Graha.jupiter), c.lagna),
      ),
    ],
  ),
  // Santapa (distress).
  _Dispute(
    key: 'santapa',
    name: const Bi('Santapa', 'संताप'),
    governs: const Bi(
      'worry and distress, which ask for patience',
      'चिंता और संताप, जिनमें धैर्य चाहिए',
    ),
    nightOnly: true,
    why: _nightOnlyWhy,
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text takes the Moon from Saturn and adds the sixth house, “at '
              'all times”, so the terms are not swapped at night.',
          'पाठ शनि में से चंद्र घटाकर छठा भाव जोड़ता है, “सदा”, इसलिए रात में पद '
              'नहीं बदलते।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.saturn), c.g(Graha.moon), _sixthHouse(c)),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: _swapsAtNight,
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.saturn), c.g(Graha.moon), _sixthHouse(c)),
      ),
    ],
  ),
  // Shraddha (faith).
  _Dispute(
    key: 'shraddha',
    name: const Bi('Shraddha', 'श्रद्धा'),
    governs: const Bi('faith and devotion', 'श्रद्धा और भक्ति'),
    nightOnly: true,
    why: _nightOnlyWhy,
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: _allTimes,
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.venus), c.g(Graha.mars), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: _swapsAtNight,
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.venus), c.g(Graha.mars), c.lagna),
      ),
    ],
  ),
  // Preeti (affection).
  _Dispute(
    key: 'preeti',
    name: const Bi('Preeti', 'प्रीति'),
    governs: const Bi('affection and liking', 'स्नेह और लगाव'),
    why: const Bi(
      'The books subtract Fortune from different points: the Learning saham '
          'in one, the Shastra saham in the other. They also differ on the '
          'swap after sunset.',
      'दोनों में पुण्य अलग-अलग बिंदु से घटाया जाता है: एक में विद्या सहम से, '
          'दूसरे में शास्त्र सहम से। सूर्यास्त के बाद के उलटाव पर भी मतभेद है।',
    ),
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts Fortune from the lot called Knowledge, “at all '
              'times”. Knowledge is the Vidya saham here; reading “at all '
              'times” as no night swap is our reading of the wording.',
          'पाठ “ज्ञान” नाम के सहम में से पुण्य घटाता है, “सदा”। यहाँ ज्ञान विद्या '
              'सहम है; “सदा” का अर्थ रात में उलटाव नहीं, यह शब्दों का हमारा पाठ है।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(_vidyaTerm(c), _punyaTerm(c), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: const Bi(
          'The software starts from its Shastra saham (Jupiter minus Saturn '
              'plus Mercury) and swaps after sunset. The JHora value kept in '
              'its test file fits this form and misses the Vidya form by about '
              'two hundred degrees.',
          'सॉफ़्टवेयर अपने शास्त्र सहम (गुरु घटा शनि जमा बुध) से शुरू करता है और '
              'सूर्यास्त के बाद पद बदलता है। इसकी जाँच-फ़ाइल का JHora मान इसी रूप से '
              'मिलता है और विद्या वाले रूप से लगभग दो सौ अंश दूर रहता है।',
        ),
        build: (_Ctx c, bool day) =>
            _swap(day, _shastraTerm(c, day), _punyaTerm(c), c.lagna),
      ),
    ],
  ),
  // Bandhu (kinsfolk).
  _Dispute(
    key: 'bandhu',
    name: const Bi('Bandhu', 'बंधु'),
    governs: const Bi('relatives and kin', 'बंधु-बांधव और रिश्तेदार'),
    nightOnly: true,
    why: _nightOnlyWhy,
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts the Moon from Mercury “by day or night”, so '
              'there is no swap.',
          'पाठ बुध में से चंद्र घटाता है, “दिन या रात”, इसलिए उलटाव नहीं है।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.mercury), c.g(Graha.moon), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: _swapsAtNight,
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.mercury), c.g(Graha.moon), c.lagna),
      ),
    ],
  ),
  // Vyapara (occupation).
  _Dispute(
    key: 'vyapara',
    name: const Bi('Vyapara', 'व्यापार'),
    governs: const Bi('occupation and business', 'पेशा और कारोबार'),
    why: const Bi(
      'The books subtract different grahas from Mars: Mercury in one, Saturn '
          'in the other.',
      'दोनों मंगल में से अलग-अलग ग्रह घटाते हैं: एक बुध, दूसरा शनि।',
    ),
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts Mercury from Mars “at all times”, the planet of '
              'trade taken from the planet of drive. Charak, as a developer’s '
              'transcription reports it, notes that this is not the formula '
              'of Vanik.',
          'पाठ मंगल में से बुध घटाता है, “सदा”: ऊर्जा के ग्रह में से व्यापार का ग्रह। '
              'चरक, जैसा एक डेवलपर के बनाए नोट्स बताते हैं, कहते हैं कि यह वणिक का '
              'सूत्र नहीं है।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.mars), c.g(Graha.mercury), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: const Bi(
          'The software gives Vyapara the same formula as its Shatru saham, '
              'Mars minus Saturn, and the JHora value in its test file is the '
              'same for the two. No reason is given.',
          'सॉफ़्टवेयर व्यापार को वही सूत्र देता है जो उसके शत्रु सहम का है, मंगल '
              'घटा शनि; इसकी जाँच-फ़ाइल में दोनों का JHora मान एक ही है। कोई कारण '
              'नहीं दिया गया।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.mars), c.g(Graha.saturn), c.lagna),
      ),
    ],
  ),
  // Putra (children): in the main list, with no night swap.
  _Dispute(
    id: SahamId.putra,
    key: 'putra',
    name: const Bi('Putra', 'पुत्र'),
    governs: const Bi(
      'children and what one nurtures',
      'संतान और जिसे हम पालते-पोसते हैं',
    ),
    nightOnly: true,
    why: _nightOnlyWhy,
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts the Moon from Jupiter “by day or night”, so '
              'there is no swap.',
          'पाठ गुरु में से चंद्र घटाता है, “दिन या रात”, इसलिए उलटाव नहीं है।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.g(Graha.jupiter), c.g(Graha.moon), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: _swapsAtNight,
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.jupiter), c.g(Graha.moon), c.lagna),
      ),
    ],
  ),
  // Asha (hope): in the main list, Venus or Mars subtracted.
  _Dispute(
    id: SahamId.asha,
    key: 'asha',
    name: const Bi('Asha', 'आशा'),
    governs: const Bi('hopes and wishes', 'आशाएँ और इच्छाएँ'),
    why: const Bi(
      'The books subtract different grahas from Saturn: Venus in one, Mars '
          'in the other.',
      'दोनों शनि में से अलग-अलग ग्रह घटाते हैं: एक शुक्र, दूसरा मंगल।',
    ),
    defaultReason: _followsHayanaratna,
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts Venus from Saturn by day and reverses it by '
              'night. A developer’s transcription of Charak’s book gives the '
              'same.',
          'पाठ दिन में शनि में से शुक्र घटाता है और रात में उलटा करता है। चरक की '
              'पुस्तक के एक डेवलपर के बनाए नोट्स भी यही देते हैं।',
        ),
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.saturn), c.g(Graha.venus), c.lagna),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: const Bi(
          'The software subtracts Mars. The JHora value kept in its test file '
              'fits the Mars form and misses the Venus form by about fifty-eight '
              'degrees. No reason is given.',
          'सॉफ़्टवेयर मंगल घटाता है। इसकी जाँच-फ़ाइल का JHora मान मंगल वाले रूप से '
              'मिलता है और शुक्र वाले रूप से लगभग अट्ठावन अंश दूर रहता है। कोई कारण '
              'नहीं दिया गया।',
        ),
        build: (_Ctx c, bool day) =>
            _swap(day, c.g(Graha.saturn), c.g(Graha.mars), c.lagna),
      ),
    ],
  ),
  // Mrityu: computed, never read. Only the name is a name; the point is shown.
  _Dispute(
    id: SahamId.mrityu,
    key: 'mrityu',
    name: const Bi('Mrityu', 'मृत्यु'),
    why: const Bi(
      'The books add different points to the eighth house less the Moon: '
          'Saturn in one, the Lagna in the other.',
      'दोनों अष्टम भाव में से चंद्र घटाकर अलग-अलग बिंदु जोड़ते हैं: एक शनि, '
          'दूसरा लग्न।',
    ),
    defaultReason: const Bi(
      'The app follows Hayanaratna here. The point is only shown with its '
          'formula; the app makes no reading of it.',
      'ऐप यहाँ हायनरत्न का अनुसरण करता है। बिंदु केवल सूत्र के साथ दिखाया जाता है; '
          'ऐप उसका कोई पठन नहीं करता।',
    ),
    views: <_SahamView>[
      _SahamView(
        isDefault: true,
        holder: _hayanaratna,
        reasoning: const Bi(
          'The text subtracts the Moon from the eighth house and adds Saturn, '
              '“at all times”. A developer’s transcription of Charak’s book '
              'gives the same.',
          'पाठ अष्टम भाव में से चंद्र घटाकर शनि जोड़ता है, “सदा”। चरक की पुस्तक की '
              'एक डेवलपर के बनाए नोट्स भी यही देते हैं।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.house(8), c.g(Graha.moon), c.g(Graha.saturn)),
      ),
      _SahamView(
        holder: _pyjhora,
        reasoning: const Bi(
          'The software adds the Lagna instead of Saturn. The JHora value kept '
              'in its test file fits the Lagna form and misses the Saturn '
              'form by about forty-four degrees.',
          'सॉफ़्टवेयर शनि की जगह लग्न जोड़ता है। इसकी जाँच-फ़ाइल का JHora मान लग्न '
              'वाले रूप से मिलता है और शनि वाले रूप से लगभग चौवालीस अंश दूर रहता है।',
        ),
        build: (_Ctx c, bool day) =>
            _Formula(c.house(8), c.g(Graha.moon), c.lagna),
      ),
    ],
  ),
];

/// "Falls at 12°34′ Mesha (12.57°), 3rd house; its lord is Mars" for a
/// longitude, with the formula that gave it.
Bi _pointResult(Kundli chart, double longitude, Bi formula) {
  final int sign = (longitude / 30.0).floor() % 12;
  final int house = ((sign - chart.lagnaRashi.index + 12) % 12) + 1;
  final Graha lord = rashiInfo(Rashi.values[sign]).lord;
  return Bi(
    '${formula.en} = ${degText(longitude % 30.0)} ${rashiBi(sign).en}, '
        '${houseBi(house).en}; its lord is ${grahaBi(lord).en}.',
    '${formula.hi} = ${rashiBi(sign).hi} ${degText(longitude % 30.0)}, '
        '${houseBi(house).hi}; इसका स्वामी ${grahaBi(lord).hi} है।',
  );
}

/// A disputed saham, worked out under each position.
class SahamMatbhed {
  const SahamMatbhed({
    required this.key,
    required this.name,
    required this.matbhed,
    required this.inMainList,
    required this.governs,
  });

  /// "mitra", "vivaha", "asha" ...
  final String key;
  final Bi name;

  /// Each view's `value` is the saham's longitude under it, in degrees.
  final Matbhed matbhed;

  /// True for Asha, Mrityu and Putra, which also stand in the main list under
  /// the default position.
  final bool inMainList;

  /// What the tradition says the point is for, where the app makes a plain
  /// statement of it. Null for Mrityu. Never a reading of the year.
  final Bi? governs;

  /// The longitudes under each view, in the order of [matbhed].views.
  List<double> get longitudes =>
      matbhed.views.map((Mat m) => m.value!).toList(growable: false);
}

/// Works out every disputed saham on [chart] under each position.
///
/// [sahams] is the main list [computeSahams] returned for the same chart and
/// the same day or night, so the sahams a formula leans on (Punya, Vidya) are
/// the ones already worked out. [isDay] picks the day or the night form of each
/// position's formula.
List<SahamMatbhed> computeSahamMatbhed(
  Kundli chart,
  List<Saham> sahams, {
  required bool isDay,
}) {
  final Map<SahamId, double> done = <SahamId, double>{
    for (final Saham s in sahams) s.id: s.longitude,
  };
  final _Ctx ctx = _Ctx(chart, done);
  final List<SahamMatbhed> out = <SahamMatbhed>[];
  for (final _Dispute d in _disputes) {
    final List<Mat> views = <Mat>[];
    for (final _SahamView v in d.views) {
      final _Formula f = v.build(ctx, isDay);
      final double longitude = _sahamLongitude(f, ctx.lagnaLon);
      views.add(
        Mat(
          position: Bi(
            '${f.text.en} (${isDay ? 'day' : 'night'} chart)',
            '${f.text.hi} (${isDay ? 'दिन' : 'रात्रि'} कुंडली)',
          ),
          holder: v.holder,
          reasoning: v.reasoning,
          result: _pointResult(chart, longitude, f.text),
          isDefault: v.isDefault,
          value: longitude,
        ),
      );
    }
    final bool same = views.every(
      (Mat m) => (m.value! - views.first.value!).abs() < 1e-6,
    );
    final Bi why = d.nightOnly && isDay && same
        ? d.why +
              const Bi(
                'This year chart was cast by day, so both land on the same '
                    'point.',
                'यह वर्ष कुंडली दिन में बनी है, इसलिए दोनों एक ही बिंदु पर आते हैं।',
              )
        : d.why;
    out.add(
      SahamMatbhed(
        key: d.key,
        name: d.name,
        inMainList: d.id != null,
        governs: d.governs,
        matbhed: Matbhed(
          key: 'saham_${d.key}',
          topic: Bi('${d.name.en} saham', '${d.name.hi} सहम'),
          views: views,
          defaultReason: d.defaultReason,
          whyTheyDiffer: why,
        ),
      ),
    );
  }
  return out;
}

/// Whether [rule] adds the extra sign to the saham of formula [f].
bool _addsSign(_Formula f, double lagnaLon, ExtraSignRule rule) {
  final double arc = norm360(f.a.longitude - f.b.longitude);
  return switch (rule) {
    ExtraSignRule.lagna => norm360(lagnaLon - f.b.longitude) > arc,
    ExtraSignRule.addedTerm => norm360(f.c.longitude - f.b.longitude) > arc,
    ExtraSignRule.never => false,
  };
}

/// The longitudes of the whole main list under one rule for the extra sign,
/// and the sahams that took the sign. The sahams that lean on others (Yasha on
/// Punya, ...) are worked out from this rule's own results, so a change of
/// rule carries through.
({Map<SahamId, double> longitudes, Set<SahamId> added}) _longitudesUnder(
  Kundli chart, {
  required bool isDay,
  required ExtraSignRule rule,
}) {
  final Map<SahamId, double> done = <SahamId, double>{};
  final Set<SahamId> added = <SahamId>{};
  final _Ctx ctx = _Ctx(chart, done);
  for (final _Spec spec in _specs) {
    final _Formula f = spec.build(ctx, isDay);
    done[spec.id] = _sahamLongitude(f, ctx.lagnaLon, rule);
    if (_addsSign(f, ctx.lagnaLon, rule)) added.add(spec.id);
  }
  return (longitudes: done, added: added);
}

Bi _namesOf(Iterable<SahamId> ids) {
  final List<Bi> names = <Bi>[
    for (final _Spec spec in _specs)
      if (ids.contains(spec.id) && !uninterpretedSahams.contains(spec.id))
        spec.name,
  ];
  // The points the app only shows, without a reading, are counted but not
  // named in a list of this kind.
  final int shown = ids.where(uninterpretedSahams.contains).length;
  if (names.isEmpty && shown == 0) return const Bi('none', 'कोई नहीं');
  final String en = names.map((Bi b) => b.en).join(', ');
  final String hi = names.map((Bi b) => b.hi).join(', ');
  if (shown == 0) return Bi(en, hi);
  final String moreEn =
      '$shown point${shown == 1 ? '' : 's'} the app only '
      'shows, without a reading';
  final String moreHi = 'ऐप के केवल दिखाए जाने वाले $shown बिंदु, बिना पठन के';
  return Bi(
    names.isEmpty ? moreEn : '$en and $moreEn',
    names.isEmpty ? moreHi : '$hi और $moreHi',
  );
}

/// The dispute over when a saham takes one more sign (30°): three positions,
/// each worked out on every saham of the main list for this year chart. The
/// default view's `value` is 0; the others carry the number of sahams that
/// land a sign away from where the default puts them.
Matbhed extraSignMatbhed(Kundli chart, {required bool isDay}) {
  final ({Map<SahamId, double> longitudes, Set<SahamId> added}) lagnaRun =
      _longitudesUnder(chart, isDay: isDay, rule: ExtraSignRule.lagna);
  final ({Map<SahamId, double> longitudes, Set<SahamId> added}) termRun =
      _longitudesUnder(chart, isDay: isDay, rule: ExtraSignRule.addedTerm);
  final ({Map<SahamId, double> longitudes, Set<SahamId> added}) neverRun =
      _longitudesUnder(chart, isDay: isDay, rule: ExtraSignRule.never);
  final Map<SahamId, double> byLagna = lagnaRun.longitudes;
  final Map<SahamId, double> byTerm = termRun.longitudes;
  final Map<SahamId, double> never = neverRun.longitudes;
  List<SahamId> moved(Map<SahamId, double> other) => <SahamId>[
    for (final SahamId id in byLagna.keys)
      if (angleDiff(byLagna[id]!, other[id]!).abs() > 1e-6) id,
  ];
  final List<SahamId> termMoves = moved(byTerm);
  final List<SahamId> neverMoves = moved(never);

  final List<SahamId> added = lagnaRun.added.toList(growable: false);

  Bi resultFor(
    String en,
    String hi,
    List<SahamId> ids, {
    bool reference = false,
  }) {
    final Bi names = _namesOf(ids);
    return reference
        ? Bi(
            'Of the ${_specs.length} sahams, ${ids.length} take the extra '
                'sign: ${names.en}.',
            '${_specs.length} सहमों में से ${ids.length} को अतिरिक्त राशि '
                'मिलती है: ${names.hi}।',
          )
        : Bi(
            '$en ${ids.length} of the ${_specs.length} sahams '
                '${ids.length == 1 ? 'lands' : 'land'} at a different point '
                'from the first view: ${names.en}.',
            '$hi ${_specs.length} सहमों में से ${ids.length} पहले मत से अलग '
                'बिंदु पर आते हैं: ${names.hi}।',
          );
  }

  return Matbhed(
    key: 'extra_sign',
    topic: const Bi(
      'When a saham takes one more sign (30°)',
      'सहम को कब एक राशि (30°) और मिलती है',
    ),
    whyTheyDiffer: const Bi(
      'The rule of the extra sign is itself disputed. Some books test the '
          'Lagna, some test the term that is added, and some authors that '
          'Balabhadra reports compute the lots without any extra sign.',
      'अतिरिक्त राशि का नियम स्वयं विवाद में है। कुछ पुस्तकें लग्न को जाँचती हैं, '
          'कुछ उस पद को जो जोड़ा जाता है, और बलभद्र जिन लेखकों का उल्लेख करते हैं '
          'उनमें कुछ बिना किसी अतिरिक्त राशि के सहम निकालते हैं।',
    ),
    defaultReason: const Bi(
      'The app has always tested the Lagna. PyJHora’s current code does the '
          'same for most sahams, so the points here agree with what that '
          'software prints; the other two readings are shown so the gap is '
          'visible.',
      'ऐप हमेशा से लग्न को जाँचता है। PyJHora का वर्तमान कोड भी अधिकतर सहमों के '
          'लिए यही करता है, इसलिए यहाँ के बिंदु उस सॉफ़्टवेयर से मेल खाते हैं; बाकी '
          'दो पाठ इसलिए दिखाए हैं कि फ़र्क साफ़ दिखे।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: 0,
        position: const Bi(
          'Add one sign if the Lagna does not lie in the arc from B forward to '
              'A.',
          'यदि लग्न B से A तक के चाप में न हो तो एक राशि जोड़ें।',
        ),
        holder: const Bi(
          'PyJHora’s current code (it tests the Lagna for most sahams), and '
              'the JHora values kept in its test file for the Shastra, '
              'Karyasiddhi and Santapa sahams on one chart. For Fortune, where '
              'the term added is the Lagna itself, Hayanaratna 4.2 says the same.',
          'PyJHora का वर्तमान कोड (अधिकतर सहमों में लग्न जाँचता है), और इसकी '
              'जाँच-फ़ाइल में एक कुंडली के शास्त्र, कार्यसिद्धि और संताप सहमों के '
              'JHora मान। पुण्य के लिए, जहाँ जोड़ा जाने वाला पद स्वयं लग्न है, '
              'हायनरत्न 4.2 भी यही कहता है।',
        ),
        reasoning: const Bi(
          'The software once tested the added term and was changed to test the '
              'Lagna, and the recorded JHora values for those three sahams are '
              'matched only when the Lagna is tested.',
          'सॉफ़्टवेयर पहले जोड़े जाने वाले पद को जाँचता था और फिर लग्न जाँचने '
              'वाला बनाया गया; उन तीनों सहमों के रखे हुए JHora मान तभी मिलते हैं जब '
              'लग्न जाँचा जाए।',
        ),
        result: resultFor('', '', added, reference: true),
      ),
      Mat(
        value: termMoves.length.toDouble(),
        position: const Bi(
          'Add one sign if the term that is added (C) does not lie in the arc '
              'from B forward to A. Where C is the Lagna this is the same as '
              'the first view.',
          'यदि जोड़ा जाने वाला पद (C) B से A तक के चाप में न हो तो एक राशि जोड़ें। '
              'जहाँ C लग्न है वहाँ यह पहले मत जैसा ही है।',
        ),
        holder: const Bi(
          'Balabhadra’s Hayanaratna 4.3, read in Gansten’s English '
              'translation: for Mitra the test is made at Venus, for Shastra at '
              'Mercury, and for one more point at Saturn',
          'बलभद्र का हायनरत्न 4.3, गैन्स्टन के अंग्रेज़ी अनुवाद में पढ़ा: मित्र में '
              'जाँच शुक्र पर, शास्त्र में बुध पर, और एक और बिंदु में शनि पर की जाती है',
        ),
        reasoning: const Bi(
          'For these sahams the text restates the Fortune rule with the term '
              'that is added named in place of the ascendant.',
          'इन सहमों के लिए पाठ पुण्य का नियम दोहराता है, पर लग्न की जगह जोड़े जाने '
              'वाले पद का नाम रखकर।',
        ),
        result: resultFor('Worked with this test,', 'इस जाँच से,', termMoves),
      ),
      Mat(
        value: neverMoves.length.toDouble(),
        position: const Bi(
          'Never add a sign: the plain arc A − B laid off from C.',
          'कभी राशि न जोड़ें: केवल चाप A − B, C से आगे।',
        ),
        holder: const Bi(
          'Keshava Daivajna, Haribhatta (Tajikasara) and Ganesha Daivajna, '
              'whom Balabhadra reports in Hayanaratna 4.2 as computing the lots '
              'without the extra sign',
          'केशव दैवज्ञ, हरिभट्ट (ताजिकसार) और गणेश दैवज्ञ, जिनके बारे में बलभद्र '
              'हायनरत्न 4.2 में बताते हैं कि वे अतिरिक्त राशि के बिना सहम निकालते हैं',
        ),
        reasoning: const Bi(
          'They work the lot as a plain arc. The translator Gansten notes that '
              'this agrees with how Graeco-Arabic lots are worked, and quotes '
              'Vishvanatha Daivajna (1629) that the Samjnatantra alone '
              'advocates adding a sign.',
          'वे सहम को सीधा चाप मानकर निकालते हैं। अनुवादक गैन्स्टन लिखते हैं कि यह '
              'यूनानी-अरबी सहमों की रीति से मेल खाता है, और विश्वनाथ दैवज्ञ (1629) को '
              'उद्धृत करते हैं कि राशि जोड़ने की बात केवल संज्ञातंत्र कहता है।',
        ),
        result: resultFor('Worked with this test,', 'इस जाँच से,', neverMoves),
      ),
    ],
  );
}

/// What the sahams still do not compute, with the reason.
const List<LeftOut> sahamLeftOut = <LeftOut>[
  LeftOut(
    key: 'vishwasghata',
    name: Bi('Vishwasghata saham', 'विश्वासघात सहम'),
    reason: Bi(
      'No formula for it could be found. It is not among the 75 names in '
          'Hayanaratna’s list, nor among the 36 sahams of PyJHora, nor in the '
          'developer’s transcription of Charak’s 41, and a search turned up '
          'none. The nearest name, “ghata” in Hayanaratna, is a different '
          'point, and tying the two together would be a guess.',
      'इसका कोई सूत्र नहीं मिला। यह हायनरत्न की 75 नामों की सूची में नहीं है, न '
          'PyJHora के 36 सहमों में, न चरक के 41 पर एक डेवलपर के नोट्स में, और खोज में भी '
          'कुछ नहीं मिला। हायनरत्न का सबसे निकट नाम “घात” एक अलग बिंदु है, और दोनों '
          'को जोड़ना अनुमान होगा।',
    ),
  ),
];
