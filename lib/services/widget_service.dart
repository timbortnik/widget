import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/weather_data.dart';

/// Service for updating the home screen widget.
class WidgetService {
  static const _androidWidgetName = 'MeteogramWidgetProvider';
  static const _iosWidgetName = 'MeteogramWidget';

  /// Update the home screen widget with new weather data.
  Future<void> updateWidget({
    required WeatherData weatherData,
    required String? locationName,
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

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Initialize widget service.
  static Future<void> initialize() async {
    // Set app group ID for iOS
    await HomeWidget.setAppGroupId('group.com.meteogram.widget');
  }
}
