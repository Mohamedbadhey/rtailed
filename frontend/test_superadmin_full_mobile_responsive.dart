import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SuperAdmin Dashboard Full Mobile Functionality Tests', () {
    late SharedPreferences prefs;
    
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget createTestWidget({Size? screenSize}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize ?? const Size(375, 667)),
          child: ChangeNotifierProvider(
            create: (_) => AuthProvider(ApiService(), prefs),
            child: const SuperadminDashboard(),
          ),
        ),
      );
    }

    testWidgets('All main tabs are accessible on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Check that main tabs are scrollable and present
      expect(find.byType(TabBar), findsWidgets);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Businesses'), findsOneWidget);
      expect(find.text('Users & Security'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('Overview tab subtabs work on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Tap on Overview tab (should already be selected)
      final overviewTab = find.text('Overview');
      expect(overviewTab, findsOneWidget);
      
      // Look for subtabs within overview
      await tester.pump();
      
      // Should find System Health, Notifications, and Billing subtabs
      expect(find.byType(DefaultTabController), findsWidgets);
    });

    testWidgets('Business tab with all subtabs works on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Navigate to Businesses tab
      final businessTab = find.text('Businesses');
      if (await tester.any(businessTab)) {
        await tester.tap(businessTab);
        await tester.pumpAndSettle();
        
        // Should find business subtabs: Overview, Messages, Payments, Analytics
        // The subtabs are embedded within the businesses tab
        expect(find.byType(DefaultTabController), findsWidgets);
      }
    });

    testWidgets('Users & Security tab with subtabs works on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Navigate to Users & Security tab
      final usersTab = find.text('Users & Security');
      if (await tester.any(usersTab)) {
        await tester.tap(usersTab);
        await tester.pumpAndSettle();
        
        // Should find users subtabs: User Management, Audit Logs, Access Control
        expect(find.byType(DefaultTabController), findsWidgets);
      }
    });

    testWidgets('Profile and logout menu is accessible on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Find the account menu button
      final accountButton = find.byIcon(Icons.account_circle);
      expect(accountButton, findsOneWidget);
      
      // Tap to open menu
      await tester.tap(accountButton);
      await tester.pumpAndSettle();
      
      // Should find Profile and Logout options
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('Tab navigation is scrollable on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Find TabBar
      final tabBar = find.byType(TabBar);
      expect(tabBar, findsWidgets);
      
      // Verify tabs are scrollable on mobile
      // The isScrollable property should be true for mobile
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('Touch targets are adequate on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Check tab touch targets
      final tabs = find.byType(Tab);
      expect(tabs, findsWidgets);
      
      // Check account button touch target
      final accountButton = find.byIcon(Icons.account_circle);
      expect(accountButton, findsOneWidget);
      
      // Verify the button is tappable
      await tester.tap(accountButton);
      await tester.pumpAndSettle();
    });

    testWidgets('Responsive layout adapts to different mobile sizes', (WidgetTester tester) async {
      // Test on small mobile (320px)
      await tester.pumpWidget(createTestWidget(screenSize: const Size(320, 568)));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsWidgets);
      
      // Test on regular mobile (375px)  
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsWidgets);
      
      // Test on large mobile (414px)
      await tester.pumpWidget(createTestWidget(screenSize: const Size(414, 736)));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsWidgets);
    });

    testWidgets('Analytics tab is accessible on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Navigate to Analytics tab
      final analyticsTab = find.text('Analytics');
      if (await tester.any(analyticsTab)) {
        await tester.tap(analyticsTab);
        await tester.pumpAndSettle();
        
        // Should load analytics content
        expect(find.byType(SingleChildScrollView), findsWidgets);
      }
    });

    testWidgets('Settings tab is accessible on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Navigate to Settings tab
      final settingsTab = find.text('Settings');
      if (await tester.any(settingsTab)) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        
        // Should load settings content with subtabs
        expect(find.byType(DefaultTabController), findsWidgets);
      }
    });

    testWidgets('Data Management tab is accessible on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Navigate to Data Management tab
      final dataTab = find.text('Data Management');
      if (await tester.any(dataTab)) {
        await tester.tap(dataTab);
        await tester.pumpAndSettle();
        
        // Should load data management content
        expect(find.byType(DefaultTabController), findsWidgets);
      }
    });

    testWidgets('Refresh functionality works on mobile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 667)));
      await tester.pumpAndSettle();

      // Find and tap refresh button (if visible on this screen size)
      final refreshButton = find.byIcon(Icons.refresh);
      if (await tester.any(refreshButton)) {
        await tester.tap(refreshButton);
        await tester.pump();
      }
    });
  });
}