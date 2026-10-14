import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'festivals.dart' show lunarMonths, lunarMonthsHindi;
import 'mat.dart';
import 'panchang.dart';
import 'panchang_tables.dart';
import 'rashi.dart';
import 'tajika_common.dart' show Bi;

/// The calendar context a printed panchang carries at its head: the year in
/// each era, the lunar month in both reckonings, the season, the ayana and the
/// solar month.

/// A name in both languages.
class NamedValue {
  const NamedValue(this.name, this.nameHindi);

  final String name;
  final String nameHindi;
}

/// A lunar month, by its position from Chaitra, and whether it is the extra
/// month that a year with thirteen months carries.
class LunarMonthLabel {
  const LunarMonthLabel({required this.index, required this.isAdhika});

  /// 0 = Chaitra .. 11 = Phalguna.
  final int index;
  final bool isAdhika;

  String get name => '${isAdhika ? 'Adhika ' : ''}${lunarMonths[index]}';
  String get nameHindi =>
      '${isAdhika ? 'अधिक ' : ''}${lunarMonthsHindi[index]}';
}

/// The Sun's sign in one zodiac, with how far into it.
class SolarSign {
  const SolarSign({required this.sign, required this.degrees});

  /// 0 = Mesha .. 11 = Meena.
  final int sign;

  /// Degrees into the sign, 0..30.
  final double degrees;

  String get name => rashiTable[sign].english;
  String get nameHindi => rashiTable[sign].hindi;
}

class PanchangCalendar {
  const PanchangCalendar({
    required this.vikramSamvat,
    required this.shakaSamvat,
    required this.kaliSamvat,
    required this.kaliAhargana,
    required this.samvatsara,
    required this.amanta,
    required this.purnimanta,
    required this.paksha,
    required this.vedicRitu,
    required this.drikRitu,
    required this.vedicAyana,
    required this.drikAyana,
    required this.nirayanaSun,
    required this.sayanaSun,
    required this.previousNewMoonJdUt,
    required this.nextNewMoonJdUt,
  });

  final int vikramSamvat;
  final int shakaSamvat;
  final int kaliSamvat;

  /// Civil days elapsed since the Kali epoch, 18 February 3102 BCE (Julian).
  final int kaliAhargana;

  /// The name of the Shaka year in the sixty-year cycle (Parabhava for Shaka
  /// 1948). See [computePanchangCalendar] for why only this one is given.
  final NamedValue samvatsara;

  final LunarMonthLabel amanta;
  final LunarMonthLabel purnimanta;
  final NamedValue paksha;

  /// Vedic ritu goes by the lunar month; Drik ritu by the tropical Sun.
  final NamedValue vedicRitu;
  final NamedValue drikRitu;

  /// Vedic ayana turns at Makara and Karka Sankranti, Drik ayana at the
  /// solstices.
  final NamedValue vedicAyana;
  final NamedValue drikAyana;

  final SolarSign nirayanaSun;
  final SolarSign sayanaSun;

  /// The new moons either side of the day's sunrise.
  final double previousNewMoonJdUt;
  final double nextNewMoonJdUt;

  /// True when the two reckonings give the month a different name, which is
  /// always so in the dark half and never in the bright half.
  bool get monthsDiffer =>
      amanta.index != purnimanta.index ||
      amanta.isAdhika != purnimanta.isAdhika;
}

