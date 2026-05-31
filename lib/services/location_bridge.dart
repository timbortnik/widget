import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Location-permission state (the subset this app needs).
enum LocationPermissionStatus { granted, denied, deniedForever }

/// Native location access over the method channel — replaces the geolocator
/// plugin. Backed by `android.location.LocationManager` (see `LocationProvider.kt`).
///
/// All fixes are foreground-only; the widget's background refresh reuses cached
/// coordinates and never calls these.
class LocationBridge {
  LocationBridge._();

  static const _channel = MethodChannel('org.bortnik.meteogram/svg');

  /// Whether device location services (GPS/network) are enabled.
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isLocationServiceEnabled') ?? false;
    } on PlatformException catch (e) {
      debugPrint('isLocationServiceEnabled failed: ${e.message}');
      return false;
    }
  }

  /// Current location-permission status (no prompt shown).
  static Future<LocationPermissionStatus> checkPermission() async {
    try {
      return _parse(await _channel.invokeMethod<String>('checkLocationPermission'));
    } on PlatformException catch (e) {
      debugPrint('checkLocationPermission failed: ${e.message}');
      return LocationPermissionStatus.denied;
    }
  }

  /// Prompt for location permission; resolves once the user responds.
  static Future<LocationPermissionStatus> requestPermission() async {
    try {
      return _parse(await _channel.invokeMethod<String>('requestLocationPermission'));
    } on PlatformException catch (e) {
      debugPrint('requestLocationPermission failed: ${e.message}');
      return LocationPermissionStatus.denied;
    }
  }

  /// One-shot current location (low accuracy). Null on timeout/failure.
  static Future<({double latitude, double longitude})?> getCurrentPosition({
    int timeoutMs = 15000,
  }) async {
    try {
      return _toPosition(await _channel
          .invokeMapMethod<String, dynamic>('getCurrentPosition', {'timeoutMs': timeoutMs}));
    } on PlatformException catch (e) {
      debugPrint('getCurrentPosition failed: ${e.message}');
      return null;
    }
  }

  /// Most-recent last-known location, or null.
  static Future<({double latitude, double longitude})?> getLastKnownPosition() async {
    try {
      return _toPosition(
          await _channel.invokeMapMethod<String, dynamic>('getLastKnownPosition'));
    } on PlatformException catch (e) {
      debugPrint('getLastKnownPosition failed: ${e.message}');
      return null;
    }
  }

  /// Open the system location-settings screen.
  static Future<void> openLocationSettings() async {
    try {
      await _channel.invokeMethod<bool>('openLocationSettings');
    } on PlatformException catch (e) {
      debugPrint('openLocationSettings failed: ${e.message}');
    }
  }

  static LocationPermissionStatus _parse(String? status) {
    switch (status) {
      case 'granted':
        return LocationPermissionStatus.granted;
      case 'deniedForever':
        return LocationPermissionStatus.deniedForever;
      default:
        return LocationPermissionStatus.denied;
    }
  }

  static ({double latitude, double longitude})? _toPosition(Map<String, dynamic>? r) {
    if (r == null) return null;
    final lat = (r['latitude'] as num?)?.toDouble();
    final lon = (r['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return (latitude: lat, longitude: lon);
  }
}
