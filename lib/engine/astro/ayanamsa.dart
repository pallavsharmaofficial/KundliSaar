import 'angles.dart';
import 'frames.dart';

/// Sidereal zodiac zero points the app can work in.
///
/// Each is defined by its value at J2000.0; the value at any other date is
/// that constant plus the general precession in longitude accumulated since.
enum Ayanamsa { lahiri, raman, krishnamurti, trueChitra, pushyaPaksha }

/// Value at J2000.0 in degrees.
const Map<Ayanamsa, double> _atJ2000 = <Ayanamsa, double>{
  Ayanamsa.lahiri: 23.853055555555557, // 23 51 11, the Indian standard
  Ayanamsa.raman: 21.013888888888889, // 21 00 50
  Ayanamsa.krishnamurti: 23.759444444444444, // 23 45 34
  Ayanamsa.trueChitra: 23.866111111111111, // Spica held at 180 00 00
  Ayanamsa.pushyaPaksha: 23.653333333333332, // Delta Cancri held at 106 00 00
};

const Map<Ayanamsa, String> ayanamsaNames = <Ayanamsa, String>{
  Ayanamsa.lahiri: 'Lahiri (Chitrapaksha)',
  Ayanamsa.raman: 'Raman',
  Ayanamsa.krishnamurti: 'Krishnamurti (KP)',
  Ayanamsa.trueChitra: 'True Chitra',
  Ayanamsa.pushyaPaksha: 'Pushya-paksha',
};

/// Ayanamsa in degrees at Julian centuries [t] of TT since J2000.
double ayanamsaDegrees(Ayanamsa which, double t) =>
    _atJ2000[which]! + precessionInLongitude(t);

/// Converts an apparent tropical longitude of date to sidereal.
double toSidereal(double tropicalLongitude, Ayanamsa which, double t) =>
    norm360(tropicalLongitude - ayanamsaDegrees(which, t));
