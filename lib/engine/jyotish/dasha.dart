import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'nakshatra.dart';

/// Length of the Vimshottari solar year in days.
const double vimshottariYear = 365.2425;

const List<Graha> vimshottariOrder = <Graha>[
  Graha.ketu,
  Graha.venus,
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.rahu,
  Graha.jupiter,
  Graha.saturn,
  Graha.mercury,
];

const Map<Graha, double> vimshottariYears = <Graha, double>{
  Graha.ketu: 7,
  Graha.venus: 20,
  Graha.sun: 6,
  Graha.moon: 10,
  Graha.mars: 7,
  Graha.rahu: 18,
  Graha.jupiter: 16,
  Graha.saturn: 19,
  Graha.mercury: 17,
};

/// One period in a dasha tree.
class DashaPeriod {
  DashaPeriod({
    required this.lord,
    required this.startJdUt,
    required this.endJdUt,
    required this.level,
    this.children = const <DashaPeriod>[],
  });

  final Graha lord;
  final double startJdUt;
  final double endJdUt;

  /// 1 = mahadasha, 2 = antardasha, 3 = pratyantardasha.
  final int level;
  final List<DashaPeriod> children;

  double get lengthDays => endJdUt - startJdUt;

  DateTime get start => utcFromJulianDay(startJdUt);
  DateTime get end => utcFromJulianDay(endJdUt);

  bool contains(double jdUt) => jdUt >= startJdUt && jdUt < endJdUt;
}

/// Builds the Vimshottari tree from the Moon's sidereal longitude at birth.
///
/// The first mahadasha is the one of the Moon's nakshatra lord, and only the
/// unspent part of it is left at birth, which is why a five-minute error in
/// birth time can move every later period by weeks.
///
/// That first mahadasha began before the person was born, so its antardashas
/// and pratyantardashas keep the grid of the whole span and birth simply cuts
/// into it: the native is born part-way through whichever sub-period was
/// running, and the sub-periods before that one never appear. Squeezing nine
/// sub-periods into the balance instead would misdate every one of them.
List<DashaPeriod> vimshottariTree({
  required double moonSiderealLongitude,
  required double birthJdUt,
  int levels = 3,
  int mahadashas = 9,
}) {
  final NakshatraInfo nakshatra = nakshatraOf(moonSiderealLongitude);
  final double within = moonSiderealLongitude % nakshatraSpan;
  final double elapsed = within / nakshatraSpan;
  final int startIndex = vimshottariOrder.indexOf(nakshatra.lord);
  final double firstYears = vimshottariYears[nakshatra.lord]!;
  final double balanceDays = (1 - elapsed) * firstYears * vimshottariYear;

  final List<DashaPeriod> periods = <DashaPeriod>[];
  double cursor = birthJdUt;
  for (int i = 0; i < mahadashas; i++) {
    final Graha lord = vimshottariOrder[(startIndex + i) % 9];
    final double fullDays = vimshottariYears[lord]! * vimshottariYear;
    final double days = i == 0 ? balanceDays : fullDays;
    final double end = cursor + days;
    periods.add(
      DashaPeriod(
        lord: lord,
        startJdUt: cursor,
        endJdUt: end,
        level: 1,
        children: levels > 1
            ? _subPeriods(
                lord,
                end - fullDays,
                end,
                2,
                levels,
                clipFrom: i == 0 ? cursor : null,
              )
            : const <DashaPeriod>[],
      ),
    );
    cursor = end;
  }
  return periods;
}

/// Splits [start, end] among the nine sub-lords in proportion to their years.
///
/// With [clipFrom] set, anything that ended before it is dropped and the one
/// straddling it starts there, with its own children still laid out on the
/// grid of its whole span.
List<DashaPeriod> _subPeriods(
  Graha lord,
  double start,
  double end,
  int level,
  int maxLevel, {
  double? clipFrom,
}) {
  final int startIndex = vimshottariOrder.indexOf(lord);
  final double total = end - start;
  final List<DashaPeriod> out = <DashaPeriod>[];
  double cursor = start;
  for (int i = 0; i < 9; i++) {
    final Graha sub = vimshottariOrder[(startIndex + i) % 9];
    final double share = vimshottariYears[sub]! / 120.0;
    final double subEnd = i == 8 ? end : cursor + total * share;
    final bool before = clipFrom != null && subEnd <= clipFrom;
    if (!before) {
      final bool straddles = clipFrom != null && cursor < clipFrom;
      out.add(
        DashaPeriod(
          lord: sub,
          startJdUt: straddles ? clipFrom : cursor,
          endJdUt: subEnd,
          level: level,
          children: level < maxLevel
              ? _subPeriods(
                  sub,
                  cursor,
                  subEnd,
                  level + 1,
                  maxLevel,
                  clipFrom: straddles ? clipFrom : null,
                )
              : const <DashaPeriod>[],
        ),
      );
    }
    cursor = subEnd;
  }
  return out;
}

/// The chain of periods running at [jdUt], outermost first.
List<DashaPeriod> dashaAt(List<DashaPeriod> tree, double jdUt) {
  final List<DashaPeriod> chain = <DashaPeriod>[];
  List<DashaPeriod> level = tree;
  while (true) {
    final DashaPeriod? match = level
        .where((DashaPeriod p) => p.contains(jdUt))
        .firstOrNull;
    if (match == null) break;
    chain.add(match);
    if (match.children.isEmpty) break;
    level = match.children;
  }
  return chain;
}

/// The eight Yoginis, a 36-year cycle read alongside Vimshottari.
const List<String> yoginiNames = <String>[
  'Mangala',
  'Pingala',
  'Dhanya',
  'Bhramari',
  'Bhadrika',
  'Ulka',
  'Siddha',
  'Sankata',
];

const List<Graha> yoginiLords = <Graha>[
  Graha.moon,
  Graha.sun,
  Graha.jupiter,
  Graha.mars,
  Graha.mercury,
  Graha.saturn,
  Graha.venus,
  Graha.rahu,
];

const List<int> yoginiYears = <int>[1, 2, 3, 4, 5, 6, 7, 8];

class YoginiPeriod {
  const YoginiPeriod({
    required this.name,
    required this.lord,
    required this.startJdUt,
    required this.endJdUt,
  });

  final String name;
  final Graha lord;
  final double startJdUt;
  final double endJdUt;
}

List<YoginiPeriod> yoginiDasha({
  required double moonSiderealLongitude,
  required double birthJdUt,
  int count = 8,
}) {
  final int nakshatra = nakshatraIndexOf(moonSiderealLongitude) + 1;
  final int first = (nakshatra + 3) % 8;
  final double within = moonSiderealLongitude % nakshatraSpan;
  final double elapsed = within / nakshatraSpan;
  final List<YoginiPeriod> out = <YoginiPeriod>[];
  double cursor = birthJdUt;
  for (int i = 0; i < count; i++) {
    final int index = (first + i) % 8;
    double days = yoginiYears[index] * vimshottariYear;
    if (i == 0) days *= (1 - elapsed);
    out.add(
      YoginiPeriod(
        name: yoginiNames[index],
        lord: yoginiLords[index],
        startJdUt: cursor,
        endJdUt: cursor + days,
      ),
    );
    cursor += days;
  }
  return out;
}
