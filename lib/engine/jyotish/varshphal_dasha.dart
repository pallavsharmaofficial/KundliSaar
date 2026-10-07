import 'dart:math' as math;

import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'dasha.dart';
import 'nakshatra.dart';
import 'rashi.dart';
import 'tajika_bala.dart';
import 'tajika_common.dart';

/// The two year-dashas of Tajika that can be computed without guessing:
/// Mudda (Vimshottari compressed into the year) and Patyayini (the year
/// shared out by the degrees the grahas stand at in their signs).

// ---------------------------------------------------------------------------
// Mudda dasha
// ---------------------------------------------------------------------------

/// An antardasha inside a Mudda period.
class MuddaSub {
  const MuddaSub({
    required this.lord,
    required this.startJd,
    required this.endJd,
  });

  final Graha lord;
  final double startJd;
  final double endJd;

  double get days => endJd - startJd;
  DateTime get startUtc => utcFromJulianDay(startJd);
  DateTime get endUtc => utcFromJulianDay(endJd);
}

/// One Mudda period.
class MuddaPeriod {
  const MuddaPeriod({
    required this.lord,
    required this.startJd,
    required this.endJd,
    required this.subPeriods,
    required this.isBalance,
    required this.isCarryOver,
  });

  final Graha lord;
  final double startJd;
  final double endJd;
  final List<MuddaSub> subPeriods;

  /// The first period: only what is left of the dasha running at the pravesh.
  final bool isBalance;

  /// The last period: the first lord's dasha coming round again to close the
  /// year, so that the year is exactly one cycle.
  final bool isCarryOver;

  double get days => endJd - startJd;
  DateTime get startUtc => utcFromJulianDay(startJd);
  DateTime get endUtc => utcFromJulianDay(endJd);

  bool contains(double jdUt) => jdUt >= startJd && jdUt < endJd;
}

/// Mudda dasha for one year, with the working that fixed it.
class MuddaDasha {
  const MuddaDasha({
    required this.periods,
    required this.startLord,
    required this.birthNakshatraLord,
    required this.advancedBy,
    required this.elapsedFraction,
    required this.yearDays,
    required this.factors,
  });

  final List<MuddaPeriod> periods;
  final Graha startLord;
  final Graha birthNakshatraLord;

  /// How many places the year's number moved the start along the
  /// Vimshottari order.
  final int advancedBy;

  /// How much of the birth nakshatra the natal Moon had crossed.
  final double elapsedFraction;
  final double yearDays;
  final List<Bi> factors;

  /// The period running at [jdUt], or null outside the year.
  MuddaPeriod? at(double jdUt) {
    for (final MuddaPeriod p in periods) {
      if (p.contains(jdUt)) return p;
    }
    return null;
  }

  double get totalDays =>
      periods.fold(0.0, (double sum, MuddaPeriod p) => sum + p.days);
}

List<MuddaSub> _subPeriods(
  Graha lord,
  double fullStart,
  double fullLength,
  double from,
  double to,
) {
  final int start = vimshottariOrder.indexOf(lord);
  final List<MuddaSub> out = <MuddaSub>[];
  double cursor = fullStart;
  for (int i = 0; i < 9; i++) {
    final Graha sub = vimshottariOrder[(start + i) % 9];
    final double end = cursor + fullLength * vimshottariYears[sub]! / 120.0;
    final double s = math.max(cursor, from);
    final double e = math.min(end, to);
    if (e > s) out.add(MuddaSub(lord: sub, startJd: s, endJd: e));
    cursor = end;
  }
  // The nine shares add up to the period only to within rounding; close the
  // last one on the period's own end so the antardashas tile it exactly.
  if (out.isNotEmpty && (to - out.last.endJd).abs() < 1e-6) {
    final MuddaSub last = out.removeLast();
    out.add(MuddaSub(lord: last.lord, startJd: last.startJd, endJd: to));
  }
  return out;
}

