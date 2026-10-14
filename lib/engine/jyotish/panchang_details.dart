import 'dart:math' as math;

import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'mat.dart';
import 'nakshatra.dart';
import 'panchang.dart';
import 'panchang_calendar.dart';
import 'panchang_tables.dart';
import 'rashi.dart';
import 'tajika_common.dart' show Bi;

// Everything a printed panchang carries beyond the five limbs, cut from the
// same Sun and Moon the limbs are: windows with exact start and end, the
// auspicious and inauspicious yogas, the Anandadi yoga, and the chandra and
// tara balas. computePanchang stays as light as it was for the muhurta finder;
// computePanchangDetails is the heavier second pass a screen asks for.

/// One stretch of one sub-rule, for rules that change part-way (Bhadra's
/// dwelling as the Moon changes sign, the several nakshatras of a Gand Mool).
class WindowPart {
  const WindowPart({
    required this.startJdUt,
    required this.endJdUt,
    required this.detail,
    required this.detailHindi,
    required this.tone,
  });

  final double startJdUt;
  final double endJdUt;
  final String detail;
  final String detailHindi;
  final PanchangTone tone;
}

/// A named window with its exact start and end.
///
/// Windows that depend on the weekday (the siddhi and pushkar yogas) are cut
/// to the Vedic day, sunrise to the next sunrise, because the vara changes at
/// sunrise. Windows that do not (Panchak, Bhadra, Gand Mool, Vinchhudo,
/// Jwalamukhi, Ravi, Aadal and Vidaal) run for their full length and may
/// begin before the day or end after it.
class PanchangWindow {
  const PanchangWindow({
    required this.note,
    required this.startJdUt,
    required this.endJdUt,
    this.label = '',
    this.labelHindi = '',
    this.detail = '',
    this.detailHindi = '',
    this.parts = const <WindowPart>[],
  });

  final RuleNote note;
  final double startJdUt;
  final double endJdUt;

  /// What this particular window is (the kind of Panchak, the nakshatras of a
  /// Gand Mool, the pair a Jwalamukhi is made of), in both languages.
  final String label;
  final String labelHindi;

  /// A further line specific to this window.
  final String detail;
  final String detailHindi;
  final List<WindowPart> parts;

  String get key => note.key;
  String get name => note.name;
  String get nameHindi => note.nameHindi;
  String get meaning => note.meaning;
  String get meaningHindi => note.meaningHindi;
  PanchangTone get tone => note.tone;

  bool overlaps(double fromJdUt, double toJdUt) =>
      startJdUt < toJdUt && endJdUt > fromJdUt;
}

/// A stretch of the Vedic day under one Anandadi yoga.
class AnandadiSpan {
  const AnandadiSpan({
    required this.index,
    required this.startJdUt,
    required this.endJdUt,
  });

  /// 0 = Ananda .. 27 = Vardhamana.
  final int index;
  final double startJdUt;
  final double endJdUt;

  AnandadiInfo get info => anandadiTable[index];
}

/// A stretch of the Vedic day with the Moon in one sign and one nakshatra.
class MoonSegment {
  const MoonSegment({
    required this.startJdUt,
    required this.endJdUt,
    required this.rashi,
    required this.nakshatra,
  });

  final double startJdUt;
  final double endJdUt;

  /// 0 = Mesha .. 11 = Meena.
  final int rashi;

  /// 0 = Ashwini .. 26 = Revati.
  final int nakshatra;
}

class PanchangDetails {
  const PanchangDetails({
    required this.panchang,
    required this.calendar,
    required this.dayStartJdUt,
    required this.dayEndJdUt,
    required this.panchak,
    required this.bhadra,
    required this.gandMool,
    required this.vinchhudo,
    required this.jwalamukhi,
    required this.aadal,
    required this.vidaal,
    required this.dishaShool,
    required this.auspicious,
    required this.anandadi,
    required this.moonSegments,
    this.matbhed = const <Matbhed>[],
  });

  final Panchang panchang;
  final PanchangCalendar calendar;

  /// The Vedic day: this sunrise to the next.
  final double dayStartJdUt;
  final double dayEndJdUt;

  /// The Panchak running at any point of the day, from its first moment to
  /// its last, or null on a day with none.
  final PanchangWindow? panchak;
  final List<PanchangWindow> bhadra;
  final List<PanchangWindow> gandMool;
  final PanchangWindow? vinchhudo;
  final List<PanchangWindow> jwalamukhi;
  final List<PanchangWindow> aadal;
  final List<PanchangWindow> vidaal;
  final DishaShool dishaShool;

  /// Sarvartha Siddhi, Amrit Siddhi, Ravi Pushya, Guru Pushya, Ravi Yoga,
  /// Dwipushkar and Tripushkar, by start time.
  final List<PanchangWindow> auspicious;
  final List<AnandadiSpan> anandadi;

  /// The Moon's signs and nakshatras across the day, the input to the balas.
  final List<MoonSegment> moonSegments;

  /// The rules of the day on which the panchang traditions differ, each as a
  /// "Two views" card worked out for this day (the year's name, Ravi Yoga,
  /// Tripushkar, the kind of Panchak, where Bhadra dwells).
  final List<Matbhed> matbhed;

  /// Every inauspicious window of the day, by start time.
  List<PanchangWindow> get inauspicious {
    final List<PanchangWindow> all = <PanchangWindow>[
      ?panchak,
      ...bhadra,
      ...gandMool,
      ?vinchhudo,
      ...jwalamukhi,
      ...aadal,
      ...vidaal,
    ];
    all.sort(
      (PanchangWindow a, PanchangWindow b) =>
          a.startJdUt.compareTo(b.startJdUt),
    );
    return all;
  }

  /// Every window the day has, auspicious or not.
  List<PanchangWindow> get allWindows => <PanchangWindow>[
    ...auspicious,
    ...inauspicious,
  ];
}

// ---------------------------------------------------------------------------
// The timeline the day is cut into
// ---------------------------------------------------------------------------

/// A stretch over which every quantity the rules read is constant.
class _Seg {
  const _Seg({
    required this.start,
    required this.end,
    required this.tithi,
    required this.karana,
    required this.nakshatra,
    required this.rashi,
    required this.sunNakshatra,
  });

  final double start;
  final double end;

  /// 0..29 from the new moon.
  final int tithi;

  /// 0..59 from the new moon.
  final int karana;
  final int nakshatra;
  final int rashi;
  final int sunNakshatra;

  /// 1..15 within the paksha; Purnima and Amavasya are both 15.
  int get tithiInPaksha => tithi % 15 + 1;

  /// The Moon's nakshatra counted from the Sun's, the Sun's own being 1, in
  /// the 27 nakshatras.
  int get countFromSun27 => (nakshatra - sunNakshatra) % 27 + 1;

  /// The same count in the 28-nakshatra series that has Abhijit in it.
  int get countFromSun28 =>
      (nakshatraPosition28(nakshatra) - nakshatraPosition28(sunNakshatra)) %
          28 +
      1;
}

/// Where each quantity next passes a multiple of [span], from [lo] to [hi].
List<double> _boundaries(
  double Function(Instant) value,
  double span,
  double lo,
  double hi, {
  required double minRate,
  required double maxRate,
}) {
  final List<double> out = <double>[];
  double from = lo;
  while (true) {
    final double v = value(Instant.fromJulianDayUt(from));
    final double target = ((v / span).floor() + 1) * span;
    final double t = crossingAfter(
      value,
      target,
      from,
      minRate: minRate,
      maxRate: maxRate,
    );
    if (t >= hi) break;
    out.add(t);
    // Step clear of the boundary; no span is crossed in under three minutes.
    from = t + 0.002;
  }
  return out;
}

List<_Seg> _timeline(Ayanamsa ay, double lo, double hi) {
  double moon(Instant i) => siderealLongitudeAt(Graha.moon, i, ay);
  double sun(Instant i) => siderealLongitudeAt(Graha.sun, i, ay);

  final List<double> cuts = <double>[
    lo,
    hi,
    ..._boundaries(
      moon,
      nakshatraSpan,
      lo,
      hi,
      minRate: moonRateMin,
      maxRate: moonRateMax,
    ),
    ..._boundaries(
      moon,
      30.0,
      lo,
      hi,
      minRate: moonRateMin,
      maxRate: moonRateMax,
    ),
    ..._boundaries(
      lunarElongationAt,
      6.0,
      lo,
      hi,
      minRate: elongationRateMin,
      maxRate: elongationRateMax,
    ),
    ..._boundaries(
      sun,
      nakshatraSpan,
      lo,
      hi,
      minRate: sunRateMin,
      maxRate: sunRateMax,
    ),
  ]..sort();

  // Boundaries that coincide (a nakshatra and a sign ending together at 120
  // degrees, a tithi and a karana ending together) are found as separate
  // roots a few millionths of a day apart; keep one of each pair so the
  // segments tile with no gap and no sliver.
  final List<double> joints = <double>[];
  for (final double cut in cuts) {
    if (joints.isEmpty || cut - joints.last > 1e-5) joints.add(cut);
  }

  final List<_Seg> out = <_Seg>[];
  for (int i = 0; i + 1 < joints.length; i++) {
    final double start = joints[i];
    final double end = joints[i + 1];
    final Instant mid = Instant.fromJulianDayUt((start + end) / 2);
    final double elongation = lunarElongationAt(mid);
    final double moonLon = moon(mid);
    out.add(
      _Seg(
        start: start,
        end: end,
        tithi: (elongation / 12.0).floor() % 30,
        karana: (elongation / 6.0).floor() % 60,
        nakshatra: nakshatraIndexOf(moonLon),
        rashi: (moonLon / 30.0).floor() % 12,
        sunNakshatra: nakshatraIndexOf(sun(mid)),
      ),
    );
  }
  return out;
}

