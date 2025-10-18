import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:retail_management/models/user.dart';
import 'package:retail_management/utils/api.dart';
import 'package:flutter/foundation.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  final ApiService _apiService;
  final SharedPreferences _prefs;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  AuthProvider(this._apiService, this._prefs) {
    _loadUser();
  }

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<void> _loadUser({BuildContext? context}) async {
    _token = _prefs.getString('token');
    if (_token != null) {
      print('Loading stored token: $_token'); // Debug log
      _apiService.setToken(_token!);
      try {
        _user = await _apiService.getProfile(context: context);
        print('User loaded: ${_user?.username}'); // Debug log
        notifyListeners();
      } catch (e) {
        print('Error loading user profile: $e'); // Debug log
        await logout();
      }
    } else {
      print('No stored token found'); // Debug log
    }
  }

  Future<void> login(String email, String password, {BuildContext? context}) async {
    try {
      print('Attempting login for user: $email'); // Debug log
      final response = await _apiService.login(email, password, context: context);
      _token = response['token'];
      _user = response['user'];
      print('Login successful, token: $_token'); // Debug log
      await _prefs.setString('token', _token!);
      _apiService.setToken(_token!);
      print('Token saved to preferences and set in ApiService'); // Debug log
      notifyListeners();
    } catch (e) {
      print('Login failed: $e'); // Debug log
      rethrow;
    }
  }

  Future<void> loginWithUsername(String username, String password, {BuildContext? context}) async {
    try {
      print('Attempting login with username: $username'); // Debug log
      final response = await _apiService.loginWithUsername(username, password, context: context);
      _token = response['token'];
      _user = response['user'];
      print('Login successful, token: $_token'); // Debug log
      await _prefs.setString('token', _token!);
      _apiService.setToken(_token!);
      print('Token saved to preferences and set in ApiService'); // Debug log
      notifyListeners();
    } catch (e) {
      print('Login failed: $e'); // Debug log
      rethrow;
    }
  }

  Future<void> loginWithIdentifier(String identifier, String password, {BuildContext? context}) async {
    try {
      print('Attempting login with identifier: $identifier'); // Debug log
      final response = await _apiService.loginWithIdentifier(identifier, password, context: context);
      _token = response['token'];
      _user = response['user'];
      print('Login successful, token: $_token'); // Debug log
      await _prefs.setString('token', _token!);
      _apiService.setToken(_token!);
      print('Token saved to preferences and set in ApiService'); // Debug log
      notifyListeners();
    } catch (e) {
      print('Login failed: $e'); // Debug log
      rethrow;
    }
  }

  Future<void> register(
    String username,
    String email,
    String password,
    String role,
    {String? adminCode, String? businessId}
  ) async {
    try {
      final response = await _apiService.register(
        username,
        email,
        password,
        role,
        adminCode: adminCode,
        businessId: businessId,
      );
      _token = response['token'];
      _user = response['user'];
      await _prefs.setString('token', _token!);
      _apiService.setToken(_token!);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _prefs.remove('token');
    _apiService.clearToken();
    await _storage.deleteAll();
    notifyListeners();
  }

  Future<void> checkAuth() async {
    try {
      final token = await _storage.read(key: 'token');
      final userData = await _storage.read(key: 'user');

      if (token != null && userData != null) {
        _token = token;
        _user = User.fromJson(json.decode(userData));
        notifyListeners();
      }
    } catch (e) {
      await logout();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? language,
  }) async {
    try {
      final updatedUser = await _apiService.updateProfile(
        username: username,
        email: email,
        currentPassword: currentPassword,
        newPassword: newPassword,
        language: language,
      );
      _user = updatedUser;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  bool hasPermission(String permission) {
    if (_user == null) return false;
    switch (_user!.role) {
      case 'admin':
        return true;
      case 'manager':
        return permission != 'manage_users';
      case 'cashier':
        return permission == 'process_sales';
      default:
        return false;
    }
  }

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }
} 