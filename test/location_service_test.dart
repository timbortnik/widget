import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meteogram_widget/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Create a mock HTTP response with UTF-8 encoding for Unicode support.
http.Response utf8Response(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock HomeWidget method channel
  final Map<String, dynamic> homeWidgetData = {};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
    if (call.method == 'saveWidgetData') {
      final args = call.arguments as Map;
      final id = args['id'] as String?;
      final data = args['data'];
      if (id != null) {
        if (data == null) {
          homeWidgetData.remove(id);
        } else {
          homeWidgetData[id] = data;
        }
      }
      return true;
    } else if (call.method == 'getWidgetData') {
      final args = call.arguments as Map;
      final id = args['id'] as String?;
      return id != null ? homeWidgetData[id] : null;
    }
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    homeWidgetData.clear();
  });

  group('CitySearchResult', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'Berlin',
        'country': 'Germany',
        'admin1': 'Berlin',
        'latitude': 52.52,
        'longitude': 13.405,
      };

      final result = CitySearchResult.fromJson(json);

      expect(result.name, 'Berlin');
      expect(result.country, 'Germany');
      expect(result.admin1, 'Berlin');
      expect(result.latitude, 52.52);
      expect(result.longitude, 13.405);
    });

    test('fromJson handles null country', () {
      final json = {
        'name': 'Test City',
        'latitude': 0.0,
        'longitude': 0.0,
      };

      final result = CitySearchResult.fromJson(json);

      expect(result.country, '');
    });

    test('fromJson handles null admin1', () {
      final json = {
        'name': 'Test City',
        'country': 'Test',
        'latitude': 0.0,
        'longitude': 0.0,
      };

      final result = CitySearchResult.fromJson(json);

      expect(result.admin1, isNull);
    });

    test('toJson produces correct output', () {
      final city = CitySearchResult(
        name: 'Kyiv',
        country: 'Ukraine',
        admin1: 'Kyiv City',
        latitude: 50.45,
        longitude: 30.52,
      );

      final json = city.toJson();

      expect(json['name'], 'Kyiv');
      expect(json['country'], 'Ukraine');
      expect(json['admin1'], 'Kyiv City');
      expect(json['latitude'], 50.45);
      expect(json['longitude'], 30.52);
    });

    test('toJson/fromJson roundtrip preserves data', () {
      final original = CitySearchResult(
        name: 'Tokyo',
        country: 'Japan',
        admin1: 'Tokyo',
        latitude: 35.6762,
        longitude: 139.6503,
      );

      final json = original.toJson();
      final restored = CitySearchResult.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.country, original.country);
      expect(restored.admin1, original.admin1);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });
  });

  group('CitySearchResult.displayName', () {
    test('includes name, admin1, and country', () {
      final city = CitySearchResult(
        name: 'Mountain View',
        country: 'United States',
        admin1: 'California',
        latitude: 37.39,
        longitude: -122.08,
      );

      expect(city.displayName, 'Mountain View, California, United States');
    });

    test('excludes admin1 when same as name', () {
      final city = CitySearchResult(
        name: 'Berlin',
        country: 'Germany',
        admin1: 'Berlin',
        latitude: 52.52,
        longitude: 13.405,
      );

      expect(city.displayName, 'Berlin, Germany');
    });

    test('excludes admin1 when null', () {
      final city = CitySearchResult(
        name: 'Singapore',
        country: 'Singapore',
        latitude: 1.35,
        longitude: 103.82,
      );

      expect(city.displayName, 'Singapore, Singapore');
    });

    test('excludes admin1 when empty', () {
      final city = CitySearchResult(
        name: 'Monaco',
        country: 'Monaco',
        admin1: '',
        latitude: 43.73,
        longitude: 7.42,
      );

      expect(city.displayName, 'Monaco, Monaco');
    });

    test('handles empty country', () {
      final city = CitySearchResult(
        name: 'Test',
        country: '',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(city.displayName, 'Test');
    });
  });

  group('LocationData', () {
    test('isGps returns true for GPS source', () {
      final location = LocationData(
        latitude: 52.52,
        longitude: 13.405,
        source: LocationSource.gps,
        city: 'Berlin',
      );

      expect(location.isGps, isTrue);
    });

    test('isGps returns false for manual source', () {
      final location = LocationData(
        latitude: 52.52,
        longitude: 13.405,
        source: LocationSource.manual,
        city: 'Berlin',
      );

      expect(location.isGps, isFalse);
    });
  });

  group('LocationService.searchCities', () {
    test('returns results for valid query', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'geocoding-api.open-meteo.com');
        expect(request.url.path, '/v1/search');

        return http.Response(
          jsonEncode({
            'results': [
              {
                'name': 'Berlin',
                'country': 'Germany',
                'admin1': 'Berlin',
                'latitude': 52.52,
                'longitude': 13.41,
              },
              {
                'name': 'Bern',
                'country': 'Switzerland',
                'admin1': 'Bern',
                'latitude': 46.95,
                'longitude': 7.45,
              },
            ],
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('Ber');

      expect(results.length, 2);
      expect(results[0].name, 'Berlin');
      expect(results[1].name, 'Bern');
    });

    test('returns empty list for short query', () async {
      final mockClient = MockClient((request) async {
        fail('Should not make HTTP request for short query');
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('B');

      expect(results, isEmpty);
    });

    test('returns empty list for empty query', () async {
      final mockClient = MockClient((request) async {
        fail('Should not make HTTP request for empty query');
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('');

      expect(results, isEmpty);
    });

    test('returns empty list when no results', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'results': null}), 200);
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('xyznonexistent');

      expect(results, isEmpty);
    });

    test('returns empty list on API error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('Berlin');

      expect(results, isEmpty);
    });

    test('passes language parameter', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return http.Response(jsonEncode({'results': <dynamic>[]}), 200);
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('Paris', language: 'fr');

      expect(capturedLanguage, 'fr');
    });
  });

  group('LocationService script detection', () {
    test('detects Cyrillic and uses Russian', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return utf8Response(
          jsonEncode({
            'results': [
              {
                'name': 'Москва',
                'country': 'Russia',
                'latitude': 55.75,
                'longitude': 37.62,
              }
            ]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('Москва', language: 'en');

      expect(capturedLanguage, 'ru');
    });

    test('detects Ukrainian-specific Cyrillic', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return utf8Response(
          jsonEncode({
            'results': [
              {
                'name': 'Київ',
                'country': 'Ukraine',
                'latitude': 50.45,
                'longitude': 30.52,
              }
            ]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('Київ', language: 'en');

      expect(capturedLanguage, 'uk');
    });

    test('detects Japanese hiragana characters', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        // Return result to avoid retry with default language
        return utf8Response(
          jsonEncode({
            'results': [{'name': 'Tokyo', 'country': 'Japan', 'latitude': 35.68, 'longitude': 139.69}]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('とうきょう', language: 'en'); // Hiragana

      expect(capturedLanguage, 'ja');
    });

    test('detects CJK characters as Chinese', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return utf8Response(
          jsonEncode({
            'results': [{'name': 'Tokyo', 'country': 'Japan', 'latitude': 35.68, 'longitude': 139.69}]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('東京', language: 'en'); // CJK

      // CJK characters default to Chinese
      expect(capturedLanguage, 'zh');
    });

    test('detects Korean characters', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return utf8Response(
          jsonEncode({
            'results': [{'name': 'Seoul', 'country': 'South Korea', 'latitude': 37.57, 'longitude': 126.98}]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('서울', language: 'en');

      expect(capturedLanguage, 'ko');
    });

    test('detects Arabic characters', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return utf8Response(
          jsonEncode({
            'results': [{'name': 'Cairo', 'country': 'Egypt', 'latitude': 30.04, 'longitude': 31.24}]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('القاهرة', language: 'en');

      expect(capturedLanguage, 'ar');
    });

    test('detects Greek characters', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return utf8Response(
          jsonEncode({
            'results': [{'name': 'Athens', 'country': 'Greece', 'latitude': 37.98, 'longitude': 23.73}]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('Αθήνα', language: 'en');

      expect(capturedLanguage, 'el');
    });

    test('uses default language for Latin script', () async {
      String? capturedLanguage;
      final mockClient = MockClient((request) async {
        capturedLanguage = request.url.queryParameters['language'];
        return http.Response(jsonEncode({'results': <dynamic>[]}), 200);
      });

      final service = LocationService(client: mockClient);
      await service.searchCities('Berlin', language: 'de');

      expect(capturedLanguage, 'de');
    });
  });

  group('LocationService recent cities', () {
    test('saves and retrieves recent city', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      final city = CitySearchResult(
        name: 'Paris',
        country: 'France',
        latitude: 48.85,
        longitude: 2.35,
      );

      await service.addRecentCity(city);
      final recent = await service.getRecentCities();

      expect(recent.length, 1);
      expect(recent[0].name, 'Paris');
    });

    test('limits recent cities to 5', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      // Add 7 cities
      for (var i = 0; i < 7; i++) {
        await service.addRecentCity(CitySearchResult(
          name: 'City $i',
          country: 'Country',
          latitude: i.toDouble(),
          longitude: i.toDouble(),
        ));
      }

      final recent = await service.getRecentCities();

      expect(recent.length, 5);
      // Most recent should be first
      expect(recent[0].name, 'City 6');
    });

    test('moves existing city to top', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      final paris = CitySearchResult(
        name: 'Paris',
        country: 'France',
        latitude: 48.85,
        longitude: 2.35,
      );
      final berlin = CitySearchResult(
        name: 'Berlin',
        country: 'Germany',
        latitude: 52.52,
        longitude: 13.405,
      );

      await service.addRecentCity(paris);
      await service.addRecentCity(berlin);
      await service.addRecentCity(paris); // Add Paris again

      final recent = await service.getRecentCities();

      expect(recent.length, 2);
      expect(recent[0].name, 'Paris'); // Paris should be first now
      expect(recent[1].name, 'Berlin');
    });

    test('returns empty list when no recent cities', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      final recent = await service.getRecentCities();

      expect(recent, isEmpty);
    });
  });

  group('LocationService saved location', () {
    test('saves and retrieves manual location', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      await service.saveLocation(48.85, 2.35, city: 'Paris');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('saved_latitude'), 48.85);
      expect(prefs.getDouble('saved_longitude'), 2.35);
      expect(prefs.getString('saved_city'), 'Paris');
      expect(prefs.getBool('use_gps'), false);
    });

    test('useGpsLocation sets GPS flag', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      await service.useGpsLocation();

      expect(await service.isUsingGps(), isTrue);
    });

    test('saveLocation disables GPS', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      await service.useGpsLocation();
      expect(await service.isUsingGps(), isTrue);

      await service.saveLocation(0, 0);
      expect(await service.isUsingGps(), isFalse);
    });
  });

  group('Default location constants', () {
    test('default latitude is Berlin', () {
      expect(kDefaultLatitude, closeTo(52.52, 0.01));
    });

    test('default longitude is Berlin', () {
      expect(kDefaultLongitude, closeTo(13.405, 0.01));
    });

    test('default city is Berlin', () {
      expect(kDefaultCity, 'Berlin');
    });
  });

  group('LocationService retry with fallback language', () {
    test('retries with default language when detected language returns no results', () async {
      int requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount++;

        // First request (detected language) returns no results
        if (requestCount == 1) {
          return utf8Response(jsonEncode({'results': null}), 200);
        }

        // Second request (fallback to device language) returns results
        return utf8Response(
          jsonEncode({
            'results': [
              {
                'name': 'Kyiv',
                'country': 'Ukraine',
                'latitude': 50.45,
                'longitude': 30.52,
              }
            ]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);

      // Search with Ukrainian text, passing 'en' as device language
      final results = await service.searchCities('Київ', language: 'en');

      // Should have made 2 requests (detected 'uk', then fallback to 'en')
      expect(requestCount, 2);
      expect(results.length, 1);
      expect(results[0].name, 'Kyiv');
    });
  });

  group('LocationService error handling', () {
    test('filters out results with null name', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'name': null,  // Invalid - null name
                'country': 'Test',
                'latitude': 50.0,
                'longitude': 10.0,
              },
              {
                'name': 'Valid City',  // Valid result
                'country': 'Test',
                'latitude': 51.0,
                'longitude': 11.0,
              }
            ]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('test');

      // Should filter out invalid result, keep only valid one
      expect(results.length, 1);
      expect(results[0].name, 'Valid City');
    });

    test('filters out results with null coordinates', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'name': 'Invalid City',
                'country': 'Test',
                'latitude': null,  // Invalid coordinates
                'longitude': null,
              },
              {
                'name': 'Valid City',
                'country': 'Test',
                'latitude': 51.0,
                'longitude': 11.0,
              }
            ]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('test');

      // Should filter out result with null coordinates
      expect(results.length, 1);
      expect(results[0].name, 'Valid City');
      expect(results[0].latitude, 51.0);
      expect(results[0].longitude, 11.0);
    });

    test('returns empty list when all results are invalid', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {'name': null, 'latitude': 0.0, 'longitude': 0.0},
              {'name': 'Test', 'latitude': null, 'longitude': 0.0},
            ]
          }),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCities('test');

      // All results invalid - should return empty list
      expect(results, isEmpty);
    });
  });

  group('LocationService dispose', () {
    test('closes HTTP client', () async {
      final service = LocationService(client: MockClient((r) async => http.Response('', 200)));

      // Should not throw
      service.dispose();
      // If we got here without exception, the test passes
    });
  });
}

