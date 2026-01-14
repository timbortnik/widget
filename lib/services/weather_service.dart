import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';

/// Service for fetching weather data from Open-Meteo API.
/// Includes caching and retry with Fibonacci backoff.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _cacheKey = 'cached_weather_data';
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
        throw WeatherException(
          'Failed to load weather data: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw WeatherException('No internet connection');
    } on TimeoutException {
      throw WeatherException('Connection timed out');
    }
  }

  /// Cache weather data to SharedPreferences.
  Future<void> _cacheData(WeatherData data, String locationKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    await prefs.setString(_cacheLocationKey, locationKey);
  }

  /// Cache location info separately (called from UI after successful load).
  Future<void> cacheLocationInfo(String? cityName, String? locationSource) async {
    final prefs = await SharedPreferences.getInstance();
    if (cityName != null) {
      await prefs.setString(_cacheCityNameKey, cityName);
    }
    if (locationSource != null) {
      await prefs.setString(_cacheLocationSourceKey, locationSource);
    }
  }

  /// Get cached city name.
  Future<String?> getCachedCityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheCityNameKey);
  }

  /// Get cached location source.
  Future<String?> getCachedLocationSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheLocationSourceKey);
  }

  /// Get cached weather data if available and for the same location.
  Future<WeatherData?> getCachedWeather([String? locationKey]) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    final cachedLocation = prefs.getString(_cacheLocationKey);

    if (cachedJson == null) return null;

    // If location key provided, check it matches
    if (locationKey != null && cachedLocation != locationKey) {
      return null;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheLocationKey);
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
