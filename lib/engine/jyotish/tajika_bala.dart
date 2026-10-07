import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';
import 'tajika_common.dart';
import 'varga.dart';

/// Pancha-vargiya bala, the five-fold strength of Tajika.
///
/// Five divisions of the zodiac each give a graha a share of a fixed total,
/// and the total is quartered into twenty "vishwa" (vishopaka). The weights
/// are those of Tajika Neelakanthi, Samjnatantra 1.39 (as printed with
/// Mahidhara's Hindi commentary on Sanskrit Wikisource):
///
///   griha (own sign) 30, uchcha (exaltation) 20, hadda (term) 15,
///   drekkana (decan) 10, navamsha (ninth part) 5; the sum, at most 80, is
///   divided by four.
///
/// The same weights are given by Balabhadra's Hayanaratna, 2.5. A graha that
/// is the lord of the division it stands in takes the whole weight; a friend
/// of the lord three quarters, a neutral half, an enemy a quarter
/// (Neelakanthi 1.40; Hayanaratna 2.5).
///
/// Variants worth knowing:
///  * PyJHora grades friend/neutral/enemy by the Parashari natural
///    friendship table and, for hadda, drekkana and navamsha, gives friends
///    half and enemies a quarter. The app follows the Tajika positional
///    friendship the texts themselves describe (see [tajikaRelation]).
///  * The drekkana here is the Tajika (Chaldean) decan, not the Parashari one.

/// The five components, in the order the texts list them.
enum PvDivision { griha, uchcha, hadda, drekkana, navamsha }

const Map<PvDivision, double> pvWeight = <PvDivision, double>{
  PvDivision.griha: 30,
  PvDivision.uchcha: 20,
  PvDivision.hadda: 15,
  PvDivision.drekkana: 10,
  PvDivision.navamsha: 5,
};

const Map<PvRelation, double> pvFraction = <PvRelation, double>{
  PvRelation.own: 1.0,
  PvRelation.friend: 0.75,
  PvRelation.neutral: 0.5,
  PvRelation.enemy: 0.25,
};

/// One of the five components, with the division lord that decided it.
class PvComponent {
  const PvComponent({
    required this.division,
    required this.points,
    required this.max,
    this.divisionLord,
    this.relation,
  });

  final PvDivision division;
  final double points;
  final double max;

  /// The lord of the sign, hadda, decan or navamsha the graha stands in.
  /// Null for uchcha, which is measured by distance, not by a lord.
  final Graha? divisionLord;

  /// How the graha stands to that lord. Null for uchcha.
  final PvRelation? relation;
}

/// How much work a graha can do on its vishwa count (Hayanaratna 2.5: under
/// five powerless, five to ten weak, ten to fifteen middling, above that
/// excellent).
enum PvBand { powerless, weak, middling, excellent }

class PanchaVargiyaBala {
  const PanchaVargiyaBala({
    required this.graha,
    required this.griha,
    required this.uchcha,
    required this.hadda,
    required this.drekkana,
    required this.navamsha,
  });

  final Graha graha;
  final PvComponent griha;
  final PvComponent uchcha;
  final PvComponent hadda;
  final PvComponent drekkana;
  final PvComponent navamsha;

  List<PvComponent> get components => <PvComponent>[
    griha,
    uchcha,
    hadda,
    drekkana,
    navamsha,
  ];

  /// The sum of the five components, out of 80.
  double get total =>
      griha.points +
      uchcha.points +
      hadda.points +
      drekkana.points +
      navamsha.points;

  /// The total quartered: vishwa out of 20.
  double get vishwa => total / 4.0;

  PvBand get band {
    final double v = vishwa;
    if (v < 5) return PvBand.powerless;
    if (v < 10) return PvBand.weak;
    if (v < 15) return PvBand.middling;
    return PvBand.excellent;
  }
}

Bi pvBandBi(PvBand band) => switch (band) {
  PvBand.powerless => const Bi('powerless', 'निर्बल'),
  PvBand.weak => const Bi('weak', 'दुर्बल'),
  PvBand.middling => const Bi('middling', 'मध्यम'),
  PvBand.excellent => const Bi('excellent', 'उत्तम'),
};

