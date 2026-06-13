import 'dart:convert';
import 'package:http/http.dart' as http;

import 'location_bridge.dart';
import 'native_svg_service.dart';
import 'widget_store.dart';

/// Default fallback location (Berlin) when GPS is unavailable.
const double kDefaultLatitude = 52.52;
const double kDefaultLongitude = 13.405;
const String kDefaultCity = 'Berlin';

/// Service for getting device location.
class LocationService {
  static const String _latKey = 'saved_latitude';
  static const String _lonKey = 'saved_longitude';
  static const String _cityKey = 'saved_city';
  static const String _useGpsKey = 'use_gps';
  static const String _sourceKey = 'location_source';

  // Last location successfully resolved from GPS. Kept separate from the manual
  // [_latKey]/[_lonKey] so a revoked permission / disabled service / cold-start
  // timeout falls back here (the user's real location) instead of Berlin.
  static const String _lastGpsLatKey = 'last_gps_latitude';
  static const String _lastGpsLonKey = 'last_gps_longitude';
  static const String _lastGpsCityKey = 'last_gps_city';

  /// HTTP client for making requests. Defaults to standard client.
  final http.Client _client;

  /// Create a LocationService with optional custom HTTP client.
  LocationService({http.Client? client}) : _client = client ?? http.Client();

  /// Get the current location (GPS or saved).
  Future<LocationData> getLocation() async {
    final useGps = await WidgetStore.getWidgetData<bool>(_useGpsKey) ?? true;
    if (useGps) {
      return _getGpsLocation();
    }
    // Fall back to GPS if no manual location is stored.
    return await getSavedLocationFromWidget() ?? _getGpsLocation();
  }

