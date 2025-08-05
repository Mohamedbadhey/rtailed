import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:retail_management/screens/home/inventory_screen.dart';

void main() {
  group('Inventory Screen Camera Functionality Tests', () {
    testWidgets('should show image source selection dialog', (WidgetTester tester) async {
      // Build the inventory screen
      await tester.pumpWidget(
        MaterialApp(
          home: const InventoryScreen(),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Find and tap the add product button
      final addButton = find.text('Add Product');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Find and tap the image placeholder
      final imagePlaceholder = find.byType(GestureDetector);
      expect(imagePlaceholder, findsWidgets);
      
      // Tap the image placeholder to trigger image picker
      await tester.tap(imagePlaceholder.first);
      await tester.pumpAndSettle();

      // Verify that the image source selection dialog appears
      expect(find.text('Select Image Source'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should have camera and gallery options in dialog', (WidgetTester tester) async {
      // Build the inventory screen
      await tester.pumpWidget(
        MaterialApp(
          home: const InventoryScreen(),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Find and tap the add product button
      final addButton = find.text('Add Product');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Find and tap the image placeholder
      final imagePlaceholder = find.byType(GestureDetector);
      expect(imagePlaceholder, findsWidgets);
      
      // Tap the image placeholder to trigger image picker
      await tester.tap(imagePlaceholder.first);
      await tester.pumpAndSettle();

      // Verify camera option
      final cameraOption = find.text('Camera');
      expect(cameraOption, findsOneWidget);
      
      // Verify gallery option
      final galleryOption = find.text('Gallery');
      expect(galleryOption, findsOneWidget);
      
      // Verify camera icon
      final cameraIcon = find.byIcon(Icons.camera_alt);
      expect(cameraIcon, findsOneWidget);
      
      // Verify gallery icon
      final galleryIcon = find.byIcon(Icons.photo_library);
      expect(galleryIcon, findsOneWidget);
    });

    testWidgets('should show improved image placeholder with camera and gallery icons', (WidgetTester tester) async {
      // Build the inventory screen
      await tester.pumpWidget(
        MaterialApp(
          home: const InventoryScreen(),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Find and tap the add product button
      final addButton = find.text('Add Product');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify that the improved image placeholder shows both camera and gallery icons
      final cameraIcon = find.byIcon(Icons.camera_alt);
      expect(cameraIcon, findsOneWidget);
      
      final galleryIcon = find.byIcon(Icons.photo_library);
      expect(galleryIcon, findsOneWidget);
      
      // Verify the placeholder text
      expect(find.text('Add Image'), findsOneWidget);
      expect(find.text('Camera or Gallery'), findsOneWidget);
    });
  });
} 