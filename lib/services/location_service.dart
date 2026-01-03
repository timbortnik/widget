import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for getting device location.
class LocationService {
  static const String _latKey = 'saved_latitude';
  static const String _lonKey = 'saved_longitude';
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

  /// Get location from GPS.
  Future<LocationData> _getGpsLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled.');
    }

    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission permanently denied. Please enable in settings.',
      );
    }

    // Get position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      isGps: true,
    );
  }

  /// Get saved location from preferences.
  Future<LocationData> _getSavedLocation(SharedPreferences prefs) async {
    final lat = prefs.getDouble(_latKey);
    final lon = prefs.getDouble(_lonKey);

    if (lat == null || lon == null) {
      // Fall back to GPS if no saved location
      return _getGpsLocation();
    }

    return LocationData(
      latitude: lat,
      longitude: lon,
      isGps: false,
    );
  }

  /// Save a manual location.
  Future<void> saveLocation(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, latitude);
    await prefs.setDouble(_lonKey, longitude);
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
}

/// Location data.
class LocationData {
  final double latitude;
  final double longitude;
  final bool isGps;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.isGps,
  });
}

/// Exception thrown when location cannot be determined.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
