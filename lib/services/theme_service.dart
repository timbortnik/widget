import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's in-app theme preference (System / Light / Dark).
///
/// The choice drives both the in-app UI and the home-screen widget, so it is
/// written to app-side [SharedPreferences] (for fast startup load) and mirrored
/// to [HomeWidget] storage (`HomeWidgetPreferences`) where the native widget
/// provider reads it to match the app's theme.
class ThemeService {
  /// SharedPreferences key holding the serialized [ThemeMode].
  static const String _prefKey = 'theme_mode';

  static const String _system = 'system';
  static const String _light = 'light';
  static const String _dark = 'dark';

  /// Loads the saved theme mode, defaulting to [ThemeMode.system].
  Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _fromString(prefs.getString(_prefKey));
  }

  /// Persists [mode] for future launches and mirrors it to the widget store.
  Future<void> save(ThemeMode mode) async {
    final value = _toString(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value);
    // Mirror to HomeWidgetPreferences so the native widget provider can match.
    await HomeWidget.saveWidgetData<String>(_prefKey, value);
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case _light:
        return ThemeMode.light;
      case _dark:
        return ThemeMode.dark;
      case _system:
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _light;
      case ThemeMode.dark:
        return _dark;
      case ThemeMode.system:
        return _system;
    }
  }
}
