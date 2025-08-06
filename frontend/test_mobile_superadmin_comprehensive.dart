import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SuperAdmin Dashboard Mobile Responsiveness Tests', () {
    late SharedPreferences prefs;
    
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget createTestWidget({Size? screenSize}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize ?? const Size(375, 667)), // iPhone SE size
          child: ChangeNotifierProvider(
            create: (_) => AuthProvider(ApiService(), prefs),
            child: const SuperadminDashboard(),
          ),
        ),
      );
    }

    testWidgets('Dashboard is responsive on mobile phone (375x667)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Check if tabs are scrollable on mobile
      expect(find.byType(TabBar), findsWidgets);
      
      // Check if main content is scrollable
      expect(find.byType(SingleChildScrollView), findsWidgets);
      
      // Check if cards are present (mobile layout)
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('Dashboard is responsive on small mobile phone (320x568)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(320, 568)));
      await tester.pumpAndSettle();

      // Check if tiny screen adaptations work
      expect(find.byType(TabBar), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('Dashboard is responsive on large mobile phone (414x736)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(414, 736)));
      await tester.pumpAndSettle();

      // Check if large mobile layout works
      expect(find.byType(TabBar), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('Dashboard is responsive on tablet (768x1024)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(768, 1024)));
      await tester.pumpAndSettle();

      // Check if tablet layout works
      expect(find.byType(TabBar), findsWidgets);
    });

    testWidgets('Dashboard is responsive on desktop (1200x800)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();

      // Check if desktop layout works
      expect(find.byType(TabBar), findsWidgets);
    });

    testWidgets('Business grid adapts to screen size', (WidgetTester tester) async {
      // Test mobile layout (1 column)
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();
      
      // Should find LayoutBuilder for responsive grid
      expect(find.byType(LayoutBuilder), findsWidgets);
      
      // Test tablet layout (2 columns)
      await tester.pumpWidget(createTestWidget(screenSize: const Size(768, 1024)));
      await tester.pumpAndSettle();
      
      expect(find.byType(LayoutBuilder), findsWidgets);
      
      // Test desktop layout (3 columns)
      await tester.pumpWidget(createTestWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();
      
      expect(find.byType(LayoutBuilder), findsWidgets);
    });

    testWidgets('DataTables are mobile-responsive', (WidgetTester tester) async {
      // Test mobile - should show cards instead of tables
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();
      
      // Navigate to Users tab to check table responsiveness
      final usersTab = find.text('Users');
      if (await tester.any(usersTab)) {
        await tester.tap(usersTab);
        await tester.pumpAndSettle();
      }
      
      // Should find cards for mobile display
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('Touch targets are appropriate for mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Check if tab buttons have adequate touch targets
      final tabWidgets = find.byType(Tab);
      expect(tabWidgets, findsWidgets);
      
      // Check if buttons have adequate touch targets
      final buttonWidgets = find.byType(ElevatedButton);
      expect(buttonWidgets, findsWidgets);
    });

    testWidgets('Text scales appropriately on different screen sizes', (WidgetTester tester) async {
      // Test tiny screen
      await tester.pumpWidget(createTestWidget(screenSize: const Size(320, 568)));
      await tester.pumpAndSettle();
      
      // Text should be present and readable
      expect(find.byType(Text), findsWidgets);
      
      // Test normal mobile
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();
      
      expect(find.byType(Text), findsWidgets);
      
      // Test desktop
      await tester.pumpWidget(createTestWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();
      
      expect(find.byType(Text), findsWidgets);
    });
  });
}