/// A run of adjacent segments the test holds for.
class _Run {
  _Run(this.start, this.end, _Seg first) : segs = <_Seg>[first];

  double start;
  double end;
  final List<_Seg> segs;
}

/// The runs of [segs] where [test] holds. With [clipLo] and [clipHi] the
/// segments are cut to that interval first. [key], when given, splits a run
/// wherever its value changes.
List<_Run> _runs(
  List<_Seg> segs,
  bool Function(_Seg) test, {
  Object? Function(_Seg)? key,
  double? clipLo,
  double? clipHi,
}) {
  final List<_Run> runs = <_Run>[];
  _Run? open;
  Object? openKey;
  for (final _Seg seg in segs) {
    final double start = clipLo == null
        ? seg.start
        : math.max(seg.start, clipLo);
    final double end = clipHi == null ? seg.end : math.min(seg.end, clipHi);
    if (end - start <= 1e-6) {
      open = null;
      continue;
    }
    if (!test(seg)) {
      open = null;
      continue;
    }
    final Object? k = key?.call(seg);
    if (open != null && (open.end - start).abs() < 1e-5 && k == openKey) {
      open.end = end;
      open.segs.add(seg);
    } else {
      open = _Run(start, end, seg);
      openKey = k;
      runs.add(open);
    }
  }
  return runs;
}

/// "1st", "2nd", "3rd", "4th", ...
String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

String _joinNames(Iterable<String> names) => names.join(', ');

List<int> _distinctInOrder(Iterable<int> values) {
  final List<int> out = <int>[];
  for (final int v in values) {
    if (!out.contains(v)) out.add(v);
  }
  return out;
}

// ---------------------------------------------------------------------------
// The details
// ---------------------------------------------------------------------------

/// The stretch of the Moon's path from [fromDeg] to [toDeg] (sidereal) that
/// touches the Vedic day, from the moment it entered to the moment it leaves,
/// or null if the Moon is not in it at any point of the day.
({double start, double end})? _moonStretch(
  double Function(Instant) moon,
  double fromDeg,
  double toDeg,
  double dayStart,
  double dayEnd,
) {
  final double width = norm360(toDeg - fromDeg);
  bool inside(double lon) => norm360(lon - fromDeg) < width;
  final double atStart = moon(Instant.fromJulianDayUt(dayStart));
  final double atEnd = moon(Instant.fromJulianDayUt(dayEnd));
  if (inside(atStart)) {
    return (
      start: crossingBefore(
        moon,
        fromDeg,
        dayStart,
        minRate: moonRateMin,
        maxRate: moonRateMax,
      ),
      end: crossingAfter(
        moon,
        toDeg,
        dayStart,
        minRate: moonRateMin,
        maxRate: moonRateMax,
      ),
    );
  }
  if (inside(atEnd)) {
    final double start = crossingAfter(
      moon,
      fromDeg,
      dayStart,
      minRate: moonRateMin,
      maxRate: moonRateMax,
    );
    return (
      start: start,
      end: crossingAfter(
        moon,
        toDeg,
        start + 0.01,
        minRate: moonRateMin,
        maxRate: moonRateMax,
      ),
    );
  }
  return null;
}

int _civilWeekday(double jdUt, Duration offset) =>
    utcFromJulianDay(jdUt).add(offset).weekday % 7;

