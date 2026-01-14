import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meteogram_widget/models/weather_data.dart';
import 'package:meteogram_widget/services/svg_chart_generator.dart';

/// Golden tests for SVG chart output.
///
/// These tests verify that the SVG generator produces consistent output.
/// To update golden files after intentional changes, run:
///   flutter test --update-goldens test/svg_chart_golden_test.dart
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en_US');
  });

  /// Create deterministic test data for golden tests.
  /// Uses fixed timestamps and predictable weather values.
  List<HourlyData> createGoldenTestData() {
    // Use a fixed base time for reproducible output
    final baseTime = DateTime.utc(2024, 6, 15, 6, 0); // 6:00 AM UTC

    return List.generate(52, (i) {
      return HourlyData(
        time: baseTime.add(Duration(hours: i)),
        // Temperature: sinusoidal pattern 15-25°C
        temperature: 20.0 + 5.0 * _sin((i - 6) * 3.14159 / 12),
        // Precipitation: some hours have rain
        precipitation: (i >= 20 && i <= 28) ? 2.0 + (i - 20) * 0.5 : 0.0,
        // Cloud cover: gradual increase
        cloudCover: ((i * 2) % 100).clamp(0, 100),
      );
    });
  }

  group('SVG Chart Golden Tests', () {
    late SvgChartGenerator generator;
    late List<HourlyData> testData;

    setUp(() {
      generator = SvgChartGenerator();
      testData = createGoldenTestData();
    });

    test('light theme SVG matches golden', () async {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6, // Current time at index 6
        latitude: 52.52, // Berlin
        colors: SvgChartColors.light,
        width: 800.0,
        height: 400.0,
        locale: 'en_US',
        usesFahrenheit: false,
      );

      await _compareGolden(svg, 'chart_light.svg');
    });

    test('dark theme SVG matches golden', () async {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.dark,
        width: 800.0,
        height: 400.0,
        locale: 'en_US',
        usesFahrenheit: false,
      );

      await _compareGolden(svg, 'chart_dark.svg');
    });

    test('fahrenheit SVG matches golden', () async {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 37.77, // San Francisco
        colors: SvgChartColors.light,
        width: 800.0,
        height: 400.0,
        locale: 'en_US',
        usesFahrenheit: true,
      );

      await _compareGolden(svg, 'chart_fahrenheit.svg');
    });

    test('widget dimensions SVG matches golden', () async {
      // Typical widget dimensions
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 1000.0,
        height: 500.0,
        locale: 'en_US',
        usesFahrenheit: false,
      );

      await _compareGolden(svg, 'chart_widget.svg');
    });

    test('no past fade SVG matches golden', () async {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800.0,
        height: 400.0,
        locale: 'en_US',
        usesFahrenheit: false,
        usePastFade: false,
      );

      await _compareGolden(svg, 'chart_no_fade.svg');
    });
  });
}

/// Simple sine approximation for deterministic test data.
double _sin(double x) {
  // Normalize to [-pi, pi]
  while (x > 3.14159) {
    x -= 2 * 3.14159;
  }
  while (x < -3.14159) {
    x += 2 * 3.14159;
  }

  // Taylor series approximation
  final x2 = x * x;
  return x * (1 - x2 / 6 + x2 * x2 / 120);
}

/// Compare SVG output against golden file.
Future<void> _compareGolden(String actual, String goldenFileName) async {
  final goldenPath = 'test/goldens/$goldenFileName';
  final goldenFile = File(goldenPath);

  // Check if we're updating goldens
  final updateGoldens = Platform.environment['UPDATE_GOLDENS'] == 'true' ||
      autoUpdateGoldenFiles;

  if (updateGoldens || !goldenFile.existsSync()) {
    // Create/update golden file
    await goldenFile.writeAsString(actual);
    return;
  }

  // Compare against existing golden
  final expected = await goldenFile.readAsString();

  // Normalize line endings for cross-platform comparison
  final normalizedActual = actual.replaceAll('\r\n', '\n');
  final normalizedExpected = expected.replaceAll('\r\n', '\n');

  expect(
    normalizedActual,
    normalizedExpected,
    reason: 'SVG output does not match golden file: $goldenPath\n'
        'Run with --update-goldens to update.',
  );
}
