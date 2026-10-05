import '../astro/ephemeris.dart';
import 'chart.dart';

/// Ashtakavarga: the bindu (benefic point) system of Parashara.
///
/// Each of the seven grahas has a fixed list of houses that are benefic when
/// counted from each of eight reference points - the seven grahas and the
/// lagna. Counting those for every sign gives that graha's bhinnashtakavarga,
/// and adding the seven together gives the sarvashtakavarga, which is what
/// practitioners read over a chart before anything else.
///
/// The grand total of all bindus is always 337, which the test suite checks.
const Map<Graha, Map<Graha, List<int>>> benefic =
    <Graha, Map<Graha, List<int>>>{
      Graha.sun: <Graha, List<int>>{
        Graha.sun: <int>[1, 2, 4, 7, 8, 9, 10, 11],
        Graha.moon: <int>[3, 6, 10, 11],
        Graha.mars: <int>[1, 2, 4, 7, 8, 9, 10, 11],
        Graha.mercury: <int>[3, 5, 6, 9, 10, 11, 12],
        Graha.jupiter: <int>[5, 6, 9, 11],
        Graha.venus: <int>[6, 7, 12],
        Graha.saturn: <int>[1, 2, 4, 7, 8, 9, 10, 11],
      },
      Graha.moon: <Graha, List<int>>{
        Graha.sun: <int>[3, 6, 7, 8, 10, 11],
        Graha.moon: <int>[1, 3, 6, 7, 10, 11],
        Graha.mars: <int>[2, 3, 5, 6, 9, 10, 11],
        Graha.mercury: <int>[1, 3, 4, 5, 7, 8, 10, 11],
        Graha.jupiter: <int>[1, 4, 7, 8, 10, 11, 12],
        Graha.venus: <int>[3, 4, 5, 7, 9, 10, 11],
        Graha.saturn: <int>[3, 5, 6, 11],
      },
      Graha.mars: <Graha, List<int>>{
        Graha.sun: <int>[3, 5, 6, 10, 11],
        Graha.moon: <int>[3, 6, 11],
        Graha.mars: <int>[1, 2, 4, 7, 8, 10, 11],
        Graha.mercury: <int>[3, 5, 6, 11],
        Graha.jupiter: <int>[6, 10, 11, 12],
        Graha.venus: <int>[6, 8, 11, 12],
        Graha.saturn: <int>[1, 4, 7, 8, 9, 10, 11],
      },
      Graha.mercury: <Graha, List<int>>{
        Graha.sun: <int>[5, 6, 9, 11, 12],
        Graha.moon: <int>[2, 4, 6, 8, 10, 11],
        Graha.mars: <int>[1, 2, 4, 7, 8, 9, 10, 11],
        Graha.mercury: <int>[1, 3, 5, 6, 9, 10, 11, 12],
        Graha.jupiter: <int>[6, 8, 11, 12],
        Graha.venus: <int>[1, 2, 3, 4, 5, 8, 9, 11],
        Graha.saturn: <int>[1, 2, 4, 7, 8, 9, 10, 11],
      },
      Graha.jupiter: <Graha, List<int>>{
        Graha.sun: <int>[1, 2, 3, 4, 7, 8, 9, 10, 11],
        Graha.moon: <int>[2, 5, 7, 9, 11],
        Graha.mars: <int>[1, 2, 4, 7, 8, 10, 11],
        Graha.mercury: <int>[1, 2, 4, 5, 6, 9, 10, 11],
        Graha.jupiter: <int>[1, 2, 3, 4, 7, 8, 10, 11],
        Graha.venus: <int>[2, 5, 6, 9, 10, 11],
        Graha.saturn: <int>[3, 5, 6, 12],
      },
      Graha.venus: <Graha, List<int>>{
        Graha.sun: <int>[8, 11, 12],
        Graha.moon: <int>[1, 2, 3, 4, 5, 8, 9, 11, 12],
        Graha.mars: <int>[3, 5, 6, 9, 11, 12],
        Graha.mercury: <int>[3, 5, 6, 9, 11],
        Graha.jupiter: <int>[5, 8, 9, 10, 11],
        Graha.venus: <int>[1, 2, 3, 4, 5, 8, 9, 10, 11],
        Graha.saturn: <int>[3, 4, 5, 8, 9, 10, 11],
      },
      Graha.saturn: <Graha, List<int>>{
        Graha.sun: <int>[1, 2, 4, 7, 8, 10, 11],
        Graha.moon: <int>[3, 6, 11],
        Graha.mars: <int>[3, 5, 6, 10, 11, 12],
        Graha.mercury: <int>[6, 8, 9, 10, 11, 12],
        Graha.jupiter: <int>[5, 6, 11, 12],
        Graha.venus: <int>[6, 11, 12],
        Graha.saturn: <int>[3, 5, 6, 11],
      },
    };

