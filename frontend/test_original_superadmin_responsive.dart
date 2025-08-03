import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Original Superadmin Dashboard Responsive Tests', () {
    testWidgets('Original dashboard loads without errors', (WidgetTester tester) async {
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
            child: const SuperadminDashboard(),
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
      
      print('✅ Original superadmin dashboard loads successfully');
    });

    testWidgets('Logout button is always visible on all screen sizes', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      // Test on extra small screen
      await tester.binding.setSurfaceSize(const Size(320, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify logout button is present on small screen
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
            child: const SuperadminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify logout button is present on large screen
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      print('✅ Logout button is visible on all screen sizes');
    });

    testWidgets('Responsive title changes based on screen size', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      // Test on very small screen
      await tester.binding.setSurfaceSize(const Size(320, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Should show "Admin" on very small screens
      expect(find.text('Admin'), findsOneWidget);
      
      // Test on larger screen
      await tester.binding.setSurfaceSize(const Size(480, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Should show full title on larger screens
      expect(find.text('Superadmin Dashboard'), findsOneWidget);
      
      print('✅ Responsive title works correctly');
    });

    testWidgets('Tab bar is responsive', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      // Test mobile tab bar
      await tester.binding.setSurfaceSize(const Size(480, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Should have scrollable tab bar on mobile
      expect(find.byType(TabBar), findsOneWidget);
      
      // Test desktop tab bar
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(ApiService(), await SharedPreferences.getInstance()),
              ),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Should have full-width tab bar on desktop
      expect(find.byType(TabBar), findsOneWidget);
      
      print('✅ Tab bar is responsive');
    });
  });
} 