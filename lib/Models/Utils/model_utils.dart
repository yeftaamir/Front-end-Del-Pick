// lib/models/utils/model_utils.dart
class ModelUtils {
  // Parse list of objects from JSON
  static List<T> parseList<T>(
      dynamic json,
      T Function(Map<String, dynamic>) fromJson,
      ) {
    if (json == null) return [];

    if (json is List) {
      return json
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }

    return [];
  }

  // Safe date parsing
  static DateTime? parseDateTime(dynamic json) {
    if (json == null) return null;

    try {
      if (json is String) {
        return DateTime.parse(json);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Safe double parsing
  static double? parseDouble(dynamic json) {
    if (json == null) return null;

    try {
      if (json is num) {
        return json.toDouble();
      }
      if (json is String) {
        return double.parse(json);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Safe int parsing
  static int? parseInt(dynamic json) {
    if (json == null) return null;

    try {
      if (json is num) {
        return json.toInt();
      }
      if (json is String) {
        return int.parse(json);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Safe bool parsing
  static bool parseBool(dynamic json, {bool defaultValue = false}) {
    if (json == null) return defaultValue;

    if (json is bool) return json;
    if (json is String) {
      return json.toLowerCase() == 'true' || json == '1';
    }
    if (json is num) {
      return json != 0;
    }

    return defaultValue;
  }
}