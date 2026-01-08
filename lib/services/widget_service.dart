import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../models/weather_data.dart';
import 'svg_chart_generator.dart';
import 'units_service.dart';

/// Widget dimensions in pixels as reported by the native widget provider.
class WidgetDimensions {
  final int widthPx;
  final int heightPx;
  final double density;

  const WidgetDimensions({
    required this.widthPx,
    required this.heightPx,
    required this.density,
  });

  /// Logical size for Flutter rendering.
  Size get logicalSize => Size(widthPx / density, heightPx / density);

  @override
  String toString() => 'WidgetDimensions(${widthPx}x${heightPx}px, density: $density)';
}

/// Service for updating the home screen widget.
class WidgetService {
  static const _androidWidgetName = 'MeteogramWidgetProvider';
  static const _iosWidgetName = 'MeteogramWidget';

  /// Update the home screen widget with new weather data.
  Future<void> updateWidget({
    required WeatherData weatherData,
    required String? locationName,
    required Locale locale,
    String? lightChartPath,
    String? darkChartPath,
  }) async {
    try {
      final currentHour = weatherData.getCurrentHour();

      // Save current temperature using locale-aware formatting
      final tempString = currentHour != null
          ? UnitsService.formatTemperature(currentHour.temperature, locale)
          : '--°';
      await HomeWidget.saveWidgetData<String>('current_temperature', tempString);

      // Save location name
      await HomeWidget.saveWidgetData<String>('location_name', locationName ?? '');

      // Save chart image paths (both themes)
      if (lightChartPath != null) {
        await HomeWidget.saveWidgetData<String>('meteogram_image_light', lightChartPath);
      }
      if (darkChartPath != null) {
        await HomeWidget.saveWidgetData<String>('meteogram_image_dark', darkChartPath);
      }

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Save chart image for a specific theme and return file path.
  Future<String?> saveChartImage(Uint8List imageBytes, {required bool isDark}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final suffix = isDark ? 'dark' : 'light';
      final file = File('${directory.path}/meteogram_chart_$suffix.png');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving chart image: $e');
      return null;
    }
  }

  /// Generate and save SVG charts for the widget.
  /// This runs in the main isolate and complements PNG generation.
  ///
  /// Optional [lightColors] and [darkColors] can be provided to apply
  /// Material You dynamic colors. If not provided, uses default colors.
  Future<void> generateAndSaveSvgCharts({
    required List<HourlyData> displayData,
    required int nowIndex,
    required double latitude,
    String locale = 'en',
    bool usesFahrenheit = false,
    SvgChartColors? lightColors,
    SvgChartColors? darkColors,
  }) async {
    try {
      final generator = SvgChartGenerator();

      // Get widget dimensions
      final dimensions = await getWidgetDimensions();
      final widthPx = dimensions?.widthPx ?? 400;
      final heightPx = dimensions?.heightPx ?? 200;

      // Generate light and dark SVGs with provided or default colors
      final svgLight = generator.generate(
        data: displayData,
        nowIndex: nowIndex,
        latitude: latitude,
        colors: lightColors ?? SvgChartColors.light,
        width: widthPx.toDouble(),
        height: heightPx.toDouble(),
        locale: locale,
        usesFahrenheit: usesFahrenheit,
      );

      final svgDark = generator.generate(
        data: displayData,
        nowIndex: nowIndex,
        latitude: latitude,
        colors: darkColors ?? SvgChartColors.dark,
        width: widthPx.toDouble(),
        height: heightPx.toDouble(),
        locale: locale,
        usesFahrenheit: usesFahrenheit,
      );

      // Save SVG files using atomic writes (write to temp, then rename)
      final docsDir = await getApplicationDocumentsDirectory();
      final lightPath = '${docsDir.path}/meteogram_light.svg';
      final darkPath = '${docsDir.path}/meteogram_dark.svg';
      final lightTempPath = '${docsDir.path}/meteogram_light.svg.tmp';
      final darkTempPath = '${docsDir.path}/meteogram_dark.svg.tmp';

      // Write to temp files first
      await File(lightTempPath).writeAsString(svgLight);
      await File(darkTempPath).writeAsString(svgDark);

      // Atomic rename to final paths
      await File(lightTempPath).rename(lightPath);
      await File(darkTempPath).rename(darkPath);

      // Save paths for native widget
      await HomeWidget.saveWidgetData<String>('svg_path_light', lightPath);
      await HomeWidget.saveWidgetData<String>('svg_path_dark', darkPath);

      debugPrint('SVG charts generated: $lightPath, $darkPath');
    } catch (e) {
      debugPrint('Error generating SVG charts: $e');
    }
  }

  /// Initialize widget service.
  static Future<void> initialize() async {
    // Set app group ID for iOS
    await HomeWidget.setAppGroupId('group.com.meteogram.widget');
  }

  /// Trigger a native widget update (to check theme mismatch and show indicator).
  Future<void> triggerWidgetUpdate() async {
    try {
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
      debugPrint('Triggered widget update for theme check');
    } catch (e) {
      debugPrint('Error triggering widget update: $e');
    }
  }

  /// Save the theme (dark/light) used for the last render.
  /// Native widget uses this to show refresh indicator on theme mismatch.
  Future<void> saveRenderedTheme(bool isDark) async {
    try {
      await HomeWidget.saveWidgetData<bool>('rendered_dark_mode', isDark);
      debugPrint('Saved rendered theme: ${isDark ? "dark" : "light"}');
    } catch (e) {
      debugPrint('Error saving rendered theme: $e');
    }
  }

  /// Get the theme used for the last render.
  /// Returns null if no render has happened yet.
  Future<bool?> getRenderedTheme() async {
    try {
      return await HomeWidget.getWidgetData<bool>('rendered_dark_mode');
    } catch (e) {
      debugPrint('Error getting rendered theme: $e');
      return null;
    }
  }

  /// Check if widget was resized and clear the flag.
  /// Returns true if widget needs re-rendering.
  Future<bool> checkAndClearResizeFlag() async {
    try {
      final resized = await HomeWidget.getWidgetData<bool>('widget_resized');
      if (resized == true) {
        await HomeWidget.saveWidgetData<bool>('widget_resized', false);
        debugPrint('Widget was resized, triggering re-render');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking resize flag: $e');
      return false;
    }
  }

  /// Get widget dimensions from native widget provider.
  /// Returns null if dimensions haven't been set (widget not yet placed).
  Future<WidgetDimensions?> getWidgetDimensions() async {
    try {
      final widthPx = await HomeWidget.getWidgetData<int>('widget_width_px');
      final heightPx = await HomeWidget.getWidgetData<int>('widget_height_px');
      final density = await HomeWidget.getWidgetData<double>('widget_density');

      if (widthPx == null || heightPx == null || density == null) {
        debugPrint('Widget dimensions not available yet');
        return null;
      }

      if (widthPx <= 0 || heightPx <= 0) {
        debugPrint('Invalid widget dimensions: ${widthPx}x$heightPx');
        return null;
      }

      final dimensions = WidgetDimensions(
        widthPx: widthPx,
        heightPx: heightPx,
        density: density,
      );
      debugPrint('Widget dimensions: $dimensions');
      return dimensions;
    } catch (e) {
      debugPrint('Error getting widget dimensions: $e');
      return null;
    }
  }
}
