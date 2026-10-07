import 'dart:math' as math;

import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'tajika_bala.dart';
import 'tajika_common.dart';

/// Tajika aspects and yogas.
///
/// The Tajika aspect is unlike the Parashari full-sign drishti the rest of
/// the app uses. Two grahas are in aspect only if their SIGNS stand in one of
/// the Tajika relations (conjunction, or the 3rd, 4th, 5th, 7th, 9th, 10th and
/// 11th sign from each other; never the 2nd, 6th, 8th or 12th), and the
/// aspect is then judged by the DEGREES each stands at within its own sign:
/// the swifter graha behind the slower one is applying (Ittasala, Arabic
/// muttasil), the swifter graha ahead of the slower is separating (Ishrafa,
/// Arabic mushrif). The orb is the mean of the two grahas' deeptamsha.
///
/// Sources: Tajika Neelakanthi, Samjnatantra ch. 2-3 (Mahidhara's commentary
/// on Sanskrit Wikisource); Balabhadra's Hayanaratna ch. 2-3 (Gansten's
/// translation on wisdomlib); K.S. Charak, A Textbook of Varshaphala, as
/// implemented in teispace/teistro-sdk for cross-checking. Where a text gives
/// a definition the code could not pin down without guessing, the yoga is left
/// out and said so in docs/ENGINE.md: Gairi-kamboola, Tambira, Kuttha and
/// Durapha.

/// Orb of light, in degrees, of each graha (Neelakanthi 3.2; Hayanaratna 3.1).
const Map<Graha, double> deeptamsha = <Graha, double>{
  Graha.sun: 15,
  Graha.moon: 12,
  Graha.mars: 8,
  Graha.mercury: 7,
  Graha.jupiter: 9,
  Graha.venus: 7,
  Graha.saturn: 9,
};

/// The orb a pair of grahas share: half the sum of their deeptamsha.
double meanOrb(Graha a, Graha b) => (deeptamsha[a]! + deeptamsha[b]!) / 2.0;

/// The Tajika relations between two signs.
enum SignAspect { conjunction, sextile, square, trine, opposition }

/// Whether the relation is read as friendly or inimical (Hayanaratna 2.1:
/// the trine and the sextile are friendly, the square and the opposition
/// inimical; a conjunction takes its colour from the grahas' dignity).
enum AspectNature { friendly, inimical, conjunct }

SignAspect? signAspectOf(int distance) => switch (distance) {
  1 => SignAspect.conjunction,
  3 || 11 => SignAspect.sextile,
  4 || 10 => SignAspect.square,
  5 || 9 => SignAspect.trine,
  7 => SignAspect.opposition,
  _ => null,
};

AspectNature natureOf(SignAspect aspect) => switch (aspect) {
  SignAspect.sextile || SignAspect.trine => AspectNature.friendly,
  SignAspect.square || SignAspect.opposition => AspectNature.inimical,
  SignAspect.conjunction => AspectNature.conjunct,
};

Bi signAspectBi(SignAspect aspect) => switch (aspect) {
  SignAspect.conjunction => const Bi('conjunction', 'युति'),
  SignAspect.sextile => const Bi(
    '3rd/11th sign aspect (friendly)',
    'तृतीय/एकादश मित्र दृष्टि',
  ),
  SignAspect.trine => const Bi(
    '5th/9th sign aspect (friendly)',
    'पंचम/नवम मित्र दृष्टि',
  ),
  SignAspect.square => const Bi(
    '4th/10th sign aspect (inimical)',
    'चतुर्थ/दशम शत्रु दृष्टि',
  ),
  SignAspect.opposition => const Bi(
    '7th sign aspect (inimical)',
    'सप्तम शत्रु दृष्टि',
  ),
};

/// The twelve yogas this engine can establish. Four of the sixteen Tajika
/// yogas are not here by design; see the library comment.
enum TajikaYogaId {
  ikkabala,
  induvara,
  ittasala,
  ishrafa,
  nakta,
  yamaya,
  manau,
  kamboola,
  khallasara,
  radda,
  duhphaliKuttha,
  dutthotthaDavira,
}

/// How the tradition reads a yoga: for the matter, against it, or mixed.
enum YogaTone { favourable, unfavourable, mixed }

Bi tajikaYogaName(TajikaYogaId id) => switch (id) {
  TajikaYogaId.ikkabala => const Bi('Ikkabala', 'इक्कबाल'),
  TajikaYogaId.induvara => const Bi('Induvara', 'इंदुवार'),
  TajikaYogaId.ittasala => const Bi(
    'Ittasala (Muthashila)',
    'इत्थशाल (मुत्थशिल)',
  ),
  TajikaYogaId.ishrafa => const Bi('Ishrafa (Mushariph)', 'ईसराफ (मुशरिफ)'),
  TajikaYogaId.nakta => const Bi('Nakta', 'नक्त'),
  TajikaYogaId.yamaya => const Bi('Yamaya', 'यमया'),
  TajikaYogaId.manau => const Bi('Manau', 'मणऊ'),
  TajikaYogaId.kamboola => const Bi('Kamboola', 'कम्बूल'),
  TajikaYogaId.khallasara => const Bi('Khallasara', 'खल्लासर'),
  TajikaYogaId.radda => const Bi('Radda', 'रद्द'),
  TajikaYogaId.duhphaliKuttha => const Bi('Duhphali-kuttha', 'दुफाली कुत्थ'),
  TajikaYogaId.dutthotthaDavira => const Bi(
    'Dutthottha-davira',
    'दुत्थोत्थ दवीर',
  ),
};

YogaTone tajikaYogaTone(TajikaYogaId id) => switch (id) {
  TajikaYogaId.ikkabala ||
  TajikaYogaId.ittasala ||
  TajikaYogaId.nakta ||
  TajikaYogaId.yamaya ||
  TajikaYogaId.kamboola ||
  TajikaYogaId.duhphaliKuttha ||
  TajikaYogaId.dutthotthaDavira => YogaTone.favourable,
  TajikaYogaId.induvara ||
  TajikaYogaId.ishrafa ||
  TajikaYogaId.manau ||
  TajikaYogaId.khallasara ||
  TajikaYogaId.radda => YogaTone.unfavourable,
};

