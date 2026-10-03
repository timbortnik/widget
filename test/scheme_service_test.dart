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

    test('only high contrast overrides the card colours', () {
      for (final scheme in [ChartScheme.defaultScheme, ChartScheme.arctic]) {
        expect(scheme.cardColors(MeteogramColors.light, isDark: false),
            same(MeteogramColors.light), reason: '$scheme');
        expect(scheme.cardColors(MeteogramColors.dark, isDark: true),
            same(MeteogramColors.dark), reason: '$scheme');
      }
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

    test('ids are unique', () {
      final ids = ChartScheme.values.map((s) => s.id).toSet();
      expect(ids.length, ChartScheme.values.length);
    });
  });
}