/// Mudda dasha for the year that runs from [startJd] to [endJd].
///
/// The nine Vimshottari lords share the year in proportion to their years,
/// 120 years mapped to the year's length. The first lord is the lord of the
/// birth nakshatra, advanced along the Vimshottari order by the number of
/// years completed ([age]); the part of that lord's dasha already gone at the
/// pravesh is taken from the fraction of the birth nakshatra the natal Moon
/// had crossed, exactly as the Vimshottari balance is, so that at age 0 the
/// Mudda dasha IS the natal Vimshottari compressed. Antardashas divide each
/// period in the same Vimshottari proportions.
///
/// Variant: PyJHora takes the nakshatra of the Moon in the annual chart in
/// place of the birth nakshatra. The Tajika books this was checked against
/// start from the birth Moon, which is what the app does.
MuddaDasha computeMudda({
  required Kundli natal,
  required int age,
  required double startJd,
  required double endJd,
}) {
  final double year = endJd - startJd;
  final double moon = natal.grahas[Graha.moon]!.siderealLongitude;
  final NakshatraInfo nakshatra = nakshatraOf(moon);
  final double elapsed = (moon % nakshatraSpan) / nakshatraSpan;
  final int baseIndex = vimshottariOrder.indexOf(nakshatra.lord);
  final int firstIndex = (baseIndex + age) % 9;
  final Graha firstLord = vimshottariOrder[firstIndex];

  double share(Graha g) => year * vimshottariYears[g]! / 120.0;
  final double firstLength = share(firstLord);
  final double virtualStart = startJd - elapsed * firstLength;

  final List<MuddaPeriod> periods = <MuddaPeriod>[];
  double cursor = virtualStart;
  for (int k = 0; k < 9; k++) {
    final Graha lord = vimshottariOrder[(firstIndex + k) % 9];
    final double length = share(lord);
    final double periodStart = cursor;
    final double periodEnd = cursor + length;
    cursor = periodEnd;
    final double s = math.max(periodStart, startJd);
    final double e = math.min(periodEnd, endJd);
    if (e <= s) continue;
    periods.add(
      MuddaPeriod(
        lord: lord,
        startJd: s,
        endJd: e,
        subPeriods: _subPeriods(lord, periodStart, length, s, e),
        isBalance: k == 0,
        isCarryOver: false,
      ),
    );
  }
  // The first lord's dasha comes round again for the part that was already
  // gone at the pravesh.
  final double carryStart = periods.isEmpty ? startJd : periods.last.endJd;
  if (endJd - carryStart > 1e-9) {
    periods.add(
      MuddaPeriod(
        lord: firstLord,
        startJd: carryStart,
        endJd: endJd,
        subPeriods: _subPeriods(
          firstLord,
          cursor,
          firstLength,
          carryStart,
          endJd,
        ),
        isBalance: false,
        isCarryOver: true,
      ),
    );
  } else if (periods.isNotEmpty) {
    // Rounding: the cycle closes on the year's end exactly.
    final MuddaPeriod last = periods.removeLast();
    periods.add(
      MuddaPeriod(
        lord: last.lord,
        startJd: last.startJd,
        endJd: endJd,
        subPeriods: last.subPeriods,
        isBalance: last.isBalance,
        isCarryOver: last.isCarryOver,
      ),
    );
  }

  final List<Bi> factors = <Bi>[
    Bi(
      'Birth nakshatra ${nakshatra.english}, whose Vimshottari lord is '
          '${grahaBi(nakshatra.lord).en}',
      'जन्म नक्षत्र ${nakshatra.hindi}, जिसका विंशोत्तरी स्वामी '
          '${grahaBi(nakshatra.lord).hi} है',
    ),
    Bi(
      'Year $age moves the start $age places along the Vimshottari order '
          '(it repeats every nine, so ${age % 9} net), so the year opens with '
          '${grahaBi(firstLord).en}',
      'वर्ष $age शुरुआत को विंशोत्तरी क्रम में $age स्थान आगे ले जाता है '
          '(क्रम नौ पर दोहराता है, इसलिए ${age % 9} शुद्ध), इसलिए वर्ष '
          '${grahaBi(firstLord).hi} से खुलता है',
    ),
    Bi(
      'The natal Moon had crossed ${(elapsed * 100).toStringAsFixed(1)}% of '
          'its nakshatra, so that share of ${grahaBi(firstLord).en}’s dasha '
          'is already gone at the pravesh',
      'जन्म का चंद्र अपने नक्षत्र का ${(elapsed * 100).toStringAsFixed(1)}% पार '
          'कर चुका था, इसलिए ${grahaBi(firstLord).hi} की उतनी दशा प्रवेश पर '
          'बीत चुकी है',
    ),
    Bi(
      '120 Vimshottari years are mapped to this year’s '
          '${year.toStringAsFixed(2)} days',
      '120 विंशोत्तरी वर्ष इस वर्ष के ${year.toStringAsFixed(2)} दिनों में '
          'बाँटे गए हैं',
    ),
  ];

  return MuddaDasha(
    periods: periods,
    startLord: firstLord,
    birthNakshatraLord: nakshatra.lord,
    advancedBy: age % 9,
    elapsedFraction: elapsed,
    yearDays: year,
    factors: factors,
  );
}

