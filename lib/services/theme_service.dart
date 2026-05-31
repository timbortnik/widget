import 'package:flutter/material.dart';
import 'widget_store.dart';

/// Persists the user's in-app theme preference (System / Light / Dark).
///
/// The choice drives both the in-app UI and the home-screen widget, so it is
/// stored in [WidgetStore] (`HomeWidgetPreferences`) — the same store the
/// native widget provider reads to match the app's theme.
class ThemeService {
  /// Storage key holding the serialized [ThemeMode].
  static const String _prefKey = 'theme_mode';

  static const String _system = 'system';
  static const String _light = 'light';
  static const String _dark = 'dark';

  /// Loads the saved theme mode, defaulting to [ThemeMode.system].
  Future<ThemeMode> load() async {
    return _fromString(await WidgetStore.getWidgetData<String>(_prefKey));
  }

  /// Persists [mode] for future launches in the shared widget store.
  Future<void> save(ThemeMode mode) async {
    await WidgetStore.saveWidgetData<String>(_prefKey, _toString(mode));
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
