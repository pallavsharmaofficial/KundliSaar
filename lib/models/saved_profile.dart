import '../data/places_repository.dart';
import '../engine/jyotish/chart.dart';

/// A person whose kundli is stored on this device.
class SavedProfile {
  const SavedProfile({
    required this.id,
    required this.name,
    required this.localDateTime,
    required this.offsetMinutes,
    required this.place,
    this.timeIsApproximate = false,
    this.gender,
  });

  factory SavedProfile.fromJson(Map<String, dynamic> json) => SavedProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    localDateTime: DateTime.parse(json['when'] as String),
    offsetMinutes: (json['offset'] as num).toInt(),
    place: Place.fromJson(json['place'] as Map<String, dynamic>),
    timeIsApproximate: (json['approx'] as bool?) ?? false,
    gender: json['gender'] as String?,
  );

  final String id;
  final String name;
  final DateTime localDateTime;
  final int offsetMinutes;
  final Place place;
  final bool timeIsApproximate;
  final String? gender;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'when': localDateTime.toIso8601String(),
    'offset': offsetMinutes,
    'place': place.toJson(),
    'approx': timeIsApproximate,
    if (gender != null) 'gender': gender,
  };

  BirthData toBirthData() => BirthData(
    name: name,
    localDateTime: localDateTime,
    utcOffset: Duration(minutes: offsetMinutes),
    place: place.toGeoPlace(),
    timeIsApproximate: timeIsApproximate,
    gender: gender,
  );
}