/// Builds everything beyond the five limbs for [panchang]'s Vedic day.
PanchangDetails computePanchangDetails(Panchang panchang) {
  final Ayanamsa ay = panchang.ayanamsa;
  final int weekday = panchang.weekday;
  final double dayStart = panchang.dayStartJdUt;
  final DateTime date = panchang.date;

  final Instant nextMidnight = Instant.fromLocal(
    DateTime(date.year, date.month, date.day + 1),
    panchang.utcOffset,
  );
  final double dayEnd =
      findRiseSet(
        Graha.sun,
        nextMidnight.julianDayUt,
        panchang.place,
        horizon: sunHorizon,
      ).rise ??
      dayStart + 1.0;

  double moon(Instant i) => siderealLongitudeAt(Graha.moon, i, ay);

  final PanchangCalendar calendar = computePanchangCalendar(panchang);

  // Three days either side is more than any nakshatra, tithi or pair of
  // adjacent nakshatras lasts, so a window's true ends are inside.
  final List<_Seg> timeline = _timeline(ay, dayStart - 3.0, dayEnd + 3.0);
  bool touchesDay(double start, double end) =>
      end > dayStart + 1e-6 && start < dayEnd - 1e-6;

  List<_Run> dayRuns(bool Function(_Seg) test) =>
      _runs(timeline, test, clipLo: dayStart, clipHi: dayEnd);
  List<_Run> fullRuns(
    bool Function(_Seg) test, {
    Object? Function(_Seg)? key,
  }) => _runs(
    timeline,
    test,
    key: key,
  ).where((_Run r) => touchesDay(r.start, r.end)).toList();

  String nakNames(Iterable<int> naks, {required bool hindi}) => _joinNames(
    _distinctInOrder(naks).map(
      (int n) => hindi ? nakshatraTable[n].hindi : nakshatraTable[n].english,
    ),
  );

  // --- Panchak ------------------------------------------------------------
  PanchangWindow? panchak;
  final ({double start, double end})? panchakSpan = _moonStretch(
    moon,
    panchakStartDegree,
    360.0,
    dayStart,
    dayEnd,
  );
  if (panchakSpan != null) {
    final PanchakKind kind =
        panchakKinds[_civilWeekday(panchakSpan.start, panchang.utcOffset)];
    panchak = PanchangWindow(
      note: panchakNote,
      startJdUt: panchakSpan.start,
      endJdUt: panchakSpan.end,
      label: kind.name,
      labelHindi: kind.nameHindi,
      detail: kind.meaning,
      detailHindi: kind.meaningHindi,
    );
  }

  // --- Vinchhudo ----------------------------------------------------------
  PanchangWindow? vinchhudo;
  final ({double start, double end})? vinchhudoSpan = _moonStretch(
    moon,
    vinchhudoSign * 30.0,
    (vinchhudoSign + 1) * 30.0,
    dayStart,
    dayEnd,
  );
  if (vinchhudoSpan != null) {
    vinchhudo = PanchangWindow(
      note: vinchhudoNote,
      startJdUt: vinchhudoSpan.start,
      endJdUt: vinchhudoSpan.end,
    );
  }

  // --- Bhadra -------------------------------------------------------------
  final List<PanchangWindow> bhadra = <PanchangWindow>[
    for (final _Run run in fullRuns((_Seg s) => isVishtiKarana(s.karana)))
      _bhadraWindow(run),
  ];

  // --- Gand Mool ----------------------------------------------------------
  // One window to each nakshatra: each has its own deity to propitiate, and
  // Ashlesha-Magha, Jyeshtha-Mula and Revati-Ashwini follow one another.
  final List<PanchangWindow> gandMool = <PanchangWindow>[
    for (final _Run run in fullRuns(
      (_Seg s) => gandMoolNakshatras.contains(s.nakshatra),
      key: (_Seg s) => s.nakshatra,
    ))
      _gandMoolWindow(run),
  ];

  // --- Jwalamukhi ---------------------------------------------------------
  final List<PanchangWindow> jwalamukhi = <PanchangWindow>[
    for (final _Run run in fullRuns(
      (_Seg s) => jwalamukhiPairs[s.tithiInPaksha] == s.nakshatra,
      key: (_Seg s) => s.tithi,
    ))
      PanchangWindow(
        note: jwalamukhiNote,
        startJdUt: run.start,
        endJdUt: run.end,
        label:
            '${tithiNames[run.segs.first.tithiInPaksha - 1]} with '
            '${nakshatraTable[run.segs.first.nakshatra].english}',
        labelHindi:
            '${tithiNamesHindi[run.segs.first.tithiInPaksha - 1]}, '
            '${nakshatraTable[run.segs.first.nakshatra].hindi}',
      ),
  ];

  // --- Aadal and Vidaal ---------------------------------------------------
  PanchangWindow countWindow(RuleNote note, _Run run) {
    final List<int> counts = _distinctInOrder(
      run.segs.map((_Seg s) => s.countFromSun28),
    );
    return PanchangWindow(
      note: note,
      startJdUt: run.start,
      endJdUt: run.end,
      label: "${counts.map(_ordinal).join(', ')} from the Sun's nakshatra",
      labelHindi:
          'सूर्य नक्षत्र से ${counts.map((int c) => '$cवाँ').join(', ')}',
    );
  }

  final List<PanchangWindow> aadal = <PanchangWindow>[
    for (final _Run run in fullRuns(
      (_Seg s) => aadalCounts.contains(s.countFromSun28),
    ))
      countWindow(aadalNote, run),
  ];
  final List<PanchangWindow> vidaal = <PanchangWindow>[
    for (final _Run run in fullRuns(
      (_Seg s) => vidaalCounts.contains(s.countFromSun28),
    ))
      countWindow(vidaalNote, run),
  ];

  // --- Auspicious yogas ---------------------------------------------------
  final List<PanchangWindow> auspicious = <PanchangWindow>[];
  final String dayEn = weekdayNames[weekday];
  final String dayHi = weekdayNamesHindi[weekday];

  // Weekday-bound yogas are cut to the Vedic day.
  for (final _Run run in dayRuns(
    (_Seg s) => sarvarthaSiddhiNakshatras[weekday].contains(s.nakshatra),
  )) {
    auspicious.add(
      PanchangWindow(
        note: sarvarthaSiddhiNote,
        startJdUt: run.start,
        endJdUt: run.end,
        label:
            '$dayEn with ${nakNames(run.segs.map((_Seg s) => s.nakshatra), hindi: false)}',
        labelHindi:
            '$dayHi, ${nakNames(run.segs.map((_Seg s) => s.nakshatra), hindi: true)}',
      ),
    );
  }
  for (final _Run run in dayRuns(
    (_Seg s) => amritSiddhiNakshatra[weekday] == s.nakshatra,
  )) {
    auspicious.add(
      PanchangWindow(
        note: amritSiddhiNote,
        startJdUt: run.start,
        endJdUt: run.end,
        label:
            '$dayEn with ${nakshatraTable[amritSiddhiNakshatra[weekday]].english}',
        labelHindi:
            '$dayHi, ${nakshatraTable[amritSiddhiNakshatra[weekday]].hindi}',
      ),
    );
  }
  if (weekday == 0 || weekday == 4) {
    for (final _Run run in dayRuns(
      (_Seg s) => s.nakshatra == pushyaNakshatra,
    )) {
      auspicious.add(
        PanchangWindow(
          note: weekday == 0 ? raviPushyaNote : guruPushyaNote,
          startJdUt: run.start,
          endJdUt: run.end,
        ),
      );
    }
  }
  if (pushkarWeekdays.contains(weekday)) {
    for (final _Run run in dayRuns(
      (_Seg s) =>
          pushkarTithis.contains(s.tithiInPaksha) &&
          dwipushkarNakshatras.contains(s.nakshatra),
    )) {
      auspicious.add(_pushkarWindow(dwipushkarNote, run, dayEn, dayHi));
    }
    for (final _Run run in dayRuns(
      (_Seg s) =>
          pushkarTithis.contains(s.tithiInPaksha) &&
          tripushkarNakshatras.contains(s.nakshatra),
    )) {
      auspicious.add(_pushkarWindow(tripushkarNote, run, dayEn, dayHi));
    }
  }
  // Ravi Yoga does not read the weekday, so it keeps its full length.
  for (final _Run run in fullRuns(
    (_Seg s) => raviYogaCounts.contains(s.countFromSun27),
  )) {
    final List<int> counts = _distinctInOrder(
      run.segs.map((_Seg s) => s.countFromSun27),
    );
    auspicious.add(
      PanchangWindow(
        note: raviYogaNote,
        startJdUt: run.start,
        endJdUt: run.end,
        label: "${counts.map(_ordinal).join(', ')} from the Sun's nakshatra",
        labelHindi:
            'सूर्य नक्षत्र से ${counts.map((int c) => '$cवाँ').join(', ')}',
      ),
    );
  }
  auspicious.sort(
    (PanchangWindow a, PanchangWindow b) => a.startJdUt.compareTo(b.startJdUt),
  );

  // --- Anandadi -----------------------------------------------------------
  final List<AnandadiSpan> anandadi = <AnandadiSpan>[];
  final int startPosition = anandadiStartPosition[weekday];
  for (final _Run run in _runs(
    timeline,
    (_Seg s) => true,
    key: (_Seg s) => (nakshatraPosition28(s.nakshatra) - startPosition) % 28,
    clipLo: dayStart,
    clipHi: dayEnd,
  )) {
    anandadi.add(
      AnandadiSpan(
        index:
            (nakshatraPosition28(run.segs.first.nakshatra) - startPosition) %
            28,
        startJdUt: run.start,
        endJdUt: run.end,
      ),
    );
  }

  // --- The Moon across the day --------------------------------------------
  final List<MoonSegment> moonSegments = <MoonSegment>[
    for (final _Run run in _runs(
      timeline,
      (_Seg s) => true,
      key: (_Seg s) => s.rashi * 27 + s.nakshatra,
      clipLo: dayStart,
      clipHi: dayEnd,
    ))
      MoonSegment(
        startJdUt: run.start,
        endJdUt: run.end,
        rashi: run.segs.first.rashi,
        nakshatra: run.segs.first.nakshatra,
      ),
  ];

  return PanchangDetails(
    panchang: panchang,
    calendar: calendar,
    dayStartJdUt: dayStart,
    dayEndJdUt: dayEnd,
    panchak: panchak,
    bhadra: bhadra,
    gandMool: gandMool,
    vinchhudo: vinchhudo,
    jwalamukhi: jwalamukhi,
    aadal: aadal,
    vidaal: vidaal,
    dishaShool: dishaShoolTable[weekday],
    auspicious: auspicious,
    anandadi: anandadi,
    moonSegments: moonSegments,
    matbhed: _dayMatbhed(
      panchang: panchang,
      calendar: calendar,
      timeline: timeline,
      dayStart: dayStart,
      dayEnd: dayEnd,
      panchakSpan: panchakSpan,
    ),
  );
}

PanchangWindow _pushkarWindow(
  RuleNote note,
  _Run run,
  String dayEn,
  String dayHi,
) {
  final _Seg first = run.segs.first;
  final String tithiEn = first.tithi == 29
      ? 'Amavasya'
      : tithiNames[first.tithi % 15];
  final String tithiHi = first.tithi == 29
      ? 'अमावस्या'
      : tithiNamesHindi[first.tithi % 15];
  return PanchangWindow(
    note: note,
    startJdUt: run.start,
    endJdUt: run.end,
    label: '$tithiEn, $dayEn, ${nakshatraTable[first.nakshatra].english}',
    labelHindi: '$tithiHi, $dayHi, ${nakshatraTable[first.nakshatra].hindi}',
  );
}

/// Bhadra, with where it dwells as the Moon changes sign during it.
PanchangWindow _bhadraWindow(_Run run) {
  final List<WindowPart> parts = <WindowPart>[];
  int? lastRashi;
  for (final _Seg seg in run.segs) {
    final double start = math.max(seg.start, run.start);
    final double end = math.min(seg.end, run.end);
    if (lastRashi == seg.rashi && parts.isNotEmpty) {
      final WindowPart prev = parts.removeLast();
      parts.add(
        WindowPart(
          startJdUt: prev.startJdUt,
          endJdUt: end,
          detail: prev.detail,
          detailHindi: prev.detailHindi,
          tone: prev.tone,
        ),
      );
    } else {
      final BhadraLoka loka = bhadraLokaBySign[seg.rashi];
      parts.add(
        WindowPart(
          startJdUt: start,
          endJdUt: end,
          detail:
              'Moon in ${rashiTable[seg.rashi].english}: Bhadra in ${bhadraLokaName[loka.index]}. ${bhadraLokaMeaning[loka.index]}',
          detailHindi:
              'चंद्रमा ${rashiTable[seg.rashi].hindi} में: भद्रा ${bhadraLokaNameHindi[loka.index]} में। ${bhadraLokaMeaningHindi[loka.index]}',
          tone: loka == BhadraLoka.prithvi
              ? PanchangTone.inauspicious
              : PanchangTone.auspicious,
        ),
      );
    }
    lastRashi = seg.rashi;
  }
  final bool anyOnEarth = parts.any(
    (WindowPart p) => p.tone == PanchangTone.inauspicious,
  );
  final BhadraLoka firstLoka = bhadraLokaBySign[run.segs.first.rashi];
  return PanchangWindow(
    note: bhadraNote,
    startJdUt: run.start,
    endJdUt: run.end,
    label: anyOnEarth
        ? 'Dwells on earth'
        : 'Dwells in ${bhadraLokaName[firstLoka.index]}',
    labelHindi: anyOnEarth
        ? 'पृथ्वी लोक में वास'
        : '${bhadraLokaNameHindi[firstLoka.index]} में वास',
    parts: parts,
  );
}

/// One nakshatra's Gand Mool, with the deity its shanti is offered to.
PanchangWindow _gandMoolWindow(_Run run) {
  final NakshatraInfo n = nakshatraTable[run.segs.first.nakshatra];
  return PanchangWindow(
    note: gandMoolNote,
    startJdUt: run.start,
    endJdUt: run.end,
    label: n.english,
    labelHindi: n.hindi,
    detail: 'Mool Shanti for ${n.english} is offered to ${n.deityEnglish}.',
    detailHindi:
        '${n.hindi} की मूल शांति ${n.deityHindi} को अर्पित की जाती है।',
  );
}

