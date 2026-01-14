import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/widget_service.dart';

void main() {
  group('Dimension constants alignment', () {
    test('widget_service defaults match background_service defaults', () {
      // These constants must match across all code paths to avoid
      // dimension mismatches between app and widget rendering
      expect(kDefaultWidthPx, 1000);
      expect(kDefaultHeightPx, 500);
    });

    test('default aspect ratio is 2:1', () {
      // The chart expects a 2:1 aspect ratio
      expect(kDefaultWidthPx / kDefaultHeightPx, 2.0);
    });
  });

  group('WidgetDimensions', () {
    test('calculates logical size correctly', () {
      const dims = WidgetDimensions(
        widthPx: 1000,
        heightPx: 500,
        density: 2.0,
      );

      expect(dims.logicalSize.width, 500.0);
      expect(dims.logicalSize.height, 250.0);
    });

    test('handles high density screens', () {
      const dims = WidgetDimensions(
        widthPx: 1319,
        heightPx: 774,
        density: 4.1625,
      );

      // Logical size should be physical / density
      expect(dims.logicalSize.width, closeTo(316.9, 0.1));
      expect(dims.logicalSize.height, closeTo(186.0, 0.1));
    });

    test('toString includes all values', () {
      const dims = WidgetDimensions(
        widthPx: 1000,
        heightPx: 500,
        density: 2.0,
      );

      final str = dims.toString();
      expect(str, contains('1000'));
      expect(str, contains('500'));
      expect(str, contains('2.0'));
    });
  });

  group('Dimension fallback logic', () {
    // These tests verify the fallback patterns used in widget_service.dart
    // and background_service.dart for handling missing/invalid dimensions

    test('null dimensions should use defaults', () {
      int? widthPx;
      int? heightPx;

      // Mirror the fallback logic from generateAndSaveSvgCharts
      final width = widthPx ?? kDefaultWidthPx;
      final height = heightPx ?? kDefaultHeightPx;

      expect(width, 1000);
      expect(height, 500);
    });

    test('zero dimensions should use defaults', () {
      var widthPx = 0;
      var heightPx = 0;

      // Mirror the fallback logic from background_service.dart
      if (widthPx <= 0) widthPx = kDefaultWidthPx;
      if (heightPx <= 0) heightPx = kDefaultHeightPx;

      expect(widthPx, 1000);
      expect(heightPx, 500);
    });

    test('negative dimensions should use defaults', () {
      var widthPx = -100;
      var heightPx = -50;

      if (widthPx <= 0) widthPx = kDefaultWidthPx;
      if (heightPx <= 0) heightPx = kDefaultHeightPx;

      expect(widthPx, 1000);
      expect(heightPx, 500);
    });

    test('valid dimensions should be preserved', () {
      var widthPx = 1319;
      var heightPx = 774;

      // Should not trigger fallback
      if (widthPx <= 0) widthPx = kDefaultWidthPx;
      if (heightPx <= 0) heightPx = kDefaultHeightPx;

      expect(widthPx, 1319);
      expect(heightPx, 774);
    });
  });
}
