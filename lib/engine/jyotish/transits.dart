import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'ashtakavarga.dart';
import 'chart.dart';
import 'nakshatra.dart';
import 'rashi.dart';

/// Gochar: where the grahas are now, read against where they were at birth.
class TransitPosition {
  const TransitPosition({
    required this.graha,
    required this.siderealLongitude,
    required this.speed,
    required this.houseFromLagna,
    required this.houseFromMoon,
    required this.bindusInSign,
  });

  final Graha graha;
  final double siderealLongitude;
  final double speed;
  final int houseFromLagna;

  /// The count that matters most in classical gochar.
  final int houseFromMoon;

  /// Sarvashtakavarga bindus in the sign being transited.
  final int bindusInSign;

  Rashi get rashi => rashiOf(siderealLongitude);
  NakshatraInfo get nakshatra => nakshatraOf(siderealLongitude);
  bool get isRetrograde =>
      speed < 0 && graha != Graha.rahu && graha != Graha.ketu;
}

/// An aspect a transiting graha is casting on a natal one.
class TransitAspect {
  const TransitAspect({
    required this.transiting,
    required this.natal,
    required this.houseDistance,
    required this.orb,
  });

  final Graha transiting;
  final Graha natal;
  final int houseDistance;

  /// Degrees from exact, in the sense of sign-to-sign aspects.
  final double orb;
}

/// Houses from the natal Moon that the tradition calls favourable for a
/// transiting graha. Anything else is read as work rather than ease.
const Map<Graha, List<int>> favourableFromMoon = <Graha, List<int>>{
  Graha.sun: <int>[3, 6, 10, 11],
  Graha.moon: <int>[1, 3, 6, 7, 10, 11],
  Graha.mars: <int>[3, 6, 11],
  Graha.mercury: <int>[2, 4, 6, 8, 10, 11],
  Graha.jupiter: <int>[2, 5, 7, 9, 11],
  Graha.venus: <int>[1, 2, 3, 4, 5, 8, 9, 11, 12],
  Graha.saturn: <int>[3, 6, 11],
  Graha.rahu: <int>[3, 6, 10, 11],
  Graha.ketu: <int>[3, 6, 10, 11],
};

class TransitReport {
  const TransitReport({
    required this.moment,
    required this.positions,
    required this.aspects,
    required this.sadeSati,
    required this.jupiterReturn,
    required this.saturnReturn,
  });

  final DateTime moment;
  final Map<Graha, TransitPosition> positions;
  final List<TransitAspect> aspects;
  final SadeSatiWindow sadeSati;

  /// Dates when Jupiter and Saturn next reach their natal signs.
  final DateTime? jupiterReturn;
  final DateTime? saturnReturn;

  bool isFavourable(Graha graha) =>
      favourableFromMoon[graha]!.contains(positions[graha]!.houseFromMoon);
}

/// The full seven and a half year passage of Saturn over the natal Moon.
class SadeSatiWindow {
  const SadeSatiWindow({
    required this.isRunning,
    required this.phase,
    required this.start,
    required this.end,
    required this.phaseEnd,
  });

  final bool isRunning;

  /// 1, 2 or 3 while running, 0 otherwise.
  final int phase;
  final DateTime? start;
  final DateTime? end;
  final DateTime? phaseEnd;
}

double _sidereal(Graha graha, Instant instant, Ayanamsa ayanamsa) => toSidereal(
  positionOf(graha, instant).tropicalLongitude,
  ayanamsa,
  instant.centuriesTt,
);

/// Finds when [graha] next enters [targetSign], searching forward in steps.
DateTime? _nextIngress(
  Graha graha,
  DateTime from,
  int targetSign,
  Ayanamsa ayanamsa, {
  int maxDays = 11000,
  double stepDays = 5,
}) {
  double jd = julianDayFromUtc(from.toUtc());
  int previous =
      (_sidereal(graha, Instant.fromJulianDayUt(jd), ayanamsa) / 30).floor() %
      12;
  for (double day = stepDays; day < maxDays; day += stepDays) {
    final Instant instant = Instant.fromJulianDayUt(jd + day);
    final int sign = (_sidereal(graha, instant, ayanamsa) / 30).floor() % 12;
    if (sign != previous && sign == targetSign) {
      // Bisect for the day of the change.
      double low = jd + day - stepDays;
      double high = jd + day;
      for (int i = 0; i < 24; i++) {
        final double mid = (low + high) / 2;
        final int at =
            (_sidereal(graha, Instant.fromJulianDayUt(mid), ayanamsa) / 30)
                .floor() %
            12;
        if (at == targetSign) {
          high = mid;
        } else {
          low = mid;
        }
      }
      return utcFromJulianDay(high);
    }
    previous = sign;
  }
  return null;
}

/// When a graha entered the sign it stands in, and when it next leaves it.
class SignStay {
  const SignStay({
    required this.sign,
    required this.entered,
    required this.leaves,
  });

  final int sign;

  /// The most recent moment the graha crossed into [sign], or null when it has
  /// been there longer than the search reaches.
  final DateTime? entered;

  /// The first moment after the one asked for that it stands outside [sign].
  /// A retrograde graha can come back across the line, so this is when it
  /// first leaves, not when it is done with the sign for good.
  final DateTime? leaves;
}

int _signAt(Graha graha, double jdUt, Ayanamsa ayanamsa) =>
    (_sidereal(graha, Instant.fromJulianDayUt(jdUt), ayanamsa) / 30).floor() %
    12;

