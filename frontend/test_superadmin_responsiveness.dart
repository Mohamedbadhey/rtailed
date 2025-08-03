import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';

void main() {
  group('Superadmin Dashboard Responsiveness Tests', () {
    testWidgets('Logout button should be visible on all screen sizes', (WidgetTester tester) async {
      // Test on extra small screen (320px width)
      await tester.binding.setSurfaceSize(const Size(320, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      // Check if logout button (account circle icon) is present
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      // Test on small screen (480px width)
      await tester.binding.setSurfaceSize(const Size(480, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      // Test on medium screen (768px width)
      await tester.binding.setSurfaceSize(const Size(768, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      
      // Test on large screen (1024px width)
      await tester.binding.setSurfaceSize(const Size(1024, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
    });

    testWidgets('Tab bar should be responsive', (WidgetTester tester) async {
      // Test mobile tab bar (small screen)
      await tester.binding.setSurfaceSize(const Size(480, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      // Should show mobile tab bar with icons and text
      expect(find.byType(TabBar), findsOneWidget);
      
      // Test desktop tab bar (large screen)
      await tester.binding.setSurfaceSize(const Size(1024, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('Content should be scrollable on mobile', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SuperadminDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      
      // Should find SingleChildScrollView for mobile content
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });
} 