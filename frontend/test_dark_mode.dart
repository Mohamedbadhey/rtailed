import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_management/utils/theme.dart';

void main() {
  group('Dark Mode Tests', () {
    testWidgets('Theme-aware colors work correctly in dark mode', (WidgetTester tester) async {
      // Build a widget with dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    Text(
                      'Primary Text',
                      style: TextStyle(
                        color: ThemeAwareColors.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Secondary Text',
                      style: TextStyle(
                        color: ThemeAwareColors.getSecondaryTextColor(context),
                      ),
                    ),
                    Container(
                      color: ThemeAwareColors.getCardColor(context),
                      child: Text('Card Text'),
                    ),
                    Container(
                      color: ThemeAwareColors.getBackgroundColor(context),
                      child: Text('Background Text'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify that the colors are appropriate for dark mode
      expect(ThemeAwareColors.getTextColor(tester.element(find.text('Primary Text'))), Colors.white);
      expect(ThemeAwareColors.getSecondaryTextColor(tester.element(find.text('Secondary Text'))), Colors.grey[300]);
      expect(ThemeAwareColors.getCardColor(tester.element(find.text('Card Text'))), const Color(0xFF2D2D2D));
      expect(ThemeAwareColors.getBackgroundColor(tester.element(find.text('Background Text'))), const Color(0xFF121212));
    });

    testWidgets('Theme-aware colors work correctly in light mode', (WidgetTester tester) async {
      // Build a widget with light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    Text(
                      'Primary Text',
                      style: TextStyle(
                        color: ThemeAwareColors.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Secondary Text',
                      style: TextStyle(
                        color: ThemeAwareColors.getSecondaryTextColor(context),
                      ),
                    ),
                    Container(
                      color: ThemeAwareColors.getCardColor(context),
                      child: Text('Card Text'),
                    ),
                    Container(
                      color: ThemeAwareColors.getBackgroundColor(context),
                      child: Text('Background Text'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify that the colors are appropriate for light mode
      expect(ThemeAwareColors.getTextColor(tester.element(find.text('Primary Text'))), const Color(0xFF2d3436));
      expect(ThemeAwareColors.getSecondaryTextColor(tester.element(find.text('Secondary Text'))), const Color(0xFF636e72));
      expect(ThemeAwareColors.getCardColor(tester.element(find.text('Card Text'))), Colors.white);
      expect(ThemeAwareColors.getBackgroundColor(tester.element(find.text('Background Text'))), const Color(0xFFf8fafc));
    });
  });
}
