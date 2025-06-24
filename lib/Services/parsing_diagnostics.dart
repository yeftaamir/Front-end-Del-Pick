// lib/Utils/parsing_diagnostics.dart
import 'dart:convert';

class ParsingDiagnostics {

  /// Comprehensive diagnosis of menu item parsing issues
  static Map<String, dynamic> diagnoseMenuItemParsing(dynamic rawData) {
    final diagnosis = <String, dynamic>{
      'status': 'unknown',
      'issues': <String>[],
      'suggestions': <String>[],
      'data_structure': {},
      'field_analysis': {},
    };

    try {
      if (rawData == null) {
        diagnosis['status'] = 'null_data';
        diagnosis['issues'].add('Raw data is null');
        return diagnosis;
      }

      if (rawData is! Map<String, dynamic>) {
        diagnosis['status'] = 'invalid_type';
        diagnosis['issues'].add('Raw data is not a Map<String, dynamic>');
        diagnosis['suggestions'].add('Ensure API returns proper JSON object');
        return diagnosis;
      }

      final data = rawData as Map<String, dynamic>;
      diagnosis['data_structure'] = _analyzeDataStructure(data);
      diagnosis['field_analysis'] = _analyzeFields(data);

      // Check for common issues
      _checkPriceField(data, diagnosis);
      _checkIdField(data, diagnosis);
      _checkBooleanFields(data, diagnosis);
      _checkStringFields(data, diagnosis);

      // Determine overall status
      if (diagnosis['issues'].isEmpty) {
        diagnosis['status'] = 'healthy';
      } else {
        diagnosis['status'] = 'has_issues';
      }

    } catch (e) {
      diagnosis['status'] = 'error';
      diagnosis['issues'].add('Diagnosis failed: $e');
    }

    return diagnosis;
  }

  /// Analyze the overall data structure
  static Map<String, dynamic> _analyzeDataStructure(Map<String, dynamic> data) {
    return {
      'total_fields': data.length,
      'field_names': data.keys.toList(),
      'field_types': data.map((key, value) => MapEntry(key, value?.runtimeType.toString() ?? 'null')),
      'null_fields': data.entries.where((e) => e.value == null).map((e) => e.key).toList(),
      'empty_string_fields': data.entries.where((e) => e.value is String && (e.value as String).isEmpty).map((e) => e.key).toList(),
    };
  }

  /// Analyze individual fields for parsing compatibility
  static Map<String, dynamic> _analyzeFields(Map<String, dynamic> data) {
    final analysis = <String, dynamic>{};

    // Analyze each field
    data.forEach((key, value) {
      analysis[key] = {
        'value': value,
        'type': value?.runtimeType.toString() ?? 'null',
        'can_parse_as_int': _canParseAsInt(value),
        'can_parse_as_double': _canParseAsDouble(value),
        'can_parse_as_bool': _canParseAsBool(value),
        'is_nullable': value == null,
        'is_empty_string': value is String && (value as String).isEmpty,
      };
    });

    return analysis;
  }

  /// Check price field specifically
  static void _checkPriceField(Map<String, dynamic> data, Map<String, dynamic> diagnosis) {
    final priceField = data['price'];

    if (priceField == null) {
      diagnosis['issues'].add('Price field is null');
      diagnosis['suggestions'].add('Ensure price field is provided by API');
      return;
    }

    if (priceField is String) {
      diagnosis['suggestions'].add('Price is coming as string: "$priceField"');

      // Check if it looks like a decimal number
      if (RegExp(r'^\d+\.\d{2}$').hasMatch(priceField)) {
        diagnosis['suggestions'].add('Price appears to be in decimal format (e.g., "15000.00")');
        diagnosis['suggestions'].add('This should be parseable with proper string handling');
      }

      // Check for currency symbols
      if (priceField.contains('Rp') || priceField.contains(',') || priceField.contains('.')) {
        diagnosis['issues'].add('Price contains formatting characters');
        diagnosis['suggestions'].add('Clean price string before parsing');
      }
    } else if (priceField is! num) {
      diagnosis['issues'].add('Price field is not a number or string: ${priceField.runtimeType}');
      diagnosis['suggestions'].add('API should return price as number or parseable string');
    }
  }

  /// Check ID fields
  static void _checkIdField(Map<String, dynamic> data, Map<String, dynamic> diagnosis) {
    ['id', 'store_id'].forEach((fieldName) {
      final field = data[fieldName];
      if (field != null && field is! int && field is! String) {
        diagnosis['issues'].add('$fieldName is not int or string: ${field.runtimeType}');
        diagnosis['suggestions'].add('Convert $fieldName to int or string');
      }
    });
  }

