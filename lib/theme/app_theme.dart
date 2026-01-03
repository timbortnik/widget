import 'package:flutter/material.dart';

/// App theme configuration with light and dark modes.
class AppTheme {
  /// Light theme.
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  );

  /// Dark theme.
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );
}

/// Colors specifically for the meteogram chart.
class MeteogramColors {
  final Color background;
  final Color temperatureLine;
  final Color precipitationBar;
  final Color nowIndicator;
  final Color gridLine;
  final Color labelText;
  final Color clearSky;
  final Color overcastSky;

  const MeteogramColors({
    required this.background,
    required this.temperatureLine,
    required this.precipitationBar,
    required this.nowIndicator,
    required this.gridLine,
    required this.labelText,
    required this.clearSky,
    required this.overcastSky,
  });

  /// Light mode chart colors.
  static const light = MeteogramColors(
    background: Color(0xFFFFFFFF),
    temperatureLine: Color(0xFFE53935),
    precipitationBar: Color(0xFF1E88E5),
    nowIndicator: Color(0xFFFF9800),
    gridLine: Color(0xFFE0E0E0),
    labelText: Color(0xFF616161),
    clearSky: Color(0xFF87CEEB),
    overcastSky: Color(0xFFB0BEC5),
  );

  /// Dark mode chart colors.
  static const dark = MeteogramColors(
    background: Color(0xFF1E1E1E),
    temperatureLine: Color(0xFFEF5350),
    precipitationBar: Color(0xFF42A5F5),
    nowIndicator: Color(0xFFFFB74D),
    gridLine: Color(0xFF424242),
    labelText: Color(0xFFBDBDBD),
    clearSky: Color(0xFF1565C0),
    overcastSky: Color(0xFF546E7A),
  );

  /// Get colors based on brightness.
  static MeteogramColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  /// Get sky color based on cloud cover percentage.
  Color getSkyColor(int cloudCover) {
    // Interpolate between clear and overcast based on cloud cover
    return Color.lerp(clearSky, overcastSky, cloudCover / 100)!;
  }
}

/// Widget transparency settings.
class WidgetTransparency {
  /// Background opacity for the widget (semi-transparent).
  static const double backgroundOpacity = 0.85;

  /// Get widget background color with transparency.
  static Color getBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor =
        brightness == Brightness.dark ? Colors.black : Colors.white;
    return baseColor.withOpacity(backgroundOpacity);
  }
}
