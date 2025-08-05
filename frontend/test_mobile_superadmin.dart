import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/superadmin_dashboard_mobile.dart';

void main() {
  group('Mobile Superadmin Dashboard Tests', () {
    testWidgets('Mobile dashboard loads correctly', (WidgetTester tester) async {
      // Set mobile screen size
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      // Build widget
      await tester.pumpWidget(MaterialApp(home: SuperadminDashboardMobile()));
      await tester.pumpAndSettle();
      
      // Verify main tabs exist
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Businesses'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
    });

    testWidgets('Overview tab shows sub-tabs', (WidgetTester tester) async {
      // Set mobile screen size
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      // Build widget
      await tester.pumpWidget(MaterialApp(home: SuperadminDashboardMobile()));
      await tester.pumpAndSettle();
      
      // Tap on Overview tab
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      
      // Verify sub-tabs exist
      expect(find.text('System Health'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
    });

    testWidgets('Businesses tab shows sub-tabs', (WidgetTester tester) async {
      // Set mobile screen size
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      // Build widget
      await tester.pumpWidget(MaterialApp(home: SuperadminDashboardMobile()));
      await tester.pumpAndSettle();
      
      // Tap on Businesses tab
      await tester.tap(find.text('Businesses'));
      await tester.pumpAndSettle();
      
      // Verify sub-tabs exist
      expect(find.text('All Businesses'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
    });
  });
} 