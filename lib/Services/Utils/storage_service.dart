// lib/services/utils/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _preferences;

  // Initialize SharedPreferences
  static Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  // Get SharedPreferences instance
  static SharedPreferences get _prefs {
    if (_preferences == null) {
      throw Exception('StorageService not initialized. Call StorageService.init() first.');
    }
    return _preferences!;
  }

  // Save string
  static Future<bool> saveString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  // Get string
  static String? getString(String key) {
    return _prefs.getString(key);
  }

  // Save int
  static Future<bool> saveInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  // Get int
  static int? getInt(String key) {
    return _prefs.getInt(key);
  }

  // Save bool
  static Future<bool> saveBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  // Get bool
  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  // Save object as JSON
  static Future<bool> saveObject(String key, Map<String, dynamic> object) async {
    final String jsonString = json.encode(object);
    return await _prefs.setString(key, jsonString);
  }

  // Get object from JSON
  static Map<String, dynamic>? getObject(String key) {
    final String? jsonString = _prefs.getString(key);
    if (jsonString != null) {
      return json.decode(jsonString) as Map<String, dynamic>;
    }
    return null;
  }

  // Remove key
  static Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  // Clear all data
  static Future<bool> clear() async {
    return await _prefs.clear();
  }

  // Check if key exists
  static bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  // Get all keys
  static Set<String> getAllKeys() {
    return _prefs.getKeys();
  }
}