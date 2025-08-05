import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/screens/home/superadmin_dashboard_mobile.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
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
          create: (_) => BrandingProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Mobile Superadmin Test',
        theme: appTheme,
        home: const SuperadminDashboardMobile(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
} 