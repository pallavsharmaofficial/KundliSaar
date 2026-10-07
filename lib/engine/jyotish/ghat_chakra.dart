/// Ghat Chakra: the elements of a day that the tradition advises a person not
/// to choose for beginning something important, keyed on the janma rashi.
///
/// It is a muhurta aid. It says which month, tithi group, weekday, nakshatra,
/// yoga, karana, prahar and Moon sign to avoid when *choosing a day to begin*;
/// it says nothing about a person's life and nothing about how any day will go.
/// Nothing here is an event, and the readings it produces say so.
///
/// Where the table comes from. Every printed janampatri carries it, and the
/// rows are the widely published ones. They were checked against several
/// independent appearances of the same table:
///
///  * the complete twelve-row table at sanjayprabhakaran.blogspot.com
///    ("Ghaata Chakra", 2025), which is the source of every column;
///  * a Slideshare print of a sample kundli (the Mesha row: Kartika, tithis
///    1-6-11, Sunday, Magha, Vishkambha, Bava, prahar 1, Moon in Mesha);
///  * a user-posted sample on IndiaDivine (the Karka row: Pausha, tithis
///    2-7-12, Wednesday, Anuradha, Vyaghata, Naga, prahar 1);
///  * the astrologyapi.com ghat_chakra documentation sample (the Dhanu row:
///    Shravana, tithis 3-8-13, Friday, Bharani, Vajra, Taitila, prahar 1);
///  * Sanjay Rath's worked Mithuna example (tithis 2-7-12, Monday, Swati) and
///    his statement that Rikta tithis are the Makara ghat tithis;
///  * a Webdunia article, which gives the ghat-Moon sequence for the twelve
///    rashis from Mesha as 1, 5, 9, 2, 6, 10, 3, 7, 4, 8, 11, 12, the same
///    sequence as the blog table's first sign column.
///
/// The Vrishabha row (Saturday, Poorna, Hasta, Margashirsha, Sukarma, Shakuni,
/// prahar 4) was also seen quoted in a search snippet. The remaining rows rest
/// on the blog table alone: Simha, Kanya, Tula, Vrishchika, Makara, Kumbha and
/// Meena for the weekday, yoga, karana, prahar and month columns. Within the
/// table the nakshatra column advances in a regular nine-star step from a star
/// of each sign, and the month column uses every Hindu month once, which are
/// the marks of an uncorrupted table. The blog prints the yoga Vajra against
/// both Dhanu and Meena; it is kept as printed.
///
/// What is deliberately not here:
///
///  * The ghat lagna. Sources that give it disagree: Sanjay Rath's Mithuna
///    example names a ghataka Moon (Kumbha) and lagna (Makara or Karka) that do
///    not match the widely printed table, and the second sign column the blog
///    prints is not labelled. It is left out rather than guessed.
///  * The lunar-month variant. Some traditions key the first column on the
///    lunar birth month instead of the janma rashi. This file uses the janma
///    rashi convention, which is the one the printed table uses.
library;

import 'chart.dart';
import 'nakshatra.dart';
import 'rashi.dart';

/// The five groups of tithis, each three of the fifteen.
enum TithiGroup { nanda, bhadra, jaya, rikta, poorna }

extension TithiGroupNames on TithiGroup {
  String get english => switch (this) {
    TithiGroup.nanda => 'Nanda',
    TithiGroup.bhadra => 'Bhadra',
    TithiGroup.jaya => 'Jaya',
    TithiGroup.rikta => 'Rikta',
    TithiGroup.poorna => 'Poorna',
  };

  String get hindi => switch (this) {
    TithiGroup.nanda => 'नंदा',
    TithiGroup.bhadra => 'भद्रा',
    TithiGroup.jaya => 'जया',
    TithiGroup.rikta => 'रिक्ता',
    TithiGroup.poorna => 'पूर्णा',
  };

