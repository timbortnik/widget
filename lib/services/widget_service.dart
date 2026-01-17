import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../models/weather_data.dart';
import 'svg_chart_generator.dart';
import 'units_service.dart';

/// SVG chart file names used by both Flutter and native widget code.
const String kLightSvgFileName = 'meteogram_light.svg';
const String kDarkSvgFileName = 'meteogram_dark.svg';

/// Default fallback dimensions - must match WidgetUtils.kt and background_service.dart
const int kDefaultWidthPx = 1000;
const int kDefaultHeightPx = 500;

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

      // Trigger widget update (SVG chart paths are saved by generateAndSaveSvgCharts)
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Generate and save SVG charts for the widget.
  /// This runs in the main isolate and complements PNG generation.
  ///
  /// Optional [lightColors] and [darkColors] can be provided to apply
  /// Material You dynamic colors. If not provided, uses default colors.
  /// Returns true if charts were generated successfully, false on error.
  Future<bool> generateAndSaveSvgCharts({
    required List<HourlyData> displayData,
    required int nowIndex,
    required double latitude,
    required double longitude,
    String locale = 'en',
    bool usesFahrenheit = false,
    SvgChartColors? lightColors,
    SvgChartColors? darkColors,
  }) async {
    try {
      final generator = SvgChartGenerator();
      final docsDir = await getApplicationDocumentsDirectory();
      final effectiveLightColors = lightColors ?? SvgChartColors.light;
      final effectiveDarkColors = darkColors ?? SvgChartColors.dark;

      // Get list of widget IDs (stored as comma-separated string by native code)
      final widgetIdsStr = await HomeWidget.getWidgetData<String>('widget_ids');

      if (widgetIdsStr != null && widgetIdsStr.isNotEmpty) {
        // Generate per-widget SVGs at each widget's dimensions
        final widgetIds = widgetIdsStr.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
        debugPrint('Generating SVGs for ${widgetIds.length} widgets: $widgetIds');

        for (final widgetId in widgetIds) {
          final widthPx = await HomeWidget.getWidgetData<int>('widget_${widgetId}_width_px') ?? kDefaultWidthPx;
          final heightPx = await HomeWidget.getWidgetData<int>('widget_${widgetId}_height_px') ?? kDefaultHeightPx;

          await _generateAndSaveSvgPair(
            generator: generator,
            docsDir: docsDir,
            displayData: displayData,
            nowIndex: nowIndex,
            latitude: latitude,
            longitude: longitude,
            widthPx: widthPx,
            heightPx: heightPx,
            locale: locale,
            usesFahrenheit: usesFahrenheit,
            lightColors: effectiveLightColors,
            darkColors: effectiveDarkColors,
            widgetId: widgetId,
          );
        }
      } else {
        // No widget IDs tracked yet, generate generic SVG for backward compatibility
        final dimensions = await getWidgetDimensions();
        final widthPx = dimensions?.widthPx ?? kDefaultWidthPx;
        final heightPx = dimensions?.heightPx ?? kDefaultHeightPx;

        await _generateAndSaveSvgPair(
          generator: generator,
          docsDir: docsDir,
          displayData: displayData,
          nowIndex: nowIndex,
          latitude: latitude,
          longitude: longitude,
          widthPx: widthPx,
          heightPx: heightPx,
          locale: locale,
          usesFahrenheit: usesFahrenheit,
          lightColors: effectiveLightColors,
          darkColors: effectiveDarkColors,
          widgetId: null,
        );
      }

      // Update last render time for conditional re-render on unlock
      await HomeWidget.saveWidgetData<int>('last_render_time', DateTime.now().millisecondsSinceEpoch);

      return true;
    } catch (e) {
      debugPrint('Error generating SVG charts: $e');
      return false;
    }
  }

  /// Helper to generate and save a pair of light/dark SVG files.
  Future<void> _generateAndSaveSvgPair({
    required SvgChartGenerator generator,
    required Directory docsDir,
    required List<HourlyData> displayData,
    required int nowIndex,
    required double latitude,
    required double longitude,
    required int widthPx,
    required int heightPx,
    required String locale,
    required bool usesFahrenheit,
    required SvgChartColors lightColors,
    required SvgChartColors darkColors,
    required int? widgetId,
  }) async {
    final svgLight = generator.generate(
      data: displayData,
      nowIndex: nowIndex,
      latitude: latitude,
      longitude: longitude,
      colors: lightColors,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      locale: locale,
      usesFahrenheit: usesFahrenheit,
    );

    final svgDark = generator.generate(
      data: displayData,
      nowIndex: nowIndex,
      latitude: latitude,
      longitude: longitude,
      colors: darkColors,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      locale: locale,
      usesFahrenheit: usesFahrenheit,
    );

    // Use widget-specific file names if widgetId provided
    final lightFileName = widgetId != null ? 'meteogram_light_$widgetId.svg' : kLightSvgFileName;
    final darkFileName = widgetId != null ? 'meteogram_dark_$widgetId.svg' : kDarkSvgFileName;
    final lightPath = '${docsDir.path}/$lightFileName';
    final darkPath = '${docsDir.path}/$darkFileName';
    final lightTempPath = '$lightPath.tmp';
    final darkTempPath = '$darkPath.tmp';

    // Write to temp files first
    await File(lightTempPath).writeAsString(svgLight);
    await File(darkTempPath).writeAsString(svgDark);

    // Atomic rename to final paths
    await File(lightTempPath).rename(lightPath);
    await File(darkTempPath).rename(darkPath);

    // Save paths for native widget
    if (widgetId != null) {
      await HomeWidget.saveWidgetData<String>('svg_path_light_$widgetId', lightPath);
      await HomeWidget.saveWidgetData<String>('svg_path_dark_$widgetId', darkPath);
      debugPrint('SVG charts generated for widget $widgetId: $lightPath');
    } else {
      await HomeWidget.saveWidgetData<String>('svg_path_light', lightPath);
      await HomeWidget.saveWidgetData<String>('svg_path_dark', darkPath);
      debugPrint('SVG charts generated: $lightPath, $darkPath');
    }
  }

  /// Initialize widget service.
  static Future<void> initialize() async {
    // Set app group ID for iOS
    await HomeWidget.setAppGroupId('group.org.bortnik.meteogram');

    // Clean up any orphaned .tmp files from previous crashes
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final tmpFiles = [
        File('${docsDir.path}/$kLightSvgFileName.tmp'),
        File('${docsDir.path}/$kDarkSvgFileName.tmp'),
      ];
      for (final file in tmpFiles) {
        try {
          await file.delete();
          debugPrint('Cleaned up orphaned temp file: ${file.path}');
        } catch (_) {
          // File doesn't exist - nothing to clean up
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
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
