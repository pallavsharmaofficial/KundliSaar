import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'dasha.dart';
import 'graha_data.dart';
import 'rashi.dart';
import 'transits.dart';

/// The nine taras, counted from the janma nakshatra to the day's nakshatra.
const List<String> taraNames = <String>[
  'Janma',
  'Sampat',
  'Vipat',
  'Kshema',
  'Pratyari',
  'Sadhaka',
  'Vadha',
  'Mitra',
  'Ati-mitra',
];

const List<String> taraNamesHindi = <String>[
  'जन्म',
  'संपत',
  'विपत',
  'क्षेम',
  'प्रत्यरि',
  'साधक',
  'वध',
  'मित्र',
  'अतिमित्र',
];

/// Taras the texts read as obstructed: Vipat, Pratyari and Vadha.
const List<int> difficultTaras = <int>[2, 4, 6];

class ReadingPoint {
  const ReadingPoint({
    required this.area,
    required this.areaHindi,
    required this.text,
    required this.textHindi,
    required this.isCaution,
  });

  final String area;
  final String areaHindi;
  final String text;
  final String textHindi;
  final bool isCaution;
}

class DailyReading {
  const DailyReading({
    required this.date,
    required this.moonHouse,
    required this.tara,
    required this.points,
    required this.luckyNumber,
    required this.luckyColour,
    required this.luckyColourHindi,
    required this.dashaChain,
  });

  final DateTime date;

  /// Where the Moon stands today, counted from the natal Moon.
  final int moonHouse;

  /// Index into [taraNames].
  final int tara;
  final List<ReadingPoint> points;
  final int luckyNumber;
  final String luckyColour;
  final String luckyColourHindi;
  final List<DashaPeriod> dashaChain;

  bool get isGoodDay =>
      <int>[1, 3, 6, 7, 10, 11].contains(moonHouse) &&
      !difficultTaras.contains(tara);
}

const Map<Graha, List<String>> _dashaThemes = <Graha, List<String>>{
  Graha.sun: <String>[
    'authority, father, recognition',
    'अधिकार, पिता, प्रतिष्ठा',
  ],
  Graha.moon: <String>['mind, mother, home', 'मन, माता, घर'],
  Graha.mars: <String>['effort, land, siblings', 'पराक्रम, भूमि, भाई-बहन'],
  Graha.mercury: <String>['speech, trade, paperwork', 'वाणी, व्यापार, कागज़ात'],
  Graha.jupiter: <String>[
    'teachers, children, counsel',
    'गुरु, संतान, परामर्श',
  ],
  Graha.venus: <String>['relationships, comfort, art', 'संबंध, सुख, कला'],
  Graha.saturn: <String>['work, duty, patience', 'कार्य, कर्तव्य, धैर्य'],
  Graha.rahu: <String>[
    'ambition, foreign matters, the unfamiliar',
    'महत्वाकांक्षा, विदेश, नया',
  ],
  Graha.ketu: <String>[
    'letting go, research, inwardness',
    'त्याग, खोज, अंतर्मुखता',
  ],
};

const List<String> _colours = <String>[
  'Red',
  'White',
  'Yellow',
  'Green',
  'Blue',
  'Cream',
  'Saffron',
  'Grey',
  'Maroon',
];
const List<String> _coloursHindi = <String>[
  'लाल',
  'सफ़ेद',
  'पीला',
  'हरा',
  'नीला',
  'क्रीम',
  'केसरिया',
  'स्लेटी',
  'मरून',
];

