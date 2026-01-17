import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Service for updating the home screen widget.
///
/// Note: SVG generation and weather fetching are handled natively in Kotlin.
/// This service only handles widget metadata updates and triggering refreshes.
class WidgetService {
  static const _androidWidgetName = 'MeteogramWidgetProvider';
  static const _iosWidgetName = 'MeteogramWidget';

  /// Trigger a native widget update.
  /// The native code will generate SVGs from cached weather data.
  Future<void> triggerWidgetUpdate() async {
    try {
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
      debugPrint('Triggered native widget update');
    } catch (e) {
      debugPrint('Error triggering widget update: $e');
    }
  }

  /// Initialize widget service.
  static Future<void> initialize() async {
    // Set app group ID for iOS
    await HomeWidget.setAppGroupId('group.org.bortnik.meteogram');
  }

  /// Check if widget was resized and clear the flag.
  /// Returns true if widget needs re-rendering.
  Future<bool> checkAndClearResizeFlag() async {
    try {
      final resized = await HomeWidget.getWidgetData<bool>('widget_resized');
      if (resized == true) {
        await HomeWidget.saveWidgetData<bool>('widget_resized', false);
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
