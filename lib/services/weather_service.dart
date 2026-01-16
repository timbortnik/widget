import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

/// Service for fetching weather data from Open-Meteo API.
/// Includes caching and retry with Fibonacci backoff.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _cacheLocationKey = 'cached_weather_location';
  static const String _cacheCityNameKey = 'cached_city_name';
  static const String _cacheLocationSourceKey = 'cached_location_source';

  /// Fibonacci backoff delays in minutes: 1, 2, 3, 5, 8
  static const List<int> _retryDelaysMinutes = [1, 2, 3, 5, 8];

  /// HTTP client for making requests. Defaults to standard client.
  /// Can be overridden for testing.
  final http.Client _client;

  /// Create a WeatherService with optional custom HTTP client.
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch weather data for foreground use.
  /// Tries once, falls back to cache on failure. Does not block with retries.
  Future<WeatherData> fetchWeather(double latitude, double longitude) async {
    final locationKey = _locationKey(latitude, longitude);

    try {
      final data = await _fetchFromApi(latitude, longitude);
      await _cacheData(data, locationKey);
      return data;
    } catch (e) {
      // On failure, try to return cached data
      final cached = await getCachedWeather(locationKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetch weather data for background use.
  /// Retries with Fibonacci backoff (1, 2, 3, 5 minutes) before giving up.
  Future<WeatherData> fetchWeatherWithRetry(double latitude, double longitude) async {
    final locationKey = _locationKey(latitude, longitude);

    try {
      final data = await _fetchWithRetry(latitude, longitude);
      await _cacheData(data, locationKey);
      return data;
    } catch (e) {
      // On failure after all retries, try to return cached data
      final cached = await getCachedWeather(locationKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  String _locationKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
  }

  /// Fetch with Fibonacci backoff retry (1, 2, 3, 5 minutes).
  Future<WeatherData> _fetchWithRetry(double latitude, double longitude) async {
    Exception? lastException;

    // First attempt (no delay)
    try {
      return await _fetchFromApi(latitude, longitude);
    } catch (e) {
      lastException = e is Exception ? e : Exception(e.toString());
    }

    // Retry attempts with Fibonacci delays
    for (final delayMinutes in _retryDelaysMinutes) {
      await Future<void>.delayed(Duration(minutes: delayMinutes));

      try {
        return await _fetchFromApi(latitude, longitude);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastException ?? WeatherException('Failed after all retries');
  }

  /// Direct API fetch without retry logic.
  Future<WeatherData> _fetchFromApi(double latitude, double longitude) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'hourly': 'temperature_2m,precipitation,cloud_cover',
      'timezone': 'UTC',
      'past_hours': kPastHours.toString(),
      'forecast_days': '2',
    });

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WeatherData.fromJson(json);
      } else if (response.statusCode == 429) {
        throw WeatherException('Rate limited. Please try again later.');
      } else {
        // Log detailed error for debugging, show generic message to user
        debugPrint('Weather API error: ${response.statusCode} ${response.body}');
        throw WeatherException('Failed to load weather data. Please try again later.');
      }
    } on SocketException {
      throw WeatherException('No internet connection');
    } on TimeoutException {
      throw WeatherException('Connection timed out');
    }
  }

  /// Cache weather data to HomeWidget shared preferences.
  /// Uses the same keys as background_service.dart for unified cache.
  Future<void> _cacheData(WeatherData data, String locationKey) async {
    // Save to HomeWidget (shared with background service)
    await HomeWidget.saveWidgetData<String>('cached_weather', jsonEncode(data.toJson()));
    await HomeWidget.saveWidgetData<double>('cached_latitude', data.latitude);
    await HomeWidget.saveWidgetData<double>('cached_longitude', data.longitude);
    await HomeWidget.saveWidgetData<int>('last_weather_update', DateTime.now().millisecondsSinceEpoch);

    // Also save location key for location-specific cache validation
    await HomeWidget.saveWidgetData<String>(_cacheLocationKey, locationKey);
  }

  /// Cache location info separately (called from UI after successful load).
  /// Uses HomeWidget for background service access.
  Future<void> cacheLocationInfo(String? cityName, String? locationSource) async {
    if (cityName != null) {
      await HomeWidget.saveWidgetData<String>(_cacheCityNameKey, cityName);
    }
    if (locationSource != null) {
      await HomeWidget.saveWidgetData<String>(_cacheLocationSourceKey, locationSource);
    }
  }

  /// Get cached city name.
  Future<String?> getCachedCityName() async {
    return HomeWidget.getWidgetData<String>(_cacheCityNameKey);
  }

  /// Get cached location source.
  Future<String?> getCachedLocationSource() async {
    return HomeWidget.getWidgetData<String>(_cacheLocationSourceKey);
  }

  /// Get cached weather data if available and for the same location.
  Future<WeatherData?> getCachedWeather([String? locationKey]) async {
    final cachedJson = await HomeWidget.getWidgetData<String>('cached_weather');
    if (cachedJson == null) return null;

    // If location key provided, check it matches
    if (locationKey != null) {
      final cachedLocation = await HomeWidget.getWidgetData<String>(_cacheLocationKey);
      if (cachedLocation != locationKey) {
        return null;
      }
    }

    try {
      final json = jsonDecode(cachedJson) as Map<String, dynamic>;
      return WeatherData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Check if cached data is stale (older than maxAge).
  Future<bool> isCacheStale({Duration maxAge = const Duration(hours: 1)}) async {
    final cached = await getCachedWeather();
    if (cached == null) return true;
    return DateTime.now().difference(cached.fetchedAt) > maxAge;
  }

  /// Clear cached weather data.
  Future<void> clearCache() async {
    // Clear from HomeWidget
    await HomeWidget.saveWidgetData<String?>('cached_weather', null);
    await HomeWidget.saveWidgetData<double?>('cached_latitude', null);
    await HomeWidget.saveWidgetData<double?>('cached_longitude', null);
    await HomeWidget.saveWidgetData<int?>('last_weather_update', null);
    await HomeWidget.saveWidgetData<String?>(_cacheLocationKey, null);
  }

  /// Dispose of resources (close HTTP client).
  void dispose() {
    _client.close();
  }
}

/// Exception thrown when weather data cannot be fetched.
class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);

  @override
  String toString() => message;
}
