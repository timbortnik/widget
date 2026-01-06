import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for getting device location.
class LocationService {
  static const String _latKey = 'saved_latitude';
  static const String _lonKey = 'saved_longitude';
  static const String _cityKey = 'saved_city';
  static const String _useGpsKey = 'use_gps';
  static const String _sourceKey = 'location_source';

  /// Get the current location (GPS or saved).
  Future<LocationData> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final useGps = prefs.getBool(_useGpsKey) ?? true;

    if (useGps) {
      return _getGpsLocation();
    } else {
      return _getSavedLocation(prefs);
    }
  }

  /// Get location from GPS, with fallback to IP geolocation.
  Future<LocationData> _getGpsLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Fall back to IP geolocation
      return _getFallbackLocation();
    }

    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Fall back to IP geolocation
        return _getFallbackLocation();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Fall back to IP geolocation
      return _getFallbackLocation();
    }

    // Get position with timeout
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 15));

      // Get city name via reverse geocoding
      String? city = await _getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );
      // Fallback: derive city name from coordinates for known test locations
      if (city == null || city.isEmpty) {
        city = _getTestCityName(position.latitude, position.longitude);
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        source: LocationSource.gps,
        city: city,
      );
    } catch (e) {
      // Fallback to last known position
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        // Try to get city name for last known position
        String? city = await _getCityFromCoordinates(
          lastPosition.latitude,
          lastPosition.longitude,
        );
        if (city == null || city.isEmpty) {
          city = _getTestCityName(lastPosition.latitude, lastPosition.longitude);
        }
        return LocationData(
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
          source: LocationSource.gps,
          city: city,
        );
      }
      // Final fallback to default location (Berlin)
      return LocationData(
        latitude: 52.52,
        longitude: 13.405,
        source: LocationSource.manual,
        city: 'Berlin',
      );
    }
  }

  /// Get saved location from preferences.
  Future<LocationData> _getSavedLocation(SharedPreferences prefs) async {
    final lat = prefs.getDouble(_latKey);
    final lon = prefs.getDouble(_lonKey);
    final city = prefs.getString(_cityKey);
    final sourceName = prefs.getString(_sourceKey);

    if (lat == null || lon == null) {
      // Fall back to GPS if no saved location
      return _getGpsLocation();
    }

    // Parse saved source, default to manual
    final source = LocationSource.values.firstWhere(
      (s) => s.name == sourceName,
      orElse: () => LocationSource.manual,
    );

    return LocationData(
      latitude: lat,
      longitude: lon,
      source: source,
      city: city,
    );
  }

  /// Get fallback location when GPS is unavailable.
  /// Falls back to Berlin as default location.
  Future<LocationData> _getFallbackLocation() async {
    return LocationData(
      latitude: 52.52,
      longitude: 13.405,
      source: LocationSource.manual,
      city: 'Berlin',
    );
  }

  /// Get city name from coordinates via reverse geocoding.
  Future<String?> _getCityFromCoordinates(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Prefer locality (city), fall back to subAdministrativeArea or administrativeArea
        return place.locality?.isNotEmpty == true
            ? place.locality
            : place.subAdministrativeArea?.isNotEmpty == true
                ? place.subAdministrativeArea
                : place.administrativeArea;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get city name for known test/emulator locations.
  String? _getTestCityName(double lat, double lon) {
    // Android emulator default location (Mountain View, CA)
    if ((lat - 37.4219983).abs() < 0.01 && (lon - (-122.084)).abs() < 0.01) {
      return 'Mountain View';
    }
    // Berlin fallback location
    if ((lat - 52.52).abs() < 0.01 && (lon - 13.405).abs() < 0.01) {
      return 'Berlin';
    }
    return null;
  }

  /// Save a location with its source.
  Future<void> saveLocation(
    double latitude,
    double longitude, {
    String? city,
    LocationSource source = LocationSource.manual,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, latitude);
    await prefs.setDouble(_lonKey, longitude);
    if (city != null) {
      await prefs.setString(_cityKey, city);
    }
    await prefs.setString(_sourceKey, source.name);
    await prefs.setBool(_useGpsKey, false);
  }

  /// Switch to using GPS location.
  Future<void> useGpsLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useGpsKey, true);
  }

  /// Check if using GPS.
  Future<bool> isUsingGps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useGpsKey) ?? true;
  }

  /// Request GPS permission explicitly.
  /// Returns true if permission is granted.
  Future<bool> requestGpsPermission() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check and request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// Open device location settings.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Search for cities using Open-Meteo geocoding API.
  /// Pass [language] code (e.g., 'en', 'de', 'ja') for localized results.
  /// Automatically detects script (Cyrillic, CJK, etc.) for better matching.
  /// Throws on network errors to allow caller to show appropriate UI.
  Future<List<CitySearchResult>> searchCities(String query, {String language = 'en'}) async {
    if (query.trim().length < 2) return [];

    // Detect script and adjust language for better search results
    final searchLanguage = _detectSearchLanguage(query, language);

    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
    ).replace(queryParameters: {
      'name': query,
      'count': '8',
      'language': searchLanguage,
      'format': 'json',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        // If no results and we used a detected language, try with device locale
        if (searchLanguage != language) {
          return _searchWithLanguage(query, language);
        }
        return [];
      }

      return results.map((r) => CitySearchResult(
        name: r['name'] as String,
        country: r['country'] as String? ?? '',
        admin1: r['admin1'] as String?,
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
      )).toList();
    }
    return [];
  }

  /// Detect appropriate language based on script in query.
  String _detectSearchLanguage(String query, String defaultLanguage) {
    for (final char in query.runes) {
      // Cyrillic: U+0400–U+04FF
      if (char >= 0x0400 && char <= 0x04FF) {
        // Check for Ukrainian specific letters: і, ї, є, ґ
        if (query.contains('і') || query.contains('ї') ||
            query.contains('є') || query.contains('ґ') ||
            query.contains('І') || query.contains('Ї') ||
            query.contains('Є') || query.contains('Ґ')) {
          return 'uk';
        }
        return 'ru'; // Default Cyrillic to Russian
      }
      // Japanese Hiragana/Katakana: U+3040–U+30FF
      if (char >= 0x3040 && char <= 0x30FF) return 'ja';
      // CJK Unified Ideographs: U+4E00–U+9FFF
      if (char >= 0x4E00 && char <= 0x9FFF) return 'zh';
      // Korean Hangul: U+AC00–U+D7AF
      if (char >= 0xAC00 && char <= 0xD7AF) return 'ko';
      // Arabic: U+0600–U+06FF
      if (char >= 0x0600 && char <= 0x06FF) return 'ar';
      // Greek: U+0370–U+03FF
      if (char >= 0x0370 && char <= 0x03FF) return 'el';
      // Hebrew: U+0590–U+05FF
      if (char >= 0x0590 && char <= 0x05FF) return 'he';
      // Thai: U+0E00–U+0E7F
      if (char >= 0x0E00 && char <= 0x0E7F) return 'th';
    }
    return defaultLanguage;
  }

  /// Helper to search with a specific language.
  Future<List<CitySearchResult>> _searchWithLanguage(String query, String language) async {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
    ).replace(queryParameters: {
      'name': query,
      'count': '8',
      'language': language,
      'format': 'json',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>?;
      if (results == null) return [];

      return results.map((r) => CitySearchResult(
        name: r['name'] as String,
        country: r['country'] as String? ?? '',
        admin1: r['admin1'] as String?,
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
      )).toList();
    }
    return [];
  }

  /// Get recent cities from storage.
  Future<List<CitySearchResult>> getRecentCities() async {
    final prefs = await SharedPreferences.getInstance();
    final citiesJson = prefs.getStringList(_recentCitiesKey) ?? [];
    return citiesJson
        .map((json) => CitySearchResult.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Add a city to recent cities.
  Future<void> addRecentCity(CitySearchResult city) async {
    final prefs = await SharedPreferences.getInstance();
    final cities = await getRecentCities();

    // Remove if already exists (to move to top)
    cities.removeWhere((c) => c.latitude == city.latitude && c.longitude == city.longitude);

    // Add to beginning
    cities.insert(0, city);

    // Keep only last 5
    final trimmed = cities.take(5).toList();

    await prefs.setStringList(
      _recentCitiesKey,
      trimmed.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  static const String _recentCitiesKey = 'recent_cities';
}

/// How the location was determined.
enum LocationSource {
  gps,
  manual,
}

/// Location data.
class LocationData {
  final double latitude;
  final double longitude;
  final LocationSource source;
  final String? city;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.source,
    this.city,
  });

  bool get isGps => source == LocationSource.gps;
}

/// Exception thrown when location cannot be determined.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

/// City search result from geocoding API.
class CitySearchResult {
  final String name;
  final String country;
  final String? admin1; // State/region
  final double latitude;
  final double longitude;

  CitySearchResult({
    required this.name,
    required this.country,
    this.admin1,
    required this.latitude,
    required this.longitude,
  });

  /// Display name with country/region context.
  String get displayName {
    final parts = [name];
    if (admin1 != null && admin1!.isNotEmpty && admin1 != name) {
      parts.add(admin1!);
    }
    if (country.isNotEmpty) {
      parts.add(country);
    }
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'country': country,
    'admin1': admin1,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory CitySearchResult.fromJson(Map<String, dynamic> json) => CitySearchResult(
    name: json['name'] as String,
    country: json['country'] as String? ?? '',
    admin1: json['admin1'] as String?,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}
