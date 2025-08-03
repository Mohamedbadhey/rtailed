import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/providers/auth_provider.dart';

// Modern Color Palette
const Color primaryGradientStart = Color(0xFF667eea);
const Color primaryGradientEnd = Color(0xFF764ba2);
const Color secondaryGradientStart = Color(0xFFf093fb);
const Color secondaryGradientEnd = Color(0xFFf5576c);
const Color accentColor = Color(0xFF4facfe);
const Color successColor = Color(0xFF00b894);
const Color warningColor = Color(0xFFfdcb6e);
const Color errorColor = Color(0xFFe17055);
const Color backgroundColor = Color(0xFFf8fafc);
const Color surfaceColor = Colors.white;
const Color textPrimary = Color(0xFF2d3436);
const Color textSecondary = Color(0xFF636e72);

// Branding-aware color getters
Color getBrandedPrimaryColor(BuildContext context) {
  try {
    final brandingProvider = Provider.of<BrandingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final businessId = authProvider.user?.businessId;
    return brandingProvider.getPrimaryColor(businessId);
  } catch (e) {
    return primaryGradientStart;
  }
}

Color getBrandedSecondaryColor(BuildContext context) {
  try {
    final brandingProvider = Provider.of<BrandingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final businessId = authProvider.user?.businessId;
    return brandingProvider.getSecondaryColor(businessId);
  } catch (e) {
    return secondaryGradientStart;
  }
}

Color getBrandedAccentColor(BuildContext context) {
  try {
    final brandingProvider = Provider.of<BrandingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final businessId = authProvider.user?.businessId;
    return brandingProvider.getAccentColor(businessId);
  } catch (e) {
    return accentColor;
  }
}

// Custom Gradients
final LinearGradient primaryGradient = LinearGradient(
  colors: [primaryGradientStart, primaryGradientEnd],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final LinearGradient secondaryGradient = LinearGradient(
  colors: [secondaryGradientStart, secondaryGradientEnd],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final LinearGradient accentGradient = LinearGradient(
  colors: [accentColor, Color(0xFF00f2fe)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Fallback text theme for when Google Fonts fails to load
final TextTheme fallbackTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  ),
  displayMedium: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  ),
  displaySmall: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ),
  headlineLarge: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ),
  headlineMedium: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ),
  headlineSmall: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ),
  titleLarge: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ),
  titleMedium: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  ),
  titleSmall: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  ),
  bodyLarge: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  ),
  bodyMedium: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  ),
  bodySmall: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  ),
  labelLarge: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  ),
  labelMedium: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  ),
  labelSmall: TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  ),
);

// Safe Google Fonts text theme with fallback
TextTheme getSafeGoogleFontsTextTheme() {
  try {
    return GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    );
  } catch (e) {
    // Return fallback theme if Google Fonts fails
    return fallbackTextTheme;
  }
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryGradientStart,
    primary: primaryGradientStart,
    secondary: secondaryGradientStart,
    background: backgroundColor,
    surface: surfaceColor,
    error: errorColor,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: textPrimary,
    onSurface: textPrimary,
    onError: Colors.white,
    brightness: Brightness.light,
  ),
  textTheme: getSafeGoogleFontsTextTheme(),
  
  // App Bar Theme
  appBarTheme: AppBarTheme(
    elevation: 0,
    centerTitle: true,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
    iconTheme: const IconThemeData(color: Colors.white, size: 24),
  ),
  
  // Elevated Button Theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 8,
      shadowColor: primaryGradientStart.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      textStyle: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  ),
  
  // Card Theme
  cardTheme: CardThemeData(
    elevation: 12,
    shadowColor: Colors.black.withOpacity(0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: surfaceColor,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  
  // Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey[200]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: primaryGradientStart, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: errorColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: GoogleFonts.poppins(
      color: textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: GoogleFonts.poppins(
      color: textSecondary.withOpacity(0.7),
      fontSize: 14,
    ),
  ),
  
  // Floating Action Button Theme
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: primaryGradientStart,
    foregroundColor: Colors.white,
    elevation: 12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  
  // Bottom Navigation Bar Theme
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: surfaceColor,
    selectedItemColor: primaryGradientStart,
    unselectedItemColor: textSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 20,
    selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
  ),
  
  // Tab Bar Theme
  tabBarTheme: TabBarThemeData(
    labelColor: primaryGradientStart,
    unselectedLabelColor: textSecondary,
    indicatorColor: primaryGradientStart,
    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
  ),
  
  // Chip Theme
  chipTheme: ChipThemeData(
    backgroundColor: Colors.grey[100],
    selectedColor: primaryGradientStart,
    disabledColor: Colors.grey[300],
    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
  ),
  
  // Divider Theme
  dividerTheme: DividerThemeData(
    color: Colors.grey[200],
    thickness: 1,
    space: 1,
  ),
  
  // Icon Theme
  iconTheme: IconThemeData(
    color: textPrimary,
    size: 24,
  ),
  
  // Scaffold Background
  scaffoldBackgroundColor: backgroundColor,
);

// Dark Theme
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: primaryGradientStart,
    secondary: secondaryGradientStart,
    background: const Color(0xFF121212),
    surface: const Color(0xFF1E1E1E),
    error: errorColor,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: Colors.white,
    onSurface: Colors.white,
    onError: Colors.white,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  appBarTheme: AppBarTheme(
    elevation: 0,
    backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 8,
    color: const Color(0xFF2D2D2D),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2D2D2D),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey[700]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: primaryGradientStart, width: 2),
    ),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
);

// Custom Widget Styles
class AppStyles {
  // Gradient Container
  static BoxDecoration gradientDecoration = BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: primaryGradientStart.withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
  
  // Glassmorphism Effect
  static BoxDecoration glassmorphismDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.2)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
  
  // Card Shadow
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
  
  // Success Card
  static BoxDecoration successCardDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [successColor.withOpacity(0.1), successColor.withOpacity(0.05)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: successColor.withOpacity(0.2)),
  );
  
  // Warning Card
  static BoxDecoration warningCardDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [warningColor.withOpacity(0.1), warningColor.withOpacity(0.05)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: warningColor.withOpacity(0.2)),
  );
  
  // Error Card
  static BoxDecoration errorCardDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [errorColor.withOpacity(0.1), errorColor.withOpacity(0.05)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: errorColor.withOpacity(0.2)),
  );
} 