  /// Get location from GPS. When no fresh fix is available (services off,
  /// permission revoked, or timeout) it reuses the last GPS location we
  /// resolved, and only falls back to the default (Berlin) if we never had one.
  Future<LocationData> _getGpsLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await LocationBridge.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _lastGpsOrFallback();
    }

    // Check permission, prompting once if it's merely denied
    var permission = await LocationBridge.checkPermission();
    if (permission == LocationPermissionStatus.denied) {
      permission = await LocationBridge.requestPermission();
    }
    if (permission != LocationPermissionStatus.granted) {
      // denied or deniedForever
      return _lastGpsOrFallback();
    }

    // Current position (native one-shot, low accuracy, 15s timeout). Returns null
    // on timeout/failure rather than throwing.
    final position = await LocationBridge.getCurrentPosition(timeoutMs: 15000);
    if (position != null) {
      return _toLocationData(position.latitude, position.longitude);
    }

    // Fallback to last known position
    final lastPosition = await LocationBridge.getLastKnownPosition();
    if (lastPosition != null) {
      return _toLocationData(lastPosition.latitude, lastPosition.longitude);
    }

    // No fresh fix: prefer the last GPS location over the Berlin default.
    return _lastGpsOrFallback();
  }

  /// Prefer the last GPS location we successfully resolved; otherwise the
  /// default (Berlin). Used whenever a fresh GPS fix can't be obtained so a
  /// transient outage doesn't bounce the user (and the widget cache) to Berlin.
  Future<LocationData> _lastGpsOrFallback() async {
    return await _getLastGpsLocation() ?? await _getFallbackLocation();
  }

  /// Build a GPS [LocationData], resolving a city name via reverse geocoding
  /// (with a test-location fallback for the emulator/Berlin).
  Future<LocationData> _toLocationData(double latitude, double longitude) async {
    String? city = await _getCityFromCoordinates(latitude, longitude);
    if (city == null || city.isEmpty) {
      city = _getTestCityName(latitude, longitude);
    }
    // Remember this fix so a later GPS outage can reuse it instead of Berlin.
    await _saveLastGpsLocation(latitude, longitude, city);
    return LocationData(
      latitude: latitude,
      longitude: longitude,
      source: LocationSource.gps,
      city: city,
    );
  }

  /// Persist the most recent GPS-resolved location to the shared widget store.
  Future<void> _saveLastGpsLocation(double latitude, double longitude, String? city) async {
    await WidgetStore.saveWidgetData<double>(_lastGpsLatKey, latitude);
    await WidgetStore.saveWidgetData<double>(_lastGpsLonKey, longitude);
    if (city != null && city.isNotEmpty) {
      await WidgetStore.saveWidgetData<String>(_lastGpsCityKey, city);
    }
  }

  /// Read the last GPS-resolved location, or null if none has been stored yet.
  Future<LocationData?> _getLastGpsLocation() async {
    final lat = await WidgetStore.getWidgetData<double>(_lastGpsLatKey);
    final lon = await WidgetStore.getWidgetData<double>(_lastGpsLonKey);
    if (lat == null || lon == null) {
      return null;
    }
    final city = await WidgetStore.getWidgetData<String>(_lastGpsCityKey);
    return LocationData(
      latitude: lat,
      longitude: lon,
      source: LocationSource.gps,
      city: city,
    );
  }

  /// Get fallback location when GPS is unavailable.
  Future<LocationData> _getFallbackLocation() async {
    return LocationData(
      latitude: kDefaultLatitude,
      longitude: kDefaultLongitude,
      source: LocationSource.manual,
      city: kDefaultCity,
    );
  }

  /// Get city name from coordinates via native platform reverse geocoding.
  ///
  /// Uses the native android.location.Geocoder through our method channel
  /// (NativeSvgService.reverseGeocode), which already prefers
  /// locality -> subAdminArea -> adminArea and returns null on failure.
  Future<String?> _getCityFromCoordinates(double lat, double lon) async {
    try {
      return await NativeSvgService.reverseGeocode(latitude: lat, longitude: lon)
          .timeout(const Duration(seconds: 5));
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
    if ((lat - kDefaultLatitude).abs() < 0.01 && (lon - kDefaultLongitude).abs() < 0.01) {
      return kDefaultCity;
    }
    return null;
  }

  /// Save a location with its source.
  /// Persisted to the shared widget store (read by both the app and the native widget).
  Future<void> saveLocation(
    double latitude,
    double longitude, {
    String? city,
    LocationSource source = LocationSource.manual,
  }) async {
    await WidgetStore.saveWidgetData<double>(_latKey, latitude);
    await WidgetStore.saveWidgetData<double>(_lonKey, longitude);
    if (city != null) {
      await WidgetStore.saveWidgetData<String>(_cityKey, city);
    }
    await WidgetStore.saveWidgetData<String>(_sourceKey, source.name);
    await WidgetStore.saveWidgetData<bool>(_useGpsKey, false);
  }

  /// Switch to using GPS location.
  /// Persisted to the shared widget store (read by both the app and the native widget).
  Future<void> useGpsLocation() async {
    await WidgetStore.saveWidgetData<bool>(_useGpsKey, true);
    await WidgetStore.saveWidgetData<String>(_sourceKey, LocationSource.gps.name);
  }

  /// Check if using GPS.
  Future<bool> isUsingGps() async {
    return await WidgetStore.getWidgetData<bool>(_useGpsKey) ?? true;
  }

  /// Get saved location from the shared widget store (for background service).
  /// Returns null if no location is saved or if using GPS.
  /// This is more reliable than SharedPreferences in background isolates.
  Future<LocationData?> getSavedLocationFromWidget() async {
    final useGps = await WidgetStore.getWidgetData<bool>(_useGpsKey) ?? true;
    if (useGps) {
      return null; // GPS mode, no saved location
    }

    final lat = await WidgetStore.getWidgetData<double>(_latKey);
    final lon = await WidgetStore.getWidgetData<double>(_lonKey);
    final city = await WidgetStore.getWidgetData<String>(_cityKey);
    final sourceName = await WidgetStore.getWidgetData<String>(_sourceKey);

    if (lat == null || lon == null) {
      return null;
    }

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

  /// Request GPS permission explicitly.
  /// Returns true if permission is granted.
  Future<bool> requestGpsPermission() async {
    // Check if location services are enabled
    final serviceEnabled = await LocationBridge.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check and request permission
    var permission = await LocationBridge.checkPermission();
    if (permission == LocationPermissionStatus.denied) {
      permission = await LocationBridge.requestPermission();
    }

    return permission == LocationPermissionStatus.granted;
  }

  /// Open device location settings.
  Future<void> openLocationSettings() async {
    await LocationBridge.openLocationSettings();
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

    final response = await _client.get(uri).timeout(const Duration(seconds: 5));

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

      return results
        .where((r) {
          // Filter out invalid results (missing required fields)
          return r['name'] != null &&
                 r['latitude'] != null &&
                 r['longitude'] != null;
        })
        .map((r) => CitySearchResult(
          name: r['name'] as String,
          country: (r['country'] as String?) ?? '',
          admin1: r['admin1'] as String?,
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
        ))
        .toList();
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

    final response = await _client.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>?;
      if (results == null) return [];

      return results
        .where((r) {
          // Filter out invalid results (missing required fields)
          return r['name'] != null &&
                 r['latitude'] != null &&
                 r['longitude'] != null;
        })
        .map((r) => CitySearchResult(
          name: r['name'] as String,
          country: (r['country'] as String?) ?? '',
          admin1: r['admin1'] as String?,
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
        ))
        .toList();
    }
    return [];
  }

  /// Get recent cities from the shared widget store (a JSON-encoded list).
  /// Returns [] if the stored data is missing or malformed (rather than throwing),
  /// and silently skips any individual entries that don't parse.
  Future<List<CitySearchResult>> getRecentCities() async {
    final raw = await WidgetStore.getWidgetData<String>(_recentCitiesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final cities = <CitySearchResult>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          try {
            cities.add(CitySearchResult.fromJson(entry));
          } catch (_) {
            // Skip a malformed entry rather than dropping the whole list.
          }
        }
      }
      return cities;
    } catch (_) {
      // Malformed JSON — start fresh instead of crashing.
      return [];
    }
  }

  /// Add a city to recent cities.
  Future<void> addRecentCity(CitySearchResult city) async {
    final cities = await getRecentCities();

    // Remove if already exists (to move to top)
    cities.removeWhere((c) => c.latitude == city.latitude && c.longitude == city.longitude);

    // Add to beginning
    cities.insert(0, city);

    // Keep only last 5
    final trimmed = cities.take(5).toList();

    await WidgetStore.saveWidgetData<String>(
      _recentCitiesKey,
      jsonEncode(trimmed.map((c) => c.toJson()).toList()),
    );
  }

  static const String _recentCitiesKey = 'recent_cities';

  /// Dispose of resources (close HTTP client).
  void dispose() {
    _client.close();
  }
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