  /// Check boolean fields
  static void _checkBooleanFields(Map<String, dynamic> data, Map<String, dynamic> diagnosis) {
    ['is_available', 'isAvailable'].forEach((fieldName) {
      final field = data[fieldName];
      if (field != null && !_canParseAsBool(field)) {
        diagnosis['issues'].add('$fieldName cannot be parsed as boolean: $field (${field.runtimeType})');
        diagnosis['suggestions'].add('Ensure $fieldName is boolean, string ("true"/"false"), or int (0/1)');
      }
    });
  }

  /// Check string fields
  static void _checkStringFields(Map<String, dynamic> data, Map<String, dynamic> diagnosis) {
    ['name', 'description', 'category'].forEach((fieldName) {
      final field = data[fieldName];
      if (field != null && field is! String) {
        diagnosis['issues'].add('$fieldName is not a string: ${field.runtimeType}');
        diagnosis['suggestions'].add('Convert $fieldName to string');
      }
    });
  }

  /// Check if value can be parsed as int
  static bool _canParseAsInt(dynamic value) {
    if (value == null) return false;
    if (value is int) return true;
    if (value is double) return true;
    if (value is String) {
      return int.tryParse(value) != null;
    }
    return false;
  }

  /// Check if value can be parsed as double
  static bool _canParseAsDouble(dynamic value) {
    if (value == null) return false;
    if (value is num) return true;
    if (value is String) {
      return double.tryParse(value.replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', '')) != null;
    }
    return false;
  }

  /// Check if value can be parsed as bool
  static bool _canParseAsBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return true;
    if (value is int) return value == 0 || value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return ['true', 'false', '1', '0'].contains(lower);
    }
    return false;
  }

  /// Pretty print diagnosis results
  static void printDiagnosis(Map<String, dynamic> diagnosis) {
    print('🩺 ====== PARSING DIAGNOSIS ======');
    print('📊 Status: ${diagnosis['status']}');

    if (diagnosis['issues'].isNotEmpty) {
      print('❌ Issues Found:');
      for (String issue in diagnosis['issues']) {
        print('   • $issue');
      }
    }

    if (diagnosis['suggestions'].isNotEmpty) {
      print('💡 Suggestions:');
      for (String suggestion in diagnosis['suggestions']) {
        print('   • $suggestion');
      }
    }

    if (diagnosis['data_structure'] != null) {
      final structure = diagnosis['data_structure'];
      print('📋 Data Structure:');
      print('   • Total fields: ${structure['total_fields']}');
      print('   • Field names: ${structure['field_names']}');
      print('   • Field types: ${structure['field_types']}');

      if (structure['null_fields'].isNotEmpty) {
        print('   • Null fields: ${structure['null_fields']}');
      }

      if (structure['empty_string_fields'].isNotEmpty) {
        print('   • Empty string fields: ${structure['empty_string_fields']}');
      }
    }

    print('🩺 ====== END DIAGNOSIS ======');
  }

  /// Test parsing with the actual MenuItemModel
  static Map<String, dynamic> testMenuItemParsing(Map<String, dynamic> rawData) {
    final result = <String, dynamic>{
      'success': false,
      'error': null,
      'parsed_data': null,
      'parsing_issues': <String>[],
    };

    try {
      // Import and test the actual model
      // Note: This would need to import the actual MenuItemModel
      // For now, we'll simulate the parsing logic

      final testParsing = <String, dynamic>{};

      // Test ID parsing
      try {
        testParsing['id'] = _parseId(rawData['id']);
      } catch (e) {
        result['parsing_issues'].add('ID parsing failed: $e');
      }

      // Test price parsing
      try {
        testParsing['price'] = _parsePrice(rawData['price']);
      } catch (e) {
        result['parsing_issues'].add('Price parsing failed: $e');
      }

      // Test store_id parsing
      try {
        testParsing['store_id'] = _parseId(rawData['store_id']);
      } catch (e) {
        result['parsing_issues'].add('Store ID parsing failed: $e');
      }

      // Test boolean parsing
      try {
        testParsing['is_available'] = _parseBool(rawData['is_available'] ?? rawData['isAvailable']);
      } catch (e) {
        result['parsing_issues'].add('Boolean parsing failed: $e');
      }

      result['parsed_data'] = testParsing;
      result['success'] = result['parsing_issues'].isEmpty;

    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  // Helper parsing methods (similar to MenuItemModel)
  static int _parseId(dynamic id) {
    if (id == null) return 0;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    if (id is double) return id.toInt();
    return 0;
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      String cleanPrice = price.replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', '').trim();
      if (price.contains('.') && price.split('.').length == 2) {
        final parts = price.replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', '').split('.');
        if (parts.length == 2 && parts[1].length <= 2) {
          return double.parse(price.replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', ''));
        }
      }
      cleanPrice = cleanPrice.replaceAll('.', '');
      return double.parse(cleanPrice);
    }
    return 0.0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value == 1;
    return true;
  }
}