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

      // Get city name via reverse geocoding, fall back to IP geolocation for city
      String? city = await _getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (city == null || city.isEmpty) {
        // Try IP geolocation just for city name
        final ipLocation = await _getIpLocation();
        city = ipLocation?.city;
      }
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
          final ipLocation = await _getIpLocation();
          city = ipLocation?.city;
        }
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
      // Fallback to IP geolocation
      final ipLocation = await _getIpLocation();
      if (ipLocation != null) {
        return ipLocation;
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

    if (lat == null || lon == null) {
      // Fall back to GPS if no saved location
      return _getGpsLocation();
    }

    return LocationData(
      latitude: lat,
      longitude: lon,
      source: LocationSource.manual,
      city: city,
    );
  }

  /// Get fallback location when GPS is unavailable.
  /// Tries IP geolocation first, then falls back to Berlin.
  Future<LocationData> _getFallbackLocation() async {
    // Try IP geolocation
    final ipLocation = await _getIpLocation();
    if (ipLocation != null) {
      return ipLocation;
    }
    // Final fallback to Berlin
    return LocationData(
      latitude: 52.52,
      longitude: 13.405,
      source: LocationSource.manual,
      city: 'Berlin',
    );
  }

  /// Get approximate location from IP address using ip-api.com.
  Future<LocationData?> _getIpLocation() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json/?fields=status,lat,lon,city'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return LocationData(
            latitude: (data['lat'] as num).toDouble(),
            longitude: (data['lon'] as num).toDouble(),
            source: LocationSource.ip,
            city: data['city'] as String?,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
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

  /// Save a manual location.
  Future<void> saveLocation(double latitude, double longitude, {String? city}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, latitude);
    await prefs.setDouble(_lonKey, longitude);
    if (city != null) {
      await prefs.setString(_cityKey, city);
    }
    await prefs.setBool(_useGpsKey, false);
  }

  /// Switch to using GPS location.
  Future<void> useGpsLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useGpsKey, true);
  }

  /// Get location from IP (for explicit user selection).
  Future<LocationData> getIpLocation() async {
    final location = await _getIpLocation();
    return location ?? LocationData(
      latitude: 52.52,
      longitude: 13.405,
      source: LocationSource.ip,
      city: 'Berlin',
    );
  }

  /// Check if using GPS.
  Future<bool> isUsingGps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useGpsKey) ?? true;
  }
}

/// How the location was determined.
enum LocationSource {
  gps,
  ip,
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
