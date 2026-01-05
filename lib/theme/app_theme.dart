import 'package:flutter/material.dart';

/// App theme configuration with light and dark modes.
class AppTheme {
  /// Light theme.
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B8DEF),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  );

  /// Dark theme.
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B8DEF),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D1B2A),
  );
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
  final Color clearSky;
  final Color partlyCloudySky;
  final Color overcastSky;
  final Color chartTempLabel;
  final Color sunshineBar;
  final Color sunshineGradient;
  final Color sunshineIcon;

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
    required this.clearSky,
    required this.partlyCloudySky,
    required this.overcastSky,
    required this.chartTempLabel,
    required this.sunshineBar,
    required this.sunshineGradient,
    required this.sunshineIcon,
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
    clearSky: Color(0xFF74B9FF),
    partlyCloudySky: Color(0xFFA0C4E8),
    overcastSky: Color(0xFFB2BEC3),
    chartTempLabel: Color(0xFF1A1A2E),
    sunshineBar: Color(0xFFFFE477),
    sunshineGradient: Color(0xFFFFB54D),
    sunshineIcon: Color(0xFFD49A00), // Darker amber for light backgrounds
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
    clearSky: Color(0xFF2D5A7B),
    partlyCloudySky: Color(0xFF3D6B8C),
    overcastSky: Color(0xFF4A5568),
    chartTempLabel: Color(0xFFF0F0F0),
    sunshineBar: Color(0xFFFFE477),
    sunshineGradient: Color(0xFFFFAF4D),
    sunshineIcon: Color(0xFFFFD93D), // Bright yellow for dark backgrounds
  );

  /// Get colors based on brightness.
  static MeteogramColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  /// Get sky color based on cloud cover percentage with smooth gradient.
  Color getSkyColor(int cloudCover) {
    if (cloudCover < 30) {
      return Color.lerp(clearSky, partlyCloudySky, cloudCover / 30)!;
    } else {
      return Color.lerp(partlyCloudySky, overcastSky, (cloudCover - 30) / 70)!;
    }
  }
}

/// Gradient presets for widget backgrounds.
class WeatherGradients {
  /// Clear day gradient
  static const clearDay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF74B9FF), Color(0xFF0984E3)],
  );

  /// Clear night gradient
  static const clearNight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D3436), Color(0xFF0D1B2A)],
  );

  /// Cloudy gradient
  static const cloudy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF636E72), Color(0xFF2D3436)],
  );

  /// Rainy gradient
  static const rainy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A5568), Color(0xFF2D3748)],
  );

  /// Get gradient based on weather conditions
  static LinearGradient forConditions({
    required int cloudCover,
    required double precipitation,
    required bool isDaytime,
  }) {
    if (precipitation > 0.5) return rainy;
    if (cloudCover > 60) return cloudy;
    return isDaytime ? clearDay : clearNight;
  }
}
