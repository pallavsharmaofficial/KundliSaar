import '../../engine/astro/ayanamsa.dart';
import '../../engine/astro/ephemeris.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/dasha.dart';
import '../../engine/jyotish/ghat_chakra.dart';
import '../../engine/jyotish/mat.dart';
import '../../engine/jyotish/numerology.dart';
import '../../engine/jyotish/panchang.dart';
import '../../engine/jyotish/panchang_calendar.dart';
import '../../engine/jyotish/panchang_details.dart';
import '../../engine/jyotish/phaladesh.dart';
import '../../engine/jyotish/remedies.dart';
import '../../engine/jyotish/sudarshan.dart';
import '../../engine/jyotish/upagrahas.dart';
import '../../engine/jyotish/varshphal.dart';
import '../../engine/jyotish/yogas.dart';

/// What the engine works out for one person, gathered once so every section
/// reads the same numbers. Nothing in here is computed twice and nothing is
/// computed by the PDF code itself.
class KundliPdfData {
  KundliPdfData._({
    required this.kundli,
    required this.phala,
    required this.gochar,
    required this.yogaMatbhed,
    required this.varshphal,
    required this.varshAge,
    required this.panchang,
    required this.calendar,
    required this.dayMatbhed,
    required this.sudarshan,
    required this.sudarshanViews,
    required this.ghat,
    required this.ghatMatbhed,
    required this.upagrahas,
    required this.upagrahaViews,
    required this.numerology,
    required this.remedies,
    required this.sadeSati,
    required this.yogini,
    required this.now,
  });

  /// Works everything out for [birth] as of [now]. The varshphal is the one for
  /// the year of life running at [now].
  ///
  /// [breathe], when given, is awaited between the heavier steps, so that a
  /// platform with only one thread can redraw while the work goes on.
  static Future<KundliPdfData> compute(
    BirthData birth, {
    required Ayanamsa ayanamsa,
    required DateTime now,
    Future<void> Function()? breathe,
  }) async {
    Future<void> pause() async => breathe == null ? null : await breathe();
    final Kundli kundli = computeKundli(birth, ayanamsa: ayanamsa);

    await pause();
    final Phaladesh phala = computePhaladesh(kundli);
    final GocharPhala gochar = phala.gochar(now: now);

    await pause();
    final List<YogaMatbhed> yogaMatbhed = findYogaMatbhed(kundli);
    final SadeSati sadeSati = sadeSatiStatus(kundli, now);

    await pause();
    final DateTime local = now.toUtc().add(birth.utcOffset);
    final DateTime born = birth.localDateTime;
    int age = local.year - born.year;
    if (DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    ).isBefore(
      DateTime(local.year, born.month, born.day, born.hour, born.minute),
    )) {
      age -= 1;
    }
    if (age < 0) age = 0;
    final Varshphal varshphal = computeVarshphal(
      kundli,
      age,
      ayanamsa: ayanamsa,
    );

    await pause();
    final Panchang panchang = computePanchang(
      localDate: DateTime(born.year, born.month, born.day),
      utcOffset: birth.utcOffset,
      place: birth.place,
      ayanamsa: ayanamsa,
    );
    final PanchangCalendar calendar = computePanchangCalendar(panchang);
    final PanchangDetails details = computePanchangDetails(panchang);

    await pause();
    return KundliPdfData._(
      kundli: kundli,
      phala: phala,
      gochar: gochar,
      yogaMatbhed: yogaMatbhed,
      varshphal: varshphal,
      varshAge: age,
      panchang: panchang,
      calendar: calendar,
      dayMatbhed: details.matbhed,
      sudarshan: computeSudarshan(kundli),
      sudarshanViews: sudarshanMatbhed(kundli),
      ghat: ghatChakraOf(kundli),
      ghatMatbhed: <Matbhed>[
        ghatChakraMatbhed(kundli),
        ghatMonthMatbhed(kundli, birth.localDateTime),
      ],
      upagrahas: computeUpagrahas(kundli),
      upagrahaViews: upagrahaMatbhed(kundli),
      numerology: computeNumerology(
        birthDate: birth.localDateTime,
        name: birth.name,
      ),
      remedies: remediesFor(kundli, limit: 4),
      sadeSati: sadeSati,
      yogini: yoginiDasha(
        moonSiderealLongitude: kundli.grahas[Graha.moon]!.siderealLongitude,
        birthJdUt: kundli.instant.julianDayUt,
      ),
      now: now,
    );
  }

  final Kundli kundli;
  final Phaladesh phala;
  final GocharPhala gochar;
  final List<YogaMatbhed> yogaMatbhed;
  final Varshphal varshphal;
  final int varshAge;
  final Panchang panchang;
  final PanchangCalendar calendar;
  final List<Matbhed> dayMatbhed;
  final SudarshanChakra sudarshan;
  final Matbhed sudarshanViews;
  final GhatChakraReading ghat;
  final List<Matbhed> ghatMatbhed;
  final UpagrahaResult upagrahas;
  final List<Matbhed> upagrahaViews;
  final NumerologyReading numerology;
  final List<RemedySet> remedies;
  final SadeSati sadeSati;
  final List<YoginiPeriod> yogini;
  final DateTime now;

  List<YogaFinding> get yogas => phala.context.yogas;
  Duration get zone => kundli.birth.utcOffset;
}