// ---------------------------------------------------------------------------
// Patyayini dasha
// ---------------------------------------------------------------------------

/// One Patyayini period. [graha] is null for the lagna's own period.
class PatyayiniPeriod {
  const PatyayiniPeriod({
    required this.graha,
    required this.name,
    required this.degree,
    required this.deducted,
    required this.startJd,
    required this.endJd,
    required this.reading,
    required this.factors,
  });

  final Graha? graha;
  final Bi name;

  /// Degrees the graha (or the lagna) stands at within its sign.
  final double degree;

  /// The degrees left after taking away the one before: its share of the
  /// year.
  final double deducted;
  final double startJd;
  final double endJd;
  final Bi reading;
  final List<Bi> factors;

  double get days => endJd - startJd;
  DateTime get startUtc => utcFromJulianDay(startJd);
  DateTime get endUtc => utcFromJulianDay(endJd);
}

class PatyayiniDasha {
  const PatyayiniDasha({
    required this.periods,
    required this.yearDays,
    required this.factors,
  });

  final List<PatyayiniPeriod> periods;
  final double yearDays;
  final List<Bi> factors;

  double get totalDays =>
      periods.fold(0.0, (double sum, PatyayiniPeriod p) => sum + p.days);
}

/// Patyayini dasha for the year of the annual chart [chart].
///
/// The seven grahas and the lagna are set in a row by the degrees they stand
/// at within their signs (the signs themselves left out), the fewest first.
/// Each one's share of the year is the number of degrees between it and the
/// one before it; the first has its own degrees. The shares sum to the
/// degrees of the last, so the year is divided in that proportion
/// (Hayanaratna 7.1; the texts it cites for leaving the signs out are the
/// Tajikamuktavali, the Tajikabhushana and the Tajikaratnamala; Yadava, who
/// counts the signs too, is the one dissent it notes, and is not followed).
/// The books count a year of 360 days; the app divides the actual length of
/// the year.
///
/// Where two stand at the same degree the stronger by five-fold strength comes
/// first, then the one whose true motion is slower, then the order lagna, Sun,
/// Moon, Mars, Mercury, Jupiter, Venus, Saturn (Hayanaratna 7.1).
PatyayiniDasha computePatyayini(
  Kundli chart,
  Map<Graha, PanchaVargiyaBala> bala, {
  required double startJd,
  required double endJd,
}) {
  final double year = endJd - startJd;
  final List<({Graha? graha, double degree, int canon})> entries =
      <({Graha? graha, double degree, int canon})>[
        (graha: null, degree: degreesInRashi(chart.ascendant), canon: 0),
        for (final Graha g in tajikaGrahas)
          (
            graha: g,
            degree: chart.grahas[g]!.degreesInSign,
            canon: 1 + tajikaGrahas.indexOf(g),
          ),
      ];
  entries.sort((a, b) {
    final double diff = a.degree - b.degree;
    if (diff.abs() > 1e-9) return diff < 0 ? -1 : 1;
    if (a.graha != null && b.graha != null) {
      final int byBala = bala[b.graha!]!.vishwa.compareTo(
        bala[a.graha!]!.vishwa,
      );
      if (byBala != 0) return byBala;
      final int bySpeed = chart.grahas[a.graha!]!.speed.abs().compareTo(
        chart.grahas[b.graha!]!.speed.abs(),
      );
      if (bySpeed != 0) return bySpeed;
    }
    return a.canon.compareTo(b.canon);
  });

  final double span = entries.last.degree;
  final List<PatyayiniPeriod> periods = <PatyayiniPeriod>[];
  double cursor = startJd;
  double previousDegree = 0;
  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final double deducted = entry.degree - previousDegree;
    previousDegree = entry.degree;
    if (deducted <= 0) continue;
    final bool last = i == entries.length - 1;
    final double length = span > 0 ? year * deducted / span : year / 8;
    final double end = last ? endJd : cursor + length;
    final Bi name = entry.graha == null
        ? const Bi('Lagna', 'लग्न')
        : grahaBi(entry.graha!);
    final String placeEn = entry.graha == null
        ? 'the lagna'
        : '${grahaBi(entry.graha!).en} in ${houseBi(chart.grahas[entry.graha!]!.house).en}';
    final String placeHi = entry.graha == null
        ? 'लग्न'
        : '${grahaBi(entry.graha!).hi} '
              '${houseBi(chart.grahas[entry.graha!]!.house).hi} में';
    final Bi reading = entry.graha == null
        ? const Bi(
            'The lagna’s own stretch: the year’s general direction and the '
                'self are what the tradition looks to.',
            'लग्न का अपना खंड: परंपरा वर्ष की सामान्य दिशा और स्वयं को देखती '
                'है।',
          )
        : Bi(
            'In ${grahaBi(entry.graha!).en}’s stretch the tradition looks to '
                '${grahaTheme(entry.graha!).en}, and to the matters of '
                '${housesBi(housesRuledBy(chart, entry.graha!)).en} which it '
                'rules; it stands in '
                '${houseBi(chart.grahas[entry.graha!]!.house).en}, which '
                'colours the stretch.',
            '${grahaBi(entry.graha!).hi} के खंड में परंपरा '
                '${grahaTheme(entry.graha!).hi} को देखती है, और '
                '${housesBi(housesRuledBy(chart, entry.graha!)).hi} के उन '
                'विषयों को जिनका वह स्वामी है; वह '
                '${houseBi(chart.grahas[entry.graha!]!.house).hi} में है, जो '
                'इस खंड को रंग देता है।',
          );
    periods.add(
      PatyayiniPeriod(
        graha: entry.graha,
        name: name,
        degree: entry.degree,
        deducted: deducted,
        startJd: cursor,
        endJd: end,
        reading: reading,
        factors: <Bi>[
          Bi(
            '$placeEn stands at ${degText(entry.degree)} of its sign',
            '$placeHi अपनी राशि के ${degText(entry.degree)} पर है',
          ),
          Bi(
            'Its share is ${degText(deducted)}, the degrees between it and the '
                'one before it, of ${degText(span)} in all',
            'इसका हिस्सा ${degText(deducted)} है, यानी इसके और पिछले के बीच '
                'के अंश, कुल ${degText(span)} में से',
          ),
        ],
      ),
    );
    cursor = end;
  }

  return PatyayiniDasha(
    periods: periods,
    yearDays: year,
    factors: <Bi>[
      const Bi(
        'The seven grahas and the lagna are ordered by their degrees within '
            'their signs, fewest first, the signs themselves left out',
        'सातों ग्रह और लग्न अपनी राशि के भीतर के अंशों से, कम से अधिक, क्रम में '
            'रखे गए हैं; राशियाँ छोड़ दी गई हैं',
      ),
      Bi(
        'Each takes the degrees between it and the one before; the year’s '
            '${year.toStringAsFixed(2)} days are divided in that proportion',
        'हर एक पिछले से अपने बीच के अंश लेता है; वर्ष के '
            '${year.toStringAsFixed(2)} दिन उसी अनुपात में बाँटे गए हैं',
      ),
    ],
  );
}
