import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../models/weather_data.dart';

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
}
