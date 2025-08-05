import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/cart_provider.dart';
import 'package:retail_management/providers/notification_provider.dart';
import 'package:retail_management/screens/auth/login_screen.dart';

import 'package:retail_management/screens/home/home_screen.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';
import 'package:retail_management/screens/home/superadmin_dashboard_mobile.dart';
import 'package:retail_management/screens/home/superadmin_dashboard_simple.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_management/providers/settings_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/providers/offline_provider.dart';
import 'package:retail_management/widgets/branding_initializer.dart';

void main() async {
  // Ensure Flutter bindings are initialized in the main zone
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle errors globally
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  
  // Initialize platform-specific services
  try {
    // Initialize path_provider for platform support
    await Future.delayed(Duration.zero);
  } catch (e) {
    print('Platform initialization warning: $e');
  }
  
  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Run the app in the main zone to avoid zone mismatch
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(ApiService(), prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(AuthProvider(ApiService(), prefs)),
          update: (_, auth, previous) => previous ?? NotificationProvider(auth),
        ),
        ChangeNotifierProvider(
          create: (_) => BrandingProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OfflineProvider(),
        ),
      ],
      child: Consumer3<SettingsProvider, AuthProvider, OfflineProvider>(
        builder: (context, settings, auth, offline, child) {
          // Connect the providers
          settings.setAuthProvider(auth);
          
          // Initialize offline provider
          offline.initialize();
          
          return BrandingInitializer(
            child: BrandingListener(
              child: MaterialApp(
                title: 'No Name',
                theme: appTheme,
                darkTheme: darkTheme,
                themeMode: settings.themeMode,
                // locale: settings.language == 'English' ? null : Locale(settings.language.toLowerCase()),
                initialRoute: '/',
                routes: {
                  '/': (context) => Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      if (auth.isAuthenticated) {
                        if (auth.user?.role == 'superadmin') {
                          return const SuperadminDashboardSimple();
                        } else {
                          return const HomeScreen();
                        }
                      } else {
                        return const LoginScreen();
                      }
                    },
                  ),
                  '/login': (context) => const LoginScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/superadmin': (context) => const SuperadminDashboardSimple(),
                },
                debugShowCheckedModeBanner: false,
              ),
            ),
          );
        },
      ),
    );
  }
} 