/// A day read for one chart: the Moon's house from the natal Moon, the tara,
/// the running dasha and the heavier transits, in that order of weight.
DailyReading dailyReading(Kundli kundli, DateTime date) {
  final TransitReport transits = computeTransits(kundli, date);
  final TransitPosition moon = transits.positions[Graha.moon]!;
  final int janma = kundli.janmaNakshatra.index;
  final int today = moon.nakshatra.index;
  final int tara = ((today - janma + 27) % 27) % 9;
  final List<DashaPeriod> chain = dashaAt(
    kundli.vimshottari,
    julianDayFromUtc(date.toUtc()),
  );

  final List<ReadingPoint> points = <ReadingPoint>[];

  points.add(
    ReadingPoint(
      area: 'The day itself',
      areaHindi: 'दिन का स्वरूप',
      text:
          'The Moon is in ${rashiInfo(moon.rashi).english}, house ${moon.houseFromMoon} from your natal Moon, in ${moon.nakshatra.english}. '
          'The tara is ${taraNames[tara]}.',
      textHindi:
          'चंद्र ${rashiInfo(moon.rashi).hindi} राशि में, आपके जन्म चंद्र से ${moon.houseFromMoon}वें भाव में हैं। तारा ${taraNamesHindi[tara]} है।',
      isCaution:
          <int>[4, 8, 12].contains(moon.houseFromMoon) ||
          difficultTaras.contains(tara),
    ),
  );

  if (chain.isNotEmpty) {
    final Graha maha = chain[0].lord;
    final Graha antar = chain.length > 1 ? chain[1].lord : maha;
    points.add(
      ReadingPoint(
        area: 'The period you are in',
        areaHindi: 'चल रही दशा',
        text:
            '${grahaInfo(maha).english} mahadasha with ${grahaInfo(antar).english} antardasha. '
            'The year leans on ${_dashaThemes[maha]![0]}, and the months on ${_dashaThemes[antar]![0]}.',
        textHindi:
            '${grahaInfo(maha).hindi} महादशा, ${grahaInfo(antar).hindi} अंतर्दशा। ज़ोर ${_dashaThemes[maha]![1]} और ${_dashaThemes[antar]![1]} पर रहता है।',
        isCaution: false,
      ),
    );
  }

  for (final Graha graha in <Graha>[Graha.sun, Graha.jupiter, Graha.saturn]) {
    final TransitPosition position = transits.positions[graha]!;
    final bool good = transits.isFavourable(graha);
    points.add(
      ReadingPoint(
        area: '${grahaInfo(graha).english} in transit',
        areaHindi: '${grahaInfo(graha).hindi} का गोचर',
        text:
            '${grahaInfo(graha).english} is in ${rashiInfo(position.rashi).english}, house ${position.houseFromMoon} from your Moon, '
            'over ${position.bindusInSign} sarvashtakavarga bindus. ${good ? 'The texts call this a supportive passage.' : 'The texts ask for patience here.'}',
        textHindi:
            '${grahaInfo(graha).hindi} ${rashiInfo(position.rashi).hindi} राशि में, जन्म चंद्र से ${position.houseFromMoon}वें भाव में हैं, ${position.bindusInSign} बिंदुओं पर। ${good ? 'यह अनुकूल गोचर माना जाता है।' : 'यहाँ धैर्य चाहिए।'}',
        isCaution: !good,
      ),
    );
  }

  if (transits.sadeSati.isRunning) {
    points.add(
      ReadingPoint(
        area: 'Sade Sati',
        areaHindi: 'साढ़ेसाती',
        text:
            'Phase ${transits.sadeSati.phase} of three is running. The tradition reads it as a stretch of work and responsibility, not punishment.',
        textHindi:
            'तीन में से ${transits.sadeSati.phase}रा चरण चल रहा है। यह परिश्रम का काल है, दंड का नहीं।',
        isCaution: true,
      ),
    );
  }

  final int lucky = ((moon.houseFromMoon + tara) % 9) + 1;
  return DailyReading(
    date: date,
    moonHouse: moon.houseFromMoon,
    tara: tara,
    points: points,
    luckyNumber: lucky,
    luckyColour: _colours[(moon.rashi.index) % _colours.length],
    luckyColourHindi: _coloursHindi[(moon.rashi.index) % _coloursHindi.length],
    dashaChain: chain,
  );
}

/// A general reading for a moon sign, for anyone who has not cast a chart.
class RashiReading {
  const RashiReading({
    required this.rashi,
    required this.moonHouse,
    required this.text,
    required this.textHindi,
  });

  final Rashi rashi;
  final int moonHouse;
  final String text;
  final String textHindi;
}

List<RashiReading> allRashiReadings(
  DateTime date, {
  required int moonSignToday,
}) {
  return <RashiReading>[
    for (final Rashi rashi in Rashi.values)
      () {
        final int house = ((moonSignToday - rashi.index + 12) % 12) + 1;
        final bool good = <int>[1, 3, 6, 7, 10, 11].contains(house);
        return RashiReading(
          rashi: rashi,
          moonHouse: house,
          text: good
              ? 'The Moon stands in house $house from your rashi today, which carries the day forward. Good for conversations and for finishing what is already begun.'
              : 'The Moon stands in house $house from your rashi today. Keep the day simple; do not start what can wait.',
          textHindi: good
              ? 'आज चंद्र आपकी राशि से $houseवें भाव में हैं, जो अनुकूल है। अधूरे काम पूरे करें।'
              : 'आज चंद्र आपकी राशि से $houseवें भाव में हैं। दिन सरल रखें, नया काम टालें।',
        );
      }(),
  ];
}
