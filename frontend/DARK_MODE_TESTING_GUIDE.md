# Dark Mode Testing Guide

## Overview
This guide provides comprehensive instructions for testing dark mode functionality across the retail management app to ensure proper text visibility and theme consistency.

## What Has Been Fixed

### 1. Theme-Aware Color System
- Added `ThemeAwareColors` class in `utils/theme.dart`
- Provides theme-aware color helpers that automatically adapt to light/dark mode
- Replaces hardcoded colors with dynamic theme-aware alternatives

### 2. Updated Screens
- **Settings Screen**: Fixed hardcoded colors for cards, text, and backgrounds
- **Inventory Screen**: Started fixing hardcoded colors (ongoing process)

### 3. Theme-Aware Color Helpers
```dart
// Text Colors
ThemeAwareColors.getTextColor(context)           // Primary text color
ThemeAwareColors.getSecondaryTextColor(context) // Secondary text color

// Background Colors
ThemeAwareColors.getBackgroundColor(context)     // Main background
ThemeAwareColors.getCardColor(context)           // Card backgrounds
ThemeAwareColors.getSurfaceColor(context)       // Surface elements

// Input Colors
ThemeAwareColors.getInputFillColor(context)      // Input field backgrounds
ThemeAwareColors.getBorderColor(context)        // Border colors

// Utility Colors
ThemeAwareColors.getGreyColor(context, shade)    // Theme-aware grey shades
ThemeAwareColors.getShadowColor(context)        // Shadow colors
```

## How to Test Dark Mode

### 1. Enable Dark Mode
1. Open the app
2. Navigate to **Settings** screen
3. Toggle **Dark Mode** switch to ON
4. The app should immediately switch to dark theme

### 2. Test Text Visibility

#### Settings Screen
- **Primary Text**: Should be white in dark mode, dark in light mode
- **Secondary Text**: Should be light grey in dark mode, darker grey in light mode
- **Card Backgrounds**: Should be dark grey in dark mode, white in light mode
- **Input Fields**: Should have dark backgrounds in dark mode

#### Inventory Screen
- **Product Names**: Should be clearly visible in both modes
- **Status Badges**: Should maintain contrast in both modes
- **Table Headers**: Should be readable in both modes
- **Filter Sections**: Should have proper contrast

### 3. Test Specific Elements

#### Cards and Containers
- [ ] Card backgrounds adapt to theme
- [ ] Card shadows are appropriate for theme
- [ ] Card borders are visible in both modes

#### Text Elements
- [ ] Primary text is readable in both modes
- [ ] Secondary text has proper contrast
- [ ] Labels and captions are visible
- [ ] Error messages are clearly visible

#### Input Fields
- [ ] Input backgrounds adapt to theme
- [ ] Input borders are visible
- [ ] Placeholder text is readable
- [ ] Focus states are clear

#### Buttons and Interactive Elements
- [ ] Button text is readable
- [ ] Button backgrounds are appropriate
- [ ] Hover states work in both modes
- [ ] Disabled states are clear

#### Tables and Data Display
- [ ] Table headers are readable
- [ ] Table rows have proper contrast
- [ ] Alternating row colors work
- [ ] Data is clearly visible

### 4. Test Edge Cases

#### System Theme Changes
1. Change system theme while app is running
2. App should adapt automatically if using system theme
3. Manual theme toggle should override system theme

#### Navigation Between Screens
1. Navigate between different screens
2. Theme should remain consistent
3. No flickering or color inconsistencies

#### Modal Dialogs
1. Open various modal dialogs
2. Check that dialogs inherit theme properly
3. Verify text readability in dialogs

## Common Issues to Look For

### 1. Hardcoded Colors
- **Problem**: `Colors.white`, `Colors.grey[600]`, etc. don't adapt to theme
- **Solution**: Replace with `ThemeAwareColors.getTextColor(context)`

### 2. Poor Contrast
- **Problem**: Text blends with background
- **Solution**: Use theme-aware colors with proper contrast ratios

### 3. Inconsistent Theming
- **Problem**: Some elements don't follow theme
- **Solution**: Ensure all UI elements use theme-aware colors

### 4. Shadow Issues
- **Problem**: Shadows too light/dark for theme
- **Solution**: Use `ThemeAwareColors.getShadowColor(context)`

## Testing Checklist

### Settings Screen
- [ ] Dark mode toggle works
- [ ] All text is readable in dark mode
- [ ] Cards have proper dark backgrounds
- [ ] Input fields are visible
- [ ] Icons have proper contrast
- [ ] Credit section text is readable
- [ ] System info section is visible

### Inventory Screen
- [ ] Product cards adapt to theme
- [ ] Table headers are readable
- [ ] Filter sections work in both modes
- [ ] Search functionality works
- [ ] Modal dialogs inherit theme
- [ ] Status badges are visible
- [ ] Action buttons are clear

### General App
- [ ] Navigation bar adapts to theme
- [ ] App bar colors are appropriate
- [ ] Loading indicators are visible
- [ ] Error messages are clear
- [ ] Success messages are visible
- [ ] Form validation messages readable

## Performance Testing

### Theme Switching
1. Toggle between light and dark mode rapidly
2. Check for smooth transitions
3. Verify no performance degradation
4. Ensure no memory leaks

### Memory Usage
1. Monitor memory usage during theme changes
2. Check for any memory leaks
3. Verify garbage collection works properly

## Accessibility Testing

### Color Blind Users
1. Test with color blindness simulators
2. Ensure sufficient contrast ratios
3. Verify text is readable without color

### Screen Readers
1. Test with screen readers
2. Verify proper semantic markup
3. Check for proper focus indicators

## Reporting Issues

When reporting dark mode issues, include:

1. **Screen**: Which screen has the issue
2. **Element**: Specific UI element affected
3. **Expected**: What should happen
4. **Actual**: What actually happens
5. **Steps**: How to reproduce
6. **Screenshot**: Visual evidence
7. **Device**: Device and OS information

## Future Improvements

1. **Complete Inventory Screen**: Finish fixing all hardcoded colors
2. **Other Screens**: Apply same fixes to remaining screens
3. **Custom Themes**: Support for custom color schemes
4. **Animation**: Smooth theme transition animations
5. **Accessibility**: Enhanced accessibility features

## Code Examples

### Before (Hardcoded Colors)
```dart
Text(
  'Product Name',
  style: TextStyle(
    color: Colors.grey[800],  // ❌ Hardcoded
  ),
)
```

### After (Theme-Aware Colors)
```dart
Text(
  'Product Name',
  style: TextStyle(
    color: ThemeAwareColors.getTextColor(context),  // ✅ Theme-aware
  ),
)
```

### Card Background
```dart
Container(
  decoration: BoxDecoration(
    color: ThemeAwareColors.getCardColor(context),
    boxShadow: [
      BoxShadow(
        color: ThemeAwareColors.getShadowColor(context),
        blurRadius: 10,
      ),
    ],
  ),
)
```

This guide should help ensure comprehensive testing of dark mode functionality across the entire application.