// ---------------------------------------------------------------------------
// Chandra bala and Tara bala
// ---------------------------------------------------------------------------

/// The Moon of a birth moment, which is all either bala reads of a chart.
class NatalMoon {
  const NatalMoon({
    required this.longitude,
    required this.rashi,
    required this.nakshatra,
    required this.pada,
  });

  /// Sidereal longitude, degrees.
  final double longitude;

  /// 0 = Mesha .. 11 = Meena.
  final int rashi;

  /// 0 = Ashwini .. 26 = Revati.
  final int nakshatra;
  final int pada;
}

/// The Moon at a birth moment in the chosen zodiac.
NatalMoon natalMoonAt({
  required DateTime localDateTime,
  required Duration utcOffset,
  Ayanamsa ayanamsa = Ayanamsa.lahiri,
}) {
  final double lon = siderealLongitudeAt(
    Graha.moon,
    Instant.fromLocal(localDateTime, utcOffset),
    ayanamsa,
  );
  return NatalMoon(
    longitude: lon,
    rashi: (lon / 30).floor() % 12,
    nakshatra: nakshatraIndexOf(lon),
    pada: padaOf(lon),
  );
}

/// The Moon sign a birth nakshatra and pada fall in. Nine padas make a sign,
/// so a nakshatra alone is not enough for the five or six that straddle two.
int rashiOfNakshatraPada(int nakshatra, int pada) =>
    (nakshatra * 4 + (pada - 1)) ~/ 9 % 12;

/// The transit Moon's strength for a person, read from the house it holds
/// counted from the natal Moon sign.
class ChandraBala {
  const ChandraBala({
    required this.house,
    required this.tone,
    required this.name,
    required this.nameHindi,
    required this.meaning,
    required this.meaningHindi,
  });

  /// 1..12, the natal Moon sign being the 1st.
  final int house;

  /// Auspicious when favourable, inauspicious when not, neutral between.
  final PanchangTone tone;
  final String name;
  final String nameHindi;
  final String meaning;
  final String meaningHindi;

  bool get isChandrashtama => house == 8;
}

/// Chandra bala for a natal Moon in [natalMoonRashi] with the Moon now in
/// [transitMoonRashi], both zero-based from Mesha.
ChandraBala chandraBala({
  required int natalMoonRashi,
  required int transitMoonRashi,
}) {
  final int house = (transitMoonRashi - natalMoonRashi) % 12 + 1;
  final bool good = chandraBalaGoodHouses.contains(house);
  final bool bad = chandraBalaBadHouses.contains(house);
  final String where =
      'The Moon is in the ${_ordinal(house)} from your Moon sign';
  final String whereHindi = 'चंद्रमा आपकी जन्म राशि से $houseवें भाव में है';
  if (house == 8) {
    return ChandraBala(
      house: house,
      tone: PanchangTone.inauspicious,
      name: 'Chandrashtama',
      nameHindi: 'चंद्राष्टम',
      meaning: '$where: the 8th, the day to take most care.',
      meaningHindi: '$whereHindi: अष्टम, सबसे सावधानी का दिन।',
    );
  }
  if (good) {
    return ChandraBala(
      house: house,
      tone: PanchangTone.auspicious,
      name: 'Favourable',
      nameHindi: 'अनुकूल',
      meaning: '$where: good for new work.',
      meaningHindi: '$whereHindi: नए कार्य के लिए शुभ।',
    );
  }
  if (bad) {
    return ChandraBala(
      house: house,
      tone: PanchangTone.inauspicious,
      name: 'Unfavourable',
      nameHindi: 'प्रतिकूल',
      meaning: '$where: avoid big beginnings.',
      meaningHindi: '$whereHindi: बड़े आरंभ से बचें।',
    );
  }
  return ChandraBala(
    house: house,
    tone: PanchangTone.neutral,
    name: 'Ordinary',
    nameHindi: 'सामान्य',
    meaning: '$where: neither helps nor hinders.',
    meaningHindi: '$whereHindi: न शुभ, न अशुभ।',
  );
}

/// Chandra bala from a birth nakshatra and pada, for callers that have the
/// nakshatra a chart prints but not the Moon's sign.
ChandraBala chandraBalaForNakshatra({
  required int natalNakshatra,
  required int natalPada,
  required int transitMoonRashi,
}) => chandraBala(
  natalMoonRashi: rashiOfNakshatraPada(natalNakshatra, natalPada),
  transitMoonRashi: transitMoonRashi,
);

/// The natal Moon signs for which the Moon in [transitMoonRashi] is
/// favourable: the list a printed panchang gives under Chandrabalam.
List<int> chandraBalaFavourableRashis(int transitMoonRashi) => <int>[
  for (int natal = 0; natal < 12; natal++)
    if (chandraBalaGoodHouses.contains((transitMoonRashi - natal) % 12 + 1))
      natal,
];

/// The transit nakshatra's strength for a person.
class TaraBala {
  const TaraBala({required this.count, required this.tara});

  /// The nakshatra counted from the natal one, which is the 1st; 1..27.
  final int count;
  final TaraInfo tara;

  PanchangTone get tone => tara.tone;
}

/// Tara bala for a natal nakshatra with the Moon now in [transitNakshatra],
/// both zero-based from Ashwini.
TaraBala taraBala({
  required int natalNakshatra,
  required int transitNakshatra,
}) {
  final int count = (transitNakshatra - natalNakshatra) % 27 + 1;
  final int number = count % 9 == 0 ? 9 : count % 9;
  return TaraBala(count: count, tara: taraTable[number - 1]);
}

/// The natal nakshatras for which the Moon in [transitNakshatra] gives a
/// favourable tara.
List<int> taraBalaFavourableNakshatras(int transitNakshatra) => <int>[
  for (int natal = 0; natal < 27; natal++)
    if (taraBala(
          natalNakshatra: natal,
          transitNakshatra: transitNakshatra,
        ).tone ==
        PanchangTone.auspicious)
      natal,
];

/// A bala that holds for a stretch of the day.
class BalaSegment<T> {
  const BalaSegment({
    required this.startJdUt,
    required this.endJdUt,
    required this.value,
  });

  final double startJdUt;
  final double endJdUt;
  final T value;
}

List<BalaSegment<T>> _merge<T>(
  List<MoonSegment> segments,
  T Function(MoonSegment) valueOf,
  bool Function(T, T) same,
) {
  final List<BalaSegment<T>> out = <BalaSegment<T>>[];
  for (final MoonSegment seg in segments) {
    final T value = valueOf(seg);
    if (out.isNotEmpty && same(out.last.value, value)) {
      final BalaSegment<T> prev = out.removeLast();
      out.add(
        BalaSegment<T>(
          startJdUt: prev.startJdUt,
          endJdUt: seg.endJdUt,
          value: prev.value,
        ),
      );
    } else {
      out.add(
        BalaSegment<T>(
          startJdUt: seg.startJdUt,
          endJdUt: seg.endJdUt,
          value: value,
        ),
      );
    }
  }
  return out;
}

/// Chandra bala across the day for a natal Moon sign: one entry for each
/// stretch over which it holds.
List<BalaSegment<ChandraBala>> chandraBalaForDay(
  PanchangDetails details, {
  required int natalMoonRashi,
}) => _merge<ChandraBala>(
  details.moonSegments,
  (MoonSegment s) =>
      chandraBala(natalMoonRashi: natalMoonRashi, transitMoonRashi: s.rashi),
  (ChandraBala a, ChandraBala b) => a.house == b.house,
);

/// Tara bala across the day for a natal nakshatra.
List<BalaSegment<TaraBala>> taraBalaForDay(
  PanchangDetails details, {
  required int natalNakshatra,
}) => _merge<TaraBala>(
  details.moonSegments,
  (MoonSegment s) =>
      taraBala(natalNakshatra: natalNakshatra, transitNakshatra: s.nakshatra),
  (TaraBala a, TaraBala b) => a.count == b.count,
);

/// Chandra bala favourable signs across the day, for a reader with no chart.
List<BalaSegment<List<int>>> chandraBalaListForDay(PanchangDetails details) =>
    _merge<List<int>>(
      details.moonSegments,
      (MoonSegment s) => chandraBalaFavourableRashis(s.rashi),
      (List<int> a, List<int> b) => a.length == b.length && a.every(b.contains),
    );

/// Tara bala favourable nakshatras across the day, for a reader with no chart.
List<BalaSegment<List<int>>> taraBalaListForDay(PanchangDetails details) =>
    _merge<List<int>>(
      details.moonSegments,
      (MoonSegment s) => taraBalaFavourableNakshatras(s.nakshatra),
      (List<int> a, List<int> b) => a.length == b.length && a.every(b.contains),
    );