  /// The three tithis of the group, counted 1 to 15 in each fortnight.
  List<int> get tithis => switch (this) {
    TithiGroup.nanda => const <int>[1, 6, 11],
    TithiGroup.bhadra => const <int>[2, 7, 12],
    TithiGroup.jaya => const <int>[3, 8, 13],
    TithiGroup.rikta => const <int>[4, 9, 14],
    TithiGroup.poorna => const <int>[5, 10, 15],
  };
}

const List<String> hinduMonthsEnglish = <String>[
  'Chaitra',
  'Vaishakha',
  'Jyeshtha',
  'Ashadha',
  'Shravana',
  'Bhadrapada',
  'Ashwina',
  'Kartika',
  'Margashirsha',
  'Pausha',
  'Magha',
  'Phalguna',
];

const List<String> hinduMonthsHindi = <String>[
  'चैत्र',
  'वैशाख',
  'ज्येष्ठ',
  'आषाढ़',
  'श्रावण',
  'भाद्रपद',
  'आश्विन',
  'कार्तिक',
  'मार्गशीर्ष',
  'पौष',
  'माघ',
  'फाल्गुन',
];

/// 0 = Sunday, to match the rest of the engine.
const List<String> ghatWeekdaysEnglish = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> ghatWeekdaysHindi = <String>[
  'रविवार',
  'सोमवार',
  'मंगलवार',
  'बुधवार',
  'गुरुवार',
  'शुक्रवार',
  'शनिवार',
];

/// One row of the table: what to avoid beginning something on, for a given
/// janma rashi.
class GhatRow {
  const GhatRow({
    required this.rashi,
    required this.monthIndex,
    required this.tithiGroup,
    required this.weekday,
    required this.nakshatraIndex,
    required this.yogaEnglish,
    required this.yogaHindi,
    required this.karanaEnglish,
    required this.karanaHindi,
    required this.prahar,
    required this.chandra,
  });

  final Rashi rashi;

  /// Index into [hinduMonthsEnglish], 0 = Chaitra.
  final int monthIndex;
  final TithiGroup tithiGroup;

  /// 0 = Sunday.
  final int weekday;

  /// Zero-based index from Ashwini, as in [nakshatraTable].
  final int nakshatraIndex;
  final String yogaEnglish;
  final String yogaHindi;
  final String karanaEnglish;
  final String karanaHindi;

  /// The prahar, one eighth of the day and night together, counted from
  /// sunrise: 1 to 4 fall by day, 5 to 8 by night.
  final int prahar;

  /// The Moon sign the tradition calls the ghat Moon for this janma rashi.
  final Rashi chandra;

  String get monthEnglish => hinduMonthsEnglish[monthIndex];
  String get monthHindi => hinduMonthsHindi[monthIndex];
  String get weekdayEnglish => ghatWeekdaysEnglish[weekday];
  String get weekdayHindi => ghatWeekdaysHindi[weekday];
  NakshatraInfo get nakshatra => nakshatraTable[nakshatraIndex];
  bool get praharIsNight => prahar > 4;
}

