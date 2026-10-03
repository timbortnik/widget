import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/scheme_service.dart';
import 'package:meteogram_widget/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the native widget-store channel with an in-memory map so we can assert
  // the value is mirrored to widget storage for the native renderer.
  final Map<String, dynamic> homeWidgetData = {};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('org.bortnik.meteogram/svg'), (call) async {
    if (call.method == 'saveWidgetData') {
      final args = call.arguments as Map;
      final id = args['id'] as String?;
      final data = args['data'];
      if (id != null) {
        if (data == null) {
          homeWidgetData.remove(id);
        } else {
          homeWidgetData[id] = data;
        }
      }
      return true;
    } else if (call.method == 'getWidgetData') {
      final args = call.arguments as Map;
      final id = args['id'] as String?;
      return id != null ? homeWidgetData[id] : null;
    }
    return null;
  });

  setUp(homeWidgetData.clear);

  group('SchemeService', () {
    test('defaults to the Material You scheme when nothing saved', () async {
      expect(await SchemeService().load(), ChartScheme.defaultScheme);
    });

    test('round-trips each scheme', () async {
      final service = SchemeService();
      for (final scheme in ChartScheme.values) {
        await service.save(scheme);
        expect(await service.load(), scheme);
      }
    });

    test('falls back to the default for an unknown stored value', () async {
      homeWidgetData['color_scheme'] = 'scheme-from-a-newer-version';
      expect(await SchemeService().load(), ChartScheme.defaultScheme);
    });

    test('persists the choice to HomeWidget storage for the widget', () async {
      await SchemeService().save(ChartScheme.arctic);
      expect(homeWidgetData['color_scheme'], 'arctic');

      await SchemeService().save(ChartScheme.highContrast);
      expect(homeWidgetData['color_scheme'], 'contrast');
    });

    test('ids match the wire values ChartSchemes.kt resolves', () {
      // These strings are the contract with the native renderer; changing one
      // silently drops the user back to the default scheme.
      expect(ChartScheme.defaultScheme.id, 'default');
      expect(ChartScheme.arctic.id, 'arctic');
      expect(ChartScheme.highContrast.id, 'contrast');
    });

    test('only the default scheme keeps the Material You card colours', () {
      expect(ChartScheme.defaultScheme.cardColors(MeteogramColors.light, isDark: false),
          same(MeteogramColors.light));
      expect(ChartScheme.defaultScheme.cardColors(MeteogramColors.dark, isDark: true),
          same(MeteogramColors.dark));
    });

    test('arctic card echoes its chart palette', () {
      // Pinned to arcticLight/arcticDark in ChartSchemes.kt (pinned there too,
      // in SvgChartGeneratorTest) — change both sides together.
      final light = ChartScheme.arctic.cardColors(MeteogramColors.light, isDark: false);
      expect(light.cardBackground, const Color(0xFFE7E9F4));
      expect(light.temperatureLine, const Color(0xFF1A6684));
      expect(light.primaryText, const Color(0xFF2E3440));
      expect(light.daylightIcon, const Color(0xFFD9864F));
      expect(light.precipitationBar, const Color(0xFF2F5FC0));

      final dark = ChartScheme.arctic.cardColors(MeteogramColors.dark, isDark: true);
      expect(dark.cardBackground, const Color(0xFF2A1D2E));
      expect(dark.temperatureLine, const Color(0xFF8FC9E0));
      expect(dark.primaryText, const Color(0xFFECEFF4));
      expect(dark.daylightIcon, const Color(0xFFE09060));
      expect(dark.precipitationBar, const Color(0xFF5B8DEF));
    });

    test('high contrast card echoes its chart palette', () {
      // Pinned to contrastLight/contrastDark in ChartSchemes.kt (pinned there
      // too, in SvgChartGeneratorTest) — change both sides together.
      final light = ChartScheme.highContrast.cardColors(MeteogramColors.light, isDark: false);
      expect(light.cardBackground, const Color(0xFFFFFFFF));
      expect(light.temperatureLine, const Color(0xFF000000));
      expect(light.primaryText, const Color(0xFF000000));
      expect(light.daylightIcon, const Color(0xFFC87000));
      expect(light.precipitationBar, const Color(0xFF0B4FA8));

      final dark = ChartScheme.highContrast.cardColors(MeteogramColors.dark, isDark: true);
      expect(dark.cardBackground, const Color(0xFF000000));
      expect(dark.temperatureLine, const Color(0xFFFFFFFF));
      expect(dark.primaryText, const Color(0xFFFFFFFF));
      expect(dark.daylightIcon, const Color(0xFFE6B84A));
      expect(dark.precipitationBar, const Color(0xFF4FC3F7));
    });

    test('only arctic colour-codes the temperature', () {
      for (final scheme in [ChartScheme.defaultScheme, ChartScheme.highContrast]) {
        expect(scheme.temperatureScale(isDark: false), isNull, reason: '$scheme');
        expect(scheme.temperatureColor(20, isDark: true), isNull, reason: '$scheme');
      }
    });

    test('arctic temperature scale matches the chart', () {
      // Pinned to temperatureScale in ChartSchemes.kt (pinned there too, in
      // SvgChartGeneratorTest) — change both sides together.
      List<(double, int)> stops(bool isDark) => ChartScheme.arctic
          .temperatureScale(isDark: isDark)!
          .map((stop) => (stop.$1, stop.$2.toARGB32()))
          .toList();
      expect(stops(false), [(-20.0, 0xFF3B3A8F), (0.0, 0xFF1A6684), (20.0, 0xFF52586A), (40.0, 0xFFB8305F)]);
      expect(stops(true), [(-20.0, 0xFFB8A8F0), (0.0, 0xFF8FC9E0), (20.0, 0xFFD8D4DC), (40.0, 0xFFF2708A)]);
    });

    test('arctic temperature colour interpolates and clamps like the chart', () {
      int at(double celsius) =>
          ChartScheme.arctic.temperatureColor(celsius, isDark: false)!.toARGB32();
      expect(at(0), 0xFF1A6684);
      expect(at(10), 0xFF365F77); // Same midpoint SvgChartColors.temperatureColorAt gives
      expect(at(-66), 0xFF3B3A8F);
      expect(at(45), 0xFFB8305F);
    });

    test('only arctic splits precipitation with a snow colour', () {
      // Pinned to snowBar in ChartSchemes.kt (pinned there too).
      expect(ChartScheme.arctic.snowColor(isDark: false), const Color(0xFF7A8AA0));
      expect(ChartScheme.arctic.snowColor(isDark: true), const Color(0xFFEEF3F7));
      for (final scheme in [ChartScheme.defaultScheme, ChartScheme.highContrast]) {
        expect(scheme.snowColor(isDark: false), isNull, reason: '$scheme');
      }
    });

    test('only arctic colour-codes the sun', () {
      for (final scheme in [ChartScheme.defaultScheme, ChartScheme.highContrast]) {
        expect(scheme.daylightScale(isDark: false), isNull, reason: '$scheme');
        expect(scheme.daylightColor(20, isDark: true), isNull, reason: '$scheme');
      }
    });

    test('arctic sun scale matches the chart', () {
      // Pinned to daylightScale in ChartSchemes.kt (pinned there too).
      List<(double, int)> stops(bool isDark) => ChartScheme.arctic
          .daylightScale(isDark: isDark)!
          .map((stop) => (stop.$1, stop.$2.toARGB32()))
          .toList();
      expect(stops(false), [(-20.0, 0xFFD9864F), (40.0, 0xFFFF8F00)]);
      expect(stops(true), [(-20.0, 0xFFE09060), (40.0, 0xFFF2D45C)]);
    });

    test('arctic sun colour interpolates and clamps like the chart', () {
      int at(double celsius) =>
          ChartScheme.arctic.daylightColor(celsius, isDark: false)!.toARGB32();
      expect(at(-20), 0xFFD9864F);
      expect(at(0), 0xFFE68935); // Same as SvgChartColors.daylightColorAt(0.0)
      expect(at(48), 0xFFFF8F00);
    });

    test('ids are unique', () {
      final ids = ChartScheme.values.map((s) => s.id).toSet();
      expect(ids.length, ChartScheme.values.length);
    });
  });
}
