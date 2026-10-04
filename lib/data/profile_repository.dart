import '../models/saved_profile.dart';
import 'local_store.dart';

/// Profiles live on the device only.
class ProfileRepository {
  ProfileRepository(this._store);

  final LocalStore _store;

  List<SavedProfile> all() => _store
      .readList(StoreKeys.profiles)
      .map(SavedProfile.fromJson)
      .toList(growable: false);

  SavedProfile? byId(String id) {
    for (final SavedProfile profile in all()) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<void> save(SavedProfile profile) async {
    final List<SavedProfile> profiles = all().toList();
    final int index = profiles.indexWhere(
      (SavedProfile p) => p.id == profile.id,
    );
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.insert(0, profile);
    }
    await _store.writeList(
      StoreKeys.profiles,
      profiles.map((SavedProfile p) => p.toJson()).toList(growable: false),
    );
  }

  Future<void> delete(String id) async {
    final List<SavedProfile> profiles = all()
        .where((SavedProfile p) => p.id != id)
        .toList(growable: false);
    await _store.writeList(
      StoreKeys.profiles,
      profiles.map((SavedProfile p) => p.toJson()).toList(growable: false),
    );
  }
}
