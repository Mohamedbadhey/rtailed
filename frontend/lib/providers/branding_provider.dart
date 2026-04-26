import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/type_converter.dart';

class BrandingProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // System branding
  Map<String, dynamic> _systemBranding = {};
  bool _systemBrandingLoaded = false;
  
  // Business branding
  Map<String, dynamic> _businessBranding = {};
  bool _businessBrandingLoaded = false;
  
  // Available themes
  List<Map<String, dynamic>> _themes = [];
  bool _themesLoaded = false;
  
  // Getters
  Map<String, dynamic> get systemBranding => _systemBranding;
  bool get systemBrandingLoaded => _systemBrandingLoaded;
  
  Map<String, dynamic> get businessBranding => _businessBranding;
  bool get businessBrandingLoaded => _businessBrandingLoaded;
  
  List<Map<String, dynamic>> get themes => _themes;
  bool get themesLoaded => _themesLoaded;
  
  // Get system branding info
  Future<void> loadSystemBranding() async {
    try {
            final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/system'),
        headers: {'Content-Type': 'application/json'},
      );
      
                  if (response.statusCode == 200) {
        final rawData = json.decode(response.body);
                                        _systemBranding = TypeConverter.safeToMap(rawData);
        _systemBrandingLoaded = true;
        
                                        notifyListeners();
              } else {
                      }
    } catch (e) {
                }
  }
  
  // Update system branding
  Future<bool> updateSystemBranding(Map<String, dynamic> brandingData) async {
    try {
      final response = await http.put(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/system'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_apiService.token ?? ''}',
        },
        body: json.encode(brandingData),
      );
      
      if (response.statusCode == 200) {
        // Update local branding data immediately
        _systemBranding.addAll(brandingData);
        _systemBrandingLoaded = true;
        
        // Notify all listeners to update the UI
        notifyListeners();
        
        // Also reload from server to get any server-side changes
        await loadSystemBranding();
        return true;
      }
      return false;
    } catch (e) {
            return false;
    }
  }
  
  // Upload system logo/favicon
  Future<Map<String, dynamic>?> uploadSystemFile(File file, String type) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/system/upload'),
      );
      
      request.headers['Authorization'] = 'Bearer ${_apiService.token ?? ''}';
      request.fields['type'] = type;
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final result = TypeConverter.safeToMap(json.decode(response.body));
        
        // Update local branding data immediately
        if (result['fileUrl'] != null) {
          if (type == 'logo') {
            _systemBranding['logo_url'] = result['fileUrl'];
          } else if (type == 'favicon') {
            _systemBranding['favicon_url'] = result['fileUrl'];
          }
        }
        
        // Notify all listeners to update the UI immediately
        notifyListeners();
        
        // Also reload from server to get any server-side changes
        await loadSystemBranding();
        return result;
      } else {
        final errorData = json.decode(response.body);
                throw Exception(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Upload system logo/favicon for web (using bytes)
  Future<Map<String, dynamic>?> uploadSystemFileBytes(Uint8List bytes, String type) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/system/upload'),
      );
      
      request.headers['Authorization'] = 'Bearer ${_apiService.token ?? ''}';
      request.fields['type'] = type;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '${type}_${DateTime.now().millisecondsSinceEpoch}.png',
          contentType: MediaType('image', 'png'),
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final result = TypeConverter.safeToMap(json.decode(response.body));
        
        // Update local branding data immediately
        if (result['fileUrl'] != null) {
          if (type == 'logo') {
            _systemBranding['logo_url'] = result['fileUrl'];
          } else if (type == 'favicon') {
            _systemBranding['favicon_url'] = result['fileUrl'];
          }
        }
        
        // Notify all listeners to update the UI immediately
        notifyListeners();
        
        // Also reload from server to get any server-side changes
        await loadSystemBranding();
        return result;
      } else {
        final errorData = json.decode(response.body);
                throw Exception(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
            rethrow;
    }
  }
  
  // Load business branding
  Future<void> loadBusinessBranding(int businessId) async {
    try {
                  final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/business/$businessId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_apiService.token ?? ''}',
        },
      );
      
                  if (response.statusCode == 200) {
        final rawData = json.decode(response.body);
                                        _businessBranding = TypeConverter.safeToMap(rawData);
        _businessBrandingLoaded = true;
        
                                        notifyListeners();
              } else {
                        throw Exception('Failed to load business branding: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
                  rethrow; // Re-throw the exception so the UI can handle it
    }
  }
  
  // Update business branding
  Future<bool> updateBusinessBranding(int businessId, Map<String, dynamic> brandingData) async {
    try {
      final response = await http.put(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/business/$businessId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_apiService.token ?? ''}',
        },
        body: json.encode(brandingData),
      );
      
      if (response.statusCode == 200) {
        // Update local branding data immediately
        _businessBranding.addAll(brandingData);
        _businessBrandingLoaded = true;
        
        // Notify all listeners to update the UI
        notifyListeners();
        
        // Also reload from server to get any server-side changes
        await loadBusinessBranding(businessId);
        return true;
      }
      return false;
    } catch (e) {
            return false;
    }
  }
  
  // Upload business logo/favicon (using same logic as product images)
  Future<Map<String, dynamic>?> uploadBusinessFile(File file, String type, int businessId) async {
    try {
            var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/business/$businessId/upload'),
      );
      
      // Use same header logic as product images
      final multipartHeaders = Map<String, String>.from({
        'Authorization': 'Bearer ${_apiService.token ?? ''}',
      });
      request.headers.addAll(multipartHeaders);
      
      // Add type field
      request.fields['type'] = type;
      
      // Use 'image' field name like product images, with proper filename
      final fileName = file.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // Changed from 'file' to 'image' to match product logic
          file.path,
          filename: fileName, // Use actual filename instead of generic
        ),
      );
      
            final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
            if (response.statusCode == 200) {
        final result = TypeConverter.safeToMap(json.decode(response.body));
        
        // Update local branding data immediately
        if (result['fileUrl'] != null) {
          if (type == 'logo') {
            _businessBranding['logo'] = result['fileUrl'];
                      } else if (type == 'favicon') {
            _businessBranding['favicon'] = result['fileUrl'];
                      }
        }
        
        // Notify all listeners to update the UI immediately
        notifyListeners();
        
        // Also reload from server to get any server-side changes
        await loadBusinessBranding(businessId);
        return result;
      } else {
        final errorData = json.decode(response.body);
                throw Exception(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
            rethrow;
    }
  }

  // Upload business logo/favicon for web (using same logic as product images)
  Future<Map<String, dynamic>?> uploadBusinessFileBytes(Uint8List bytes, String type, int businessId) async {
    try {
            var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/business/$businessId/upload'),
      );
      
      // Use same header logic as product images
      final multipartHeaders = Map<String, String>.from({
        'Authorization': 'Bearer ${_apiService.token ?? ''}',
      });
      request.headers.addAll(multipartHeaders);
      
      // Add type field
      request.fields['type'] = type;
      
      // Use 'image' field name like product images, with proper filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${type}_$timestamp.png';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image', // Changed from 'file' to 'image' to match product logic
          bytes,
          filename: fileName, // Use proper filename instead of generic
        ),
      );
      
            final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
            if (response.statusCode == 200) {
        final result = TypeConverter.safeToMap(json.decode(response.body));
        
        // Update local branding data immediately
        if (result['fileUrl'] != null) {
          if (type == 'logo') {
            _businessBranding['logo'] = result['fileUrl'];
                      } else if (type == 'favicon') {
            _businessBranding['favicon'] = result['fileUrl'];
                      }
        }
        
        // Notify all listeners to update the UI immediately
        notifyListeners();
        
        // Also reload from server to get any server-side changes
        await loadBusinessBranding(businessId);
        return result;
      } else {
        final errorData = json.decode(response.body);
                throw Exception(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
            rethrow;
    }
  }
  
  // Load themes
  Future<void> loadThemes() async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/themes'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _themes = TypeConverter.safeToList(data);
        _themesLoaded = true;
        notifyListeners();
      }
    } catch (e) {
          }
  }
  
  // Get branding files for business
  Future<List<Map<String, dynamic>>> getBusinessFiles(int businessId) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/business/$businessId/files'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_apiService.token ?? ''}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TypeConverter.safeToList(data);
      }
      return [];
    } catch (e) {
            return [];
    }
  }
  
  // Delete branding file
  Future<bool> deleteFile(int fileId) async {
    try {
      final response = await http.delete(
        Uri.parse('https://rtailed-production.up.railway.app/api/branding/files/$fileId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_apiService.token ?? ''}',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
            return false;
    }
  }
  
  // Getters for current branding details
  String? getCurrentLogo(int? businessId) {
    if (businessId != null && _businessBrandingLoaded) {
      final logo = TypeConverter.safeToString(_businessBranding['logo']);
            return logo;
    }
    final systemLogo = TypeConverter.safeToString(_systemBranding['logo_url']);
        return systemLogo;
  }
  
  String? getCurrentFavicon(int? businessId) {
    if (businessId != null && _businessBrandingLoaded) {
      return TypeConverter.safeToString(_businessBranding['favicon']);
    }
    return TypeConverter.safeToString(_systemBranding['favicon_url']);
  }
  
  String getCurrentAppName(int? businessId) {
    if (businessId != null && _businessBrandingLoaded) {
      final appName = TypeConverter.safeToString(_businessBranding['name'] ?? 'Kobciye');
            return appName;
    }
    final systemAppName = TypeConverter.safeToString(_systemBranding['app_name'] ?? 'Kobciye');
        return systemAppName;
  }
  
  Color getPrimaryColor(int? businessId) {
    String colorHex;
    if (businessId != null && _businessBrandingLoaded) {
      colorHex = TypeConverter.safeToString(_businessBranding['primary_color'] ?? '#1976D2');
    } else {
      colorHex = TypeConverter.safeToString(_systemBranding['primary_color'] ?? '#1976D2');
    }
    return _hexToColor(colorHex);
  }
  
  Color getSecondaryColor(int? businessId) {
    String colorHex;
    if (businessId != null && _businessBrandingLoaded) {
      colorHex = TypeConverter.safeToString(_businessBranding['secondary_color'] ?? '#424242');
    } else {
      colorHex = TypeConverter.safeToString(_systemBranding['secondary_color'] ?? '#424242');
    }
    return _hexToColor(colorHex);
  }
  
  Color getAccentColor(int? businessId) {
    String colorHex;
    if (businessId != null && _businessBrandingLoaded) {
      colorHex = TypeConverter.safeToString(_businessBranding['accent_color'] ?? '#FFC107');
    } else {
      colorHex = TypeConverter.safeToString(_systemBranding['accent_color'] ?? '#FFC107');
    }
    return _hexToColor(colorHex);
  }
  
  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }
  
  // Get current branding based on business ID
  Map<String, dynamic> getCurrentBranding(int? businessId) {
    if (businessId != null && _businessBrandingLoaded) {
      return _businessBranding;
    }
    return _systemBranding;
  }
  
  // Get business branding for specific business
  Map<String, dynamic> getBusinessBranding(int businessId) {
    if (_businessBrandingLoaded && _businessBranding.isNotEmpty) {
      return _businessBranding;
    }
    return {};
  }
  
  // Get current business logo
  String? getCurrentBusinessLogo(int businessId) {
    if (_businessBrandingLoaded) {
      return TypeConverter.safeToString(_businessBranding['logo']);
    }
    return null;
  }
  
  // Get current business favicon
  String? getCurrentBusinessFavicon(int businessId) {
    if (_businessBrandingLoaded) {
      return TypeConverter.safeToString(_businessBranding['favicon']);
    }
    return null;
  }
} 