// ---------------------------------------------------------------------------
// Where the panchang traditions differ: मतभेद
//
// What was read. Drik Panchang's day pages and yoga date tables (the Ravi Yoga
// and Tripushkar windows for October 2026 and 2026 were checked against the
// rules to the minute), Vedpanchang's yoga pages, Ernst Wilhelm's Classical
// Muhurta (Kala Occult, 2003), the English translation of the Muhurta
// Chintamani by Daivagya Acharya Shriram, and the Hindi dailies and websites
// named beside each view. The Sanskrit verses of the Muhurta Chintamani and of
// Narada could not be read, so no verse is credited with anything here.
// ---------------------------------------------------------------------------

const List<String> _clockMonths = <String>[
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

const List<String> _clockMonthsHindi = <String>[
  'जन॰',
  'फ़र॰',
  'मार्च',
  'अप्रैल',
  'मई',
  'जून',
  'जुल॰',
  'अग॰',
  'सित॰',
  'अक्तू॰',
  'नव॰',
  'दिस॰',
];

/// "14:10" for a moment on the day's own date, "15 Oct 04:03" for another.
Bi _momentBi(double jdUt, Panchang panchang) {
  final DateTime local = utcFromJulianDay(jdUt).add(panchang.utcOffset);
  final String hm =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final bool sameDay =
      local.year == panchang.date.year &&
      local.month == panchang.date.month &&
      local.day == panchang.date.day;
  if (sameDay) return Bi(hm, hm);
  return Bi(
    '${local.day} ${_clockMonths[local.month - 1]} $hm',
    '${local.day} ${_clockMonthsHindi[local.month - 1]} $hm',
  );
}

Bi _windowsBi(List<_Run> runs, Panchang panchang, Bi none) {
  if (runs.isEmpty) return none;
  final List<String> en = <String>[];
  final List<String> hi = <String>[];
  for (final _Run r in runs) {
    final Bi a = _momentBi(r.start, panchang);
    final Bi b = _momentBi(r.end, panchang);
    en.add('${a.en} to ${b.en}');
    hi.add('${a.hi} से ${b.hi}');
  }
  return Bi('${en.join('; ')}.', '${hi.join('; ')}।');
}

double _hoursOf(List<_Run> runs) =>
    runs.fold(0.0, (double sum, _Run r) => sum + (r.end - r.start) * 24.0);

List<Matbhed> _dayMatbhed({
  required Panchang panchang,
  required PanchangCalendar calendar,
  required List<_Seg> timeline,
  required double dayStart,
  required double dayEnd,
  required ({double start, double end})? panchakSpan,
}) {
  final int weekday = panchang.weekday;
  bool touchesDay(double start, double end) =>
      end > dayStart + 1e-6 && start < dayEnd - 1e-6;
  List<_Run> dayRuns(bool Function(_Seg) test) =>
      _runs(timeline, test, clipLo: dayStart, clipHi: dayEnd);
  List<_Run> fullRuns(bool Function(_Seg) test) => _runs(
    timeline,
    test,
  ).where((_Run r) => touchesDay(r.start, r.end)).toList();

  // --- Ravi Yoga ----------------------------------------------------------
  const List<int> raviStars = <int>[7, 12, 0, 21];
  final List<_Run> raviA = fullRuns(
    (_Seg s) => raviYogaCounts.contains(s.countFromSun27),
  );
  final List<_Run> raviB = weekday == 0
      ? dayRuns((_Seg s) => raviStars.contains(s.nakshatra))
      : <_Run>[];
  final List<_Run> raviC = fullRuns(
    (_Seg s) =>
        raviYogaCounts.contains(s.countFromSun27) && s.countFromSun27 != 9,
  );
  const Bi noRavi = Bi(
    'No Ravi Yoga on this day by this reading.',
    'इस पाठ से इस दिन रवि योग नहीं है।',
  );
  final Matbhed ravi = Matbhed(
    key: 'panchang_ravi_yoga',
    topic: const Bi('Ravi Yoga', 'रवि योग'),
    whyTheyDiffer: const Bi(
      'Drik Panchang and most pages count the Moon’s nakshatra from the Sun’s. '
          'Vedpanchang names a different yoga under the same name, a Sunday '
          'with one of four nakshatras. And one compilation of the classical '
          'texts lists only five of the six distances.',
      'ड्रिक पंचांग और अधिकतर पन्ने चंद्र का नक्षत्र सूर्य के नक्षत्र से गिनते हैं। '
          'वेदपंचांग उसी नाम से एक अलग योग बताता है, चार नक्षत्रों में से किसी एक के '
          'साथ रविवार। और शास्त्रों का एक संग्रह छह में से केवल पाँच दूरियाँ गिनाता है।',
    ),
    defaultReason: const Bi(
      'The app follows Drik Panchang, whose October 2026 windows for New Delhi '
          'match the six-distance rule to the minute.',
      'ऐप ड्रिक पंचांग का अनुसरण करता है, जिसकी अक्तूबर 2026 की नई दिल्ली की समय-सीमाएँ '
          'छह दूरियों वाले नियम से मिनट-मिनट मेल खाती हैं।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: _hoursOf(raviA),
        position: const Bi(
          'The Moon’s nakshatra is the 4th, 6th, 9th, 10th, 13th or 20th from the '
              'Sun’s nakshatra, the Sun’s own being the 1st.',
          'चंद्र का नक्षत्र सूर्य के नक्षत्र से 4, 6, 9, 10, 13 या 20वाँ है, सूर्य का अपना '
              'पहला गिनकर।',
        ),
        holder: const Bi(
          'Drik Panchang (its windows match this rule to the minute), '
              'OnlineJyotish and HoraSarvam',
          'ड्रिक पंचांग (उसकी समय-सीमाएँ इस नियम से मिनट-मिनट मिलती हैं), '
              'OnlineJyotish और HoraSarvam',
        ),
        reasoning: const Bi(
          'The pages give the six distances and say the yoga forms when the Moon '
              'stands that far from the Sun’s nakshatra; they give no reason '
              'beyond the list.',
          'पन्ने छह दूरियाँ देते हैं और कहते हैं कि योग तब बनता है जब चंद्र सूर्य के '
              'नक्षत्र से उतनी दूर हो; सूची के आगे कोई कारण नहीं देते।',
        ),
        result: _windowsBi(raviA, panchang, noRavi),
      ),
      Mat(
        value: _hoursOf(raviB),
        position: const Bi(
          'A Sunday on which the Moon is in Pushya, Hasta, Ashwini or Shravana.',
          'रविवार जिस दिन चंद्र पुष्य, हस्त, अश्विनी या श्रवण में हो।',
        ),
        holder: const Bi(
          'Vedpanchang (its Ravi Yoga page lists Sundays only)',
          'वेदपंचांग (उसके रवि योग के पन्ने में केवल रविवार हैं)',
        ),
        reasoning: const Bi(
          'It treats Ravi Yoga as a pairing of the Sun’s day with a nakshatra, like '
              'Ravi Pushya. The page read gives no reason, and Drik shows its '
              'Ravi Yoga on any weekday.',
          'वह रवि योग को सूर्य के वार और नक्षत्र का जोड़ मानता है, रवि पुष्य की तरह। '
              'पढ़ा गया पन्ना कोई कारण नहीं देता, और ड्रिक अपना रवि योग किसी भी वार पर '
              'दिखाता है।',
        ),
        result: weekday == 0
            ? _windowsBi(raviB, panchang, noRavi)
            : const Bi(
                'Today is not a Sunday, so there is no Ravi Yoga by this reading.',
                'आज रविवार नहीं है, इसलिए इस पाठ से रवि योग नहीं है।',
              ),
      ),
      Mat(
        value: _hoursOf(raviC),
        position: const Bi(
          'The same, without the 9th: the 4th, 6th, 10th, 13th or 20th.',
          'वही, 9वें के बिना: 4, 6, 10, 13 या 20वाँ।',
        ),
        holder: const Bi(
          'Ernst Wilhelm, Classical Muhurta (Kala Occult, 2003), p. 64, a '
              'compilation of classical muhurta texts; he marks the 10th as '
              'inauspicious (Ulka) but still Ravi',
          'अर्न्स्ट विल्हेल्म, क्लासिकल मुहूर्त (काला ऑकल्ट, 2003), पृ. 64, शास्त्रीय मुहूर्त '
              'ग्रंथों का संग्रह; वे 10वें को अशुभ (उल्का) कहते हैं पर रवि ही मानते हैं',
        ),
        reasoning: const Bi(
          'He lists five distances and no 9th; the page read cites no verse '
              'for it.',
          'वे पाँच दूरियाँ गिनाते हैं और 9वाँ नहीं; पढ़े गए पन्ने में इसके लिए कोई श्लोक '
              'नहीं दिया।',
        ),
        result: _windowsBi(raviC, panchang, noRavi),
      ),
    ],
  );

  // --- Tripushkar ---------------------------------------------------------
  List<_Run> pushkar(List<int> tithis, List<int> stars) =>
      pushkarWeekdays.contains(weekday)
      ? dayRuns(
          (_Seg s) =>
              tithis.contains(s.tithiInPaksha) && stars.contains(s.nakshatra),
        )
      : <_Run>[];
  final List<_Run> triA = pushkar(pushkarTithis, tripushkarNakshatras);
  final List<_Run> triB = pushkar(const <int>[3, 8, 13], tripushkarNakshatras);
  final List<_Run> triC = pushkar(pushkarTithis, const <int>[2, 6, 20]);
  final Bi noPushkar = pushkarWeekdays.contains(weekday)
      ? const Bi(
          'No Tripushkar on this day by this reading.',
          'इस पाठ से इस दिन त्रिपुष्कर नहीं है।',
        )
      : const Bi(
          'Not a Sunday, Tuesday or Saturday, so no Tripushkar by any reading.',
          'न रविवार, न मंगलवार, न शनिवार, इसलिए किसी भी पाठ से त्रिपुष्कर नहीं।',
        );
  final Matbhed tripushkar = Matbhed(
    key: 'panchang_tripushkar',
    topic: const Bi('Tripushkar Yoga', 'त्रिपुष्कर योग'),
    whyTheyDiffer: const Bi(
      'All agree on the weekdays (Sunday, Tuesday, Saturday). They differ on '
          'the tithis and on which nakshatras count. The same question about '
          'tithis holds for Dwipushkar Yoga.',
      'वारों पर सब एकमत हैं (रविवार, मंगलवार, शनिवार)। फ़र्क तिथियों में है और इसमें '
          'कि कौन-से नक्षत्र गिने जाएँ। तिथियों का यही प्रश्न द्विपुष्कर योग पर भी लागू है।',
    ),
    defaultReason: const Bi(
      'The app follows Drik Panchang, whose 2026 Tripushkar dates all fall on '
          'tithis 2, 7 and 12 with the six nakshatras (all 17 were checked).',
      'ऐप ड्रिक पंचांग का अनुसरण करता है, जिसकी 2026 की त्रिपुष्कर तिथियाँ सब 2, 7 और '
          '12 तिथि पर छह नक्षत्रों के साथ पड़ती हैं (सभी 17 जाँची गईं)।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: _hoursOf(triA),
        position: const Bi(
          'The Bhadra tithis (2nd, 7th, 12th) on a Sunday, Tuesday or Saturday, '
              'with Krittika, Punarvasu, Uttara Phalguni, Vishakha, Uttara '
              'Ashadha or Purva Bhadrapada.',
          'भद्रा तिथियाँ (दूसरी, सातवीं, बारहवीं) रविवार, मंगलवार या शनिवार को, कृत्तिका, '
              'पुनर्वसु, उत्तरा फाल्गुनी, विशाखा, उत्तराषाढ़ा या पूर्व भाद्रपद के साथ।',
        ),
        holder: const Bi(
          'Drik Panchang, Ernst Wilhelm (Classical Muhurta, pp. 82 and 88), '
              'Webdunia (Hemant Richhariya), Astroshastra and HoraSarvam',
          'ड्रिक पंचांग, अर्न्स्ट विल्हेल्म (क्लासिकल मुहूर्त, पृ. 82 और 88), वेबदुनिया '
              '(हेमंत रिछारिया), Astroshastra और HoraSarvam',
        ),
        reasoning: const Bi(
          'The Bhadra group of tithis is named in the Muhurta Chintamani’s table '
              'of tithi groups (in the translation by Daivagya Acharya Shriram). '
              'The six nakshatras are those with three padas in one sign and one in '
              'the next, which is where the name “three-fold” comes from.',
          'तिथियों का भद्रा समूह मुहूर्त चिंतामणि की तिथि-वर्गों की तालिका में बताया गया है '
              '(दैवज्ञ आचार्य श्रीराम के अनुवाद में)। छह नक्षत्र वे हैं जिनके तीन पाद एक '
              'राशि में और एक अगली में हैं, जहाँ से “त्रि” नाम आता है।',
        ),
        result: _windowsBi(triA, panchang, noPushkar),
      ),
      Mat(
        value: _hoursOf(triB),
        position: const Bi(
          'The Jaya tithis (3rd, 8th, 13th) instead, with the same six nakshatras.',
          'इसके बजाय जया तिथियाँ (तीसरी, आठवीं, तेरहवीं), वही छह नक्षत्र।',
        ),
        holder: const Bi(
          'The Hindi prose of PanchangBodh (panchangbodh.com), whose own table '
              'of dates uses the 2nd, 7th and 12th; no classical source and no '
              'other panchang was found for it',
          'PanchangBodh (panchangbodh.com) का हिंदी गद्य, जिसकी अपनी तिथि-सूची दूसरी, '
              'सातवीं और बारहवीं लेती है; इसके लिए कोई शास्त्रीय स्रोत या दूसरा पंचांग नहीं '
              'मिला',
        ),
        reasoning: const Bi(
          'No reason is given. It is shown because the question was raised, and '
              'because it is the only text found that names these tithis; the '
              'weight of the sources is on the first reading.',
          'कोई कारण नहीं दिया गया। यह इसलिए दिखाया है कि प्रश्न उठाया गया था, और क्योंकि '
              'ये तिथियाँ बताने वाला यही एकमात्र पाठ मिला; स्रोतों का वज़न पहले पाठ पर है।',
        ),
        result: _windowsBi(triB, panchang, noPushkar),
      ),
      Mat(
        value: _hoursOf(triC),
        position: const Bi(
          'The Bhadra tithis with only Krittika, Punarvasu and Uttara Ashadha.',
          'भद्रा तिथियाँ केवल कृत्तिका, पुनर्वसु और उत्तराषाढ़ा के साथ।',
        ),
        holder: const Bi(
          'Vedpanchang (its Tripushkar page); DekhoPanchang gives yet another '
              'list of four (Krittika, Punarvasu, Vishakha, Uttara Bhadrapada)',
          'वेदपंचांग (उसका त्रिपुष्कर का पन्ना); DekhoPanchang चार नक्षत्रों की एक और '
              'सूची देता है (कृत्तिका, पुनर्वसु, विशाखा, उत्तरा भाद्रपद)',
        ),
        reasoning: const Bi(
          'It keeps three of the six. The page read gives no reason for the '
              'shorter list.',
          'वह छह में से तीन रखता है। पढ़ा गया पन्ना छोटी सूची का कोई कारण नहीं देता।',
        ),
        result: _windowsBi(triC, panchang, noPushkar),
      ),
    ],
  );

  final List<Matbhed> out = <Matbhed>[
    samvatsaraMatbhed(calendar, panchang),
    ravi,
    tripushkar,
  ];

  // --- The kind of Panchak ------------------------------------------------
  if (panchakSpan != null) {
    final int civil = _civilWeekday(panchakSpan.start, panchang.utcOffset);
    final DateTime local = utcFromJulianDay(
      panchakSpan.start,
    ).add(panchang.utcOffset);
    final double midnight = Instant.fromLocal(
      DateTime(local.year, local.month, local.day),
      panchang.utcOffset,
    ).julianDayUt;
    final double? rise = findRiseSet(
      Graha.sun,
      midnight,
      panchang.place,
      horizon: sunHorizon,
    ).rise;
    final int vedic = (rise != null && panchakSpan.start < rise)
        ? (civil + 6) % 7
        : civil;
    const List<String> order = <String>[
      'roga',
      'raja',
      'agni',
      'madhyam',
      'chora',
      'mrityu',
    ];
    Mat kindView({
      required int wd,
      required bool isDefault,
      required Bi position,
      required Bi holder,
      required Bi reasoning,
    }) {
      final PanchakKind kind = panchakKinds[wd];
      final Bi when = _momentBi(panchakSpan.start, panchang);
      return Mat(
        isDefault: isDefault,
        value: order.indexOf(kind.key).toDouble(),
        position: position,
        holder: holder,
        reasoning: reasoning,
        result: Bi(
          'The Panchak begins on ${weekdayNames[wd]} (${when.en}): '
              '${kind.name}.',
          'पंचक ${weekdayNamesHindi[wd]} (${when.hi}) को आरंभ होता है: '
              '${kind.nameHindi}।',
        ),
      );
    }

    out.add(
      Matbhed(
        key: 'panchang_panchak_kind',
        topic: const Bi('The kind of Panchak', 'पंचक का प्रकार'),
        whyTheyDiffer: const Bi(
          'The kind is named for the weekday the Panchak begins on (Sunday Roga, '
              'Monday Raja, Tuesday Agni, Friday Chora, Saturday Mrityu). '
              'Sources do not say whether that is the weekday on the clock or '
              'the weekday of the panchang day, which turns at sunrise, so a '
              'start in the small hours can take either. For a Wednesday or '
              'Thursday start some sources say Madhyam and some say no kind. '
              'Drik Panchang does not name the kinds at all; it uses the same '
              'five words for a different thing, the Panchaka windows within the '
              'day.',
          'प्रकार उस वार से नाम पाता है जिस दिन पंचक आरंभ होता है (रविवार रोग, सोमवार '
              'राज, मंगलवार अग्नि, शुक्रवार चोर, शनिवार मृत्यु)। स्रोत नहीं बताते कि वह '
              'घड़ी का वार है या पंचांग के दिन का, जो सूर्योदय पर बदलता है, इसलिए '
              'रात के आख़िरी पहर की शुरुआत दोनों में से कोई ले सकती है। बुधवार या '
              'गुरुवार की शुरुआत पर कुछ स्रोत मध्यम कहते हैं, कुछ कोई प्रकार नहीं।',
        ),
        defaultReason: const Bi(
          'The app has used the weekday on the clock. Drik Panchang prints each '
              'Panchak with that weekday, and the sites that name the kinds '
              'against dates (PanchangBodh, SmartPuja) follow it.',
          'ऐप घड़ी का वार लेता आया है। ड्रिक पंचांग हर पंचक को उसी वार के साथ छापता है, '
              'और जो साइटें तारीख़ों के सामने प्रकार लिखती हैं (PanchangBodh, SmartPuja) वे '
              'उसी को मानती हैं।',
        ),
        views: <Mat>[
          kindView(
            wd: civil,
            isDefault: true,
            position: const Bi(
              'The weekday on the clock at the moment the Moon enters Kumbha.',
              'जिस क्षण चंद्र कुंभ में आता है, उस समय घड़ी का वार।',
            ),
            holder: const Bi(
              'Drik Panchang prints each start with its clock weekday (and names no '
                  'kinds); PanchangBodh and SmartPuja name the kinds from that '
                  'weekday, and Prabhat Khabar gives the same weekday table',
              'ड्रिक पंचांग हर आरंभ को घड़ी के वार के साथ छापता है (और प्रकार नहीं बताता); '
                  'PanchangBodh और SmartPuja उसी वार से प्रकार बताते हैं, और प्रभात खबर '
                  'वही वार-तालिका देता है',
            ),
            reasoning: const Bi(
              'It is the weekday a reader sees against the time on the page, and '
                  'the kinds are named from it in print.',
              'पन्ने पर समय के सामने पाठक को यही वार दिखता है, और छपाई में प्रकार इसी '
                  'से बताए जाते हैं।',
            ),
          ),
          kindView(
            wd: vedic,
            isDefault: false,
            position: const Bi(
              'The weekday of the panchang day, which turns at sunrise, so a start '
                  'before sunrise belongs to the day before.',
              'पंचांग के दिन का वार, जो सूर्योदय पर बदलता है, इसलिए सूर्योदय से पहले की '
                  'शुरुआत पिछले दिन की मानी जाती है।',
            ),
            holder: const Bi(
              'Vedpanchang files a Panchak that starts before sunrise under the '
                  'previous panchang day (it names no kinds); no source states '
                  'the rule outright',
              'वेदपंचांग सूर्योदय से पहले शुरू होने वाले पंचक को पिछले पंचांग-दिन में रखता '
                  'है (वह प्रकार नहीं बताता); किसी स्रोत ने नियम साफ़ नहीं लिखा',
            ),
            reasoning: const Bi(
              'The vara of a panchang changes at sunrise, so the day a Panchak '
                  'starts on is the one that is running, not the one on the clock.',
              'पंचांग का वार सूर्योदय पर बदलता है, इसलिए पंचक जिस दिन आरंभ होता है वह चलता '
                  'हुआ दिन है, घड़ी वाला नहीं।',
            ),
          ),
        ],
      ),
    );
  }
  return out;
}

