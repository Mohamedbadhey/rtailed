import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/screens/auth/login_screen.dart';
import 'package:retail_management/utils/responsive_utils.dart';

void main() {
  group('Responsive Login Screen Tests', () {
    testWidgets('Login screen is responsive on mobile (375x667)', (WidgetTester tester) async {
      // Set mobile screen size
      await tester.binding.setSurfaceSize(const Size(375, 667));
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify responsive elements
      final logo = find.byType(Image);
      expect(logo, findsOneWidget);

      // Check if form is properly sized for mobile
      final formContainer = find.byType(Container).first;
      final RenderBox formBox = tester.renderObject<RenderBox>(formContainer);
      expect(formBox.size.width, 375 - 32); // Full width minus padding

      print('✅ Mobile responsive test passed');
    });

    testWidgets('Login screen is responsive on tablet (768x1024)', (WidgetTester tester) async {
      // Set tablet screen size
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify responsive elements
      final logo = find.byType(Image);
      expect(logo, findsOneWidget);

      // Check if form is properly sized for tablet
      final formContainer = find.byType(Container).first;
      final RenderBox formBox = tester.renderObject<RenderBox>(formContainer);
      expect(formBox.size.width, 500); // Fixed width for tablet

      print('✅ Tablet responsive test passed');
    });

    testWidgets('Login screen is responsive on desktop (1200x800)', (WidgetTester tester) async {
      // Set desktop screen size
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify responsive elements
      final logo = find.byType(Image);
      expect(logo, findsOneWidget);

      // Check if form is properly sized for desktop
      final formContainer = find.byType(Container).first;
      final RenderBox formBox = tester.renderObject<RenderBox>(formContainer);
      expect(formBox.size.width, 600); // Fixed width for desktop

      print('✅ Desktop responsive test passed');
    });

    testWidgets('Responsive utils work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test mobile breakpoint
              await tester.binding.setSurfaceSize(const Size(375, 667));
              await tester.pump();
              
              final isMobile = ResponsiveUtils.isMobile(context);
              final isTablet = ResponsiveUtils.isTablet(context);
              final isDesktop = ResponsiveUtils.isDesktop(context);
              
              expect(isMobile, true);
              expect(isTablet, false);
              expect(isDesktop, false);

              // Test tablet breakpoint
              await tester.binding.setSurfaceSize(const Size(768, 1024));
              await tester.pump();
              
              final isMobile2 = ResponsiveUtils.isMobile(context);
              final isTablet2 = ResponsiveUtils.isTablet(context);
              final isDesktop2 = ResponsiveUtils.isDesktop(context);
              
              expect(isMobile2, false);
              expect(isTablet2, true);
              expect(isDesktop2, false);

              // Test desktop breakpoint
              await tester.binding.setSurfaceSize(const Size(1200, 800));
              await tester.pump();
              
              final isMobile3 = ResponsiveUtils.isMobile(context);
              final isTablet3 = ResponsiveUtils.isTablet(context);
              final isDesktop3 = ResponsiveUtils.isDesktop(context);
              
              expect(isMobile3, false);
              expect(isTablet3, false);
              expect(isDesktop3, true);

              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      print('✅ Responsive utils test passed');
    });

    testWidgets('Local logo loads correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocalLogo(size: 60),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify local logo is displayed
      final logo = find.byType(Image);
      expect(logo, findsOneWidget);

      print('✅ Local logo test passed');
    });
  });
}
