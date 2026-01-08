import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Renders SVG to bitmap using native platform renderer (AndroidSVG on Android).
/// This ensures exact visual match between widget and app.
class NativeSvgRenderer {
  static const _channel = MethodChannel('org.bortnik.meteogram/svg');

  /// Render SVG string to PNG bitmap bytes.
  /// Returns null if rendering fails.
  static Future<Uint8List?> renderSvgToPng({
    required String svgString,
    required int width,
    required int height,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('renderSvg', {
        'svg': svgString,
        'width': width,
        'height': height,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Native SVG render error: ${e.message}');
      return null;
    }
  }
}
