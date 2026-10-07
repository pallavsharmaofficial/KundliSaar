import 'dart:math' as math;

import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'nakshatra.dart';
import 'panchang.dart';
import 'panchang_calendar.dart';
import 'panchang_tables.dart';
import 'rashi.dart';

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
