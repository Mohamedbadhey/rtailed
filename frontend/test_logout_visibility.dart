import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/screens/home/superadmin_dashboard_simple.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Logout Button Visibility Test', () {
    testWidgets('Logout button is visible on all screen sizes', (WidgetTester tester) async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Test on extra small screen (320px width)
      await tester.binding.setSurfaceSize(const Size(320, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardSimple(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify logout button is present on small screen
      expect(find.byIcon(Icons.account_circle), findsOneWidget, reason: 'Logout button should be visible on small screen');
      
      // Test on large screen (1024px width)
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardSimple(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify logout button is present on large screen
      expect(find.byIcon(Icons.account_circle), findsOneWidget, reason: 'Logout button should be visible on large screen');
      
      print('✅ Logout button is visible on all screen sizes');
    });

    testWidgets('Logout button opens menu when tapped', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardSimple(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Tap the logout button
      await tester.tap(find.byIcon(Icons.account_circle));
      await tester.pumpAndSettle();
      
      // Verify menu items are present
      expect(find.text('Profile'), findsOneWidget, reason: 'Profile menu item should be visible');
      expect(find.text('Logout'), findsOneWidget, reason: 'Logout menu item should be visible');
      
      print('✅ Logout button opens menu correctly');
    });
  });
} 