/// The condition each yoga rests on, in words.
Bi tajikaYogaCondition(TajikaYogaId id) => switch (id) {
  TajikaYogaId.ikkabala => const Bi(
    'Every graha stands in a kendra (1, 4, 7, 10) or a panaphara '
        '(2, 5, 8, 11) of the year chart, none in 3, 6, 9 or 12.',
    'सभी ग्रह वर्ष कुंडली के केंद्र (1, 4, 7, 10) या पणफर (2, 5, 8, 11) '
        'में हैं, 3, 6, 9, 12 में कोई नहीं।',
  ),
  TajikaYogaId.induvara => const Bi(
    'Every graha stands in 3, 6, 9 or 12 of the year chart, none in a '
        'kendra or a panaphara.',
    'सभी ग्रह वर्ष कुंडली के 3, 6, 9, 12 भावों में हैं, केंद्र या पणफर में '
        'कोई नहीं।',
  ),
  TajikaYogaId.ittasala => const Bi(
    'The swifter graha is behind the slower one, within the orb they share '
        '(half the sum of their deeptamsha), and their signs are in a Tajika '
        'aspect.',
    'शीघ्रगामी ग्रह मंदगामी से पीछे है, दोनों के साझा दीप्तांश (दीप्तांशों '
        'के योग का आधा) के भीतर, और दोनों की राशियों में ताजिक दृष्टि है।',
  ),
  TajikaYogaId.ishrafa => const Bi(
    'The swifter graha has moved ahead of the slower one but is still '
        'inside the orb they share, with their signs in a Tajika aspect.',
    'शीघ्रगामी ग्रह मंदगामी से आगे निकल चुका है पर साझा दीप्तांश के भीतर '
        'है, और दोनों की राशियों में ताजिक दृष्टि है।',
  ),
  TajikaYogaId.nakta => const Bi(
    'The lagna lord and the matter’s lord have no aspect between them. A '
        'third graha, swifter than both and standing between them in degrees, '
        'is in aspect with both: it applies to the one ahead and has just '
        'left the one behind, within its own deeptamsha.',
    'लग्नेश और कार्येश में आपस में दृष्टि नहीं है। तीसरा ग्रह, दोनों से '
        'शीघ्रगामी और अंशों में दोनों के बीच, दोनों को देखता है: वह आगे वाले '
        'के निकट आ रहा है और पीछे वाले से अभी निकला है, अपने दीप्तांश के भीतर।',
  ),
  TajikaYogaId.yamaya => const Bi(
    'The lagna lord and the matter’s lord have no aspect between them. A '
        'third graha, slower than both and ahead of both in degrees, is in '
        'aspect with both and within its own deeptamsha of each.',
    'लग्नेश और कार्येश में आपस में दृष्टि नहीं है। तीसरा ग्रह, दोनों से '
        'मंदगामी और अंशों में दोनों से आगे, दोनों को देखता है और अपने '
        'दीप्तांश के भीतर है।',
  ),
  TajikaYogaId.manau => const Bi(
    'Mars or Saturn stands in an inimical aspect (conjunction, 4th, 7th or '
        '10th sign) to the swifter graha of an Ittasala, within its own '
        'deeptamsha.',
    'मंगल या शनि इत्थशाल के शीघ्रगामी ग्रह से शत्रु दृष्टि (युति, चतुर्थ, '
        'सप्तम या दशम) में है, अपने दीप्तांश के भीतर।',
  ),
  TajikaYogaId.kamboola => const Bi(
    'The lagna lord and the matter’s lord are in Ittasala, and the Moon is '
        'in Ittasala with one or both of them.',
    'लग्नेश और कार्येश में इत्थशाल है, और चंद्र उनमें से एक या दोनों से '
        'इत्थशाल में है।',
  ),
  TajikaYogaId.khallasara => const Bi(
    'The Moon forms neither an Ittasala nor a conjunction with the lagna '
        'lord or with the matter’s lord.',
    'चंद्र न लग्नेश से और न कार्येश से इत्थशाल या युति करता है।',
  ),
  TajikaYogaId.radda => const Bi(
    'The Ittasala is between grahas of which one is retrograde, combust, or '
        'in the 6th, 8th or 12th house.',
    'इत्थशाल जिन ग्रहों में है उनमें से एक वक्री, अस्त, या 6, 8, 12 भाव में '
        'है।',
  ),
  TajikaYogaId.duhphaliKuttha => const Bi(
    'In an Ittasala the slower graha is in its own sign, exaltation or '
        'triplicity while the swifter has none of these.',
    'इत्थशाल में मंदगामी ग्रह स्वराशि, उच्च या अपने त्रिराशि में है जबकि '
        'शीघ्रगामी के पास इनमें से कुछ नहीं।',
  ),
  TajikaYogaId.dutthotthaDavira => const Bi(
    'The lagna lord and the matter’s lord are both weak (under 10 vishwa) '
        'but each is in Ittasala with a third graha that is strong in its own '
        'sign or exaltation.',
    'लग्नेश और कार्येश दोनों दुर्बल (10 विश्वा से कम) हैं पर हर एक तीसरे ग्रह '
        'से इत्थशाल में है जो स्वराशि या उच्च में बलवान है।',
  ),
};

