import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_management/providers/auth_provider.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'English';
  String _currency = 'USD';
  bool _notificationsEnabled = true;
  bool _autoPrintAfterSale = false; // auto print 58mm receipt after sale
  bool _printPromptEnabled = true;   // show the print choice prompt after sale


  final SharedPreferences prefs;
  AuthProvider? _authProvider;

  SettingsProvider(this.prefs) {
    _loadSettings();
  }

  // Set the auth provider reference
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  
  // Get language from current user or fallback to stored preference
  String get language {
    if (_authProvider?.user != null) {
      return _authProvider!.user!.language;
    }
    return _language;
  }
  
  String get currency => _currency;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get autoPrintAfterSale => _autoPrintAfterSale;
  bool get printPromptEnabled => _printPromptEnabled; // when false, suppress print prompt entirely

  void setPrintPromptEnabled(bool enabled) {
    _printPromptEnabled = enabled;
    prefs.setBool('printPromptEnabled', enabled);
    notifyListeners();
  }

  void setAutoPrintAfterSale(bool enabled) {
    _autoPrintAfterSale = enabled;
    prefs.setBool('autoPrintAfterSale', enabled);
    notifyListeners();
  }

  void _loadSettings() {
    final theme = prefs.getString('themeMode');
    if (theme != null) {
      _themeMode = ThemeMode.values.firstWhere((e) => e.toString() == theme, orElse: () => ThemeMode.system);
    }
    _language = prefs.getString('language') ?? 'English';
    _currency = prefs.getString('currency') ?? 'USD';
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    // Load printing preferences (fallback to defaults if not set yet)
    _printPromptEnabled = prefs.getBool('printPromptEnabled') ?? _printPromptEnabled;
    _autoPrintAfterSale = prefs.getBool('autoPrintAfterSale') ?? _autoPrintAfterSale;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    prefs.setString('themeMode', mode.toString());
    notifyListeners();
  }

  // Update language for current user
  void setLanguage(String lang) async {
    _language = lang;
    prefs.setString('language', lang);
    
    // Update user's language preference if user is logged in
    if (_authProvider?.user != null) {
      try {
        // Update user's language preference in the backend
        await _authProvider!.updateProfile(language: lang);
      } catch (e) {
        print('Error updating user language: $e');
        // Fallback to local update if API fails
        final updatedUser = _authProvider!.user!.copyWith(language: lang);
        _authProvider!.setUser(updatedUser);
      }
    }
    
    notifyListeners();
  }

  void setCurrency(String curr) {
    _currency = curr;
    prefs.setString('currency', curr);
    notifyListeners();
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    prefs.setBool('notificationsEnabled', enabled);
    notifyListeners();
  }
} 