import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'festivals.dart' show lunarMonths, lunarMonthsHindi;
import 'panchang.dart';
import 'panchang_tables.dart';
import 'rashi.dart';

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
/// * Only the Shaka samvatsara name is given. The names of Vikram years in
///   the sixty-year cycle follow Jupiter in the North and are printed
///   differently by Drik Panchang and the Hindi dailies for the same year, so
///   no single North Indian name could be established.
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