/// What the tradition reads each yoga to indicate, in plain words. These are
/// statements of what the books say the pattern means, not forecasts.
Bi tajikaYogaIndicates(TajikaYogaId id) => switch (id) {
  TajikaYogaId.ikkabala => const Bi(
    'The tradition reads this as a pattern of support for standing and '
        'comfort through the year.',
    'परंपरा इसे वर्ष भर प्रतिष्ठा और सुख के सहारे का योग पढ़ती है।',
  ),
  TajikaYogaId.induvara => const Bi(
    'The tradition reads this as a year that asks for patience and steady '
        'effort, with matters moving slowly.',
    'परंपरा इसे धैर्य और निरंतर प्रयास माँगने वाला वर्ष पढ़ती है, जिसमें '
        'कार्य धीरे बढ़ते हैं।',
  ),
  TajikaYogaId.ittasala => const Bi(
    'Applying: the tradition reads the matter these two signify as moving '
        'toward completion.',
    'समीप आता हुआ: परंपरा इन दोनों के विषय को पूर्णता की ओर बढ़ता पढ़ती है।',
  ),
  TajikaYogaId.ishrafa => const Bi(
    'Separating: the tradition reads the matter as slipping away, and '
        'effort as better placed elsewhere.',
    'दूर जाता हुआ: परंपरा इस विषय को हाथ से निकलता पढ़ती है, और प्रयास '
        'अन्यत्र लगाना बेहतर मानती है।',
  ),
  TajikaYogaId.nakta => const Bi(
    'The matter is read as completing through a go-between: a third party '
        'carries the light from one significator to the other.',
    'विषय किसी मध्यस्थ के माध्यम से पूर्ण होता पढ़ा जाता है: तीसरा पक्ष एक '
        'कारक का प्रकाश दूसरे तक पहुँचाता है।',
  ),
  TajikaYogaId.yamaya => const Bi(
    'The matter is read as completing through a slower, steadier party, '
        'such as an elder or counsellor, to whom both significators turn.',
    'विषय किसी धीमे, स्थिर पक्ष, जैसे बड़े या सलाहकार, के माध्यम से पूर्ण '
        'होता पढ़ा जाता है, जिसकी ओर दोनों कारक मुड़ते हैं।',
  ),
  TajikaYogaId.manau => const Bi(
    'A harsh graha takes the light of the swifter one: the tradition reads '
        'the Ittasala as obstructed.',
    'क्रूर ग्रह शीघ्रगामी का प्रकाश ले लेता है: परंपरा इत्थशाल में बाधा '
        'पढ़ती है।',
  ),
  TajikaYogaId.kamboola => const Bi(
    'The Moon adds her support: the tradition reads the matter as '
        'accomplished with ease.',
    'चंद्र का सहयोग मिलता है: परंपरा विषय को सहजता से सिद्ध होता पढ़ती है।',
  ),
  TajikaYogaId.khallasara => const Bi(
    'The Moon’s support is missing: the tradition reads what the two lords '
        'promise as held back.',
    'चंद्र का सहयोग नहीं है: परंपरा दोनों स्वामियों की संभावना को रुका हुआ '
        'पढ़ती है।',
  ),
  TajikaYogaId.radda => const Bi(
    'The completion is spoiled: the tradition reads the matter as delayed '
        'or dampened.',
    'पूर्णता बिगड़ जाती है: परंपरा विषय को विलंबित या फीका पढ़ती है।',
  ),
  TajikaYogaId.duhphaliKuttha => const Bi(
    'The dignified slower graha lifts the weaker one: the matter is read '
        'as completing through the stronger party’s strength.',
    'बलवान मंदगामी ग्रह दुर्बल को उठाता है: विषय बलवान पक्ष के बल से पूर्ण '
        'होता पढ़ा जाता है।',
  ),
  TajikaYogaId.dutthotthaDavira => const Bi(
    'The matter is read as completing through another’s help rather than '
        'through the two lords’ own strength.',
    'विषय दोनों स्वामियों के अपने बल से नहीं बल्कि किसी और की सहायता से '
        'पूर्ण होता पढ़ा जाता है।',
  ),
};

// ---------------------------------------------------------------------------
// The year grid: where each graha is, hour by hour, through the year.
// ---------------------------------------------------------------------------

/// Sidereal longitudes of the seven grahas sampled across the year from the
/// annual chart's own moment. Daily samples serve every graha but the Moon,
/// which is sampled every six hours; positions in between are interpolated
/// along the shorter arc. It lets the engine say WHEN an Ittasala becomes
/// exact from the grahas' real motion rather than from a rule of thumb.
class YearGrid {
  YearGrid._(this.startJd, this.endJd, this._samples, this._steps);

  factory YearGrid.build(Kundli chart, double endJd) {
    final double start = chart.instant.julianDayUt;
    final Map<Graha, List<double>> samples = <Graha, List<double>>{};
    final Map<Graha, double> steps = <Graha, double>{};
    for (final Graha graha in tajikaGrahas) {
      final double step = graha == Graha.moon ? 0.25 : 1.0;
      final int count = ((endJd - start) / step).ceil() + 2;
      final List<double> values = List<double>.filled(count, 0);
      for (int i = 0; i < count; i++) {
        final Instant instant = Instant.fromJulianDayUt(start + i * step);
        values[i] = toSidereal(
          positionOf(graha, instant).tropicalLongitude,
          chart.ayanamsa,
          instant.centuriesTt,
        );
      }
      samples[graha] = values;
      steps[graha] = step;
    }
    return YearGrid._(start, endJd, samples, steps);
  }

  final double startJd;
  final double endJd;
  final Map<Graha, List<double>> _samples;
  final Map<Graha, double> _steps;

  double stepOf(Graha graha) => _steps[graha]!;

  /// Sidereal longitude of [graha] at [jd], by cubic (Catmull-Rom)
  /// interpolation through the four nearest samples, along the short arc.
  double lonAt(Graha graha, double jd) {
    final List<double> values = _samples[graha]!;
    final double step = _steps[graha]!;
    double x = (jd - startJd) / step;
    if (x < 0) x = 0;
    int i = x.floor();
    if (i > values.length - 2) i = values.length - 2;
    final double t = x - i;
    final double base = values[i];
    final double c = norm180(values[i + 1] - base);
    // At either end of the grid the missing neighbour is extrapolated along
    // the same line, so the first and last segments are as good as the rest.
    final double a = i > 0 ? norm180(values[i - 1] - base) : -c;
    final double d = i + 2 < values.length
        ? norm180(values[i + 2] - base)
        : 2 * c;
    final double offset =
        0.5 *
        ((c - a) * t +
            (2 * a + 4 * c - d) * t * t +
            (-a - 3 * c + d) * t * t * t);
    return norm360(base + offset);
  }
}

/// What next happens to an aspect, from the grahas' real motion.
enum TajikaEventKind {
  /// The two reach the same degree of their signs: the Ittasala completes.
  perfects,

  /// The pair drifts out of its shared orb.
  leavesOrb,

  /// One of them changes sign first, so the aspect lapses.
  signChange,
}

class TajikaEvent {
  const TajikaEvent(this.kind, this.jd);

  final TajikaEventKind kind;
  final double jd;

  DateTime get utc => utcFromJulianDay(jd);
}

double _bisect(double lo, double hi, bool Function(double) happened) {
  double a = lo;
  double b = hi;
  for (int i = 0; i < 40; i++) {
    final double mid = (a + b) / 2.0;
    if (happened(mid)) {
      b = mid;
    } else {
      a = mid;
    }
    if (b - a < 1e-5) break;
  }
  return b;
}

({int distance, double gap}) _pairState(
  YearGrid grid,
  Graha faster,
  Graha slower,
  double jd,
) {
  final double f = grid.lonAt(faster, jd);
  final double s = grid.lonAt(slower, jd);
  final int signF = (f / 30.0).floor() % 12;
  final int signS = (s / 30.0).floor() % 12;
  return (distance: signDistance(signF, signS), gap: (s % 30.0) - (f % 30.0));
}