/// The new moon nearest [estimateJd], found by bisection on the signed
/// elongation, which climbs through zero at every conjunction.
double _newMoonNear(double estimateJd) {
  double low = estimateJd - 2.2;
  double high = estimateJd + 2.2;
  double signed(double jd) =>
      norm180(lunarElongationAt(Instant.fromJulianDayUt(jd)));
  for (int i = 0; i < 60 && high - low > 1e-6; i++) {
    final double mid = (low + high) / 2;
    if (signed(mid) < 0) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return (low + high) / 2;
}

const double _meanSynodicMonth = 29.530588;

/// The last new moon at or before [jd].
double newMoonAtOrBefore(double jd) {
  final double elongation = lunarElongationAt(Instant.fromJulianDayUt(jd));
  double candidate = _newMoonNear(jd - elongation / 12.19);
  // The estimate can land a few hours either side of the true conjunction.
  while (candidate > jd) {
    candidate = _newMoonNear(candidate - _meanSynodicMonth);
  }
  return candidate;
}

/// The new moon that follows [newMoonJd].
double nextNewMoon(double newMoonJd) =>
    _newMoonNear(newMoonJd + _meanSynodicMonth);

/// The lunar month that runs from one new moon to the next. It is named for
/// the sign the Sun is in when it starts, plus one: Chaitra opens with the Sun
/// in Meena. A month in which the Sun does not change sign holds no
/// Sankranti and is the adhika, the extra month, which takes the name of the
/// nija month after it.
LunarMonthLabel _monthBetween(double startJd, double endJd, Ayanamsa ay) {
  int signAt(double jd) =>
      (siderealLongitudeAt(Graha.sun, Instant.fromJulianDayUt(jd), ay) / 30)
          .floor() %
      12;
  final int start = signAt(startJd);
  return LunarMonthLabel(
    index: (start + 1) % 12,
    isAdhika: start == signAt(endJd),
  );
}

/// The calendar context for [panchang]'s day.
///
/// Conventions, North Indian and Drik:
/// * The Vikram year turns on Chaitra Shukla Pratipada (Chaitradi). Gujarat's
///   Kartikadi year turns after Diwali instead and runs a year ahead from
///   Kartik to Phalguna; it is not shown. An adhika Chaitra still belongs to
///   the old year.
/// * Shaka year = Vikram year - 135, Kali year = Vikram year + 3044.
/// * The month of the day is the one holding sunrise; purnimanta takes the
///   next amanta month's name for the dark half. So the year turns on the
///   first day whose sunrise lies in Chaitra. When Pratipada begins after
///   sunrise (Delhi, 19 March 2026) festival calendars still name that day
///   the new year; this reads it as the next morning, like the rest of the
///   engine reads the Vedic day.
/// * The samvatsara given here is the Shaka year's, in the southern count
///   (one name a year). The name of a Vikram year follows Jupiter in the
///   North and is printed differently by Drik Panchang and the Hindi dailies
///   for the same year; [samvatsaraMatbhed] shows the three names side by
///   side.
PanchangCalendar computePanchangCalendar(Panchang panchang) {
  final double sunrise = panchang.dayStartJdUt;
  final Ayanamsa ay = panchang.ayanamsa;
  final Instant atSunrise = Instant.fromJulianDayUt(sunrise);
  final double sunSidereal = siderealLongitudeAt(Graha.sun, atSunrise, ay);
  final double sunTropical = longitudeOfDate(Graha.sun, atSunrise);

  final double previousNm = newMoonAtOrBefore(sunrise);
  final double nextNm = nextNewMoon(previousNm);
  final LunarMonthLabel amanta = _monthBetween(previousNm, nextNm, ay);
  final bool dark = panchang.tithi.index >= 15;
  final LunarMonthLabel purnimanta = dark
      ? _monthBetween(nextNm, nextNewMoon(nextNm), ay)
      : amanta;

  final DateTime date = panchang.date;
  // The year turns at Chaitra: months Magha and Phalguna, and anything before
  // March, still belong to the year that began the spring before.
  final bool newYearBegun =
      date.month >= 3 &&
      amanta.index != 10 &&
      amanta.index != 11 &&
      !(amanta.isAdhika && amanta.index == 0);
  final int vikram = date.year + (newYearBegun ? 57 : 56);
  final int shaka = vikram - 135;
  final int kali = vikram + 3044;
  final int ahargana =
      (julianDayFromUtc(DateTime.utc(date.year, date.month, date.day)) -
              588465.5)
          .round();

  final int siderealSign = (sunSidereal / 30).floor() % 12;
  final int tropicalSign = (sunTropical / 30).floor() % 12;
  // Uttarayana from Makara through Mithuna (nirayana) or from the December
  // solstice to the June one (sayana).
  final int vedicAyana = siderealSign >= 3 && siderealSign <= 8 ? 1 : 0;
  final int drikAyana = tropicalSign >= 3 && tropicalSign <= 8 ? 1 : 0;
  final int drikRitu = ((tropicalSign + 1) % 12) ~/ 2;
  final int vedicRitu = amanta.index ~/ 2;
  final int samvatsaraIndex = (shaka + 11) % 60;

  return PanchangCalendar(
    vikramSamvat: vikram,
    shakaSamvat: shaka,
    kaliSamvat: kali,
    kaliAhargana: ahargana,
    samvatsara: NamedValue(
      samvatsaraNames[samvatsaraIndex],
      samvatsaraNamesHindi[samvatsaraIndex],
    ),
    amanta: amanta,
    purnimanta: purnimanta,
    paksha: dark
        ? const NamedValue('Krishna paksha', 'कृष्ण पक्ष')
        : const NamedValue('Shukla paksha', 'शुक्ल पक्ष'),
    vedicRitu: NamedValue(rituNames[vedicRitu], rituNamesHindi[vedicRitu]),
    drikRitu: NamedValue(rituNames[drikRitu], rituNamesHindi[drikRitu]),
    vedicAyana: NamedValue(ayanaNames[vedicAyana], ayanaNamesHindi[vedicAyana]),
    drikAyana: NamedValue(ayanaNames[drikAyana], ayanaNamesHindi[drikAyana]),
    nirayanaSun: SolarSign(
      sign: siderealSign,
      degrees: degreesInRashi(sunSidereal),
    ),
    sayanaSun: SolarSign(
      sign: tropicalSign,
      degrees: degreesInRashi(sunTropical),
    ),
    previousNewMoonJdUt: previousNm,
    nextNewMoonJdUt: nextNm,
  );
}

// =============================================================================
// The name of the Vikram year: मतभेद between Drik, the Hindi press and the
// southern count.
//
// What was seen. Drik Panchang's day pages print, under "Lunar Month, Samvat
// and Brihaspati Samvatsara", Vikram 2082 as Kalayukta, 2083 as Siddharthi and
// 2084 as Raudra, with a separate samvatsara row that reads "Siddharthi upto
// 03:53 PM, Apr 21, 2026" and then Raudra; its Shaka row reads 1948 Parabhava.
// Vedpanchang prints Vikram 2083 as Siddharthi. Aaj Tak, Patrika, Amar Ujala
// and Prabhat Khabar name Vikram 2083 Raudra. English Wikipedia's table puts
// Vikram 2083 at Parabhava, the southern count.
//
// What is inferred, and flagged as such. Drik does not state its rule. The one
// that fits every label seen (Vikram 2079 to 2086) is: the Brihaspati
// samvatsara running at Mesha Sankranti names the Vikram year. The Brihaspati
// samvatsara changes every 361.026721 days, the Surya Siddhanta's mean Jovian
// year, which is about 4.23 days shorter than the solar year; Drik's printed
// changeover times (25 Apr 2025, 21 Apr 2026, 17 Apr 2027, 12 Apr 2028) are
// spaced by it. So the model below is anchored on the changeover Drik prints
// for 21 April 2026, 15:53 IST, and counted in mean Jovian years from there.
// The skipped name (Durmati, between 17 Apr 2027 and 12 Apr 2028, which lies
// wholly between two Mesha Sankrantis) comes out of it by itself. The Hindi
// press has no single rule; the one that fits 2080, 2082 and 2083 but not 2081
// is: the samvatsara running on 1 October of the year.
// =============================================================================

/// The mean Jovian year of the Surya Siddhanta, in days.
const double jovianYearDays = 361.026721;

/// The moment the Brihaspati samvatsara changes from Siddharthi to Raudra,
/// as Drik Panchang prints it for New Delhi: 21 April 2026, 15:53 IST.
final DateTime jovianAnchorUtc = DateTime.utc(2026, 4, 21, 10, 23);

/// Raudra, counted from zero at Prabhava.
const int jovianAnchorIndex = 53;

/// The Brihaspati samvatsara running at [utc], counted from zero at Prabhava.
int jovianSamvatsaraIndexAt(DateTime utc) {
  final double days =
      utc.difference(jovianAnchorUtc).inMicroseconds /
      Duration.microsecondsPerDay;
  final int steps = (days / jovianYearDays).floor();
  return (((jovianAnchorIndex + steps) % 60) + 60) % 60;
}

/// When the Brihaspati samvatsara running at [utc] began.
DateTime jovianSamvatsaraStartUtc(DateTime utc) {
  final double days =
      utc.difference(jovianAnchorUtc).inMicroseconds /
      Duration.microsecondsPerDay;
  final int steps = (days / jovianYearDays).floor();
  return jovianAnchorUtc.add(
    Duration(
      microseconds: (steps * jovianYearDays * Duration.microsecondsPerDay)
          .round(),
    ),
  );
}

/// The instant the Sun enters sidereal Mesha in [year] (Gregorian), in UT.
DateTime meshaSankrantiUtc(int year, Ayanamsa ay) {
  double lo = Instant.fromUtc(DateTime.utc(year, 4, 8)).julianDayUt;
  double hi = Instant.fromUtc(DateTime.utc(year, 4, 20)).julianDayUt;
  double signed(double jd) =>
      norm180(siderealLongitudeAt(Graha.sun, Instant.fromJulianDayUt(jd), ay));
  for (int i = 0; i < 60; i++) {
    final double mid = (lo + hi) / 2;
    if (signed(mid) < 0) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return utcFromJulianDay((lo + hi) / 2);
}

/// The name Drik Panchang gives the Vikram year [vikram]: the Brihaspati
/// samvatsara running at that year's Mesha Sankranti (see the note above).
int drikVikramNameIndex(int vikram, Ayanamsa ay) =>
    jovianSamvatsaraIndexAt(meshaSankrantiUtc(vikram - 57, ay));

/// The name the Hindi press gives the Vikram year [vikram], on the rule that
/// fits most of what was printed: the samvatsara running on 1 October.
int pressVikramNameIndex(int vikram) =>
    jovianSamvatsaraIndexAt(DateTime.utc(vikram - 57, 10, 1));

/// The southern count: one name a year, from the Shaka year.
int southernNameIndex(int shaka) => (shaka + 11) % 60;

Bi _samvatsaraBi(int index) => Bi(
  '${samvatsaraNames[index]} (${index + 1} of 60)',
  '${samvatsaraNamesHindi[index]} (60 में से ${index + 1})',
);

/// The three names of this day's Vikram year, side by side. Each view's
/// `value` is the name's place in the sixty-year cycle, counted from one.
Matbhed samvatsaraMatbhed(PanchangCalendar calendar, Panchang panchang) {
  final Ayanamsa ay = panchang.ayanamsa;
  final int vikram = calendar.vikramSamvat;
  final int drik = drikVikramNameIndex(vikram, ay);
  final int press = pressVikramNameIndex(vikram);
  final int south = southernNameIndex(calendar.shakaSamvat);
  final int drikAhead = (drik - south + 60) % 60;
  final int pressAhead = (press - south + 60) % 60;
  final DateTime sunrise = utcFromJulianDay(panchang.dayStartJdUt);
  final int running = jovianSamvatsaraIndexAt(sunrise);
  final DateTime since = jovianSamvatsaraStartUtc(
    sunrise,
  ).add(panchang.utcOffset);
  final String sinceEn =
      '${since.day} ${_months[since.month - 1]} ${since.year}';
  final String sinceHi =
      '${since.day} ${_monthsHindi[since.month - 1]} ${since.year}';
  return Matbhed(
    key: 'samvatsara',
    topic: Bi(
      'The name of Vikram ${calendar.vikramSamvat}',
      'विक्रम ${calendar.vikramSamvat} का नाम',
    ),
    whyTheyDiffer: Bi(
      'The sixty names go round in a fixed order, but the north counts them '
          'by Jupiter and the south by the calendar. A Jupiter-year is about 361 '
          'days, four days short of the solar year, so about every 85 years a '
          'name is skipped and the north runs further ahead of the south: '
          '${_samvatsaraBi(drik).en} is $drikAhead places ahead of ${_samvatsaraBi(south).en}, '
          'and ${_samvatsaraBi(press).en} is $pressAhead. The Vikram year begins in March '
          'or April, close to the day the Jupiter-name changes, so it can be '
          'called by either of two neighbouring names. (The “12 years” '
          'sometimes quoted is the gap of the Gujarati count today, which adds '
          '9 to the Vikram year, and on our model it was also the gap of the '
          'Jupiter count until about 1942; each skipped name adds one.)',
      'साठ नाम एक तय क्रम में घूमते हैं, पर उत्तर उन्हें बृहस्पति से गिनता है और '
          'दक्षिण कैलेंडर से। बृहस्पति का वर्ष लगभग 361 दिन का है, सौर वर्ष से चार '
          'दिन छोटा, इसलिए लगभग हर 85 वर्ष में एक नाम छूट जाता है और उत्तर दक्षिण से '
          'और आगे निकल जाता है: ${_samvatsaraBi(drik).hi} ${_samvatsaraBi(south).hi} '
          'से $drikAhead स्थान आगे है, और ${_samvatsaraBi(press).hi} $pressAhead स्थान आगे है। विक्रम वर्ष मार्च या '
          'अप्रैल में शुरू होता है, उस दिन के पास जब बृहस्पति का नाम बदलता है, इसलिए '
          'उसे दो पड़ोसी नामों में से किसी से भी बुलाया जा सकता है। (कभी-कभी कहा '
          'जाने वाला “12 वर्ष” आज गुजराती गणना का अंतर है, जो विक्रम वर्ष में 9 जोड़ती '
          'है, और हमारे मॉडल में लगभग 1942 तक बृहस्पति वाली गणना का भी था; हर छूटा '
          'हुआ नाम एक जोड़ता है।)',
    ),
    defaultReason: const Bi(
      'For the Vikram year the app follows the North Indian reading that Drik '
          'Panchang prints, as it does elsewhere. The southern name is the one '
          'the calendar above has always shown for the Shaka year.',
      'विक्रम वर्ष के लिए ऐप वही उत्तर भारतीय पाठ लेता है जो ड्रिक पंचांग छापता है, '
          'जैसा वह बाकी जगह करता है। दक्षिणी नाम वही है जो ऊपर की तिथि-सूची शक वर्ष '
          'के लिए हमेशा से दिखाती आई है।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: drik + 1.0,
        position: const Bi(
          'The Vikram year takes the name of the Jupiter-samvatsara running at '
              'Mesha Sankranti, the Sun’s entry into Mesha in April.',
          'विक्रम वर्ष उस बृहस्पति-संवत्सर का नाम लेता है जो मेष संक्रांति, यानी अप्रैल '
              'में सूर्य के मेष में प्रवेश, पर चल रहा हो।',
        ),
        holder: const Bi(
          'Drik Panchang and Vedpanchang, both of which print this name for the '
              'year; the rule itself is not stated by either and is our '
              'reading of what they print (it fits every year from Vikram 2079 '
              'to 2086)',
          'ड्रिक पंचांग और वेदपंचांग, दोनों यही नाम छापते हैं; नियम दोनों में कहीं '
              'लिखा नहीं, वह उनके छापे का हमारा पाठ है (वह विक्रम 2079 से 2086 के '
              'हर वर्ष से मेल खाता है)',
        ),
        reasoning: const Bi(
          'The year begins in the name that is running when the Sun enters '
              'Mesha, so it keeps that name even after Jupiter’s name '
              'changes a week or two later. Drik’s separate row shows the later '
              'name from the day it changes.',
          'वर्ष उसी नाम से शुरू होता है जो सूर्य के मेष में जाते समय चल रहा हो, इसलिए '
              'बृहस्पति का नाम एक-दो सप्ताह बाद बदलने पर भी वह वही रहता है। ड्रिक की '
              'अलग पंक्ति बाद वाला नाम बदलने के दिन से दिखाती है।',
        ),
        result: Bi(
          'Vikram ${calendar.vikramSamvat}: ${_samvatsaraBi(drik).en}. The Jupiter-'
              'samvatsara running on this day is ${_samvatsaraBi(running).en}, '
              'since about $sinceEn.',
          'विक्रम ${calendar.vikramSamvat}: ${_samvatsaraBi(drik).hi}। इस दिन '
              'बृहस्पति-संवत्सर ${_samvatsaraBi(running).hi} चल रहा है, लगभग '
              '$sinceHi से।',
        ),
      ),
      Mat(
        value: press + 1.0,
        position: const Bi(
          'The Vikram year is called by the name that runs for most of it, taken '
              'here as the Jupiter-samvatsara running on 1 October.',
          'विक्रम वर्ष को उस नाम से बुलाया जाता है जो उसके अधिकांश भाग में चलता है, यहाँ '
              '1 अक्तूबर को चल रहा बृहस्पति-संवत्सर माना गया है।',
        ),
        holder: const Bi(
          'The Hindi dailies: Aaj Tak, Patrika, Amar Ujala and Prabhat Khabar all '
              'printed Raudra for Vikram 2083 in March 2026 (Amar Ujala’s Varanasi '
              'report adds that a samvatsara is skipped this year). They state no '
              'rule, and they have not been steady from year to year (Pingala '
              'for both 2080 and 2081, and two names offered for 2079); the 1 '
              'October rule is our guess that fits 2080, 2082 and 2083 but not '
              '2081',
          'हिंदी दैनिक: आज तक, पत्रिका, अमर उजाला और प्रभात खबर ने मार्च 2026 में '
              'विक्रम 2083 के लिए रौद्र छापा (अमर उजाला की वाराणसी रिपोर्ट जोड़ती है कि '
              'इस वर्ष एक संवत्सर छूट रहा है)। वे कोई नियम नहीं बताते, और वे साल-दर-साल '
              'एक-से नहीं रहे (2080 और 2081 दोनों के लिए पिंगल, और 2079 के लिए दो '
              'नाम); 1 अक्तूबर वाला नियम हमारा अनुमान है जो 2080, 2082 और 2083 से मेल '
              'खाता है पर 2081 से नहीं',
        ),
        reasoning: const Bi(
          'The name that rules most of the year is the one the year lives '
              'under, so the early weeks before Jupiter’s name changes are '
              'counted with the later name.',
          'जो नाम वर्ष के अधिकांश भाग पर राज करता है वही वर्ष का नाम है, इसलिए '
              'बृहस्पति का नाम बदलने से पहले के आरंभिक सप्ताह भी बाद वाले नाम के साथ '
              'गिने जाते हैं।',
        ),
        result: Bi(
          'Vikram ${calendar.vikramSamvat}: ${_samvatsaraBi(press).en}.',
          'विक्रम ${calendar.vikramSamvat}: ${_samvatsaraBi(press).hi}।',
        ),
      ),
      Mat(
        value: south + 1.0,
        position: const Bi(
          'One name a year, counted from the Shaka year, with no skipped name.',
          'हर वर्ष एक नाम, शक वर्ष से गिना हुआ, कोई नाम छूटता नहीं।',
        ),
        holder: const Bi(
          'The southern count: Drik Panchang’s Shaka row, English Wikipedia’s '
              'table of the sixty years, and PyJHora’s code',
          'दक्षिणी गणना: ड्रिक पंचांग की शक वाली पंक्ति, अंग्रेज़ी विकिपीडिया की साठ वर्षों '
              'की तालिका, और PyJHora का कोड',
        ),
        reasoning: const Bi(
          'The south dropped the skipped name about a thousand years ago and '
              'counts the sixty names as a plain cycle by the year; Wikipedia '
              'dates the change to around AD 905 to 909.',
          'दक्षिण ने छूटने वाला नाम लगभग हज़ार वर्ष पहले छोड़ दिया और साठ नामों को वर्ष '
              'के हिसाब से सीधे चक्र की तरह गिनता है; विकिपीडिया इस बदलाव का समय '
              'लगभग ईसवी 905 से 909 बताता है।',
        ),
        result: Bi(
          'Shaka ${calendar.shakaSamvat}: ${_samvatsaraBi(south).en}.',
          'शक ${calendar.shakaSamvat}: ${_samvatsaraBi(south).hi}।',
        ),
      ),
    ],
  );
}

const List<String> _months = <String>[
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

const List<String> _monthsHindi = <String>[
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
