import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/shadbala.dart';
import 'package:kundlisaar/engine/jyotish/yogas.dart';

void main() {
  final DateTime local = DateTime(1990, 8, 15, 10, 30);
  final Duration off = TimeZones.offsetFor('Asia/Kolkata', local);
  final Kundli k = computeKundli(BirthData(name: 'T', localDateTime: local, utcOffset: off, place: const GeoPlace(name: 'Delhi', latitude: 28.6139, longitude: 77.2090, timeZoneId: 'Asia/Kolkata')));
  print('lagna ${k.lagnaRashi} moon ${k.moonRashi} off $off');
  for (final PlacedGraha g in k.grahas.values) {
    print('${g.graha.name} ${g.siderealLongitude.toStringAsFixed(2)} h${g.house} ${g.dignity.name}');
  }
  final sw = Stopwatch()..start();
  print(computeShadbala(k).length);
  print(findYogas(k).map((y) => y.key).toList());
  print('ms ${sw.elapsedMilliseconds}');
}
