import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

/// Service for fetching weather data from Open-Meteo API.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch weather data for the given coordinates.
  ///
  /// Returns weather data with 2 hours of past data and 2 days of forecast.
  Future<WeatherData> fetchWeather(double latitude, double longitude) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'hourly': 'temperature_2m,precipitation,cloud_cover',
      'timezone': 'auto',
      'past_hours': '8',
      'forecast_days': '2',
    });

    final response = await http.get(uri);

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
  }
}

/// Exception thrown when weather data cannot be fetched.
class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);

  @override
  String toString() => message;
}
