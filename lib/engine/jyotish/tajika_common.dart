import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';

/// A line of text in both languages. Every reading, factor and name the
/// varshphal engine produces is one of these, so the screen never has to
/// translate and a test can check that neither language is ever empty.
class Bi {
  const Bi(this.en, this.hi);

  final String en;
  final String hi;

  String of(bool hindi) => hindi ? hi : en;

  bool get isComplete => en.trim().isNotEmpty && hi.trim().isNotEmpty;

  /// Joins two lines with a space, language by language.
  Bi operator +(Bi other) => Bi('$en ${other.en}', '$hi ${other.hi}');

  @override
  String toString() => en;
}

/// Joins several lines into one paragraph, skipping the empty ones.
Bi joinBi(Iterable<Bi> parts, {String separator = ' '}) {
  final List<Bi> kept = parts
      .where((Bi b) => b.en.isNotEmpty || b.hi.isNotEmpty)
      .toList(growable: false);
  return Bi(
    kept.map((Bi b) => b.en).join(separator),
    kept.map((Bi b) => b.hi).join(separator),
  );
}

/// The seven grahas Tajika works with. Rahu and Ketu take no part in its
/// aspects, yogas, five-fold strength or sahams.
const List<Graha> tajikaGrahas = <Graha>[
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

/// The fixed order of speed the Tajika texts use to say which graha is the
/// swifter of two: the Moon, then Mercury, Venus, the Sun, Mars, Jupiter and
/// Saturn. It is a ranking, not a measurement, so a retrograde Mars is still
/// slower than the Sun.
const List<Graha> tajikaSpeedOrder = <Graha>[
  Graha.moon,
  Graha.mercury,
  Graha.venus,
  Graha.sun,
  Graha.mars,
  Graha.jupiter,
  Graha.saturn,
];

/// True when [a] is the swifter of the two in the Tajika ranking.
bool isSwifter(Graha a, Graha b) =>
    tajikaSpeedOrder.indexOf(a) < tajikaSpeedOrder.indexOf(b);

Bi grahaBi(Graha graha) {
  final GrahaInfo info = grahaInfo(graha);
  return Bi(info.english, info.hindi);
}

Bi rashiBi(int sign) {
  final RashiInfo info = rashiInfo(Rashi.values[sign % 12]);
  return Bi(info.english, info.hindi);
}

const List<String> _hindiOrdinals = <String>[
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
];

/// "house 4" and "चतुर्थ भाव".
Bi houseBi(int house) =>
    Bi('house $house', '${_hindiOrdinals[(house - 1) % 12]} भाव');

/// "houses 1 and 8" and "प्रथम व अष्टम भाव".
Bi housesBi(List<int> houses) {
  if (houses.isEmpty) return const Bi('no house', 'कोई भाव नहीं');
  if (houses.length == 1) return houseBi(houses.first);
  final List<String> hi = houses
      .map((int h) => _hindiOrdinals[(h - 1) % 12])
      .toList(growable: false);
  return Bi('houses ${houses.join(' and ')}', '${hi.join(' व ')} भाव');
}

/// What each house is read for. Worded to describe a field of life, never an
/// event, and kept free of anything the app does not make statements about.
const List<Bi> houseThemes = <Bi>[
  Bi('the body and the year’s own direction', 'शरीर और वर्ष की दिशा'),
  Bi('money kept and what is said', 'धन और वाणी'),
  Bi('courage, siblings and short journeys', 'पराक्रम और भाई-बहन'),
  Bi('home, land and the mother', 'घर, भूमि और माता'),
  Bi('children, learning and what is created', 'संतान और विद्या'),
  Bi('rivals, debt and daily service', 'प्रतिस्पर्धा और ऋण'),
  Bi('partnership and agreements', 'साझेदारी और अनुबंध'),
  Bi(
    'things that change hands, and what is inherited',
    'परिवर्तन और उत्तराधिकार',
  ),
  Bi('fortune, teachers and long journeys', 'भाग्य, गुरु और लंबी यात्रा'),
  Bi('work and standing', 'कर्म और प्रतिष्ठा'),
  Bi('gains and the people who bring them', 'लाभ और मित्र'),
  Bi('expense, retreat and what is released', 'व्यय और एकांत'),
];

Bi houseTheme(int house) => houseThemes[(house - 1) % 12];

/// What each graha stands for, worded for a year reading. Deliberately not
/// the app's general karaka line, which names things this reading never
/// speaks to.
const Map<Graha, Bi> grahaThemes = <Graha, Bi>{
  Graha.sun: Bi(
    'authority, confidence and the father',
    'अधिकार, आत्मविश्वास और पिता',
  ),
  Graha.moon: Bi('the mind, mood and the mother', 'मन, भाव और माता'),
  Graha.mars: Bi(
    'courage, drive, siblings and land',
    'साहस, ऊर्जा, भाई-बहन और भूमि',
  ),
  Graha.mercury: Bi('speech, learning and trade', 'वाणी, विद्या और व्यापार'),
  Graha.jupiter: Bi(
    'guidance, teachers and children',
    'मार्गदर्शन, गुरु और संतान',
  ),
  Graha.venus: Bi('relationships, comfort and the arts', 'संबंध, सुख और कला'),
  Graha.saturn: Bi('work, discipline and patience', 'कर्म, अनुशासन और धैर्य'),
  Graha.rahu: Bi(
    'ambition and what is unfamiliar or foreign',
    'महत्वाकांक्षा और अपरिचित या विदेशी बातें',
  ),
  Graha.ketu: Bi('detachment and inner work', 'वैराग्य और अंतर्मुखी साधना'),
};

Bi grahaTheme(Graha graha) => grahaThemes[graha]!;

/// The houses of [chart] whose signs [graha] rules, in house order.
List<int> housesRuledBy(Kundli chart, Graha graha) {
  final List<int> houses = <int>[];
  for (int house = 1; house <= 12; house++) {
    if (rashiInfo(Rashi.values[chart.signOfHouse(house)]).lord == graha) {
      houses.add(house);
    }
  }
  return houses;
}

/// The lord of the sign that is [house] of [chart].
Graha houseLord(Kundli chart, int house) =>
    rashiInfo(Rashi.values[chart.signOfHouse(house)]).lord;

/// The point a house starts from in the equal-house scheme the annual chart
/// is read in: the lagna degree repeated in each sign. Using it keeps the
/// sign of a house point identical to the whole-sign house it names.
double housePoint(Kundli chart, int house) =>
    norm360(chart.ascendant + 30.0 * (house - 1));

/// Sign-distance from [from] to [to], counted inclusively, 1..12.
int signDistance(int from, int to) => ((to - from + 12) % 12) + 1;

/// The classical positional friendship the Tajika five-fold strength uses.
///
/// A graha stands to the lord of a division according to where that lord's
/// sign lies from its own: the third, fifth, ninth and eleventh signs are
/// friendly; the second, sixth, eighth and twelfth are neutral; the first,
/// fourth, seventh and tenth are inimical (Hayanaratna 2.4, the three-fold
/// scheme from the Romakatajika; Charak's Textbook of Varshaphala).
PvRelation tajikaRelation(Kundli chart, Graha graha, Graha lord) {
  if (graha == lord) return PvRelation.own;
  final int from = chart.grahas[graha]!.rashi.index;
  final int to = chart.grahas[lord]!.rashi.index;
  switch (signDistance(from, to)) {
    case 3:
    case 5:
    case 9:
    case 11:
      return PvRelation.friend;
    case 2:
    case 6:
    case 8:
    case 12:
      return PvRelation.neutral;
    default:
      return PvRelation.enemy;
  }
}

enum PvRelation { own, friend, neutral, enemy }

/// "12°34′" for a degree count.
String degText(double degrees) {
  final double d = degrees.abs();
  int whole = d.floor();
  int minutes = ((d - whole) * 60).round();
  if (minutes == 60) {
    whole += 1;
    minutes = 0;
  }
  return '$whole°${minutes.toString().padLeft(2, '0')}′';
}

/// Words that no reading this engine produces may contain. The honesty rule
/// of the app: nothing about death, illness, pregnancy, examinations, courts
/// or the returns on an investment. The names of the Roga and Mrityu sahams
/// are the one place the engine has to say what the point is called; their
/// readings are empty.
const List<String> forbiddenEnglishTerms = <String>[
  'death',
  'die',
  'dies',
  'dying',
  'dead',
  'mortal',
  'fatal',
  'illness',
  'disease',
  'sick',
  'health',
  'pregnan',
  'conceive',
  'conception',
  'miscarr',
  'exam',
  'court',
  'lawsuit',
  'verdict',
  'invest',
  'profit',
  'surgery',
  'accident',
  'hospital',
];

const List<String> forbiddenHindiTerms = <String>[
  'मृत्यु',
  'मौत',
  'रोग',
  'बीमार',
  'स्वास्थ्य',
  'गर्भ',
  'परीक्षा',
  'अदालत',
  'मुकदमा',
  'निवेश',
  'मुनाफ़ा',
  'दुर्घटना',
  'अस्पताल',
];

/// Returns the first forbidden term found in [text], or null when it is clean.
String? forbiddenTermIn(Bi text) {
  final String en = text.en.toLowerCase();
  for (final String term in forbiddenEnglishTerms) {
    if (RegExp('\\b${RegExp.escape(term)}').hasMatch(en)) return term;
  }
  for (final String term in forbiddenHindiTerms) {
    if (text.hi.contains(term)) return term;
  }
  return null;
}

const List<String> _englishMonths = <String>[
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

const List<String> _hindiMonths = <String>[
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

/// "14 Aug 2026" and "14 अगस्त 2026" for a wall-clock date.
Bi dateBi(DateTime local) => Bi(
  '${local.day} ${_englishMonths[local.month - 1]} ${local.year}',
  '${local.day} ${_hindiMonths[local.month - 1]} ${local.year}',
);

/// "7.5" for 7.46, and "8" for 8.0.
String compactNumber(double value, {int decimals = 1}) {
  final String fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  final String trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
