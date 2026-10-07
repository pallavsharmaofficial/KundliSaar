import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/data/places_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final PlacesRepository places = PlacesRepository();

  Future<List<String>> namesFor(String query) async {
    final List<Place> found = await places.search(query);
    return found.map((Place p) => p.name).toList();
  }

  group('finding a birth place', () {
    test('a name typed without its macrons still finds the town', () async {
      // Two in five Indian names in the gazetteer carry one. They were all
      // in the file and none of them could be reached from a keyboard.
      for (final String typed in <String>[
        'jhansi',
        'aligarh',
        'rajkot',
        'ghaziabad',
        'sikar',
        'ratlam',
        'barmer',
      ]) {
        final List<String> found = await namesFor(typed);
        expect(found, isNotEmpty, reason: typed);
      }
    });

    test('the district towns people are actually born in are present', () async {
      for (final String town in <String>[
        'Jhansi', 'Rewa', 'Satna', 'Chhindwara', 'Betul', 'Guna', 'Damoh',
        'Bhilwara', 'Tonk', 'Pali', 'Bundi', 'Sikar',
        'Gorakhpur', 'Etawah', 'Hardoi', 'Basti', 'Banda', 'Deoria',
        'Muzaffarpur', 'Chhapra', 'Hajipur', 'Siwan', 'Purnia', 'Begusarai',
      ]) {
        expect(await namesFor(town.toLowerCase()), isNotEmpty, reason: town);
      }
    });

    test('a place carries its state, not a bare code', () async {
      final List<Place> found = await places.search('jhansi');
      expect(found.first.admin, 'Uttar Pradesh');
      expect(found.first.label, contains('Uttar Pradesh'));
      expect(found.first.timeZoneId, 'Asia/Kolkata');
    });

    test('searching a state name lists its towns', () async {
      expect(await namesFor('rajasthan'), isNotEmpty);
    });

    test('every place has coordinates, a zone and a search key', () async {
      final List<Place> all = await places.load();
      expect(all.length, greaterThan(9000));
      for (final Place p in all) {
        expect(p.latitude, inInclusiveRange(-90, 90));
        expect(p.longitude, inInclusiveRange(-180, 180));
        expect(p.timeZoneId, isNotEmpty);
        expect(p.searchKey, isNotEmpty);
        expect(p.searchKey, equals(p.searchKey.toLowerCase()));
      }
    });
  });
}
