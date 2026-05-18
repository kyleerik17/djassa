import 'package:shared_preferences/shared_preferences.dart';

/// Source de données locale pour le stockage des préférences
class LocalDataSource {
  final SharedPreferences _prefs;

  LocalDataSource({required SharedPreferences prefs}) : _prefs = prefs;

  /// Sauvegarde une chaîne de caractères
  Future<void> saveString({required String key, required String value}) async {
    await _prefs.setString(key, value);
  }

  /// Récupère une chaîne de caractères
  String? getString(String key) {
    return _prefs.getString(key);
  }

  /// Sauvegarde un entier
  Future<void> saveInt({required String key, required int value}) async {
    await _prefs.setInt(key, value);
  }

  /// Récupère un entier
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  /// Sauvegarde un booléen
  Future<void> saveBool({required String key, required bool value}) async {
    await _prefs.setBool(key, value);
  }

  /// Récupère un booléen
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// Supprime une clé
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Efface toutes les données
  Future<void> clear() async {
    await _prefs.clear();
  }

  /// Vérifie si une clé existe
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
}