Bi pvDivisionBi(PvDivision division) => switch (division) {
  PvDivision.griha => const Bi('Griha', 'गृह'),
  PvDivision.uchcha => const Bi('Uchcha', 'उच्च'),
  PvDivision.hadda => const Bi('Hadda', 'हद्दा'),
  PvDivision.drekkana => const Bi('Drekkana', 'द्रेष्काण'),
  PvDivision.navamsha => const Bi('Navamsha', 'नवांश'),
};

Bi pvRelationBi(PvRelation relation) => switch (relation) {
  PvRelation.own => const Bi('own', 'स्व'),
  PvRelation.friend => const Bi('friend', 'मित्र'),
  PvRelation.neutral => const Bi('neutral', 'सम'),
  PvRelation.enemy => const Bi('enemy', 'शत्रु'),
};

/// The hadda (term) of Tajika, as printed in Neelakanthi 1.33-38 and in
/// Hayanaratna 2.5. Each row gives the degree at which each lord's term ENDS,
/// so Mesha reads Jupiter to 6°, Venus to 12°, Mercury to 20°, Mars to 25°
/// and Saturn to 30°.
///
/// This is the Egyptian scheme with two lords transposed in Mithuna (Venus
/// before Jupiter) and in Dhanu (Mars before Saturn), which is how the Tajika
/// books print it; the Ptolemaic and the Jataka tables differ.
const List<List<(double, Graha)>> haddaTable = <List<(double, Graha)>>[
  // Mesha
  <(double, Graha)>[
    (6, Graha.jupiter),
    (12, Graha.venus),
    (20, Graha.mercury),
    (25, Graha.mars),
    (30, Graha.saturn),
  ],
  // Vrishabha
  <(double, Graha)>[
    (8, Graha.venus),
    (14, Graha.mercury),
    (22, Graha.jupiter),
    (27, Graha.saturn),
    (30, Graha.mars),
  ],
  // Mithuna
  <(double, Graha)>[
    (6, Graha.mercury),
    (12, Graha.venus),
    (17, Graha.jupiter),
    (24, Graha.mars),
    (30, Graha.saturn),
  ],
  // Karka
  <(double, Graha)>[
    (7, Graha.mars),
    (13, Graha.venus),
    (19, Graha.mercury),
    (26, Graha.jupiter),
    (30, Graha.saturn),
  ],
  // Simha
  <(double, Graha)>[
    (6, Graha.jupiter),
    (11, Graha.venus),
    (18, Graha.saturn),
    (24, Graha.mercury),
    (30, Graha.mars),
  ],
  // Kanya
  <(double, Graha)>[
    (7, Graha.mercury),
    (17, Graha.venus),
    (21, Graha.jupiter),
    (28, Graha.mars),
    (30, Graha.saturn),
  ],
  // Tula
  <(double, Graha)>[
    (6, Graha.saturn),
    (14, Graha.mercury),
    (21, Graha.jupiter),
    (28, Graha.venus),
    (30, Graha.mars),
  ],
  // Vrischika
  <(double, Graha)>[
    (7, Graha.mars),
    (11, Graha.venus),
    (19, Graha.mercury),
    (24, Graha.jupiter),
    (30, Graha.saturn),
  ],
  // Dhanu
  <(double, Graha)>[
    (12, Graha.jupiter),
    (17, Graha.venus),
    (21, Graha.mercury),
    (26, Graha.mars),
    (30, Graha.saturn),
  ],
  // Makara
  <(double, Graha)>[
    (7, Graha.mercury),
    (14, Graha.jupiter),
    (22, Graha.venus),
    (26, Graha.saturn),
    (30, Graha.mars),
  ],
  // Kumbha
  <(double, Graha)>[
    (7, Graha.mercury),
    (13, Graha.venus),
    (20, Graha.jupiter),
    (25, Graha.mars),
    (30, Graha.saturn),
  ],
  // Meena
  <(double, Graha)>[
    (12, Graha.venus),
    (16, Graha.jupiter),
    (19, Graha.mercury),
    (28, Graha.mars),
    (30, Graha.saturn),
  ],
];

