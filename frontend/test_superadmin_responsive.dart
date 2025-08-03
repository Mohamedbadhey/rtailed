import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:provider/provider.dart';

void main() {
  group('Superadmin Dashboard Responsive Tests', () {
    
    // Test different screen sizes
    final screenSizes = [
      {'width': 320, 'height': 568, 'name': 'iPhone SE (1st gen)'},
      {'width': 375, 'height': 667, 'name': 'iPhone 6/7/8'},
      {'width': 414, 'height': 896, 'name': 'iPhone X/XS/11 Pro'},
      {'width': 390, 'height': 844, 'name': 'iPhone 12/13/14'},
      {'width': 428, 'height': 926, 'name': 'iPhone 12/13/14 Pro Max'},
      {'width': 360, 'height': 640, 'name': 'Android Small'},
      {'width': 480, 'height': 800, 'name': 'Android Medium'},
      {'width': 600, 'height': 960, 'name': 'Android Large'},
      {'width': 768, 'height': 1024, 'name': 'iPad'},
      {'width': 1024, 'height': 1366, 'name': 'Desktop'},
    ];

    for (final screenSize in screenSizes) {
      testWidgets('Superadmin Dashboard - ${screenSize['name']}', (WidgetTester tester) async {
        // Set up the widget with the specific screen size
        await tester.binding.setSurfaceSize(Size(screenSize['width']!.toDouble(), screenSize['height']!.toDouble()));
        
        // Create the widget with providers
        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
                ChangeNotifierProvider(create: (_) => BrandingProvider()),
              ],
              child: const SuperadminDashboard(),
            ),
          ),
        );

        // Wait for the widget to build
        await tester.pumpAndSettle();

        // Test 1: Verify the app bar is visible and properly sized
        expect(find.byType(AppBar), findsOneWidget);
        
        // Test 2: Verify tab bar is present and scrollable on mobile
        if (screenSize['width']! < 768) {
          expect(find.byType(TabBar), findsOneWidget);
          
          // Check if tab bar is scrollable
          final tabBar = tester.widget<TabBar>(find.byType(TabBar));
          expect(tabBar.isScrollable, isTrue);
        }

        // Test 3: Verify all 6 main tabs are present
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Businesses'), findsOneWidget);
        expect(find.text('Users'), findsOneWidget);
        expect(find.text('Analytics'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Data'), findsOneWidget);

        // Test 4: Verify tab content is scrollable
        expect(find.byType(SingleChildScrollView), findsWidgets);

        // Test 5: Verify cards are properly sized
        expect(find.byType(Card), findsWidgets);

        // Test 6: Verify buttons have proper touch targets (minimum 44px)
        final buttons = find.byType(ElevatedButton);
        for (final button in buttons.evaluate()) {
          final buttonWidget = tester.widget<ElevatedButton>(button);
          final renderBox = button.renderObject as RenderBox;
          final size = renderBox.size;
          
          // Check minimum touch target size
          expect(size.width, greaterThanOrEqualTo(44.0));
          expect(size.height, greaterThanOrEqualTo(44.0));
        }

        // Test 7: Verify icons are properly sized
        final icons = find.byType(Icon);
        for (final icon in icons.evaluate()) {
          final iconWidget = tester.widget<Icon>(icon);
          expect(iconWidget.size, isNotNull);
          expect(iconWidget.size!, greaterThan(0));
        }

        // Test 8: Verify text is readable
        final textWidgets = find.byType(Text);
        for (final text in textWidgets.evaluate()) {
          final textWidget = tester.widget<Text>(text);
          if (textWidget.style != null) {
            expect(textWidget.style!.fontSize, greaterThan(8.0));
          }
        }

        // Test 9: Verify responsive breakpoints work correctly
        final screenWidth = screenSize['width']!.toDouble();
        final isTiny = screenWidth < 320;
        final isExtraSmall = screenWidth < 360;
        final isVerySmall = screenWidth < 480;
        final isMobile = screenWidth < 768;

        if (isTiny) {
          // Verify tiny screen optimizations
          expect(find.text('Admin'), findsOneWidget); // Shortened title
        } else if (isVerySmall) {
          // Verify very small screen optimizations
          expect(find.text('Superadmin'), findsOneWidget); // Medium title
        } else {
          // Verify normal screen
          expect(find.text('Superadmin Dashboard'), findsOneWidget); // Full title
        }

        // Test 10: Verify tab switching works
        await tester.tap(find.text('Businesses'));
        await tester.pumpAndSettle();
        expect(find.text('Businesses'), findsOneWidget);

        await tester.tap(find.text('Users'));
        await tester.pumpAndSettle();
        expect(find.text('Users'), findsOneWidget);

        await tester.tap(find.text('Analytics'));
        await tester.pumpAndSettle();
        expect(find.text('Analytics'), findsOneWidget);

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);

        await tester.tap(find.text('Data'));
        await tester.pumpAndSettle();
        expect(find.text('Data'), findsOneWidget);

        await tester.tap(find.text('Overview'));
        await tester.pumpAndSettle();
        expect(find.text('Overview'), findsOneWidget);

        print('✅ ${screenSize['name']} (${screenSize['width']}x${screenSize['height']}) - All tests passed');
      });
    }

    testWidgets('Superadmin Dashboard - Accessibility Tests', (WidgetTester tester) async {
      // Set up the widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => BrandingProvider()),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test 1: Verify semantic labels are present
      expect(find.bySemanticsLabel('Refresh'), findsOneWidget);
      expect(find.bySemanticsLabel('Account'), findsOneWidget);

      // Test 2: Verify tab semantics
      expect(find.bySemanticsLabel('Overview tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Businesses tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Users tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Analytics tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Settings tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Data tab'), findsOneWidget);

      print('✅ Accessibility tests passed');
    });

    testWidgets('Superadmin Dashboard - Performance Tests', (WidgetTester tester) async {
      // Set up the widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => BrandingProvider()),
            ],
            child: const SuperadminDashboard(),
          ),
        ),
      );

      // Test 1: Verify widget builds without errors
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test 2: Verify smooth scrolling
      final scrollView = find.byType(SingleChildScrollView).first;
      await tester.fling(scrollView, const Offset(0, -300), 3000);
      await tester.pumpAndSettle();

      // Test 3: Verify tab switching is smooth
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byType(Tab).at(i));
        await tester.pumpAndSettle();
      }

      print('✅ Performance tests passed');
    });
  });
} 