import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'panchang.dart';
import 'rashi.dart';

/// The twelve amanta lunar months, which run new moon to new moon and take
/// their name from the solar sign the Sun enters inside them.
const List<String> lunarMonths = <String>[
  'Chaitra',
  'Vaishakha',
  'Jyeshtha',
  'Ashadha',
  'Shravana',
  'Bhadrapada',
  'Ashwin',
  'Kartik',
  'Margashirsha',
  'Pausha',
  'Magha',
  'Phalguna',
];

const List<String> lunarMonthsHindi = <String>[
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

/// A festival or observance on a particular day.
class Festival {
  const Festival({
    required this.date,
    required this.english,
    required this.hindi,
    required this.detail,
    required this.detailHindi,
    required this.isMajor,
  });

  final DateTime date;
  final String english;
  final String hindi;
  final String detail;
  final String detailHindi;
  final bool isMajor;
}

/// When in the day a festival's tithi has to be running for the day to carry
/// it. Diwali is the clearest case: Lakshmi Puja is done at dusk, so the day
/// holding Amavasya in the evening takes the festival even when that morning
/// still belonged to Chaturdashi.
enum _When { sunrise, midday, aparahna, pradosh, nishita }

/// A rule of the form "this month, this paksha, this tithi".
class _Rule {
  const _Rule(
    this.month,
    this.shukla,
    this.tithi,
    this.english,
    this.hindi, {
    this.when = _When.sunrise,
  });

  final int month;
  final bool shukla;

  /// One to fifteen within the paksha.
  final int tithi;
  final String english;
  final String hindi;

  /// The moment of the day the rule is read at.
  final _When when;
}

const List<_Rule> _rules = <_Rule>[
  _Rule(
    0,
    true,
    1,
    'Gudi Padwa, Chaitra Navratri begins',
    'गुड़ी पडवा, चैत्र नवरात्रि आरंभ',
  ),
  _Rule(0, true, 9, 'Ram Navami', 'राम नवमी'),
  _Rule(0, true, 15, 'Hanuman Jayanti', 'हनुमान जयंती'),
  _Rule(1, true, 3, 'Akshaya Tritiya', 'अक्षय तृतीया'),
  _Rule(1, true, 15, 'Buddha Purnima', 'बुद्ध पूर्णिमा'),
  _Rule(2, false, 15, 'Vat Savitri Amavasya', 'वट सावित्री अमावस्या'),
  _Rule(3, true, 2, 'Rath Yatra', 'रथ यात्रा'),
  _Rule(3, true, 11, 'Devshayani Ekadashi', 'देवशयनी एकादशी'),
  _Rule(3, true, 15, 'Guru Purnima', 'गुरु पूर्णिमा'),
  _Rule(4, true, 15, 'Raksha Bandhan', 'रक्षा बंधन'),
  _Rule(
    4,
    false,
    8,
    'Krishna Janmashtami',
    'कृष्ण जन्माष्टमी',
    when: _When.nishita,
  ),
  _Rule(5, true, 4, 'Ganesh Chaturthi', 'गणेश चतुर्थी', when: _When.midday),
  _Rule(
    5,
    false,
    15,
    'Sarva Pitru Amavasya',
    'सर्व पितृ अमावस्या',
    when: _When.aparahna,
  ),
  _Rule(6, true, 1, 'Sharad Navratri begins', 'शारदीय नवरात्रि आरंभ'),
  _Rule(6, true, 8, 'Durga Ashtami', 'दुर्गाष्टमी'),
  _Rule(
    6,
    true,
    10,
    'Dussehra, Vijayadashami',
    'दशहरा, विजयादशमी',
    when: _When.aparahna,
  ),
  _Rule(6, true, 15, 'Sharad Purnima', 'शरद पूर्णिमा'),
  _Rule(6, false, 13, 'Dhanteras', 'धनतेरस', when: _When.pradosh),
  _Rule(6, false, 14, 'Narak Chaturdashi, Choti Diwali', 'नरक चतुर्दशी'),
  _Rule(
    6,
    false,
    15,
    'Diwali, Lakshmi Puja',
    'दीपावली, लक्ष्मी पूजन',
    when: _When.pradosh,
  ),
  _Rule(7, true, 1, 'Govardhan Puja', 'गोवर्धन पूजा'),
  _Rule(7, true, 2, 'Bhai Dooj', 'भाई दूज'),
  _Rule(7, true, 6, 'Chhath Puja', 'छठ पूजा'),
  _Rule(7, true, 11, 'Devuthani Ekadashi, Tulsi Vivah', 'देवउठनी एकादशी'),
  _Rule(7, true, 15, 'Kartik Purnima, Dev Diwali', 'कार्तिक पूर्णिमा'),
  _Rule(8, true, 11, 'Gita Jayanti', 'गीता जयंती'),
  _Rule(10, true, 5, 'Vasant Panchami', 'वसंत पंचमी'),
  _Rule(10, false, 14, 'Maha Shivaratri', 'महाशिवरात्रि', when: _When.nishita),
  _Rule(11, true, 15, 'Holika Dahan', 'होलिका दहन', when: _When.pradosh),
  _Rule(11, false, 1, 'Holi, Dhulandi', 'होली, धुलेंडी'),
];

double _elongationAt(double jdUt) {
  final Instant instant = Instant.fromJulianDayUt(jdUt);
  return norm360(
    positionOf(Graha.moon, instant).tropicalLongitude -
        positionOf(Graha.sun, instant).tropicalLongitude,
  );
}

/// New moon instants spanning a year, found by watching the elongation wrap.
List<double> _newMoons(double fromJd, double toJd) {
  final List<double> moons = <double>[];
  double previous = _elongationAt(fromJd);
  for (double jd = fromJd + 1; jd <= toJd; jd += 1) {
    final double current = _elongationAt(jd);
    if (current < previous) {
      double low = jd - 1;
      double high = jd;
      for (int i = 0; i < 32; i++) {
        final double mid = (low + high) / 2;
        if (_elongationAt(mid) > 180) {
          low = mid;
        } else {
          high = mid;
        }
      }
      moons.add(high);
    }
    previous = current;
  }
  return moons;
}

/// Everything the calendar knows about a single day.
class LunarDay {
  const LunarDay({
    required this.date,
    required this.sunriseJdUt,
    required this.sunsetJdUt,
    required this.tithiIndex,
    required this.tithiAtMidday,
    required this.tithiAtAparahnaStart,
    required this.tithiAtAparahnaEnd,
    required this.tithiAtPradosh,
    required this.tithiAtNishita,
    required this.bhadraAtPradosh,
    required this.monthIndex,
  });

  final DateTime date;
  final double sunriseJdUt;
  final double sunsetJdUt;

  /// Zero to twenty-nine from the new moon, at sunrise.
  final int tithiIndex;

  /// The same count at the moments the rules actually ask for. The day is
  /// divided into five parts: madhyahna is the third and aparahna the fourth,
  /// and a festival read in one of them can fall a day away from a festival
  /// read in the other.
  final int tithiAtMidday;

  /// Aparahna is a stretch, not an instant, and the rule is whether the tithi
  /// touches it at all. Sampling one moment put Vijayadashami a day late in
  /// years where Dashami begins inside that window.
  final int tithiAtAparahnaStart;
  final int tithiAtAparahnaEnd;
  final int tithiAtPradosh;
  final int tithiAtNishita;

  /// True when Vishti karana, which the texts call Bhadra, covers dusk. No
  /// fire is lit and no new thing begun while it runs, which is exactly why
  /// Holika Dahan slips to the following evening in some years.
  final bool bhadraAtPradosh;
  final int monthIndex;

  int tithiFor(int when) => switch (when) {
    1 => tithiAtMidday,
    2 => tithiAtAparahnaStart,
    3 => tithiAtPradosh,
    4 => tithiAtNishita,
    _ => tithiIndex,
  };

  /// Every tithi the day carries at the moment this rule is read at. Aparahna
  /// spans a stretch of the afternoon, so it can hold two.
  List<int> tithisFor(int when) => when == 2
      ? <int>{tithiAtAparahnaStart, tithiAtAparahnaEnd}.toList()
      : <int>[tithiFor(when)];

  bool get isShukla => tithiIndex < 15;
  int get tithiInPaksha => (tithiIndex % 15) + 1;
  String get month => lunarMonths[monthIndex];
}

/// The lunar calendar for a civil year at one place.
List<LunarDay> lunarYear({
  required int year,
  required GeoPlace place,
  required Duration utcOffset,
  Ayanamsa ayanamsa = Ayanamsa.lahiri,
}) {
  final double start =
      julianDayFromUtc(DateTime.utc(year - 1, 12, 1)) -
      utcOffset.inMinutes / 1440.0;
  final double end =
      julianDayFromUtc(DateTime.utc(year + 1, 1, 31)) -
      utcOffset.inMinutes / 1440.0;
  final List<double> newMoons = _newMoons(start, end);

  // Each lunar month takes its name from the sign the Sun enters within it.
  final Map<double, int> monthNames = <double, int>{};
  for (final double moon in newMoons) {
    final Instant instant = Instant.fromJulianDayUt(moon);
    final double sun = toSidereal(
      positionOf(Graha.sun, instant).tropicalLongitude,
      ayanamsa,
      instant.centuriesTt,
    );
    monthNames[moon] = (((sun / 30).floor() + 1) % 12);
  }

  final List<LunarDay> days = <LunarDay>[];
  final DateTime first = DateTime(year, 1, 1);
  for (
    int i = 0;
    i < (DateTime(year + 1, 1, 1).difference(first).inDays);
    i++
  ) {
    final DateTime date = first.add(Duration(days: i));
    final double midnightUt =
        julianDayFromUtc(DateTime.utc(date.year, date.month, date.day)) -
        utcOffset.inMinutes / 1440.0;
    final RiseSet riseSet = fastSunRiseSet(midnightUt, place);
    final double sunrise = riseSet.rise ?? midnightUt + 0.25;
    final double sunset = riseSet.set ?? midnightUt + 0.75;
    int tithiAt(double jd) => (_elongationAt(jd) / 12).floor().clamp(0, 29);
    bool bhadraAt(double jd) {
      final int karana = (_elongationAt(jd) / 6).floor().clamp(0, 59);
      return karana >= 1 && karana <= 56 && (karana - 1) % 7 == 6;
    }

    final int tithi = tithiAt(sunrise);
    double lastMoon = newMoons.first;
    for (final double moon in newMoons) {
      if (moon <= sunrise) lastMoon = moon;
    }
    days.add(
      LunarDay(
        date: date,
        sunriseJdUt: sunrise,
        sunsetJdUt: sunset,
        tithiIndex: tithi,
        tithiAtMidday: tithiAt((sunrise + sunset) / 2),
        tithiAtAparahnaStart: tithiAt(sunrise + (sunset - sunrise) * 0.6),
        tithiAtAparahnaEnd: tithiAt(sunrise + (sunset - sunrise) * 0.8),
        // Pradosh runs from dusk for about two and a half ghatis.
        tithiAtPradosh: tithiAt(sunset + 0.02),
        // Nishita is the middle of the night, after midnight.
        tithiAtNishita: tithiAt((sunset + sunrise + 1) / 2),
        bhadraAtPradosh: bhadraAt(sunset + 0.02),
        monthIndex: monthNames[lastMoon] ?? 0,
      ),
    );
  }
  return days;
}

/// Festivals and recurring observances for a civil year.
List<Festival> festivalsForYear({
  required int year,
  required GeoPlace place,
  required Duration utcOffset,
  Ayanamsa ayanamsa = Ayanamsa.lahiri,
  bool includeMonthly = true,
}) {
  final List<LunarDay> days = lunarYear(
    year: year,
    place: place,
    utcOffset: utcOffset,
    ayanamsa: ayanamsa,
  );
  final List<Festival> out = <Festival>[];

  // Rules are matched first, then resolved. When a tithi is in pradosh on two
  // evenings in a row the texts take the second: Holika Dahan moves to the day
  // after the first, because Bhadra covers the earlier evening.
  for (final _Rule rule in _rules) {
    final List<LunarDay> matches = <LunarDay>[];
    for (final LunarDay day in days) {
      final bool hit = day
          .tithisFor(rule.when.index)
          .any(
            (int observed) =>
                rule.month == day.monthIndex &&
                rule.shukla == (observed < 15) &&
                rule.tithi == (observed % 15) + 1,
          );
      if (hit) matches.add(day);
    }
    if (matches.isEmpty) continue;
    LunarDay chosen = matches.first;
    if (rule.when == _When.pradosh) {
      for (final LunarDay day in matches.skip(1)) {
        if (day.date.difference(chosen.date).inDays == 1) {
          chosen = day;
        } else {
          break;
        }
      }
      // Bhadra at dusk pushes the observance to the next evening.
      if (chosen.bhadraAtPradosh) {
        final int index = days.indexOf(chosen);
        if (index >= 0 && index + 1 < days.length) chosen = days[index + 1];
      }
    }
    final int observed = chosen
        .tithisFor(rule.when.index)
        .firstWhere(
          (int t) => rule.tithi == (t % 15) + 1 && rule.shukla == (t < 15),
          orElse: () => chosen.tithiFor(rule.when.index),
        );
    out.add(
      Festival(
        date: chosen.date,
        english: rule.english,
        hindi: rule.hindi,
        detail:
            '${chosen.month} ${observed < 15 ? 'Shukla' : 'Krishna'} ${observed == 29 ? 'Amavasya' : tithiNames[observed % 15]}',
        detailHindi:
            '${lunarMonthsHindi[chosen.monthIndex]} ${observed < 15 ? '\u0936\u0941\u0915\u094d\u0932' : '\u0915\u0943\u0937\u094d\u0923'} ${observed == 29 ? '\u0905\u092e\u093e\u0935\u0938\u094d\u092f\u093e' : tithiNamesHindi[observed % 15]}',
        isMajor: true,
      ),
    );
  }

  for (final LunarDay day in days) {
    if (!includeMonthly) break;
    if (day.tithiInPaksha == 11) {
      out.add(
        Festival(
          date: day.date,
          english: 'Ekadashi',
          hindi: 'एकादशी',
          detail:
              '${day.month} ${day.isShukla ? 'Shukla' : 'Krishna'} Ekadashi, a fasting day',
          detailHindi:
              '${lunarMonthsHindi[day.monthIndex]} एकादशी, व्रत का दिन',
          isMajor: false,
        ),
      );
    } else if (day.tithiIndex == 14) {
      out.add(
        Festival(
          date: day.date,
          english: 'Purnima',
          hindi: 'पूर्णिमा',
          detail: '${day.month} Purnima, the full moon',
          detailHindi: '${lunarMonthsHindi[day.monthIndex]} पूर्णिमा',
          isMajor: false,
        ),
      );
    } else if (day.tithiIndex == 29) {
      out.add(
        Festival(
          date: day.date,
          english: 'Amavasya',
          hindi: 'अमावस्या',
          detail: '${day.month} Amavasya, the new moon',
          detailHindi: '${lunarMonthsHindi[day.monthIndex]} अमावस्या',
          isMajor: false,
        ),
      );
    } else if (!day.isShukla && day.tithiInPaksha == 14) {
      out.add(
        Festival(
          date: day.date,
          english: 'Masik Shivaratri',
          hindi: 'मासिक शिवरात्रि',
          detail: 'The monthly night of Shiva',
          detailHindi: 'मासिक शिवरात्रि',
          isMajor: false,
        ),
      );
    }
  }

  // Sankranti: the Sun changing sign, with Makar Sankranti the best known.
  int previousSign = -1;
  for (final LunarDay day in days) {
    final Instant instant = Instant.fromJulianDayUt(day.sunriseJdUt);
    final double sun = toSidereal(
      positionOf(Graha.sun, instant).tropicalLongitude,
      ayanamsa,
      instant.centuriesTt,
    );
    final int sign = (sun / 30).floor() % 12;
    if (previousSign >= 0 && sign != previousSign) {
      const List<String> names = <String>[
        'Mesha',
        'Vrishabha',
        'Mithuna',
        'Karka',
        'Simha',
        'Kanya',
        'Tula',
        'Vrischika',
        'Dhanu',
        'Makar',
        'Kumbha',
        'Meena',
      ];
      out.add(
        Festival(
          date: day.date,
          english: '${names[sign]} Sankranti',
          hindi: '${rashiTable[sign].hindi} संक्रांति',
          detail: sign == 9
              ? 'Makar Sankranti: the Sun turns north. Kites, til and gur.'
              : 'The Sun enters ${names[sign]}.',
          detailHindi: sign == 9
              ? 'मकर संक्रांति: सूर्य उत्तरायण होते हैं।'
              : 'सूर्य ${rashiTable[sign].hindi} राशि में प्रवेश करते हैं।',
          isMajor: sign == 9,
        ),
      );
    }
    previousSign = sign;
  }

  out.sort((Festival a, Festival b) => a.date.compareTo(b.date));
  return out;
}
