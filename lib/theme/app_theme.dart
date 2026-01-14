import 'package:flutter/material.dart';

// =============================================================================
// IMPORTANT: NO HARDCODED COLORS
// =============================================================================
// All colors in this app MUST be defined in this theme file and accessed via:
//   - Theme.of(context) for standard Material colors
//   - MeteogramColors.of(context) for chart-specific colors
//
// NEVER hardcode color values directly in widgets or screens.
// This ensures consistent theming across light/dark modes.
//
// For the Android home screen widget:
//   - Background uses ?android:attr/colorBackground (system color, not hardcoded)
//   - UI element colors are in android/app/src/main/res/values[-night]/colors.xml
// =============================================================================

/// App theme configuration with light and dark modes.
/// Supports Material You dynamic colors when available.
class AppTheme {
  // Fallback seed color when dynamic colors unavailable
  static const _fallbackSeed = Color(0xFF5B8DEF);

  /// Light theme - uses dynamic ColorScheme if provided.
  static ThemeData light([ColorScheme? dynamicScheme]) {
    final colorScheme = dynamicScheme ?? ColorScheme.fromSeed(
      seedColor: _fallbackSeed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      // No explicit scaffoldBackgroundColor - Material 3 uses colorScheme automatically
    );
  }

  /// Dark theme - uses dynamic ColorScheme if provided.
  static ThemeData dark([ColorScheme? dynamicScheme]) {
    final colorScheme = dynamicScheme ?? ColorScheme.fromSeed(
      seedColor: _fallbackSeed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // No explicit scaffoldBackgroundColor - Material 3 uses colorScheme automatically
    );
  }
}

/// Modern color palette for the meteogram.
class MeteogramColors {
  final Color background;
  final Color cardBackground;
  final Color temperatureLine;
  final Color temperatureGradientStart;
  final Color temperatureGradientEnd;
  final Color precipitationBar;
  final Color precipitationGradient;
  final Color nowIndicator;
  final Color gridLine;
  final Color labelText;
  final Color primaryText;
  final Color secondaryText;
  final Color chartTempLabel;
  final Color sunshineBar;
  final Color sunshineGradient;
  final Color sunshineIcon;
  final Color timeLabel;

  const MeteogramColors({
    required this.background,
    required this.cardBackground,
    required this.temperatureLine,
    required this.temperatureGradientStart,
    required this.temperatureGradientEnd,
    required this.precipitationBar,
    required this.precipitationGradient,
    required this.nowIndicator,
    required this.gridLine,
    required this.labelText,
    required this.primaryText,
    required this.secondaryText,
    required this.chartTempLabel,
    required this.sunshineBar,
    required this.sunshineGradient,
    required this.sunshineIcon,
    required this.timeLabel,
  });

  /// Light mode - clean, airy design
  static const light = MeteogramColors(
    background: Color(0xFFF5F7FA),
    cardBackground: Color(0xFFFFFFFF),
    temperatureLine: Color(0xFFFF6B6B),
    temperatureGradientStart: Color(0x40FF6B6B),
    temperatureGradientEnd: Color(0x00FF6B6B),
    precipitationBar: Color(0xFF4ECDC4),
    precipitationGradient: Color(0x804ECDC4),
    nowIndicator: Color(0xFFFFE66D),
    gridLine: Color(0x20000000),
    labelText: Color(0xFF4A5568),
    primaryText: Color(0xFF2D3436),
    secondaryText: Color(0xFF636E72),
    chartTempLabel: Color(0xFF1A1A2E),
    sunshineBar: Color(0xFFFFF0AA),      // Light pastel yellow
    sunshineGradient: Color(0xFFFFD580),  // Light pastel orange
    sunshineIcon: Color(0xFFD49A00),      // Darker amber for light backgrounds
    timeLabel: Color(0xFF4A5568),         // Fallback - overridden by Material You tertiary
  );

  /// Dark mode - rich, elegant design
  static const dark = MeteogramColors(
    background: Color(0xFF0D1B2A),
    cardBackground: Color(0xFF1B2838),
    temperatureLine: Color(0xFFFF7675),
    temperatureGradientStart: Color(0x60FF7675),
    temperatureGradientEnd: Color(0x00FF7675),
    precipitationBar: Color(0xFF00CEC9),
    precipitationGradient: Color(0x8000CEC9),
    nowIndicator: Color(0xFFFDCB6E),
    gridLine: Color(0x30FFFFFF),
    labelText: Color(0xFFE0E0E0),
    primaryText: Color(0xFFFFFFFF),
    secondaryText: Color(0xFFB2BEC3),
    chartTempLabel: Color(0xFFF0F0F0),
    sunshineBar: Color(0xFFFFF0AA),      // Light pastel yellow
    sunshineGradient: Color(0xFFFFD080),  // Light pastel orange
    sunshineIcon: Color(0xFFFFD93D),      // Bright yellow for dark backgrounds
    timeLabel: Color(0xFFE0E0E0),         // Fallback - overridden by Material You tertiary
  );

  /// Get colors based on theme, using Material You colors.
  static MeteogramColors of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return fromColorScheme(theme.colorScheme, isDark: isDark);
  }

  /// Create colors from a specific ColorScheme.
  /// Used for generating widget SVGs with both light and dark Material You colors.
  static MeteogramColors fromColorScheme(ColorScheme colorScheme, {required bool isDark}) {
    // Use Material You colors with appropriate contrast for each theme:
    // - Light mode: onPrimaryContainer (darker, better contrast on light bg)
    // - Dark mode: primary (brighter, better contrast on dark bg)
    final tempColor = isDark ? colorScheme.primary : colorScheme.onPrimaryContainer;

    final base = isDark ? dark : light;
    return base.copyWith(
      background: colorScheme.surface,
      temperatureLine: tempColor,
      temperatureGradientStart: tempColor.withAlpha(isDark ? 0x60 : 0x40),
      temperatureGradientEnd: tempColor.withAlpha(0x00),
      timeLabel: colorScheme.tertiary,
    );
  }

  /// Create a copy with overridden values.
  MeteogramColors copyWith({
    Color? background,
    Color? temperatureLine,
    Color? temperatureGradientStart,
    Color? temperatureGradientEnd,
    Color? timeLabel,
  }) {
    return MeteogramColors(
      background: background ?? this.background,
      cardBackground: cardBackground,
      temperatureLine: temperatureLine ?? this.temperatureLine,
      temperatureGradientStart: temperatureGradientStart ?? this.temperatureGradientStart,
      temperatureGradientEnd: temperatureGradientEnd ?? this.temperatureGradientEnd,
      precipitationBar: precipitationBar,
      precipitationGradient: precipitationGradient,
      nowIndicator: nowIndicator,
      gridLine: gridLine,
      labelText: labelText,
      primaryText: primaryText,
      secondaryText: secondaryText,
      chartTempLabel: chartTempLabel,
      sunshineBar: sunshineBar,
      sunshineGradient: sunshineGradient,
      sunshineIcon: sunshineIcon,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }

}