/// The twelve rows, in the order Mesha to Meena. See the library comment for
/// how each was checked.
const List<GhatRow> ghatChakraTable = <GhatRow>[
  GhatRow(
    rashi: Rashi.mesha,
    monthIndex: 7,
    tithiGroup: TithiGroup.nanda,
    weekday: 0,
    nakshatraIndex: 9,
    yogaEnglish: 'Vishkambha',
    yogaHindi: 'विष्कुंभ',
    karanaEnglish: 'Bava',
    karanaHindi: 'बव',
    prahar: 1,
    chandra: Rashi.mesha,
  ),
  GhatRow(
    rashi: Rashi.vrishabha,
    monthIndex: 8,
    tithiGroup: TithiGroup.poorna,
    weekday: 6,
    nakshatraIndex: 12,
    yogaEnglish: 'Sukarma',
    yogaHindi: 'सुकर्मा',
    karanaEnglish: 'Shakuni',
    karanaHindi: 'शकुनि',
    prahar: 4,
    chandra: Rashi.simha,
  ),
  GhatRow(
    rashi: Rashi.mithuna,
    monthIndex: 3,
    tithiGroup: TithiGroup.bhadra,
    weekday: 1,
    nakshatraIndex: 14,
    yogaEnglish: 'Parigha',
    yogaHindi: 'परिघ',
    karanaEnglish: 'Chatushpada',
    karanaHindi: 'चतुष्पद',
    prahar: 3,
    chandra: Rashi.dhanu,
  ),
  GhatRow(
    rashi: Rashi.karka,
    monthIndex: 9,
    tithiGroup: TithiGroup.bhadra,
    weekday: 3,
    nakshatraIndex: 16,
    yogaEnglish: 'Vyaghata',
    yogaHindi: 'व्याघात',
    karanaEnglish: 'Naga',
    karanaHindi: 'नाग',
    prahar: 1,
    chandra: Rashi.vrishabha,
  ),
  GhatRow(
    rashi: Rashi.simha,
    monthIndex: 2,
    tithiGroup: TithiGroup.jaya,
    weekday: 6,
    nakshatraIndex: 18,
    yogaEnglish: 'Dhriti',
    yogaHindi: 'धृति',
    karanaEnglish: 'Bava',
    karanaHindi: 'बव',
    prahar: 1,
    chandra: Rashi.kanya,
  ),
  GhatRow(
    rashi: Rashi.kanya,
    monthIndex: 5,
    tithiGroup: TithiGroup.poorna,
    weekday: 6,
    nakshatraIndex: 21,
    yogaEnglish: 'Shubha',
    yogaHindi: 'शुभ',
    karanaEnglish: 'Kaulava',
    karanaHindi: 'कौलव',
    prahar: 1,
    chandra: Rashi.makara,
  ),
  GhatRow(
    rashi: Rashi.tula,
    monthIndex: 10,
    tithiGroup: TithiGroup.rikta,
    weekday: 4,
    nakshatraIndex: 23,
    yogaEnglish: 'Shukla',
    yogaHindi: 'शुक्ल',
    karanaEnglish: 'Taitila',
    karanaHindi: 'तैतिल',
    prahar: 4,
    chandra: Rashi.mithuna,
  ),
  GhatRow(
    rashi: Rashi.vrischika,
    monthIndex: 6,
    tithiGroup: TithiGroup.nanda,
    weekday: 5,
    nakshatraIndex: 26,
    yogaEnglish: 'Vyatipata',
    yogaHindi: 'व्यतीपात',
    karanaEnglish: 'Gara',
    karanaHindi: 'गर',
    prahar: 1,
    chandra: Rashi.tula,
  ),
  GhatRow(
    rashi: Rashi.dhanu,
    monthIndex: 4,
    tithiGroup: TithiGroup.jaya,
    weekday: 5,
    nakshatraIndex: 1,
    yogaEnglish: 'Vajra',
    yogaHindi: 'वज्र',
    karanaEnglish: 'Taitila',
    karanaHindi: 'तैतिल',
    prahar: 1,
    chandra: Rashi.karka,
  ),
  GhatRow(
    rashi: Rashi.makara,
    monthIndex: 1,
    tithiGroup: TithiGroup.rikta,
    weekday: 2,
    nakshatraIndex: 3,
    yogaEnglish: 'Vaidhriti',
    yogaHindi: 'वैधृति',
    karanaEnglish: 'Shakuni',
    karanaHindi: 'शकुनि',
    prahar: 4,
    chandra: Rashi.vrischika,
  ),
  GhatRow(
    rashi: Rashi.kumbha,
    monthIndex: 0,
    tithiGroup: TithiGroup.jaya,
    weekday: 4,
    nakshatraIndex: 5,
    yogaEnglish: 'Ganda',
    yogaHindi: 'गंड',
    karanaEnglish: 'Vanija',
    karanaHindi: 'वणिज',
    prahar: 3,
    chandra: Rashi.kumbha,
  ),
  GhatRow(
    rashi: Rashi.meena,
    monthIndex: 11,
    tithiGroup: TithiGroup.poorna,
    weekday: 5,
    nakshatraIndex: 8,
    yogaEnglish: 'Vajra',
    yogaHindi: 'वज्र',
    karanaEnglish: 'Vishti (Bhadra)',
    karanaHindi: 'विष्टि (भद्रा)',
    prahar: 6,
    chandra: Rashi.meena,
  ),
];