/// What the panchang part still does not compute, with the reason.
const List<LeftOut> panchangLeftOut = <LeftOut>[
  LeftOut(
    key: 'bhadra_loka',
    name: Bi(
      'The heaven and netherworld split of Bhadra',
      'भद्रा के स्वर्ग और पाताल का बँटवारा',
    ),
    reason: Bi(
      'No second table of signs for Bhadra’s dwelling was found: Drik’s daily '
          'line, Ernst Wilhelm and Astrobix (quoting the Muhurta Chintamani) agree '
          'on the table the app uses. What the sources differ on is how harmful '
          'a Bhadra that is not on earth is, and one site ranks the netherworld '
          'worst by a tithi-and-paksha rule it does not spell out, so there is '
          'nothing to compute.',
      'भद्रा के वास की राशियों की कोई दूसरी तालिका नहीं मिली: ड्रिक की दैनिक पंक्ति, '
          'अर्न्स्ट विल्हेल्म और Astrobix (मुहूर्त चिंतामणि का हवाला देकर) उसी तालिका पर '
          'एक हैं जो ऐप लेता है। स्रोत इस पर अलग हैं कि जो भद्रा पृथ्वी पर न हो वह कितनी '
          'हानिकारक है, और एक साइट पाताल को सबसे बुरा बताती है, तिथि और पक्ष के उस नियम '
          'से जो वह खोलकर नहीं लिखती, इसलिए गिनने को कुछ नहीं है।',
    ),
  ),
];

