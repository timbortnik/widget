import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'widget_store.dart';

/// Service for updating the home screen widget.
///
/// Note: SVG generation and weather fetching are handled natively in Kotlin.
/// This service only handles widget metadata updates and triggering refreshes.
class WidgetService {
  static const _androidWidgetName = 'MeteogramWidgetProvider';
  static const _androidWeeklyWidgetName = 'MeteogramWeeklyWidgetProvider';
  static const _iosWidgetName = 'MeteogramWidget';
  static const _channel = MethodChannel('org.bortnik.meteogram/svg');

  /// Whether a placed widget can't refresh in the background because the user
  /// set this app's battery usage to "Restricted" (background usage off).
  /// See `WidgetUtils.isWidgetBackgroundRestricted` on the native side.
  ///
  /// False when the check fails: a missing hint is better than a wrong one.
  Future<bool> isBackgroundRestricted() async {
    try {
      return await _channel.invokeMethod<bool>('isWidgetBackgroundRestricted') ?? false;
    } on PlatformException catch (e) {
      debugPrint('isWidgetBackgroundRestricted failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Trigger a native widget update for all provider variants.
  /// The native code will generate SVGs from cached weather data.
  Future<void> triggerWidgetUpdate() async {
    try {
      await WidgetStore.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
      await WidgetStore.updateWidget(androidName: _androidWeeklyWidgetName);
      debugPrint('Triggered native widget update');
    } catch (e) {
      debugPrint('Error triggering widget update: $e');
    }
  }

  /// Check if widget was resized and clear the flag.
  /// Returns true if widget needs re-rendering.
  Future<bool> checkAndClearResizeFlag() async {
    try {
      final resized = await WidgetStore.getWidgetData<bool>('widget_resized');
      if (resized == true) {
        await WidgetStore.saveWidgetData<bool>('widget_resized', false);
        debugPrint('Widget was resized');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking resize flag: $e');
      return false;
    }
  }
}