GhatRow ghatRowFor(Rashi janmaRashi) => ghatChakraTable[janmaRashi.index];

/// The ghat chakra of a person, with a statement in both languages.
class GhatChakraReading {
  const GhatChakraReading({
    required this.row,
    required this.statementEnglish,
    required this.statementHindi,
    required this.cautionEnglish,
    required this.cautionHindi,
    required this.factorsEnglish,
    required this.factorsHindi,
  });

  final GhatRow row;
  final String statementEnglish;
  final String statementHindi;

  /// What the table is for, and what it is not.
  final String cautionEnglish;
  final String cautionHindi;

  /// The chart factors the row was keyed on.
  final List<String> factorsEnglish;
  final List<String> factorsHindi;
}

/// Keys the table on the janma rashi, the convention of the printed table.
GhatChakraReading ghatChakraOf(Kundli kundli) {
  final Rashi moon = kundli.moonRashi;
  final GhatRow row = ghatRowFor(moon);
  final RashiInfo info = rashiInfo(moon);
  final RashiInfo chandra = rashiInfo(row.chandra);
  final String tithisEn = row.tithiGroup.tithis.join(', ');
  return GhatChakraReading(
    row: row,
    statementEnglish:
        'For a ${info.english} Moon, the ghat chakra marks these as poor choices for beginning something important: '
        '${row.tithiGroup.english} tithis ($tithisEn) of either fortnight, ${row.weekdayEnglish}, '
        '${row.nakshatra.english} nakshatra, ${row.yogaEnglish} yoga, ${row.karanaEnglish} karana, '
        'prahar ${row.prahar}, the month of ${row.monthEnglish}, and the Moon passing through ${chandra.english}.',
    statementHindi:
        '${info.hindi} राशि के चंद्र के लिए घात चक्र इन्हें कोई महत्वपूर्ण कार्य आरंभ करने के लिए अनुपयुक्त मानता है: '
        'दोनों पक्षों की ${row.tithiGroup.hindi} तिथियाँ ($tithisEn), ${row.weekdayHindi}, '
        '${row.nakshatra.hindi} नक्षत्र, ${row.yogaHindi} योग, ${row.karanaHindi} करण, '
        'प्रहर ${row.prahar}, ${row.monthHindi} मास, और चंद्रमा का ${chandra.hindi} राशि से गुज़रना।',
    cautionEnglish:
        'This is a muhurta aid for choosing a day to begin something, and nothing more. It says nothing about your life or how any day will go. The tradition weighs it more when several of these coincide on one day; a single one is only a reason to prefer another day when the panchang allows. Some traditions key the table on the lunar birth month instead of the Moon sign; this one uses the Moon sign.',
    cautionHindi:
        'यह कोई काम शुरू करने का दिन चुनने के लिए मुहूर्त का सहारा है, इससे अधिक कुछ नहीं। यह आपके जीवन या किसी दिन के बारे में कुछ नहीं कहता। परंपरा इसे तब अधिक महत्व देती है जब इनमें से कई एक ही दिन मिलें; अकेला एक केवल यह कारण है कि पंचांग अनुमति दे तो दूसरा दिन चुना जाए। कुछ परंपराएँ तालिका को चंद्र राशि के बजाय चंद्र जन्म-मास पर आधारित करती हैं; यहाँ चंद्र राशि ली गई है।',
    factorsEnglish: <String>[
      'Moon: ${info.english}, ${kundli.janmaNakshatra.english}',
    ],
    factorsHindi: <String>[
      'चंद्र: ${info.hindi}, ${kundli.janmaNakshatra.hindi}',
    ],
  );
}