// ---------------------------------------------------------------------------
// The balas: Chandra bala and the Janma tara
// ---------------------------------------------------------------------------

/// Chandra bala for [natalMoonRashi] across the day, under the house list the
/// app uses and under the one that adds the 2nd, 5th and 9th in the bright
/// half. Each view's `value` is the number of the day's Moon stretches it
/// counts as favourable.
Matbhed chandraBalaMatbhed(
  PanchangDetails details, {
  required int natalMoonRashi,
}) {
  final bool bright = details.panchang.paksha == 'Shukla';
  const List<int> extra = <int>[2, 5, 9];
  bool goodA(int h) => chandraBalaGoodHouses.contains(h);
  bool goodB(int h) => goodA(h) || (bright && extra.contains(h));
  Bi line(bool Function(int) good) {
    final List<String> en = <String>[];
    final List<String> hi = <String>[];
    for (final MoonSegment seg in details.moonSegments) {
      final int h = (seg.rashi - natalMoonRashi) % 12 + 1;
      final String sign = rashiTable[seg.rashi].english;
      final String signHi = rashiTable[seg.rashi].hindi;
      final bool g = good(h);
      final bool viaExtra = !goodA(h) && g;
      final String tag = h == 8
          ? 'Chandrashtama'
          : (g
                ? (viaExtra
                      ? 'favourable, subject to the vedha test the text adds'
                      : 'favourable')
                : (chandraBalaBadHouses.contains(h)
                      ? 'unfavourable'
                      : 'ordinary'));
      final String tagHi = h == 8
          ? 'चंद्राष्टम'
          : (g
                ? (viaExtra
                      ? 'अनुकूल, वेध की उस जाँच के अधीन जो ग्रंथ जोड़ता है'
                      : 'अनुकूल')
                : (chandraBalaBadHouses.contains(h) ? 'प्रतिकूल' : 'सामान्य'));
      en.add('Moon in $sign, the ${_ordinal(h)} from your Moon sign: $tag');
      hi.add('चंद्रमा $signHi में, आपकी राशि से $hवाँ: $tagHi');
    }
    return Bi('${en.join('; ')}.', '${hi.join('; ')}।');
  }

  int favourable(bool Function(int) good) => details.moonSegments
      .where((MoonSegment s) => good((s.rashi - natalMoonRashi) % 12 + 1))
      .length;
  return Matbhed(
    key: 'panchang_chandra_bala',
    topic: const Bi('Chandra bala: the good houses', 'चंद्र बल: शुभ भाव'),
    whyTheyDiffer: Bi(
      bright
          ? 'Today is in the bright half, the half in which the second list '
                'adds the 2nd, 5th and 9th houses.'
          : 'Today is in the dark half, in which the two lists are the same.',
      bright
          ? 'आज शुक्ल पक्ष है, वह पक्ष जिसमें दूसरी सूची दूसरा, पाँचवाँ और नौवाँ भाव जोड़ती है।'
          : 'आज कृष्ण पक्ष है, जिसमें दोनों सूचियाँ एक हैं।',
    ),
    defaultReason: const Bi(
      'The app uses the list Drik Panchang and Vedpanchang print every day.',
      'ऐप वह सूची लेता है जो ड्रिक पंचांग और वेदपंचांग रोज़ छापते हैं।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: favourable(goodA).toDouble(),
        position: const Bi(
          'Favourable in the 1st, 3rd, 6th, 7th, 10th and 11th from the birth '
              'Moon sign; the 8th is Chandrashtama.',
          'जन्म राशि से पहले, तीसरे, छठे, सातवें, दसवें और ग्यारहवें में अनुकूल; '
              'आठवाँ चंद्राष्टम है।',
        ),
        holder: const Bi(
          'Drik Panchang and Vedpanchang (their daily lists), Vijayalur citing '
              'the Muhurta Chintamani, and Ernst Wilhelm (Classical Muhurta)',
          'ड्रिक पंचांग और वेदपंचांग (उनकी दैनिक सूचियाँ), मुहूर्त चिंतामणि का हवाला '
              'देता Vijayalur, और अर्न्स्ट विल्हेल्म (क्लासिकल मुहूर्त)',
        ),
        reasoning: const Bi(
          'These are the houses the Moon is said to favour as it passes them; no '
              'bright-half addition is made in the daily lists.',
          'ये वे भाव हैं जिन्हें चंद्र गुज़रते समय अनुकूल कहा गया है; दैनिक सूचियों में '
              'शुक्ल पक्ष का कोई जोड़ नहीं है।',
        ),
        result: line(goodA),
      ),
      Mat(
        value: favourable(goodB).toDouble(),
        position: const Bi(
          'The same, and in the bright half also the 2nd, 5th and 9th.',
          'वही, और शुक्ल पक्ष में दूसरा, पाँचवाँ और नौवाँ भी।',
        ),
        holder: const Bi(
          'The Muhurta Chintamani, in the English translation by Daivagya '
              'Acharya Shriram (the passage on the Moon’s gochara): the Moon in '
              'the bright half is auspicious in the 2nd, 9th and 5th, provided no '
              'planet stands respectively in the 6th, 8th and 4th',
          'मुहूर्त चिंतामणि, दैवज्ञ आचार्य श्रीराम के अंग्रेज़ी अनुवाद में (चंद्र के गोचर '
              'वाला अंश): शुक्ल पक्ष का चंद्र दूसरे, नौवें और पाँचवें में शुभ है, बशर्ते '
              'क्रमशः छठे, आठवें और चौथे में कोई ग्रह न हो',
        ),
        reasoning: const Bi(
          'A bright Moon is strong enough to help from these houses as well, '
              'while an obstruction (vedha) from the 6th, 8th or 4th spoils it. '
              'The vedha test is not worked out here.',
          'शुक्ल पक्ष का चंद्र इतना बली है कि इन भावों से भी सहारा देता है, पर छठे, '
              'आठवें या चौथे से वेध उसे बिगाड़ देता है। वेध की जाँच यहाँ नहीं की गई।',
        ),
        result: line(goodB),
      ),
    ],
  );
}

