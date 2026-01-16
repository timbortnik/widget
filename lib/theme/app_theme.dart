import 'package:flutter/material.dart';

import '../services/material_you_service.dart';

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
/// Supports Material You dynamic colors extracted from native Android code.
class AppTheme {
  // Fallback seed color when dynamic colors unavailable (neutral gray)
  static const _fallbackSeed = Color(0xFF808080);

  /// Light theme - uses native Material You colors if provided.
  static ThemeData light([MaterialYouThemeColors? nativeColors]) {
    final ColorScheme colorScheme;
    if (nativeColors != null) {
      // Build ColorScheme from native colors
      colorScheme = ColorScheme.fromSeed(
        seedColor: nativeColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: nativeColors.primary,
        onPrimaryContainer: nativeColors.onPrimaryContainer,
        tertiary: nativeColors.tertiary,
        surface: nativeColors.surface,
        onSurface: nativeColors.onSurface,
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: _fallbackSeed,
        brightness: Brightness.light,
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
    );
  }

  /// Dark theme - uses native Material You colors if provided.
  static ThemeData dark([MaterialYouThemeColors? nativeColors]) {
    final ColorScheme colorScheme;
    if (nativeColors != null) {
      // Build ColorScheme from native colors
      colorScheme = ColorScheme.fromSeed(
        seedColor: nativeColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: nativeColors.primary,
        onPrimaryContainer: nativeColors.onPrimaryContainer,
        tertiary: nativeColors.tertiary,
        surface: nativeColors.surface,
        onSurface: nativeColors.onSurface,
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: _fallbackSeed,
        brightness: Brightness.dark,
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
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
  final Color daylightBar;
  final Color daylightGradient;
  final Color daylightIcon;
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
    required this.daylightBar,
    required this.daylightGradient,
    required this.daylightIcon,
    required this.timeLabel,
  });

  /// Light mode - clean, airy design
  static const light = MeteogramColors(
    background: Color(0xFFFAFAFA),       // Neutral light gray (fallback)
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
    daylightBar: Color(0xFFFFF0AA),      // Light pastel yellow
    daylightGradient: Color(0xFFFFD580),  // Light pastel orange
    daylightIcon: Color(0xFFD49A00),      // Darker amber for light backgrounds
    timeLabel: Color(0xFF4A5568),         // Fallback - overridden by Material You tertiary
  );

  /// Dark mode - rich, elegant design
  static const dark = MeteogramColors(
    background: Color(0xFF121212),       // Neutral dark gray (fallback)
    cardBackground: Color(0xFF2D2D2D),   // Elevated surface (fallback)
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
    daylightBar: Color(0xFFFFF0AA),      // Light pastel yellow
    daylightGradient: Color(0xFFFFD080),  // Light pastel orange
    daylightIcon: Color(0xFFFFD93D),      // Bright yellow for dark backgrounds
    timeLabel: Color(0xFFE0E0E0),         // Fallback - overridden by Material You tertiary
  );

  /// Get colors based on theme, using Material You colors.
  static MeteogramColors of(BuildContext context, {MaterialYouThemeColors? nativeColors}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return fromNativeColors(
      nativeColors: nativeColors,
      colorScheme: theme.colorScheme,
      isDark: isDark,
    );
  }

  /// Create colors from native Material You colors with ColorScheme fallback.
  /// Native colors provide proper surface container variants that Flutter's
  /// dynamic_color package fails to extract correctly.
  static MeteogramColors fromNativeColors({
    required MaterialYouThemeColors? nativeColors,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    // Use Material You colors with appropriate contrast for each theme:
    // - Light mode: onPrimaryContainer (darker, better contrast on light bg)
    // - Dark mode: primary (brighter, better contrast on dark bg)
    final tempColor = isDark ? colorScheme.primary : colorScheme.onPrimaryContainer;

    final base = isDark ? dark : light;

    // Use native surface container colors (properly extracted from Android)
    // Fall back to generated surfaceContainerHigh if native colors unavailable
    final cardColor = nativeColors?.surfaceContainerHigh ?? colorScheme.surfaceContainerHigh;

    return base.copyWith(
      background: colorScheme.surface,
      cardBackground: cardColor,
      temperatureLine: tempColor,
      temperatureGradientStart: tempColor.withAlpha(isDark ? 0x60 : 0x40),
      temperatureGradientEnd: tempColor.withAlpha(0x00),
      timeLabel: colorScheme.tertiary,
    );
  }

  /// Create colors from a specific ColorScheme (legacy method for compatibility).
  static MeteogramColors fromColorScheme(ColorScheme colorScheme, {required bool isDark}) {
    return fromNativeColors(
      nativeColors: null,
      colorScheme: colorScheme,
      isDark: isDark,
    );
  }

  /// Create a copy with overridden values.
  MeteogramColors copyWith({
    Color? background,
    Color? cardBackground,
    Color? temperatureLine,
    Color? temperatureGradientStart,
    Color? temperatureGradientEnd,
    Color? timeLabel,
  }) {
    return MeteogramColors(
      background: background ?? this.background,
      cardBackground: cardBackground ?? this.cardBackground,
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
      daylightBar: daylightBar,
      daylightGradient: daylightGradient,
      daylightIcon: daylightIcon,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }

}
