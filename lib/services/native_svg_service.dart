import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../models/weather_data.dart';

/// Service for native Kotlin operations via method channel.
/// Handles SVG generation, weather fetching, and cache management.
class NativeSvgService {
  static const _channel = MethodChannel('org.bortnik.meteogram/svg');

  // Cache keys (must match Kotlin WeatherFetcher constants)
  static const _keyCachedWeather = 'cached_weather';
  static const _keyLastWeatherUpdate = 'last_weather_update';
  static const _keyCachedCityName = 'cached_city_name';
  static const _keyCachedLocationSource = 'cached_location_source';

  /// Staleness threshold for weather data (15 minutes)
  static const _staleThreshold = Duration(minutes: 15);

  // ============ Weather Fetching ============

  /// Fetch weather data via native Kotlin HTTP client.
  /// Weather is saved to SharedPreferences for later use.
  /// Returns true on success, false on failure.
  static Future<bool> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('fetchWeather', {
        'latitude': latitude,
        'longitude': longitude,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Native weather fetch failed: ${e.message}');
      return false;
    }
  }

  // ============ Cache Reading ============

  /// Get cached weather data if available.
  static Future<WeatherData?> getCachedWeather() async {
    final jsonStr = await HomeWidget.getWidgetData<String>(_keyCachedWeather);
    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WeatherData.fromJson(json);
    } catch (e) {
      debugPrint('Error parsing cached weather: $e');
      return null;
    }
  }

  /// Get cached city name.
  static Future<String?> getCachedCityName() async {
    return HomeWidget.getWidgetData<String>(_keyCachedCityName);
  }

  /// Get cached location source.
  static Future<String?> getCachedLocationSource() async {
    return HomeWidget.getWidgetData<String>(_keyCachedLocationSource);
  }

  /// Check if cached data is stale (older than 15 minutes).
  static Future<bool> isCacheStale() async {
    final lastUpdate = await HomeWidget.getWidgetData<int>(_keyLastWeatherUpdate);
    if (lastUpdate == null) return true;

    final age = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    return age > _staleThreshold.inMilliseconds;
  }

  // ============ Cache Writing ============

  /// Save location info to cache for offline display.
  static Future<void> cacheLocationInfo(String? cityName, String? locationSource) async {
    if (cityName != null) {
      await HomeWidget.saveWidgetData<String>(_keyCachedCityName, cityName);
    }
    if (locationSource != null) {
      await HomeWidget.saveWidgetData<String>(_keyCachedLocationSource, locationSource);
    }
  }

  /// Generate SVG string using native Kotlin generator.
  /// Returns null if generation fails (e.g., no cached weather data).
  ///
  /// The native generator reads weather data from SharedPreferences,
  /// so weather must be cached before calling this.
  static Future<String?> generateSvg({
    required int width,
    required int height,
    required bool isLight,
    required bool usesFahrenheit,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('generateSvg', {
        'width': width,
        'height': height,
        'isLight': isLight,
        'usesFahrenheit': usesFahrenheit,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Native SVG generation failed: ${e.message}');
      return null;
    }
  }

  /// Generate both light and dark SVG strings.
  /// Returns a record with light and dark SVGs, or nulls if generation fails.
  static Future<({String? light, String? dark})> generateSvgPair({
    required int width,
    required int height,
    required bool usesFahrenheit,
  }) async {
    final light = await generateSvg(
      width: width,
      height: height,
      isLight: true,
      usesFahrenheit: usesFahrenheit,
    );
    final dark = await generateSvg(
      width: width,
      height: height,
      isLight: false,
      usesFahrenheit: usesFahrenheit,
    );
    return (light: light, dark: dark);
  }
}
