import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/screens/home/inventory_screen.dart';

void main() {
  group('Mobile Inventory Tests', () {
    testWidgets('Category dropdown shows in mobile add product dialog', (WidgetTester tester) async {
      // Set mobile screen size
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      // Build widget
      await tester.pumpWidget(MaterialApp(home: InventoryScreen()));
      await tester.pumpAndSettle();
      
      // Tap add product button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify category dropdown exists
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Select Category'), findsOneWidget);
    });

    testWidgets('Mobile product list shows categories with icons', (WidgetTester tester) async {
      // Set mobile screen size
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      // Build widget
      await tester.pumpWidget(MaterialApp(home: InventoryScreen()));
      await tester.pumpAndSettle();
      
      // Verify category icons are present
      expect(find.byIcon(Icons.category), findsWidgets);
    });

    testWidgets('Mobile breakpoint detection works correctly', (WidgetTester tester) async {
      // Test mobile size
      tester.binding.window.physicalSizeTestValue = const Size(500, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      await tester.pumpWidget(MaterialApp(home: InventoryScreen()));
      await tester.pumpAndSettle();
      
      // Should show mobile layout (Add button instead of "Add Product")
      expect(find.text('Add'), findsOneWidget);
      
      // Test tablet size
      tester.binding.window.physicalSizeTestValue = const Size(800, 600);
      await tester.pumpAndSettle();
      
      // Should show desktop layout
      expect(find.text('Add Product'), findsOneWidget);
    });

    testWidgets('Category is optional in mobile form', (WidgetTester tester) async {
      // Set mobile screen size
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      // Build widget
      await tester.pumpWidget(MaterialApp(home: InventoryScreen()));
      await tester.pumpAndSettle();
      
      // Open add product dialog
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Fill required fields
      await tester.enterText(find.byType(TextFormField).first, 'Test Product');
      await tester.enterText(find.byType(TextFormField).at(1), 'TEST001');
      await tester.enterText(find.byType(TextFormField).at(3), '10.00');
      await tester.enterText(find.byType(TextFormField).at(4), '5.00');
      await tester.enterText(find.byType(TextFormField).at(5), '100');
      
      // Try to save without selecting category (should work now)
      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();
      
      // Should not show validation error for category
      expect(find.text('Please select a category'), findsNothing);
    });
  });
} 