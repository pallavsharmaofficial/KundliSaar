import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/astro/houses.dart';

/// One place in the offline gazetteer.
class Place {
  const Place({
    required this.name,
    required this.admin,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timeZoneId,
    required this.population,
    this.searchKey = '',
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['n'] as String,
    admin: (json['a'] as String?) ?? '',
    country: json['c'] as String,
    latitude: (json['y'] as num).toDouble(),
    longitude: (json['x'] as num).toDouble(),
    timeZoneId: json['z'] as String,
    population: (json['p'] as num?)?.toInt() ?? 0,
    searchKey: (json['s'] as String?) ?? '',
  );

  final String name;
  final String admin;
  final String country;
  final double latitude;
  final double longitude;
  final String timeZoneId;
  final int population;

  /// The name folded to plain ASCII and lowercased, built when the asset is
  /// generated. Two in five Indian names carry a macron -- Jhānsi, Rājkot,
  /// Alīgarh -- and matching the raw name meant nobody typing on an ordinary
  /// keyboard could reach them.
  final String searchKey;

  String get _needle =>
      searchKey.isEmpty ? PlacesRepository._fold(name) : searchKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'n': name,
    'a': admin,
    'c': country,
    'y': latitude,
    'x': longitude,
    'z': timeZoneId,
    'p': population,
    if (searchKey.isNotEmpty) 's': searchKey,
  };

  String get label =>
      admin.isEmpty ? '$name, $country' : '$name, $admin, $country';

  GeoPlace toGeoPlace() => GeoPlace(
    name: label,
    latitude: latitude,
    longitude: longitude,
    timeZoneId: timeZoneId,
  );
}

/// Loads the bundled place list once and searches it in memory. Nothing here
/// touches the network, which is the point: the app has to work with the radio
/// off.
class PlacesRepository {
  PlacesRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<Place>? _places;

  Future<List<Place>> load() async {
    if (_places != null) return _places!;
    final String raw = await _bundle.loadString('assets/data/places.json');
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    _places = (json['places'] as List<dynamic>)
        .map((dynamic e) => Place.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _places!;
  }

  Future<List<Place>> search(String query, {int limit = 30}) async {
    final List<Place> places = await load();
    final String needle = _fold(query);
    if (needle.isEmpty) {
      return places.take(limit).toList(growable: false);
    }
    final List<Place> starts = <Place>[];
    final List<Place> contains = <Place>[];
    for (final Place place in places) {
      final String name = place._needle;
      if (name.startsWith(needle)) {
        starts.add(place);
      } else if (name.contains(needle) ||
          _fold(place.admin).startsWith(needle)) {
        contains.add(place);
      }
      if (starts.length >= limit) break;
    }
    return <Place>[...starts, ...contains].take(limit).toList(growable: false);
  }

  /// Lowercases and drops the diacritics, so a person typing "jhansi" or
  /// "aligarh" reaches Jhānsi and Alīgarh. The asset carries the same folding
  /// precomputed for every name; this is for what the person types.
  static String _fold(String value) {
    final StringBuffer out = StringBuffer();
    for (final int rune in value.toLowerCase().trim().runes) {
      out.write(_plain[rune] ?? String.fromCharCode(rune));
    }
    return out.toString();
  }

  /// Every non-ASCII letter the gazetteer actually uses, mapped to the key a
  /// person would press. Generated from the asset, not guessed.
  static const Map<int, String> _plain = <int, String>{
    0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
    0x101: 'a', 0x103: 'a', 0x105: 'a', 0x1EA1: 'a', 0x1EA7: 'a',
    0x1EAD: 'a', 0x1EAF: 'a',
    0xE7: 'c', 0x107: 'c', 0x10D: 'c',
    0x111: 'd', 0x10F: 'd', 0x1E0D: 'd',
    0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e', 0x113: 'e', 0x115: 'e',
    0x117: 'e', 0x119: 'e', 0x11B: 'e', 0x1EBF: 'e', 0x1EC7: 'e',
    0x11F: 'g', 0x123: 'g',
    0x1E25: 'h', 0x127: 'h',
    0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i', 0x129: 'i', 0x12B: 'i',
    0x12D: 'i', 0x131: 'i', 0x1ECB: 'i',
    0x142: 'l', 0x13C: 'l', 0x1E37: 'l',
    0xF1: 'n', 0x144: 'n', 0x146: 'n', 0x148: 'n', 0x1E45: 'n', 0x1E47: 'n',
    0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o',
    0x14D: 'o', 0x14F: 'o', 0x151: 'o', 0x1ED9: 'o', 0x1EDB: 'o',
    0x1EE3: 'o', 0x1EE1: 'o',
    0x159: 'r', 0x1E5B: 'r',
    0x15B: 's', 0x15F: 's', 0x161: 's', 0x1E63: 's',
    0x163: 't', 0x165: 't', 0x1E6D: 't',
    0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u', 0x169: 'u', 0x16B: 'u',
    0x16D: 'u', 0x16F: 'u', 0x1EE7: 'u', 0x1EE9: 'u',
    0xFD: 'y', 0xFF: 'y',
    0x17A: 'z', 0x17C: 'z', 0x17E: 'z',
    0x2019: "'",
    // Combining marks, for text that arrives already decomposed.
    0x304: '', 0x307: '', 0x323: '', 0x301: '', 0x300: '', 0x302: '',
    0x303: '', 0x308: '', 0x30C: '',
  };
}
