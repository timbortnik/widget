import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

/// Service to read Material You colors extracted by native Android code.
///
/// Colors are extracted in Kotlin (MaterialYouColorExtractor.kt) from
/// system_accent and system_neutral palettes and stored in HomeWidgetPreferences.
class MaterialYouService {
  // Keys matching Kotlin MaterialYouColorExtractor
  static const String _keyLightPrimary = 'material_you_light_primary';
  static const String _keyLightOnPrimaryContainer = 'material_you_light_on_primary_container';
  static const String _keyLightTertiary = 'material_you_light_tertiary';
  static const String _keyLightSurface = 'material_you_light_surface';
  static const String _keyLightSurfaceContainer = 'material_you_light_surface_container';
  static const String _keyLightSurfaceContainerHigh = 'material_you_light_surface_container_high';
  static const String _keyLightOnSurface = 'material_you_light_on_surface';

  static const String _keyDarkPrimary = 'material_you_dark_primary';
  static const String _keyDarkOnPrimaryContainer = 'material_you_dark_on_primary_container';
  static const String _keyDarkTertiary = 'material_you_dark_tertiary';
  static const String _keyDarkSurface = 'material_you_dark_surface';
  static const String _keyDarkSurfaceContainer = 'material_you_dark_surface_container';
  static const String _keyDarkSurfaceContainerHigh = 'material_you_dark_surface_container_high';
  static const String _keyDarkOnSurface = 'material_you_dark_on_surface';

  /// Get Material You colors for light and dark themes.
  /// Returns null if colors are not available (Android < 12 or not yet extracted).
  static Future<MaterialYouColors?> getColors() async {
    // Read from HomeWidgetPreferences (same file as native Kotlin code)
    final lightPrimary = await HomeWidget.getWidgetData<int>(_keyLightPrimary);

    // Check if colors have been extracted by native code
    if (lightPrimary == null) {
      return null;
    }

    return MaterialYouColors(
      light: MaterialYouThemeColors(
        primary: Color(lightPrimary),
        onPrimaryContainer: Color(await HomeWidget.getWidgetData<int>(_keyLightOnPrimaryContainer) ?? lightPrimary),
        tertiary: Color(await HomeWidget.getWidgetData<int>(_keyLightTertiary) ?? lightPrimary),
        surface: Color(await HomeWidget.getWidgetData<int>(_keyLightSurface) ?? 0xFFFAFAFA),
        surfaceContainer: Color(await HomeWidget.getWidgetData<int>(_keyLightSurfaceContainer) ?? 0xFFEEEEEE),
        surfaceContainerHigh: Color(await HomeWidget.getWidgetData<int>(_keyLightSurfaceContainerHigh) ?? 0xFFE0E0E0),
        onSurface: Color(await HomeWidget.getWidgetData<int>(_keyLightOnSurface) ?? 0xFF1C1C1C),
      ),
      dark: MaterialYouThemeColors(
        primary: Color(await HomeWidget.getWidgetData<int>(_keyDarkPrimary) ?? 0xFF90CAF9),
        onPrimaryContainer: Color(await HomeWidget.getWidgetData<int>(_keyDarkOnPrimaryContainer) ?? 0xFFE3F2FD),
        tertiary: Color(await HomeWidget.getWidgetData<int>(_keyDarkTertiary) ?? 0xFF80CBC4),
        surface: Color(await HomeWidget.getWidgetData<int>(_keyDarkSurface) ?? 0xFF121212),
        surfaceContainer: Color(await HomeWidget.getWidgetData<int>(_keyDarkSurfaceContainer) ?? 0xFF1E1E1E),
        surfaceContainerHigh: Color(await HomeWidget.getWidgetData<int>(_keyDarkSurfaceContainerHigh) ?? 0xFF2D2D2D),
        onSurface: Color(await HomeWidget.getWidgetData<int>(_keyDarkOnSurface) ?? 0xFFE0E0E0),
      ),
    );
  }
}

/// Container for light and dark Material You colors.
class MaterialYouColors {
  final MaterialYouThemeColors light;
  final MaterialYouThemeColors dark;

  const MaterialYouColors({
    required this.light,
    required this.dark,
  });
}

/// Material You colors for a single theme (light or dark).
class MaterialYouThemeColors {
  final Color primary;
  final Color onPrimaryContainer;
  final Color tertiary;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color onSurface;

  const MaterialYouThemeColors({
    required this.primary,
    required this.onPrimaryContainer,
    required this.tertiary,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
  });
}
