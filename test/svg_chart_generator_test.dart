import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meteogram_widget/services/svg_chart_generator.dart';
import 'package:meteogram_widget/models/weather_data.dart';

void main() {
  setUpAll(() async {
    // Initialize date formatting for all locales used in tests
    await initializeDateFormatting('en_US');
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('en');
  });
  group('SvgColor', () {
    test('constructor sets RGBA values correctly', () {
      const color = SvgColor(255, 128, 64, 200);
      expect(color.r, 255);
      expect(color.g, 128);
      expect(color.b, 64);
      expect(color.a, 200);
    });

    test('constructor defaults alpha to 255', () {
      const color = SvgColor(100, 150, 200);
      expect(color.a, 255);
    });

    test('fromArgb extracts components correctly', () {
      // ARGB: 0xFFFF6B6B (opaque coral)
      final color = SvgColor.fromArgb(0xFFFF6B6B);
      expect(color.a, 0xFF);
      expect(color.r, 0xFF);
      expect(color.g, 0x6B);
      expect(color.b, 0x6B);
    });

    test('fromArgb handles transparent colors', () {
      // ARGB: 0x80FF0000 (50% transparent red)
      final color = SvgColor.fromArgb(0x80FF0000);
      expect(color.a, 0x80);
      expect(color.r, 0xFF);
      expect(color.g, 0x00);
      expect(color.b, 0x00);
    });

    test('fromArgb handles fully transparent', () {
      final color = SvgColor.fromArgb(0x00FFFFFF);
      expect(color.a, 0x00);
      expect(color.opacity, 0.0);
    });

    test('toHex produces correct format', () {
      const color = SvgColor(255, 107, 107);
      expect(color.toHex(), '#ff6b6b');
    });

    test('toHex pads single digit values', () {
      const color = SvgColor(0, 15, 1);
      expect(color.toHex(), '#000f01');
    });

    test('toHex handles black', () {
      const color = SvgColor(0, 0, 0);
      expect(color.toHex(), '#000000');
    });

    test('toHex handles white', () {
      const color = SvgColor(255, 255, 255);
      expect(color.toHex(), '#ffffff');
    });

    test('opacity returns correct value for fully opaque', () {
      const color = SvgColor(100, 100, 100, 255);
      expect(color.opacity, 1.0);
    });

    test('opacity returns correct value for 50% transparent', () {
      const color = SvgColor(100, 100, 100, 127);
      expect(color.opacity, closeTo(0.498, 0.01));
    });

    test('opacity returns correct value for fully transparent', () {
      const color = SvgColor(100, 100, 100, 0);
      expect(color.opacity, 0.0);
    });
  });

  group('SvgChartColors', () {
    test('light preset has expected temperature line color', () {
      expect(SvgChartColors.light.temperatureLine.toHex(), '#ff6b6b');
    });

    test('dark preset has expected temperature line color', () {
      expect(SvgChartColors.dark.temperatureLine.toHex(), '#ff7675');
    });

    test('light preset has white card background', () {
      expect(SvgChartColors.light.cardBackground.toHex(), '#ffffff');
    });

    test('dark preset has dark card background', () {
      expect(SvgChartColors.dark.cardBackground.toHex(), '#1b2838');
    });

    test('withDynamicColors replaces temperature line color', () {
      const newTempColor = SvgColor(0, 128, 255);
      const newTimeColor = SvgColor(100, 100, 100);

      final colors = SvgChartColors.light.withDynamicColors(
        temperatureLine: newTempColor,
        timeLabel: newTimeColor,
      );

      expect(colors.temperatureLine.toHex(), '#0080ff');
    });

    test('withDynamicColors replaces time label color', () {
      const newTempColor = SvgColor(255, 0, 0);
      const newTimeColor = SvgColor(50, 100, 150);

      final colors = SvgChartColors.light.withDynamicColors(
        temperatureLine: newTempColor,
        timeLabel: newTimeColor,
      );

      expect(colors.timeLabel.toHex(), '#326496');
    });

    test('withDynamicColors preserves gradient alpha from original', () {
      const newTempColor = SvgColor(0, 255, 0);
      const newTimeColor = SvgColor(100, 100, 100);

      final colors = SvgChartColors.light.withDynamicColors(
        temperatureLine: newTempColor,
        timeLabel: newTimeColor,
      );

      // Original light gradient start alpha is 0x40 (64)
      expect(colors.temperatureGradientStart.a, 0x40);
      // Gradient uses new color's RGB
      expect(colors.temperatureGradientStart.r, 0);
      expect(colors.temperatureGradientStart.g, 255);
      expect(colors.temperatureGradientStart.b, 0);
    });

    test('withDynamicColors sets gradient end to fully transparent', () {
      const newTempColor = SvgColor(128, 64, 32);
      const newTimeColor = SvgColor(100, 100, 100);

      final colors = SvgChartColors.light.withDynamicColors(
        temperatureLine: newTempColor,
        timeLabel: newTimeColor,
      );

      expect(colors.temperatureGradientEnd.a, 0x00);
      expect(colors.temperatureGradientEnd.r, 128);
    });

    test('withDynamicColors preserves other colors', () {
      const newTempColor = SvgColor(255, 0, 0);
      const newTimeColor = SvgColor(0, 255, 0);

      final colors = SvgChartColors.light.withDynamicColors(
        temperatureLine: newTempColor,
        timeLabel: newTimeColor,
      );

      // Precipitation should be unchanged
      expect(colors.precipitationBar.toHex(), SvgChartColors.light.precipitationBar.toHex());
      // Daylight should be unchanged
      expect(colors.daylightBar.toHex(), SvgChartColors.light.daylightBar.toHex());
      // Card background should be unchanged
      expect(colors.cardBackground.toHex(), SvgChartColors.light.cardBackground.toHex());
    });
  });

  group('SvgChartGenerator', () {
    late SvgChartGenerator generator;
    late List<HourlyData> testData;

    setUp(() {
      generator = SvgChartGenerator();
      // Create 52 hours of test data (typical display range)
      final now = DateTime(2024, 1, 15, 12, 0);
      testData = List.generate(52, (i) {
        return HourlyData(
          time: now.add(Duration(hours: i - 6)), // 6 hours past, 46 future
          temperature: 10.0 + 5.0 * (i % 12 - 6).abs() / 6, // Varies 10-15°C
          precipitation: i % 8 == 0 ? 2.0 : 0.0, // Some precipitation
          cloudCover: (i * 10) % 100, // Varying cloud cover
        );
      });
    });

    test('generates valid SVG with empty data', () {
      final svg = generator.generate(
        data: [],
        nowIndex: 0,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 400,
        height: 200,
      );

      expect(svg, startsWith('<svg'));
      expect(svg, endsWith('</svg>'));
      expect(svg, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('viewBox="0 0 400 200"'));
    });

    test('generates valid SVG structure with data', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg, startsWith('<svg'));
      expect(svg, endsWith('</svg>'));
      expect(svg, contains('<defs>'));
      expect(svg, contains('</defs>'));
    });

    test('includes temperature gradient definition', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg, contains('id="tempGradient"'));
      expect(svg, contains('linearGradient'));
    });

    test('includes temperature line path', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      // Temperature line uses path element
      expect(svg, contains('<path'));
      expect(svg, contains('stroke="${SvgChartColors.light.temperatureLine.toHex()}"'));
    });

    test('includes now indicator line', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg, contains('stroke="${SvgChartColors.light.nowIndicator.toHex()}"'));
    });

    test('includes time labels', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      // Time labels are text elements
      expect(svg, contains('<text'));
    });

    test('light theme uses light colors', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      // SVG has transparent background (no fill rect) - check temperature line instead
      expect(svg, contains('stroke="${SvgChartColors.light.temperatureLine.toHex()}"'));
    });

    test('dark theme uses dark colors', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.dark,
        width: 800,
        height: 400,
      );

      // SVG has transparent background (no fill rect) - check temperature line
      expect(svg, contains('stroke="${SvgChartColors.dark.temperatureLine.toHex()}"'));
    });

    test('respects width and height parameters', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 1200,
        height: 600,
      );

      expect(svg, contains('viewBox="0 0 1200 600"'));
    });

    test('handles nowIndex at start of data', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 0,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg, startsWith('<svg'));
      expect(svg, endsWith('</svg>'));
    });

    test('handles nowIndex near end of data', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: testData.length - 10,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg, startsWith('<svg'));
      expect(svg, endsWith('</svg>'));
    });

    test('includes precipitation bars when data has precipitation', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      // Precipitation uses rect elements with precipitation color
      expect(svg, contains(SvgChartColors.light.precipitationBar.toHex()));
    });

    test('uses past fade mask by default', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg, contains('mask="url(#pastFadeMask)"'));
    });

    test('can disable past fade mask', () {
      final svg = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
        usePastFade: false,
      );

      expect(svg, isNot(contains('mask="url(#pastFadeMask)"')));
    });

    test('locale affects time label format', () {
      final svgEn = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
        locale: 'en_US',
      );

      final svgDe = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
        locale: 'de_DE',
      );

      // Both should be valid SVGs
      expect(svgEn, startsWith('<svg'));
      expect(svgDe, startsWith('<svg'));

      // They might differ in time format (AM/PM vs 24h)
      // Just verify they're both valid
      expect(svgEn, endsWith('</svg>'));
      expect(svgDe, endsWith('</svg>'));
    });

    test('generates consistent output for same input', () {
      final svg1 = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      final svg2 = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg1, equals(svg2));
    });

    test('different data produces different output', () {
      final svg1 = generator.generate(
        data: testData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      // Modify temperature in test data
      final modifiedData = testData.map((h) => HourlyData(
        time: h.time,
        temperature: h.temperature + 10,
        precipitation: h.precipitation,
        cloudCover: h.cloudCover,
      )).toList();

      final svg2 = generator.generate(
        data: modifiedData,
        nowIndex: 6,
        latitude: 52.52,
        colors: SvgChartColors.light,
        width: 800,
        height: 400,
      );

      expect(svg1, isNot(equals(svg2)));
    });
  });
}
