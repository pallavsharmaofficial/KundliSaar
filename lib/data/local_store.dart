import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A tiny JSON document store over shared_preferences, which is localStorage
/// on the web. Everything the app keeps about a person lives here and nowhere
/// else: there is no account and no server.
class LocalStore {
  LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  List<Map<String, dynamic>> readList(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic> readMap(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final dynamic decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

class StoreKeys {
  static const String profiles = 'profiles';
  static const String settings = 'settings';
  static const String lastProfile = 'last_profile';
}
