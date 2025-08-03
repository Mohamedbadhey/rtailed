import 'dart:convert';

/// Utility class to safely convert data types and handle JSON parsing issues
class TypeConverter {
  /// Safely convert dynamic data to Map<String, dynamic>
  static Map<String, dynamic> safeToMap(dynamic data) {
    if (data == null) return {};
    
    if (data is Map<String, dynamic>) {
      return data;
    }
    
    if (data is Map) {
      // Handle LinkedMap<dynamic, dynamic> and other Map types
      final result = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = _safeConvertValue(entry.value);
        result[key] = value;
      }
      return result;
    }
    
    if (data is String) {
      try {
        final json = jsonDecode(data);
        return safeToMap(json);
      } catch (e) {
        return {};
      }
    }
    
    return {};
  }

  /// Safely convert dynamic data to List<Map<String, dynamic>>
  static List<Map<String, dynamic>> safeToList(dynamic data) {
    if (data == null) return [];
    
    if (data is List<Map<String, dynamic>>) {
      return data;
    }
    
    if (data is List) {
      return data.map((item) => safeToMap(item)).toList();
    }
    
    return [];
  }

  /// Safely convert a value to the appropriate type
  static dynamic _safeConvertValue(dynamic value) {
    if (value == null) return null;
    
    // Handle numeric conversions
    if (value is num) {
      return value.toDouble();
    }
    
    if (value is String) {
      // Try to convert numeric strings to double
      if (_isNumeric(value)) {
        return double.tryParse(value) ?? value;
      }
      return value;
    }
    
    if (value is bool) {
      return value;
    }
    
    if (value is Map) {
      return safeToMap(value);
    }
    
    if (value is List) {
      return value.map((item) => _safeConvertValue(item)).toList();
    }
    
    return value.toString();
  }

  /// Check if a string is numeric
  static bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return double.tryParse(str) != null;
  }

  /// Safely convert to double
  static double safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Safely convert to int
  static int safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Safely convert to string
  static String safeToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  /// Safely convert to boolean
  static bool safeToBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  /// Convert MySQL data types to proper Dart types
  static Map<String, dynamic> convertMySQLTypes(dynamic data) {
    final converted = safeToMap(data);
    final result = <String, dynamic>{};
    
    for (final entry in converted.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Handle specific MySQL type conversions
      if (key == 'is_active' || key == 'is_deleted' || key == 'is_read') {
        result[key] = safeToBool(value);
      } else if (key == 'last_login' || key == 'read_at' || key == 'created_at' || key == 'updated_at') {
        result[key] = value; // Keep as is for dates
      } else if (value is num) {
        result[key] = value.toDouble();
      } else if (value is String && _isNumeric(value)) {
        result[key] = double.tryParse(value) ?? value;
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  /// Convert a list of MySQL data to proper Dart types
  static List<Map<String, dynamic>> convertMySQLList(List<dynamic> data) {
    return data.map((item) => convertMySQLTypes(item)).toList();
  }

  /// Safe JSON parsing with error handling
  static Map<String, dynamic> safeJsonDecode(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      return safeToMap(decoded);
    } catch (e) {
      print('Error parsing JSON: $e');
      return {};
    }
  }

  /// Safe JSON encoding with error handling
  static String safeJsonEncode(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      print('Error encoding JSON: $e');
      return '{}';
    }
  }
} 