/// The first thing that happens to the pair after the year chart: reaching
/// the exact degree, leaving the orb, or a sign change that ends the aspect.
TajikaEvent? _projectEvent(
  YearGrid grid,
  Graha faster,
  Graha slower,
  int distance0,
  double gap0,
  double orb,
) {
  final double step = math.min(grid.stepOf(faster), grid.stepOf(slower));
  final bool startedApplying = gap0 >= 0;
  double previous = grid.startJd;
  for (double jd = grid.startJd + step; jd <= grid.endJd + step; jd += step) {
    final double at = math.min(jd, grid.endJd);
    final ({int distance, double gap}) state = _pairState(
      grid,
      faster,
      slower,
      at,
    );
    if (state.distance != distance0) {
      final double when = _bisect(
        previous,
        at,
        (double t) => _pairState(grid, faster, slower, t).distance != distance0,
      );
      return TajikaEvent(TajikaEventKind.signChange, when);
    }
    final bool crossed = startedApplying ? state.gap < 0 : state.gap >= 0;
    if (crossed) {
      final double when = _bisect(previous, at, (double t) {
        final double g = _pairState(grid, faster, slower, t).gap;
        return startedApplying ? g < 0 : g >= 0;
      });
      return TajikaEvent(TajikaEventKind.perfects, when);
    }
    if (state.gap.abs() > orb) {
      final double when = _bisect(
        previous,
        at,
        (double t) => _pairState(grid, faster, slower, t).gap.abs() > orb,
      );
      return TajikaEvent(TajikaEventKind.leavesOrb, when);
    }
    previous = at;
    if (at >= grid.endJd) break;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Aspects between pairs.
// ---------------------------------------------------------------------------

/// An Ittasala or an Ishrafa between two grahas of the year chart.
class TajikaAspect {
  const TajikaAspect({
    required this.faster,
    required this.slower,
    required this.kind,
    required this.signAspect,
    required this.gap,
    required this.orb,
    required this.isExact,
    required this.event,
    required this.name,
    required this.reading,
    required this.factors,
  });

  final Graha faster;
  final Graha slower;

  /// [TajikaYogaId.ittasala] while applying, [TajikaYogaId.ishrafa] once the
  /// swifter graha has passed.
  final TajikaYogaId kind;
  final SignAspect signAspect;

  /// Degrees by which the swifter is behind (Ittasala) or past (Ishrafa) the
  /// slower, measured within the signs.
  final double gap;
  final double orb;

  /// An Ittasala closer than one arc-minute: the "purna" kind.
  final bool isExact;

  /// What the grahas' real motion does to the pair next, or null if nothing
  /// happens before the year ends.
  final TajikaEvent? event;
  final Bi name;
  final Bi reading;
  final List<Bi> factors;

  bool get isApplying => kind == TajikaYogaId.ittasala;
  bool involves(Graha graha) => faster == graha || slower == graha;
  AspectNature get nature => natureOf(signAspect);

  /// How far into its orb the pair is: 0 exact, 1 at the edge.
  double get closeness => gap.abs() / orb;
}

/// A yoga as it stands in this year chart, with its working.
class TajikaYoga {
  const TajikaYoga({
    required this.id,
    required this.grahas,
    required this.condition,
    required this.indicates,
    required this.factors,
    this.matterHouse,
  });

  final TajikaYogaId id;

  /// The grahas that make the yoga.
  final List<Graha> grahas;

  /// The house whose matter it concerns, when it is read for a matter.
  final int? matterHouse;
  final Bi condition;
  final Bi indicates;
  final List<Bi> factors;

  Bi get name => tajikaYogaName(id);
  YogaTone get tone => tajikaYogaTone(id);
}

/// What the Tajika yogas say about one house's matter: the pair of the lagna
/// lord and the lord of that house.
class TajikaMatter {
  const TajikaMatter({
    required this.house,
    required this.lagnesha,
    required this.karyesha,
    required this.yogas,
    required this.reading,
    required this.factors,
  });

  final int house;
  final Graha lagnesha;
  final Graha karyesha;
  final List<TajikaYoga> yogas;
  final Bi reading;
  final List<Bi> factors;

  Bi get theme => houseTheme(house);
}

class TajikaReport {
  const TajikaReport({
    required this.aspects,
    required this.chartYogas,
    required this.lagnesha,
    required this.matters,
  });

  /// Every Ittasala and Ishrafa among the seven grahas, closest first.
  final List<TajikaAspect> aspects;

  /// Ikkabala or Induvara when the year chart has one.
  final List<TajikaYoga> chartYogas;
  final Graha lagnesha;

  /// Houses 2 to 12 read against the lagna lord.
  final List<TajikaMatter> matters;

  TajikaAspect? aspectBetween(Graha a, Graha b) {
    for (final TajikaAspect aspect in aspects) {
      if (aspect.involves(a) && aspect.involves(b)) return aspect;
    }
    return null;
  }

  List<TajikaAspect> aspectsOf(Graha graha) => aspects
      .where((TajikaAspect a) => a.involves(graha))
      .toList(growable: false);

  /// Every yoga the report names, chart yogas first.
  List<TajikaYoga> get allYogas => <TajikaYoga>[
    ...chartYogas,
    for (final TajikaMatter m in matters) ...m.yogas,
  ];
}

Bi _linkSentence(Kundli chart, TajikaAspect a) {
  final Bi fast = grahaBi(a.faster);
  final Bi slow = grahaBi(a.slower);
  final Bi fastHouses = housesBi(housesRuledBy(chart, a.faster));
  final Bi slowHouses = housesBi(housesRuledBy(chart, a.slower));
  final String gapText = degText(a.gap);
  final String orbText = compactNumber(a.orb);
  final Bi aspect = signAspectBi(a.signAspect);
  if (a.isApplying) {
    final String friction = a.nature == AspectNature.inimical
        ? ' The aspect is an inimical one, so the tradition reads the '
              'completion as coming with friction.'
        : '';
    final String frictionHi = a.nature == AspectNature.inimical
        ? ' यह शत्रु दृष्टि है, इसलिए परंपरा पूर्णता को कुछ रगड़ के साथ पढ़ती है।'
        : '';
    return Bi(
      '${fast.en}, the swifter, is $gapText behind ${slow.en} within an '
          'orb of $orbText°, by ${aspect.en}: Ittasala (Muthashila). The '
          'tradition reads the matters of ${fast.en}’s ${fastHouses.en} and '
          '${slow.en}’s ${slowHouses.en} as drawing together toward '
          'completion.$friction',
      '${fast.hi}, शीघ्रगामी, ${slow.hi} से $gapText पीछे है, $orbText° दीप्तांश '
          'के भीतर, ${aspect.hi} से: इत्थशाल (मुत्थशिल)। परंपरा ${fast.hi} के '
          '${fastHouses.hi} और ${slow.hi} के ${slowHouses.hi} के विषयों को '
          'पूर्णता की ओर पास आता पढ़ती है।$frictionHi',
    );
  }
  return Bi(
    '${fast.en}, the swifter, has moved $gapText past ${slow.en} inside a '
        '$orbText° orb, by ${aspect.en}: Ishrafa (Mushariph). The tradition '
        'reads the matters of ${fast.en}’s ${fastHouses.en} and ${slow.en}’s '
        '${slowHouses.en} as past their peak and slipping away; effort is '
        'better placed elsewhere.',
    '${fast.hi}, शीघ्रगामी, ${slow.hi} से $gapText आगे निकल चुका है, $orbText° '
        'दीप्तांश के भीतर, ${aspect.hi} से: ईसराफ (मुशरिफ)। परंपरा ${fast.hi} के '
        '${fastHouses.hi} और ${slow.hi} के ${slowHouses.hi} के विषयों को अपने '
        'शिखर से उतरता और हाथ से निकलता पढ़ती है; प्रयास अन्यत्र लगाना बेहतर है।',
  );
}

List<TajikaAspect> _pairAspects(Kundli chart, YearGrid grid) {
  final List<TajikaAspect> out = <TajikaAspect>[];
  for (int i = 0; i < tajikaGrahas.length; i++) {
    for (int j = i + 1; j < tajikaGrahas.length; j++) {
      final Graha a = tajikaGrahas[i];
      final Graha b = tajikaGrahas[j];
      final Graha faster = isSwifter(a, b) ? a : b;
      final Graha slower = faster == a ? b : a;
      final PlacedGraha f = chart.grahas[faster]!;
      final PlacedGraha s = chart.grahas[slower]!;
      final SignAspect? signAspect = signAspectOf(
        signDistance(f.rashi.index, s.rashi.index),
      );
      if (signAspect == null) continue;
      final double gap = s.degreesInSign - f.degreesInSign;
      final double orb = meanOrb(faster, slower);
      if (gap.abs() > orb) continue;
      // A retrograde swifter graha does not apply (Hayanaratna 3.3).
      if (f.isRetrograde) continue;
      final TajikaYogaId kind = gap >= 0
          ? TajikaYogaId.ittasala
          : TajikaYogaId.ishrafa;
      final TajikaEvent? event = _projectEvent(
        grid,
        faster,
        slower,
        signDistance(f.rashi.index, s.rashi.index),
        gap,
        orb,
      );
      final TajikaAspect draft = TajikaAspect(
        faster: faster,
        slower: slower,
        kind: kind,
        signAspect: signAspect,
        gap: gap.abs(),
        orb: orb,
        isExact: kind == TajikaYogaId.ittasala && gap < 1.0 / 60.0,
        event: event,
        name: tajikaYogaName(kind),
        reading: const Bi('', ''),
        factors: <Bi>[
          Bi(
            '${grahaBi(faster).en} in ${rashiBi(f.rashi.index).en} '
                '${degText(f.degreesInSign)}, ${grahaBi(slower).en} in '
                '${rashiBi(s.rashi.index).en} ${degText(s.degreesInSign)}',
            '${grahaBi(faster).hi} ${rashiBi(f.rashi.index).hi} '
                '${degText(f.degreesInSign)} में, ${grahaBi(slower).hi} '
                '${rashiBi(s.rashi.index).hi} ${degText(s.degreesInSign)} में',
          ),
          Bi(
            'Signs are in a ${signAspectBi(signAspect).en}',
            'राशियों में ${signAspectBi(signAspect).hi} है',
          ),
          Bi(
            'Shared orb ${compactNumber(orb)}° = half of '
                '${compactNumber(deeptamsha[faster]!, decimals: 0)}° + '
                '${compactNumber(deeptamsha[slower]!, decimals: 0)}° deeptamsha; '
                'the gap is ${degText(gap.abs())}',
            'साझा दीप्तांश ${compactNumber(orb)}° = '
                '${compactNumber(deeptamsha[faster]!, decimals: 0)}° + '
                '${compactNumber(deeptamsha[slower]!, decimals: 0)}° का आधा; '
                'अंतर ${degText(gap.abs())} है',
          ),
          Bi(
            '${grahaBi(faster).en} is swifter than ${grahaBi(slower).en} in the '
                'Tajika order of speed',
            'ताजिक गति क्रम में ${grahaBi(faster).hi} ${grahaBi(slower).hi} से '
                'शीघ्रगामी है',
          ),
        ],
      );
      out.add(
        TajikaAspect(
          faster: draft.faster,
          slower: draft.slower,
          kind: draft.kind,
          signAspect: draft.signAspect,
          gap: draft.gap,
          orb: draft.orb,
          isExact: draft.isExact,
          event: draft.event,
          name: draft.name,
          reading: _linkSentence(chart, draft),
          factors: draft.factors,
        ),
      );
    }
  }
  out.sort(
    (TajikaAspect a, TajikaAspect b) => a.closeness.compareTo(b.closeness),
  );
  return out;
}

// ---------------------------------------------------------------------------
// Yogas.
// ---------------------------------------------------------------------------

bool _hasDignity(PlacedGraha g, {required bool isDay}) {
  switch (g.dignity) {
    case Dignity.exalted:
    case Dignity.moolatrikona:
    case Dignity.own:
      return true;
    case Dignity.friend:
    case Dignity.neutral:
    case Dignity.enemy:
    case Dignity.debilitated:
      return trirashiLordOf(g.rashi.index, isDay: isDay) == g.graha;
  }
}

bool _isStrongInSign(PlacedGraha g) =>
    g.dignity == Dignity.exalted ||
    g.dignity == Dignity.moolatrikona ||
    g.dignity == Dignity.own;

/// Superior, middling, neutral or inferior, as Hayanaratna 3.8 grades a
/// graha for the Kamboola.
Bi _gradeBi(Kundli chart, Graha graha) {
  final PlacedGraha g = chart.grahas[graha]!;
  if (_isStrongInSign(g)) return const Bi('superior', 'उत्तम');
  if (g.dignity == Dignity.debilitated || g.dignity == Dignity.enemy) {
    return const Bi('inferior', 'अधम');
  }
  final double lon = g.siderealLongitude;
  if (haddaLordOf(lon) == graha ||
      drekkanaLordOf(lon) == graha ||
      navamshaLordOf(lon) == graha) {
    return const Bi('middling', 'मध्यम');
  }
  return const Bi('neutral', 'सम');
}

Bi _placementBi(Kundli chart, Graha graha) {
  final PlacedGraha g = chart.grahas[graha]!;
  return Bi(
    '${grahaBi(graha).en} in ${rashiBi(g.rashi.index).en}, '
        '${houseBi(g.house).en}',
    '${grahaBi(graha).hi} ${rashiBi(g.rashi.index).hi} में, '
        '${houseBi(g.house).hi}',
  );
}

class _Yogas {
  _Yogas(this.chart, this.bala, this.aspects, {required this.isDay})
    : lagnesha = houseLord(chart, 1);

  final Kundli chart;
  final Map<Graha, PanchaVargiyaBala> bala;
  final List<TajikaAspect> aspects;
  final bool isDay;
  final Graha lagnesha;

  TajikaAspect? between(Graha a, Graha b) {
    for (final TajikaAspect t in aspects) {
      if (t.involves(a) && t.involves(b)) return t;
    }
    return null;
  }

  PlacedGraha at(Graha g) => chart.grahas[g]!;

  bool hasSignAspect(Graha a, Graha b) =>
      signAspectOf(signDistance(at(a).rashi.index, at(b).rashi.index)) != null;

  TajikaYoga build(
    TajikaYogaId id,
    List<Graha> grahas,
    List<Bi> factors, {
    int? house,
  }) => TajikaYoga(
    id: id,
    grahas: grahas,
    condition: tajikaYogaCondition(id),
    indicates: tajikaYogaIndicates(id),
    factors: factors,
    matterHouse: house,
  );

  /// Ikkabala and Induvara, which belong to the whole chart.
  List<TajikaYoga> chartYogas() {
    final List<int> houses = tajikaGrahas
        .map((Graha g) => at(g).house)
        .toList(growable: false);
    final bool allActive = houses.every(
      (int h) => const <int>[1, 2, 4, 5, 7, 8, 10, 11].contains(h),
    );
    final bool allCadent = houses.every(
      (int h) => const <int>[3, 6, 9, 12].contains(h),
    );
    final Bi where = Bi(
      'Houses of the seven grahas: ${houses.join(', ')}',
      'सातों ग्रहों के भाव: ${houses.join(', ')}',
    );
    return <TajikaYoga>[
      if (allActive) build(TajikaYogaId.ikkabala, tajikaGrahas, <Bi>[where]),
      if (allCadent) build(TajikaYogaId.induvara, tajikaGrahas, <Bi>[where]),
    ];
  }

  List<TajikaYoga> forMatter(int house) {
    final Graha karyesha = houseLord(chart, house);
    final Graha lord = lagnesha;
    if (karyesha == lord) return const <TajikaYoga>[];
    final List<TajikaYoga> out = <TajikaYoga>[];
    final List<Bi> pairFactors = <Bi>[
      Bi(
        'Lagna lord: ${_placementBi(chart, lord).en}',
        'लग्नेश: ${_placementBi(chart, lord).hi}',
      ),
      Bi(
        'Lord of ${houseBi(house).en}: ${_placementBi(chart, karyesha).en}',
        '${houseBi(house).hi} का स्वामी: ${_placementBi(chart, karyesha).hi}',
      ),
    ];
    final TajikaAspect? pair = between(lord, karyesha);
    final Graha moon = Graha.moon;
    final bool moonIsPair = lord == moon || karyesha == moon;

    if (pair != null && pair.isApplying) {
      out.add(
        build(
          TajikaYogaId.ittasala,
          <Graha>[lord, karyesha],
          <Bi>[...pairFactors, ...pair.factors],
          house: house,
        ),
      );
      // Radda: a participant is retrograde, combust or in 6/8/12.
      final List<Bi> spoilers = <Bi>[];
      for (final Graha g in <Graha>[pair.faster, pair.slower]) {
        final PlacedGraha p = at(g);
        if (p.isRetrograde) {
          spoilers.add(
            Bi('${grahaBi(g).en} is retrograde', '${grahaBi(g).hi} वक्री है'),
          );
        }
        if (p.isCombust) {
          spoilers.add(
            Bi('${grahaBi(g).en} is combust', '${grahaBi(g).hi} अस्त है'),
          );
        }
        if (const <int>[6, 8, 12].contains(p.house)) {
          spoilers.add(
            Bi(
              '${grahaBi(g).en} is in ${houseBi(p.house).en}',
              '${grahaBi(g).hi} ${houseBi(p.house).hi} में है',
            ),
          );
        }
      }
      if (spoilers.isNotEmpty) {
        out.add(
          build(
            TajikaYogaId.radda,
            <Graha>[lord, karyesha],
            spoilers,
            house: house,
          ),
        );
      }
      // Kamboola: the Moon joins the Ittasala.
      if (!moonIsPair) {
        final TajikaAspect? withLord = between(moon, lord);
        final TajikaAspect? withKaryesha = between(moon, karyesha);
        final bool moonApplies =
            (withLord != null && withLord.isApplying) ||
            (withKaryesha != null && withKaryesha.isApplying);
        if (moonApplies) {
          out.add(
            build(
              TajikaYogaId.kamboola,
              <Graha>[moon, lord, karyesha],
              <Bi>[
                Bi(
                  'Moon in Ittasala with '
                      '${<String>[if (withLord != null && withLord.isApplying) grahaBi(lord).en, if (withKaryesha != null && withKaryesha.isApplying) grahaBi(karyesha).en].join(' and ')}',
                  'चंद्र का इत्थशाल '
                      '${<String>[if (withLord != null && withLord.isApplying) grahaBi(lord).hi, if (withKaryesha != null && withKaryesha.isApplying) grahaBi(karyesha).hi].join(' और ')} से है',
                ),
                Bi(
                  'Dignity grade: Moon ${_gradeBi(chart, moon).en}, '
                      '${grahaBi(lord).en} ${_gradeBi(chart, lord).en}, '
                      '${grahaBi(karyesha).en} ${_gradeBi(chart, karyesha).en}',
                  'गरिमा श्रेणी: चंद्र ${_gradeBi(chart, moon).hi}, '
                      '${grahaBi(lord).hi} ${_gradeBi(chart, lord).hi}, '
                      '${grahaBi(karyesha).hi} ${_gradeBi(chart, karyesha).hi}',
                ),
              ],
              house: house,
            ),
          );
        }
      }
      // Manau: Mars or Saturn takes the swifter graha's light.
      for (final Graha m in <Graha>[Graha.mars, Graha.saturn]) {
        if (m == pair.faster || m == pair.slower) continue;
        final int distance = signDistance(
          at(m).rashi.index,
          at(pair.faster).rashi.index,
        );
        if (!const <int>[1, 4, 7, 10].contains(distance)) continue;
        final double reach =
            (at(m).degreesInSign - at(pair.faster).degreesInSign).abs();
        if (reach <= deeptamsha[m]!) {
          out.add(
            build(
              TajikaYogaId.manau,
              <Graha>[m, pair.faster],
              <Bi>[
                Bi(
                  '${grahaBi(m).en} is ${degText(reach)} from '
                      '${grahaBi(pair.faster).en}, inside its own '
                      '${compactNumber(deeptamsha[m]!, decimals: 0)}° deeptamsha, '
                      'in an inimical aspect',
                  '${grahaBi(m).hi} ${grahaBi(pair.faster).hi} से ${degText(reach)} '
                      'पर है, अपने ${compactNumber(deeptamsha[m]!, decimals: 0)}° '
                      'दीप्तांश के भीतर, शत्रु दृष्टि में',
                ),
              ],
              house: house,
            ),
          );
        }
      }
      // Duhphali-kuttha: a dignified slower graha, a swifter with none.
      final PlacedGraha slow = at(pair.slower);
      final PlacedGraha fast = at(pair.faster);
      if (_hasDignity(slow, isDay: isDay) && !_hasDignity(fast, isDay: isDay)) {
        out.add(
          build(
            TajikaYogaId.duhphaliKuttha,
            <Graha>[pair.faster, pair.slower],
            <Bi>[
              Bi(
                '${grahaBi(pair.slower).en} (slower) holds '
                    '${_dignityWord(slow).en}; ${grahaBi(pair.faster).en} '
                    '(swifter) holds none',
                '${grahaBi(pair.slower).hi} (मंदगामी) के पास ${_dignityWord(slow).hi} है; '
                    '${grahaBi(pair.faster).hi} (शीघ्रगामी) के पास कुछ नहीं',
              ),
            ],
            house: house,
          ),
        );
      }
    } else if (pair != null) {
      out.add(
        build(
          TajikaYogaId.ishrafa,
          <Graha>[lord, karyesha],
          <Bi>[...pairFactors, ...pair.factors],
          house: house,
        ),
      );
    } else {
      // No aspect between the two: look for a go-between.
      out.addAll(_goBetweens(lord, karyesha, pairFactors, house));
    }

    // Khallasara: the Moon is with neither lord.
    if (!moonIsPair) {
      final TajikaAspect? withLord = between(moon, lord);
      final TajikaAspect? withKaryesha = between(moon, karyesha);
      final bool moonApplies =
          (withLord != null && withLord.isApplying) ||
          (withKaryesha != null && withKaryesha.isApplying);
      final bool moonWithConjunct =
          at(moon).rashi == at(lord).rashi ||
          at(moon).rashi == at(karyesha).rashi;
      if (!moonApplies && !moonWithConjunct) {
        out.add(
          build(
            TajikaYogaId.khallasara,
            <Graha>[moon, lord, karyesha],
            <Bi>[
              Bi(
                'Moon in ${rashiBi(at(moon).rashi.index).en} '
                    '${degText(at(moon).degreesInSign)}: no Ittasala and no '
                    'conjunction with ${grahaBi(lord).en} or '
                    '${grahaBi(karyesha).en}',
                'चंद्र ${rashiBi(at(moon).rashi.index).hi} '
                    '${degText(at(moon).degreesInSign)} में: '
                    '${grahaBi(lord).hi} या ${grahaBi(karyesha).hi} से न '
                    'इत्थशाल, न युति',
              ),
            ],
            house: house,
          ),
        );
      }
    }

    // Dutthottha-davira: both weak, helped by a strong third.
    final double lordVishwa = bala[lord]!.vishwa;
    final double karyeshaVishwa = bala[karyesha]!.vishwa;
    if (lordVishwa < 10 && karyeshaVishwa < 10) {
      for (final Graha third in tajikaGrahas) {
        if (third == lord || third == karyesha) continue;
        if (!_isStrongInSign(at(third))) continue;
        final TajikaAspect? a = between(lord, third);
        final TajikaAspect? b = between(karyesha, third);
        if (a != null && a.isApplying && b != null && b.isApplying) {
          out.add(
            build(
              TajikaYogaId.dutthotthaDavira,
              <Graha>[lord, karyesha, third],
              <Bi>[
                Bi(
                  '${grahaBi(lord).en} ${compactNumber(lordVishwa)} and '
                      '${grahaBi(karyesha).en} ${compactNumber(karyeshaVishwa)} '
                      'vishwa, both under 10',
                  '${grahaBi(lord).hi} ${compactNumber(lordVishwa)} और '
                      '${grahaBi(karyesha).hi} ${compactNumber(karyeshaVishwa)} '
                      'विश्वा, दोनों 10 से कम',
                ),
                Bi(
                  '${grahaBi(third).en} holds ${_dignityWord(at(third)).en} and is '
                      'in Ittasala with both',
                  '${grahaBi(third).hi} के पास ${_dignityWord(at(third)).hi} है और वह '
                      'दोनों से इत्थशाल में है',
                ),
              ],
              house: house,
            ),
          );
          break;
        }
      }
    }
    return out;
  }

  /// Nakta and Yamaya: a third graha carries the light between two that are
  /// not in aspect, measured by the third graha's own deeptamsha.
  List<TajikaYoga> _goBetweens(
    Graha lord,
    Graha karyesha,
    List<Bi> pairFactors,
    int house,
  ) {
    final List<TajikaYoga> out = <TajikaYoga>[];
    final double lordDeg = at(lord).degreesInSign;
    final double karyeshaDeg = at(karyesha).degreesInSign;
    final Graha rear = lordDeg <= karyeshaDeg ? lord : karyesha;
    final Graha front = rear == lord ? karyesha : lord;
    final double rearDeg = at(rear).degreesInSign;
    final double frontDeg = at(front).degreesInSign;
    for (final Graha third in tajikaGrahas) {
      if (third == lord || third == karyesha) continue;
      final PlacedGraha t = at(third);
      if (!hasSignAspect(third, lord) || !hasSignAspect(third, karyesha)) {
        continue;
      }
      final double reach = deeptamsha[third]!;
      if (isSwifter(third, lord) && isSwifter(third, karyesha)) {
        if (t.isRetrograde) continue;
        final double d = t.degreesInSign;
        if (d >= rearDeg &&
            d <= frontDeg &&
            frontDeg - d <= reach &&
            d - rearDeg <= reach) {
          out.add(
            build(
              TajikaYogaId.nakta,
              <Graha>[lord, third, karyesha],
              <Bi>[
                ...pairFactors,
                Bi(
                  '${grahaBi(third).en} at ${degText(d)} is swifter than both and '
                      'stands between ${grahaBi(rear).en} (${degText(rearDeg)}) '
                      'and ${grahaBi(front).en} (${degText(frontDeg)}), within its '
                      'own ${compactNumber(reach, decimals: 0)}° deeptamsha of each',
                  '${grahaBi(third).hi} ${degText(d)} पर दोनों से शीघ्रगामी है और '
                      '${grahaBi(rear).hi} (${degText(rearDeg)}) तथा '
                      '${grahaBi(front).hi} (${degText(frontDeg)}) के बीच है, '
                      'अपने ${compactNumber(reach, decimals: 0)}° दीप्तांश के भीतर',
                ),
              ],
              house: house,
            ),
          );
        }
      } else if (isSwifter(lord, third) && isSwifter(karyesha, third)) {
        if (at(lord).isRetrograde || at(karyesha).isRetrograde) continue;
        final double d = t.degreesInSign;
        if (d >= lordDeg &&
            d >= karyeshaDeg &&
            d - lordDeg <= reach &&
            d - karyeshaDeg <= reach) {
          out.add(
            build(
              TajikaYogaId.yamaya,
              <Graha>[lord, third, karyesha],
              <Bi>[
                ...pairFactors,
                Bi(
                  '${grahaBi(third).en} at ${degText(d)} is slower than both and '
                      'ahead of both, within its own '
                      '${compactNumber(reach, decimals: 0)}° deeptamsha of each',
                  '${grahaBi(third).hi} ${degText(d)} पर दोनों से मंदगामी और '
                      'दोनों से आगे है, अपने ${compactNumber(reach, decimals: 0)}° '
                      'दीप्तांश के भीतर',
                ),
              ],
              house: house,
            ),
          );
        }
      }
    }
    return out;
  }
}

Bi _dignityWord(PlacedGraha g) => switch (g.dignity) {
  Dignity.exalted => const Bi('exaltation', 'उच्च राशि'),
  Dignity.moolatrikona => const Bi('moolatrikona', 'मूलत्रिकोण'),
  Dignity.own => const Bi('its own sign', 'स्वराशि'),
  _ => const Bi('its own triplicity', 'अपनी त्रिराशि'),
};

Bi _matterReading(Kundli chart, int house, List<TajikaYoga> yogas) {
  final Bi theme = houseTheme(house);
  final Graha lagnesha = houseLord(chart, 1);
  final Graha karyesha = houseLord(chart, house);
  if (lagnesha == karyesha) {
    return Bi(
      '${grahaBi(lagnesha).en} is both the lagna lord and the lord of '
          '${houseBi(house).en} (${theme.en}), so there is no pair of lords '
          'to read for this matter.',
      '${grahaBi(lagnesha).hi} लग्नेश भी है और ${houseBi(house).hi} '
          '(${theme.hi}) का स्वामी भी, इसलिए इस विषय में पढ़ने के लिए '
          'स्वामियों का जोड़ा नहीं है।',
    );
  }
  if (yogas.isEmpty) {
    return Bi(
      'No Tajika yoga forms between the lagna lord and the lord of '
          '${houseBi(house).en} (${theme.en}); the year chart says nothing '
          'special about this matter.',
      'लग्नेश और ${houseBi(house).hi} के स्वामी (${theme.hi}) के बीच कोई ताजिक '
          'योग नहीं बनता; वर्ष कुंडली इस विषय पर कुछ विशेष नहीं कहती।',
    );
  }
  final Bi names = Bi(
    yogas.map((TajikaYoga y) => y.name.en).join(', '),
    yogas.map((TajikaYoga y) => y.name.hi).join(', '),
  );
  return Bi(
    '${houseBi(house).en} (${theme.en}): $names. '
        '${yogas.map((TajikaYoga y) => y.indicates.en).join(' ')}',
    '${houseBi(house).hi} (${theme.hi}): ${names.hi}। '
        '${yogas.map((TajikaYoga y) => y.indicates.hi).join(' ')}',
  );
}

/// Reads the Tajika aspects and yogas of the year chart [chart].
///
/// [bala] is the five-fold strength of its grahas, [grid] the year's real
/// motion from the chart onwards, and [isDay] whether the chart was cast by
/// day (it chooses the triplicity ruler Duhphali-kuttha looks at).
TajikaReport computeTajika(
  Kundli chart,
  Map<Graha, PanchaVargiyaBala> bala,
  YearGrid grid, {
  required bool isDay,
}) {
  final List<TajikaAspect> aspects = _pairAspects(chart, grid);
  final _Yogas yogas = _Yogas(chart, bala, aspects, isDay: isDay);
  final List<TajikaMatter> matters = <TajikaMatter>[];
  for (int house = 2; house <= 12; house++) {
    final List<TajikaYoga> list = yogas.forMatter(house);
    matters.add(
      TajikaMatter(
        house: house,
        lagnesha: yogas.lagnesha,
        karyesha: houseLord(chart, house),
        yogas: list,
        reading: _matterReading(chart, house, list),
        factors: <Bi>[
          Bi(
            'Lagna lord ${grahaBi(yogas.lagnesha).en} with the lord of '
                '${houseBi(house).en}, ${grahaBi(houseLord(chart, house)).en}',
            'लग्नेश ${grahaBi(yogas.lagnesha).hi} और ${houseBi(house).hi} '
                'के स्वामी ${grahaBi(houseLord(chart, house)).hi}',
          ),
        ],
      ),
    );
  }
  return TajikaReport(
    aspects: aspects,
    chartYogas: yogas.chartYogas(),
    lagnesha: yogas.lagnesha,
    matters: matters,
  );
}
