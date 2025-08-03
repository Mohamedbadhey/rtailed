import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/superadmin_dashboard.dart';

void main() {
  group('Device Compatibility Tests', () {
    testWidgets('Test superadmin dashboard on different screen sizes', (WidgetTester tester) async {
      // Test 1: Extra Small Phone (320px width)
      await _testScreenSize(tester, const Size(320, 600), 'Extra Small Phone');
      
      // Test 2: Small Phone (375px width) - iPhone SE
      await _testScreenSize(tester, const Size(375, 667), 'Small Phone');
      
      // Test 3: Medium Phone (414px width) - iPhone 12 Pro Max
      await _testScreenSize(tester, const Size(414, 896), 'Medium Phone');
      
      // Test 4: Large Phone (480px width)
      await _testScreenSize(tester, const Size(480, 800), 'Large Phone');
      
      // Test 5: Small Tablet (768px width) - iPad
      await _testScreenSize(tester, const Size(768, 1024), 'Small Tablet');
      
      // Test 6: Large Tablet (1024px width) - iPad Pro
      await _testScreenSize(tester, const Size(1024, 1366), 'Large Tablet');
      
      // Test 7: Desktop (1440px width)
      await _testScreenSize(tester, const Size(1440, 900), 'Desktop');
      
      // Test 8: Large Desktop (1920px width)
      await _testScreenSize(tester, const Size(1920, 1080), 'Large Desktop');
    });
  });
}

Future<void> _testScreenSize(WidgetTester tester, Size size, String deviceName) async {
  print('Testing $deviceName (${size.width}x${size.height})');
  
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      home: SuperadminDashboard(),
    ),
  );
  await tester.pumpAndSettle();
  
  // Verify essential elements are present
  expect(find.byType(Scaffold), findsOneWidget, reason: 'Scaffold should be present on $deviceName');
  expect(find.byType(AppBar), findsOneWidget, reason: 'AppBar should be present on $deviceName');
  expect(find.byType(TabBar), findsOneWidget, reason: 'TabBar should be present on $deviceName');
  expect(find.byType(TabBarView), findsOneWidget, reason: 'TabBarView should be present on $deviceName');
  
  // Verify logout button is always visible
  expect(find.byIcon(Icons.account_circle), findsOneWidget, reason: 'Logout button should be visible on $deviceName');
  
  // Verify tabs are present
  expect(find.byType(Tab), findsWidgets, reason: 'Tabs should be present on $deviceName');
  
  print('✅ $deviceName test passed');
} 