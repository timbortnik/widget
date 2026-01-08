import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meteogram_widget/models/weather_data.dart';
import 'package:meteogram_widget/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Set up SharedPreferences mock for all tests
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WeatherService API responses', () {
    test('parses successful API response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.path, '/v1/forecast');
        expect(request.url.queryParameters['latitude'], '52.52');
        expect(request.url.queryParameters['longitude'], '13.405');
        expect(request.url.queryParameters['timezone'], 'UTC');

        return http.Response(
          jsonEncode(_validWeatherResponse()),
          200,
        );
      });

      final service = WeatherService(client: mockClient);
      final data = await service.fetchWeather(52.52, 13.405);

      expect(data.latitude, closeTo(52.52, 0.01));
      expect(data.longitude, closeTo(13.41, 0.01));
      expect(data.timezone, 'UTC');
      expect(data.hourly.length, greaterThan(0));
    });

    test('parses temperature, precipitation, and cloud cover', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_validWeatherResponse()),
          200,
        );
      });

      final service = WeatherService(client: mockClient);
      final data = await service.fetchWeather(52.52, 13.405);

      // First entry is 6 hours in the past: 15.0 + (-6) * 0.5 = 12.0
      expect(data.hourly.first.temperature, 12.0);
      expect(data.hourly.first.precipitation, 0.0);
      // Cloud cover: 50 + ((-6) % 10) * 5 = 50 + 4 * 5 = 70 (Dart modulo)
      expect(data.hourly.first.cloudCover, 70);
    });

    test('throws WeatherException on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(52.52, 13.405),
        throwsA(isA<WeatherException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        )),
      );
    });

    test('throws WeatherException on 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(52.52, 13.405),
        throwsA(isA<WeatherException>().having(
          (e) => e.message,
          'message',
          contains('500'),
        )),
      );
    });

    test('throws rate limit exception on 429', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Too Many Requests', 429);
      });

      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(52.52, 13.405),
        throwsA(isA<WeatherException>().having(
          (e) => e.message,
          'message',
          contains('Rate limited'),
        )),
      );
    });

    test('throws WeatherException on timeout', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return http.Response('OK', 200);
      });

      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(52.52, 13.405),
        throwsA(isA<WeatherException>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        )),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('throws WeatherException on socket exception', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No internet');
      });

      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(52.52, 13.405),
        throwsA(isA<WeatherException>().having(
          (e) => e.message,
          'message',
          contains('internet'),
        )),
      );
    });
  });

  group('WeatherService caching', () {
    test('caches successful response', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(jsonEncode(_validWeatherResponse()), 200);
      });

      final service = WeatherService(client: mockClient);

      // First fetch
      await service.fetchWeather(52.52, 13.405);
      expect(requestCount, 1);

      // Verify cache was saved
      final cached = await service.getCachedWeather();
      expect(cached, isNotNull);
      expect(cached!.latitude, closeTo(52.52, 0.01));
    });

    test('returns cached data on API failure', () async {
      // First, successfully fetch and cache data
      var shouldFail = false;
      final mockClient = MockClient((request) async {
        if (shouldFail) {
          return http.Response('Server Error', 500);
        }
        return http.Response(jsonEncode(_validWeatherResponse()), 200);
      });

      final service = WeatherService(client: mockClient);

      // First fetch succeeds and caches
      await service.fetchWeather(52.52, 13.405);

      // Now make API fail
      shouldFail = true;

      // Should return cached data instead of throwing
      final data = await service.fetchWeather(52.52, 13.405);
      expect(data, isNotNull);
      expect(data.latitude, closeTo(52.52, 0.01));
    });

    test('throws when API fails and no cache available', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(52.52, 13.405),
        throwsA(isA<WeatherException>()),
      );
    });

    test('returns null for wrong location cache', () async {
      SharedPreferences.setMockInitialValues({
        'cached_weather_data': jsonEncode(_validWeatherResponse()),
        'cached_weather_location': '40.71,-74.01', // New York
      });

      final service = WeatherService(client: MockClient((r) async => http.Response('', 500)));

      // Request Berlin but cache is for New York
      final cached = await service.getCachedWeather('52.52,13.41');
      expect(cached, isNull);
    });

    test('clearCache removes cached data', () async {
      SharedPreferences.setMockInitialValues({
        'cached_weather_data': jsonEncode(_validWeatherResponse()),
        'cached_weather_location': '52.52,13.41',
      });

      final service = WeatherService(client: MockClient((r) async => http.Response('', 200)));

      // Verify cache exists
      var cached = await service.getCachedWeather();
      expect(cached, isNotNull);

      // Clear cache
      await service.clearCache();

      // Verify cache is gone
      cached = await service.getCachedWeather();
      expect(cached, isNull);
    });

    test('isCacheStale returns true when no cache', () async {
      final service = WeatherService(client: MockClient((r) async => http.Response('', 200)));
      expect(await service.isCacheStale(), isTrue);
    });

    test('isCacheStale returns false for fresh cache', () async {
      final freshResponse = _validWeatherResponse();
      freshResponse['fetchedAt'] = DateTime.now().toIso8601String();

      SharedPreferences.setMockInitialValues({
        'cached_weather_data': jsonEncode(freshResponse),
        'cached_weather_location': '52.52,13.41',
      });

      final service = WeatherService(client: MockClient((r) async => http.Response('', 200)));
      expect(await service.isCacheStale(), isFalse);
    });

    test('isCacheStale returns true for old cache', () async {
      final oldResponse = _validWeatherResponse();
      oldResponse['fetchedAt'] = DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String();

      SharedPreferences.setMockInitialValues({
        'cached_weather_data': jsonEncode(oldResponse),
        'cached_weather_location': '52.52,13.41',
      });

      final service = WeatherService(client: MockClient((r) async => http.Response('', 200)));
      expect(await service.isCacheStale(), isTrue);
    });
  });

  group('WeatherService location info caching', () {
    test('caches city name', () async {
      final service = WeatherService(client: MockClient((r) async => http.Response('', 200)));

      await service.cacheLocationInfo('Berlin', 'gps');

      expect(await service.getCachedCityName(), 'Berlin');
      expect(await service.getCachedLocationSource(), 'gps');
    });

    test('handles null city name', () async {
      final service = WeatherService(client: MockClient((r) async => http.Response('', 200)));

      await service.cacheLocationInfo(null, 'manual');

      expect(await service.getCachedCityName(), isNull);
      expect(await service.getCachedLocationSource(), 'manual');
    });
  });

  group('WeatherException', () {
    test('toString returns message', () {
      final exception = WeatherException('Test error');
      expect(exception.toString(), 'Test error');
    });

    test('message is accessible', () {
      final exception = WeatherException('Network error');
      expect(exception.message, 'Network error');
    });
  });

  group('WeatherService request parameters', () {
    test('sends correct query parameters', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_validWeatherResponse()), 200);
      });

      final service = WeatherService(client: mockClient);
      await service.fetchWeather(37.7749, -122.4194);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['latitude'], '37.7749');
      expect(capturedUri!.queryParameters['longitude'], '-122.4194');
      expect(capturedUri!.queryParameters['hourly'], 'temperature_2m,precipitation,cloud_cover');
      expect(capturedUri!.queryParameters['timezone'], 'UTC');
      expect(capturedUri!.queryParameters['past_hours'], '6');
      expect(capturedUri!.queryParameters['forecast_days'], '2');
    });

    test('handles negative coordinates', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_validWeatherResponse()), 200);
      });

      final service = WeatherService(client: mockClient);
      await service.fetchWeather(-33.8688, 151.2093); // Sydney

      expect(capturedUri!.queryParameters['latitude'], '-33.8688');
      expect(capturedUri!.queryParameters['longitude'], '151.2093');
    });
  });
}

/// Generate a valid weather API response for testing.
Map<String, dynamic> _validWeatherResponse() {
  final now = DateTime.now().toUtc();
  final times = <String>[];
  final temps = <double>[];
  final precip = <double>[];
  final clouds = <int>[];

  // Generate 54 hours of data (6 past + 48 forecast)
  for (var i = -6; i < 48; i++) {
    final time = now.add(Duration(hours: i));
    times.add(time.toIso8601String().replaceAll('Z', ''));
    temps.add(15.0 + i * 0.5);
    precip.add(i % 8 == 0 ? 1.5 : 0.0);
    clouds.add(50 + (i % 10) * 5);
  }

  return {
    'latitude': 52.52,
    'longitude': 13.41,
    'timezone': 'UTC',
    'fetchedAt': now.toIso8601String(),
    'hourly': {
      'time': times,
      'temperature_2m': temps,
      'precipitation': precip,
      'cloud_cover': clouds,
    },
  };
}
