import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../models/weather_data.dart';

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
    String? chartImagePath,
  }) async {
    try {
      final currentHour = weatherData.getCurrentHour();

      // Save current temperature
      final tempString = currentHour != null
          ? '${currentHour.temperature.round()}°'
          : '--°';
      await HomeWidget.saveWidgetData<String>('current_temperature', tempString);

      // Save location name
      await HomeWidget.saveWidgetData<String>('location_name', locationName ?? '');

      // Save chart image path
      if (chartImagePath != null) {
        await HomeWidget.saveWidgetData<String>('meteogram_image', chartImagePath);
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

  /// Save chart image and return file path.
  Future<String?> saveChartImage(Uint8List imageBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/meteogram_chart.png');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving chart image: $e');
      return null;
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
