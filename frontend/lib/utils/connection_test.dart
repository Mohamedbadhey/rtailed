import 'package:http/http.dart' as http;
import 'dart:convert';

class ConnectionTest {
  static const String baseUrl = 'https://rtailed-production.up.railway.app/api';

  /// Test the connection to the backend server
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Backend connection successful',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Backend responded with status: ${response.statusCode}',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend',
        'error': e.toString(),
      };
    }
  }

  /// Test database connection through the backend
  static Future<Map<String, dynamic>> testDatabaseConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Database connection successful',
          'data': 'Products endpoint accessible',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Database connected but authentication required',
          'error': 'Please login to access data',
        };
      } else {
        return {
          'success': false,
          'message': 'Database connection failed',
          'error': 'Status: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to test database connection',
        'error': e.toString(),
      };
    }
  }

  /// Get connection status summary
  static Future<Map<String, dynamic>> getConnectionStatus() async {
    final backendTest = await testConnection();
    final dbTest = await testDatabaseConnection();

    return {
      'backend': backendTest,
      'database': dbTest,
      'overall': backendTest['success'] && dbTest['success'],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
} 