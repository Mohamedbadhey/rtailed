import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/main.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/screens/auth/login_screen.dart';
import 'package:retail_management/screens/home/home_screen.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/widgets/branded_header.dart';

void main() {
  group('Branding Integration Tests', () {
    testWidgets('Login screen should display branded header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify that BrandedHeader is present
      expect(find.byType(BrandedHeader), findsOneWidget);
    });

    testWidgets('Home screen should use branded app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ],
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that BrandedAppBar is present
      expect(find.byType(BrandedAppBar), findsOneWidget);
    });

    testWidgets('Superadmin dashboard should use branded app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ],
          child: MaterialApp(
            home: SuperadminDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that BrandedAppBar is present
      expect(find.byType(BrandedAppBar), findsOneWidget);
    });

    testWidgets('BrandedAppBar should display title correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: BrandedAppBar(
              title: 'Test Title',
            ),
            body: Container(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the title is displayed
      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('BrandedHeader should display subtitle correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandedHeader(
              subtitle: 'Test Subtitle',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the subtitle is displayed
      expect(find.text('Test Subtitle'), findsOneWidget);
    });
  });
} 