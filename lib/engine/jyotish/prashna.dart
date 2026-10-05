import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';

/// Prashna: the chart of the moment a question is asked.
///
/// The classical reading weighs the lagna and its lord, the Moon, and whatever
/// sits in the first and eighth houses. The app reports the leaning and every
/// factor behind it, and never turns it into a prediction about health, money
/// or anyone else's intentions.
class PrashnaReading {
  const PrashnaReading({
    required this.question,
    required this.chart,
    required this.score,
    required this.factors,
    required this.factorsHindi,
  });

  final String question;
  final Kundli chart;

  /// Minus five to plus five; the sign is the leaning, the size is how clear.
  final int score;
  final List<String> factors;
  final List<String> factorsHindi;

  String verdict({required bool hindi}) {
    if (score >= 3) {
      return hindi ? 'संकेत अनुकूल हैं' : 'The signs lean favourable';
    }
    if (score <= -3) {
      return hindi ? 'संकेत प्रतिकूल हैं' : 'The signs lean against it';
    }
    return hindi
        ? 'संकेत मिले-जुले हैं, अभी स्पष्ट उत्तर नहीं'
        : 'The signs are mixed; the chart does not answer cleanly';
  }
}

const List<Graha> _benefics = <Graha>[
  Graha.jupiter,
  Graha.venus,
  Graha.mercury,
];
const List<Graha> _malefics = <Graha>[
  Graha.sun,
  Graha.mars,
  Graha.saturn,
  Graha.rahu,
  Graha.ketu,
];

PrashnaReading castPrashna({
  required String question,
  required DateTime moment,
  required Duration utcOffset,
  required GeoPlace place,
  Ayanamsa ayanamsa = Ayanamsa.lahiri,
}) {
  final Kundli chart = computeKundli(
    BirthData(
      name: 'Prashna',
      localDateTime: moment,
      utcOffset: utcOffset,
      place: place,
    ),
    ayanamsa: ayanamsa,
  );

  int score = 0;
  final List<String> factors = <String>[];
  final List<String> hindi = <String>[];

  final Graha lagnaLord = rashiInfo(chart.lagnaRashi).lord;
  final PlacedGraha lord = chart.grahas[lagnaLord]!;
  if (<int>[1, 4, 5, 7, 9, 10].contains(lord.house)) {
    score += 2;
    factors.add(
      'The lagna lord ${grahaInfo(lagnaLord).english} stands in house ${lord.house}, a strong place for the matter asked about.',
    );
    hindi.add(
      'लग्नेश ${grahaInfo(lagnaLord).hindi} ${lord.house}वें भाव में है, जो बलवान स्थान है।',
    );
  } else if (<int>[6, 8, 12].contains(lord.house)) {
    score -= 2;
    factors.add(
      'The lagna lord ${grahaInfo(lagnaLord).english} falls in house ${lord.house}, which the texts call a weak place.',
    );
    hindi.add(
      'लग्नेश ${grahaInfo(lagnaLord).hindi} ${lord.house}वें भाव में है, जो दुर्बल स्थान है।',
    );
  }

  if (lord.dignity == Dignity.exalted ||
      lord.dignity == Dignity.own ||
      lord.dignity == Dignity.moolatrikona) {
    score += 1;
    factors.add('It is strong by sign.');
    hindi.add('वह राशि से बलवान है।');
  } else if (lord.dignity == Dignity.debilitated) {
    score -= 1;
    factors.add('It is debilitated.');
    hindi.add('वह नीच राशि में है।');
  }

  final PlacedGraha moon = chart.grahas[Graha.moon]!;
  if (<int>[6, 8, 12].contains(moon.house)) {
    score -= 2;
    factors.add(
      'The Moon is in house ${moon.house}, which unsettles the question.',
    );
    hindi.add(
      'चंद्र ${moon.house}वें भाव में है, जो प्रश्न को अस्थिर करता है।',
    );
  } else {
    score += 1;
    factors.add(
      'The Moon is in house ${moon.house}, which carries the question well.',
    );
    hindi.add('चंद्र ${moon.house}वें भाव में है, जो अनुकूल है।');
  }

  final List<PlacedGraha> inLagna = chart.grahasInHouse(1);
  for (final PlacedGraha graha in inLagna) {
    if (_benefics.contains(graha.graha)) {
      score += 1;
      factors.add(
        '${grahaInfo(graha.graha).english} sits in the lagna, a benefic on the question itself.',
      );
      hindi.add('${grahaInfo(graha.graha).hindi} लग्न में है, जो शुभ है।');
    } else if (_malefics.contains(graha.graha)) {
      score -= 1;
      factors.add(
        '${grahaInfo(graha.graha).english} sits in the lagna, which obstructs.',
      );
      hindi.add(
        '${grahaInfo(graha.graha).hindi} लग्न में है, जो बाधा देता है।',
      );
    }
  }

  final List<PlacedGraha> inEighth = chart.grahasInHouse(8);
  if (inEighth.any((PlacedGraha g) => _malefics.contains(g.graha))) {
    score -= 1;
    factors.add('A malefic occupies the eighth house, so expect delay.');
    hindi.add('आठवें भाव में पाप ग्रह है, विलंब संभव है।');
  }

  return PrashnaReading(
    question: question,
    chart: chart,
    score: score.clamp(-5, 5),
    factors: factors,
    factorsHindi: hindi,
  );
}
