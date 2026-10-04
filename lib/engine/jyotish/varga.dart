import 'rashi.dart';

/// The sixteen divisional charts of the Shodashavarga scheme.
enum Varga {
  d1,
  d2,
  d3,
  d4,
  d7,
  d9,
  d10,
  d12,
  d16,
  d20,
  d24,
  d27,
  d30,
  d40,
  d45,
  d60,
}

class VargaInfo {
  const VargaInfo(
    this.varga,
    this.divisions,
    this.english,
    this.hindi,
    this.reads,
  );

  final Varga varga;
  final int divisions;
  final String english;
  final String hindi;

  /// What the chart is traditionally read for.
  final String reads;
}

const List<VargaInfo> vargaTable = <VargaInfo>[
  VargaInfo(Varga.d1, 1, 'Rasi', 'राशि', 'The body, the life as a whole'),
  VargaInfo(Varga.d2, 2, 'Hora', 'होरा', 'Wealth and resources'),
  VargaInfo(Varga.d3, 3, 'Drekkana', 'द्रेष्काण', 'Siblings, courage'),
  VargaInfo(Varga.d4, 4, 'Chaturthamsa', 'चतुर्थांश', 'Home, land, fortune'),
  VargaInfo(Varga.d7, 7, 'Saptamsa', 'सप्तांश', 'Children and lineage'),
  VargaInfo(
    Varga.d9,
    9,
    'Navamsa',
    'नवांश',
    'Marriage, dharma, inner strength',
  ),
  VargaInfo(Varga.d10, 10, 'Dasamsa', 'दशांश', 'Work and standing'),
  VargaInfo(Varga.d12, 12, 'Dwadasamsa', 'द्वादशांश', 'Parents and ancestry'),
  VargaInfo(Varga.d16, 16, 'Shodasamsa', 'षोडशांश', 'Vehicles, comforts'),
  VargaInfo(
    Varga.d20,
    20,
    'Vimsamsa',
    'विंशांश',
    'Worship and spiritual practice',
  ),
  VargaInfo(
    Varga.d24,
    24,
    'Chaturvimsamsa',
    'चतुर्विंशांश',
    'Learning and education',
  ),
  VargaInfo(Varga.d27, 27, 'Bhamsa', 'भांश', 'Strengths and weaknesses'),
  VargaInfo(
    Varga.d30,
    30,
    'Trimsamsa',
    'त्रिंशांश',
    'Troubles and their causes',
  ),
  VargaInfo(Varga.d40, 40, 'Khavedamsa', 'खवेदांश', 'Maternal legacy'),
  VargaInfo(
    Varga.d45,
    45,
    'Akshavedamsa',
    'अक्षवेदांश',
    'Paternal legacy, character',
  ),
  VargaInfo(Varga.d60, 60, 'Shashtiamsa', 'षष्ठ्यंश', 'The sum of past karma'),
];

VargaInfo vargaInfo(Varga varga) =>
    vargaTable.firstWhere((VargaInfo info) => info.varga == varga);

bool _isOdd(int sign) =>
    sign % 2 == 0; // zero-based: Aries, Gemini, ... are odd signs

Quality _qualityOf(int sign) => Quality.values[sign % 3];

Element _elementOf(int sign) => Element.values[sign % 4];

/// The sign a longitude falls in for a given divisional chart, zero-based.
///
/// Follows the Parashari rules as they are given in Brihat Parashara Hora
/// Shastra, chapter 6.
int vargaSign(Varga varga, double siderealLongitude) {
  final int sign = (siderealLongitude / 30.0).floor() % 12;
  final double deg = siderealLongitude % 30.0;
  switch (varga) {
    case Varga.d1:
      return sign;
    case Varga.d2:
      // Leo for the Sun's hora, Cancer for the Moon's.
      final bool firstHalf = deg < 15.0;
      if (_isOdd(sign)) return firstHalf ? 4 : 3;
      return firstHalf ? 3 : 4;
    case Varga.d3:
      return (sign + 4 * (deg / 10.0).floor()) % 12;
    case Varga.d4:
      return (sign + 3 * (deg / 7.5).floor()) % 12;
    case Varga.d7:
      final int part = (deg / (30.0 / 7)).floor();
      return _isOdd(sign) ? (sign + part) % 12 : (sign + 6 + part) % 12;
    case Varga.d9:
      return (siderealLongitude / (30.0 / 9)).floor() % 12;
    case Varga.d10:
      final int part = (deg / 3.0).floor();
      return _isOdd(sign) ? (sign + part) % 12 : (sign + 8 + part) % 12;
    case Varga.d12:
      return (sign + (deg / 2.5).floor()) % 12;
    case Varga.d16:
      final int part = (deg / (30.0 / 16)).floor();
      final int start = switch (_qualityOf(sign)) {
        Quality.movable => 0,
        Quality.fixed => 4,
        Quality.dual => 8,
      };
      return (start + part) % 12;
    case Varga.d20:
      final int part = (deg / 1.5).floor();
      final int start = switch (_qualityOf(sign)) {
        Quality.movable => 0,
        Quality.fixed => 8,
        Quality.dual => 4,
      };
      return (start + part) % 12;
    case Varga.d24:
      final int part = (deg / 1.25).floor();
      return _isOdd(sign) ? (4 + part) % 12 : (3 + part) % 12;
    case Varga.d27:
      final int part = (deg / (30.0 / 27)).floor();
      final int start = switch (_elementOf(sign)) {
        Element.fire => 0,
        Element.earth => 3,
        Element.air => 6,
        Element.water => 9,
      };
      return (start + part) % 12;
    case Varga.d30:
      if (_isOdd(sign)) {
        if (deg < 5) return 0; // Mars
        if (deg < 10) return 10; // Saturn
        if (deg < 18) return 8; // Jupiter
        if (deg < 25) return 2; // Mercury
        return 6; // Venus
      }
      if (deg < 5) return 1; // Venus
      if (deg < 12) return 5; // Mercury
      if (deg < 20) return 11; // Jupiter
      if (deg < 25) return 9; // Saturn
      return 7; // Mars
    case Varga.d40:
      final int part = (deg / 0.75).floor();
      return (_isOdd(sign) ? part : 6 + part) % 12;
    case Varga.d45:
      final int part = (deg / (30.0 / 45)).floor();
      final int start = switch (_qualityOf(sign)) {
        Quality.movable => 0,
        Quality.fixed => 4,
        Quality.dual => 8,
      };
      return (start + part) % 12;
    case Varga.d60:
      final int part = (deg / 0.5).floor();
      return (sign + part) % 12;
  }
}

/// A representative longitude inside the varga sign, so divisional charts can
/// be drawn with degrees as well as placements.
double vargaLongitude(Varga varga, double siderealLongitude) {
  final int sign = vargaSign(varga, siderealLongitude);
  final VargaInfo info = vargaInfo(varga);
  final double span = 30.0 / info.divisions;
  final double within = (siderealLongitude % span) / span * 30.0;
  return sign * 30.0 + within;
}