/// Finds the entry into, and the first exit from, the sign [graha] occupies at
/// [moment]. The scan steps [stepDays] at a time and bisects the step that
/// crosses the boundary, which is exact to well under a minute.
SignStay signStayAt(
  Graha graha,
  DateTime moment,
  Ayanamsa ayanamsa, {
  int maxDays = 1600,
  double stepDays = 5,
}) {
  final double jd = julianDayFromUtc(moment.toUtc());
  final int here = _signAt(graha, jd, ayanamsa);

  double? crossing(double direction) {
    for (double day = stepDays; day <= maxDays; day += stepDays) {
      final double at = jd + direction * day;
      if (_signAt(graha, at, ayanamsa) == here) continue;
      // [inside] still stands in the sign, [outside] no longer does.
      double inside = jd + direction * (day - stepDays);
      double outside = at;
      for (int i = 0; i < 24; i++) {
        final double mid = (inside + outside) / 2;
        if (_signAt(graha, mid, ayanamsa) == here) {
          inside = mid;
        } else {
          outside = mid;
        }
      }
      return (inside + outside) / 2;
    }
    return null;
  }

  final double? back = crossing(-1);
  final double? ahead = crossing(1);
  return SignStay(
    sign: here,
    entered: back == null ? null : utcFromJulianDay(back),
    leaves: ahead == null ? null : utcFromJulianDay(ahead),
  );
}

SadeSatiWindow _sadeSati(Kundli kundli, DateTime moment) {
  final Ayanamsa ayanamsa = kundli.ayanamsa;
  final int moonSign = kundli.moonRashi.index;
  final Instant now = Instant.fromUtc(moment.toUtc());
  final int saturnSign =
      (_sidereal(Graha.saturn, now, ayanamsa) / 30).floor() % 12;
  final int distance = (saturnSign - moonSign + 12) % 12;
  final bool running = distance == 11 || distance == 0 || distance == 1;
  if (!running) {
    final DateTime? start = _nextIngress(
      Graha.saturn,
      moment,
      (moonSign + 11) % 12,
      ayanamsa,
    );
    return SadeSatiWindow(
      isRunning: false,
      phase: 0,
      start: start,
      end: start == null
          ? null
          : _nextIngress(
              Graha.saturn,
              start.add(const Duration(days: 400)),
              (moonSign + 2) % 12,
              ayanamsa,
            ),
      phaseEnd: null,
    );
  }
  final int phase = distance == 11 ? 1 : (distance == 0 ? 2 : 3);
  final DateTime? phaseEnd = _nextIngress(
    Graha.saturn,
    moment,
    (saturnSign + 1) % 12,
    ayanamsa,
    maxDays: 1400,
  );
  final DateTime? end = _nextIngress(
    Graha.saturn,
    moment,
    (moonSign + 2) % 12,
    ayanamsa,
    maxDays: 4000,
  );
  return SadeSatiWindow(
    isRunning: true,
    phase: phase,
    start: null,
    end: phase == 3 ? phaseEnd : end,
    phaseEnd: phaseEnd,
  );
}

TransitReport computeTransits(Kundli kundli, DateTime moment) {
  final Instant instant = Instant.fromUtc(moment.toUtc());
  final AshtakavargaResult ashtakavarga = computeAshtakavarga(kundli);
  final int lagnaSign = kundli.lagnaRashi.index;
  final int moonSign = kundli.moonRashi.index;

  final Map<Graha, TransitPosition> positions = <Graha, TransitPosition>{};
  for (final Graha graha in Graha.values) {
    final BodyPosition body = positionOf(graha, instant);
    final double sidereal = toSidereal(
      body.tropicalLongitude,
      kundli.ayanamsa,
      instant.centuriesTt,
    );
    final int sign = (sidereal / 30).floor() % 12;
    positions[graha] = TransitPosition(
      graha: graha,
      siderealLongitude: sidereal,
      speed: body.speed,
      houseFromLagna: ((sign - lagnaSign + 12) % 12) + 1,
      houseFromMoon: ((sign - moonSign + 12) % 12) + 1,
      bindusInSign: ashtakavarga.sarva[sign],
    );
  }

  final List<TransitAspect> aspects = <TransitAspect>[];
  for (final Graha transiting in <Graha>[
    Graha.sun,
    Graha.mars,
    Graha.jupiter,
    Graha.saturn,
    Graha.rahu,
  ]) {
    for (final Graha natal in Graha.values) {
      final double orb = norm180(
        positions[transiting]!.siderealLongitude -
            kundli.grahas[natal]!.siderealLongitude,
      ).abs();
      final int distance =
          ((rashiOf(positions[transiting]!.siderealLongitude).index -
                  kundli.grahas[natal]!.rashi.index +
                  12) %
              12) +
          1;
      final bool casts =
          distance == 1 ||
          distance == 7 ||
          (transiting == Graha.mars && <int>[4, 8].contains(distance)) ||
          (transiting == Graha.jupiter && <int>[5, 9].contains(distance)) ||
          (transiting == Graha.saturn && <int>[3, 10].contains(distance));
      if (casts && orb < 12) {
        aspects.add(
          TransitAspect(
            transiting: transiting,
            natal: natal,
            houseDistance: distance,
            orb: orb,
          ),
        );
      }
    }
  }
  aspects.sort((TransitAspect a, TransitAspect b) => a.orb.compareTo(b.orb));

  return TransitReport(
    moment: moment,
    positions: positions,
    aspects: aspects,
    sadeSati: _sadeSati(kundli, moment),
    jupiterReturn: _nextIngress(
      Graha.jupiter,
      moment,
      kundli.grahas[Graha.jupiter]!.rashi.index,
      kundli.ayanamsa,
      maxDays: 4600,
      stepDays: 10,
    ),
    saturnReturn: _nextIngress(
      Graha.saturn,
      moment,
      kundli.grahas[Graha.saturn]!.rashi.index,
      kundli.ayanamsa,
      maxDays: 11000,
      stepDays: 15,
    ),
  );
}