/// Benefic houses counted from the lagna, by graha.
const Map<Graha, List<int>> beneficFromLagna = <Graha, List<int>>{
  Graha.sun: <int>[3, 4, 6, 10, 11, 12],
  Graha.moon: <int>[3, 6, 10, 11],
  Graha.mars: <int>[1, 3, 6, 10, 11],
  Graha.mercury: <int>[1, 2, 4, 6, 8, 10, 11],
  Graha.jupiter: <int>[1, 2, 4, 5, 6, 7, 9, 10, 11],
  Graha.venus: <int>[1, 2, 3, 4, 5, 8, 9, 11],
  Graha.saturn: <int>[1, 3, 4, 6, 10, 11],
};

const List<Graha> ashtakavargaGrahas = <Graha>[
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

/// One graha's bhinnashtakavarga: bindus per sign, indexed from Aries.
class Bhinnashtakavarga {
  const Bhinnashtakavarga({required this.graha, required this.bindus});

  final Graha graha;
  final List<int> bindus;

  int get total => bindus.fold(0, (int sum, int b) => sum + b);

  /// Bindus in the sign a graha actually occupies: the number read first.
  int inOwnSign(int signIndex) => bindus[signIndex % 12];
}

/// Every bhinnashtakavarga plus the sarvashtakavarga.
class AshtakavargaResult {
  const AshtakavargaResult({required this.charts, required this.sarva});

  final Map<Graha, Bhinnashtakavarga> charts;

  /// Sum of the seven charts, by sign from Aries.
  final List<int> sarva;

  int get sarvaTotal => sarva.fold(0, (int sum, int b) => sum + b);

  /// Signs ordered by strength, strongest first.
  List<int> get strongestSigns {
    final List<int> order = List<int>.generate(12, (int i) => i);
    order.sort((int a, int b) => sarva[b].compareTo(sarva[a]));
    return order;
  }
}

AshtakavargaResult computeAshtakavarga(Kundli kundli) {
  final Map<Graha, int> signOf = <Graha, int>{
    for (final Graha graha in ashtakavargaGrahas)
      graha: kundli.grahas[graha]!.rashi.index,
  };
  final int lagnaSign = kundli.lagnaRashi.index;

  final Map<Graha, Bhinnashtakavarga> charts = <Graha, Bhinnashtakavarga>{};
  final List<int> sarva = List<int>.filled(12, 0);

  for (final Graha subject in ashtakavargaGrahas) {
    final List<int> bindus = List<int>.filled(12, 0);
    benefic[subject]!.forEach((Graha from, List<int> houses) {
      for (final int house in houses) {
        bindus[(signOf[from]! + house - 1) % 12] += 1;
      }
    });
    for (final int house in beneficFromLagna[subject]!) {
      bindus[(lagnaSign + house - 1) % 12] += 1;
    }
    charts[subject] = Bhinnashtakavarga(graha: subject, bindus: bindus);
    for (int i = 0; i < 12; i++) {
      sarva[i] += bindus[i];
    }
  }

  return AshtakavargaResult(charts: charts, sarva: sarva);
}

/// How the tradition reads a sarvashtakavarga score for a sign.
String sarvaVerdict(int bindus, {required bool hindi}) {
  if (bindus >= 34) {
    return hindi ? 'बहुत बलवान' : 'Very strong';
  }
  if (bindus >= 30) return hindi ? 'बलवान' : 'Strong';
  if (bindus >= 25) return hindi ? 'सामान्य' : 'Average';
  return hindi ? 'कमज़ोर' : 'Weak';
}