/// The hadda lord of a longitude.
Graha haddaLordOf(double siderealLongitude) {
  final int sign = (siderealLongitude / 30.0).floor() % 12;
  final double degree = siderealLongitude % 30.0;
  for (final (double end, Graha lord) in haddaTable[sign]) {
    if (degree < end) return lord;
  }
  return haddaTable[sign].last.$2;
}

/// The Tajika decan lord of a longitude.
///
/// The thirty-six decans run through the planets in the weekday order taking
/// every sixth in turn, beginning with Mars at 0° Mesha: Mars, Sun, Venus,
/// Mercury, Moon, Saturn, Jupiter, and round again. Mesha therefore reads Mars,
/// Sun, Venus (Hayanaratna 2.5; the counting rule is in Mahidhara's
/// commentary on Neelakanthi 1.42).
Graha drekkanaLordOf(double siderealLongitude) {
  const List<Graha> weekdayOrder = <Graha>[
    Graha.sun,
    Graha.moon,
    Graha.mars,
    Graha.mercury,
    Graha.jupiter,
    Graha.venus,
    Graha.saturn,
  ];
  final int sign = (siderealLongitude / 30.0).floor() % 12;
  final int decan = ((siderealLongitude % 30.0) / 10.0).floor().clamp(0, 2);
  final int index = sign * 3 + decan;
  return weekdayOrder[(2 + 5 * index) % 7];
}

/// The lord of the navamsha sign a longitude falls in.
Graha navamshaLordOf(double siderealLongitude) =>
    rashiInfo(Rashi.values[vargaSign(Varga.d9, siderealLongitude)]).lord;

PvComponent _shared(
  Kundli chart,
  Graha graha,
  PvDivision division,
  Graha lord,
) {
  final PvRelation relation = tajikaRelation(chart, graha, lord);
  final double max = pvWeight[division]!;
  return PvComponent(
    division: division,
    points: max * pvFraction[relation]!,
    max: max,
    divisionLord: lord,
    relation: relation,
  );
}

PvComponent _uchcha(Graha graha, double longitude) {
  final double debilitation = norm360(
    grahaInfo(graha).exaltationDegree! + 180.0,
  );
  final double arc = norm180(longitude - debilitation).abs();
  const double max = 20.0;
  return PvComponent(
    division: PvDivision.uchcha,
    points: arc / 180.0 * max,
    max: max,
  );
}

/// The five-fold strength of the seven grahas in [chart].
Map<Graha, PanchaVargiyaBala> computePanchaVargiyaBala(Kundli chart) {
  final Map<Graha, PanchaVargiyaBala> out = <Graha, PanchaVargiyaBala>{};
  for (final Graha graha in tajikaGrahas) {
    final double longitude = chart.grahas[graha]!.siderealLongitude;
    final Graha signLord = rashiInfo(rashiOf(longitude)).lord;
    out[graha] = PanchaVargiyaBala(
      graha: graha,
      griha: _shared(chart, graha, PvDivision.griha, signLord),
      uchcha: _uchcha(graha, longitude),
      hadda: _shared(chart, graha, PvDivision.hadda, haddaLordOf(longitude)),
      drekkana: _shared(
        chart,
        graha,
        PvDivision.drekkana,
        drekkanaLordOf(longitude),
      ),
      navamsha: _shared(
        chart,
        graha,
        PvDivision.navamsha,
        navamshaLordOf(longitude),
      ),
    );
  }
  return out;
}

/// The tri-rashi pati of a sign: the lord of its triplicity by day or by
/// night. The triplicities are the fire, earth, air and water signs; the day
/// and night rulers are Sun and Jupiter, Venus and Moon, Saturn and Mercury,
/// Venus and Mars (Hayanaratna 5.7). The third, participating, ruler of each
/// triplicity (Saturn, Mars, Jupiter, Moon) is not used: the Tajika books give
/// the year to the day lord by day and the night lord by night.
Graha trirashiLordOf(int sign, {required bool isDay}) {
  switch (sign % 4) {
    case 0:
      return isDay ? Graha.sun : Graha.jupiter;
    case 1:
      return isDay ? Graha.venus : Graha.moon;
    case 2:
      return isDay ? Graha.saturn : Graha.mercury;
    default:
      return isDay ? Graha.venus : Graha.mars;
  }
}
