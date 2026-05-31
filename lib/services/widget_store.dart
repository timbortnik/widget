import 'package:flutter/services.dart';

/// Key-value bridge to the shared `HomeWidgetPreferences` SharedPreferences file,
/// plus a widget-refresh trigger. Replaces the `home_widget` package's storage +
/// `updateWidget` surface (the only parts this app used) over our existing native
/// method channel — see [MainActivity] `getWidgetData`/`saveWidgetData`/`updateWidget`.
///
/// The native side replicates `home_widget`'s exact serialization (a companion
/// `home_widget.double.<key>` flag and `doubleToRawLongBits` for doubles), so data
/// written by earlier `home_widget`-backed installs is preserved across upgrade.
class WidgetStore {
  WidgetStore._();

  static const _channel = MethodChannel('org.bortnik.meteogram/svg');

  /// Reads the value stored under [key], or null if absent.
  static Future<T?> getWidgetData<T>(String key) {
    return _channel.invokeMethod<T>('getWidgetData', {'id': key});
  }

  /// Persists [value] under [key]. A null value removes the key.
  /// Returns true if the write committed successfully.
  static Future<bool> saveWidgetData<T>(String key, T? value) async {
    final committed = await _channel.invokeMethod<bool>('saveWidgetData', {
      'id': key,
      'data': value,
    });
    return committed ?? false;
  }

  /// Triggers a native refresh of the given Android widget provider by sending
  /// an `ACTION_APPWIDGET_UPDATE` broadcast. [iOSName] is accepted for call-site
  /// compatibility and ignored (this is an Android-only app).
  static Future<void> updateWidget({String? androidName, String? iOSName}) async {
    if (androidName == null) return;
    await _channel.invokeMethod<bool>('updateWidget', {'name': androidName});
  }
}
