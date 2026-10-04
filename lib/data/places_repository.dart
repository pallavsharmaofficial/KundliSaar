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
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['n'] as String,
    admin: (json['a'] as String?) ?? '',
    country: json['c'] as String,
    latitude: (json['y'] as num).toDouble(),
    longitude: (json['x'] as num).toDouble(),
    timeZoneId: json['z'] as String,
    population: (json['p'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final String admin;
  final String country;
  final double latitude;
  final double longitude;
  final String timeZoneId;
  final int population;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'n': name,
    'a': admin,
    'c': country,
    'y': latitude,
    'x': longitude,
    'z': timeZoneId,
    'p': population,
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
      final String name = _fold(place.name);
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

  static String _fold(String value) => value.toLowerCase().trim();
}