/// The Janma tara across the day for [natalNakshatra]: neutral (the app's
/// reading), or unfavourable, fully in the first round of nine and half in the
/// second, and negligibly in the third. Each view's `value` is the number of the
/// day's Moon stretches in which it counts the Janma tara against the day.
Matbhed taraBalaMatbhed(
  PanchangDetails details, {
  required int natalNakshatra,
}) {
  Bi line(bool unfavourable) {
    final List<String> en = <String>[];
    final List<String> hi = <String>[];
    for (final MoonSegment seg in details.moonSegments) {
      final int count = (seg.nakshatra - natalNakshatra) % 27 + 1;
      final TaraInfo tara = taraTable[(count % 9 == 0 ? 9 : count % 9) - 1];
      final String star = nakshatraTable[seg.nakshatra].english;
      final String starHi = nakshatraTable[seg.nakshatra].hindi;
      String tone = tara.tone == PanchangTone.auspicious
          ? 'favourable'
          : (tara.tone == PanchangTone.inauspicious
                ? 'unfavourable'
                : 'neutral');
      String toneHi = tara.tone == PanchangTone.auspicious
          ? 'अनुकूल'
          : (tara.tone == PanchangTone.inauspicious ? 'प्रतिकूल' : 'तटस्थ');
      if (count % 9 == 1 && unfavourable) {
        final int round = (count - 1) ~/ 9;
        tone = switch (round) {
          0 => 'unfavourable in full',
          1 => 'unfavourable by half',
          _ => 'negligible',
        };
        toneHi = switch (round) {
          0 => 'पूरी तरह प्रतिकूल',
          1 => 'आधा प्रतिकूल',
          _ => 'नगण्य',
        };
      }
      en.add(
        'Moon in $star, the ${_ordinal(count)} from your star: ${tara.name} '
        'tara, $tone',
      );
      hi.add(
        'चंद्रमा $starHi में, आपके नक्षत्र से $countवाँ: ${tara.nameHindi} तारा, '
        '$toneHi',
      );
    }
    return Bi('${en.join('; ')}.', '${hi.join('; ')}।');
  }

  int against() => details.moonSegments.where((MoonSegment s) {
    final int count = (s.nakshatra - natalNakshatra) % 27 + 1;
    return count % 9 == 1 && (count - 1) ~/ 9 < 2;
  }).length;
  return Matbhed(
    key: 'panchang_janma_tara',
    topic: const Bi('The Janma tara', 'जन्म तारा'),
    whyTheyDiffer: const Bi(
      'Every source agrees on the other eight taras. The Janma tara, your own '
          'birth star and the 10th and 19th from it, is where they part. Drik '
          'Panchang and Vedpanchang list only the good taras and leave it out '
          'without calling it bad.',
      'बाकी आठ तारों पर सब स्रोत एकमत हैं। जन्म तारा, यानी आपका अपना जन्म नक्षत्र और '
          'उससे दसवाँ और उन्नीसवाँ, वह जगह है जहाँ वे अलग होते हैं। ड्रिक पंचांग और '
          'वेदपंचांग केवल शुभ तारे गिनाते हैं और इसे बुरा कहे बिना छोड़ देते हैं।',
    ),
    defaultReason: const Bi(
      'The app has called it neutral, the middle of the sources: it is not '
          'in the good list of the daily panchangs and it is not bad in all of '
          'them. The graded reading is shown beside it.',
      'ऐप इसे तटस्थ कहता आया है, स्रोतों का बीच का रास्ता: यह दैनिक पंचांगों की शुभ '
          'सूची में नहीं है और सब में बुरा भी नहीं। चक्र के हिसाब से घटता-बढ़ता पाठ उसके बगल में दिखाया है।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: 0,
        position: const Bi(
          'The Janma tara is neutral: take care over the day’s plans, and read '
              'nothing more into it.',
          'जन्म तारा तटस्थ है: दिन की योजनाओं पर ध्यान रखें, इससे अधिक कुछ न पढ़ें।',
        ),
        holder: const Bi(
          'BhaktiBharat lists it as neutral; Drik Panchang and Vedpanchang leave '
              'it out of the good taras without calling it bad',
          'BhaktiBharat इसे तटस्थ गिनता है; ड्रिक पंचांग और वेदपंचांग इसे बुरा कहे बिना '
              'शुभ तारों से बाहर रखते हैं',
        ),
        reasoning: const Bi(
          'The sources that rate it bad are not agreed on how bad, and some '
              'rate it good for certain work, so a single colour would overstate.',
          'जो स्रोत इसे बुरा कहते हैं वे कितना बुरा, इस पर एकमत नहीं, और कुछ इसे कुछ '
              'कामों के लिए अच्छा भी कहते हैं, इसलिए एक रंग देना बढ़ा-चढ़ाकर कहना होगा।',
        ),
        result: line(false),
      ),
      Mat(
        value: against().toDouble(),
        position: const Bi(
          'The Janma tara is unfavourable: fully in the first round of nine '
              'stars, by half in the second round (the 10th), and negligibly in '
              'the third (the 19th).',
          'जन्म तारा प्रतिकूल है: नौ नक्षत्रों के पहले चक्र में पूरी तरह, दूसरे चक्र '
              '(दसवें) में आधा, और तीसरे (उन्नीसवें) में नगण्य।',
        ),
        holder: const Bi(
          'Ernst Wilhelm (Classical Muhurta, pp. 89 to 93), who names the 1st, '
              '10th and 19th from the birth star Janma, Anujanma and Trijanma; '
              'ShubhPanchang (“Not Good”); DekhoPanchang (inauspicious, with a '
              'nuance in the later rounds); Vijayalur, where a first-round Janma '
              'tara is set aside and a comment cites B. V. Raman for the half and '
              'negligible rounds',
          'अर्न्स्ट विल्हेल्म (क्लासिकल मुहूर्त, पृ. 89 से 93), जो जन्म नक्षत्र से पहले, '
              'दसवें और उन्नीसवें को जन्म, अनुजन्म और त्रिजन्म कहते हैं; ShubhPanchang '
              '(“अच्छा नहीं”); DekhoPanchang (अशुभ, बाद के चक्रों में एक बारीकी के साथ); '
              'Vijayalur, जहाँ पहले चक्र का जन्म तारा छोड़ दिया जाता है और एक टिप्पणी आधे '
              'और नगण्य चक्रों के लिए बी. वी. रमन का हवाला देती है',
        ),
        reasoning: const Bi(
          'Wilhelm rates the Janma tara unfavourable in the first round, half as '
              'much in the second and almost not at all in the third, and '
              'advises against it for marriage; he also lists building, starting '
              'study and new jewellery as work it suits, and says its ill effect '
              'does not hold after midday (that last point is not worked out '
              'here). This app only states the tradition’s rating and adds nothing '
              'to it.',
          'विल्हेल्म जन्म तारा को पहले चक्र में प्रतिकूल, दूसरे में उसका आधा और तीसरे में '
              'लगभग नहीं के बराबर मानते हैं, और विवाह के लिए उसे टालने की सलाह देते हैं; '
              'वे भवन-निर्माण, पढ़ाई शुरू करने और नए गहनों को उसके अनुकूल काम भी गिनाते '
              'हैं, और कहते हैं कि दोपहर के बाद उसका बुरा असर नहीं रहता (यह बात यहाँ नहीं '
              'गिनी गई)। यह ऐप केवल परंपरा की दी हुई श्रेणी बताता है, उसमें कुछ जोड़ता नहीं।',
        ),
        result: line(true),
      ),
    ],
  );
}
