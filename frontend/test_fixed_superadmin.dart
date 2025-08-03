import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/screens/home/superadmin_dashboard_fixed.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Fixed Superadmin Dashboard Tests', () {
    testWidgets('Dashboard loads without errors', (WidgetTester tester) async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardFixed(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Verify essential elements are present
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      print('✅ Fixed superadmin dashboard loads successfully');
    });

    testWidgets('Logout button is always visible', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardFixed(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Verify logout button is present
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      // Tap the logout button
      await tester.tap(find.byIcon(Icons.account_circle));
      await tester.pumpAndSettle();
      
      // Verify popup menu appears
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      
      print('✅ Logout button is visible and functional');
    });

    testWidgets('Responsive design works', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      // Test on small screen
      await tester.binding.setSurfaceSize(const Size(320, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardFixed(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify mobile layout
      expect(find.text('Admin'), findsOneWidget); // Short title on small screens
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      // Test on large screen
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboardFixed(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify desktop layout
      expect(find.text('Superadmin Dashboard'), findsOneWidget); // Full title on large screens
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      print('✅ Responsive design works correctly');
    });
  });
} 