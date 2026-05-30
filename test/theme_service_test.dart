import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the HomeWidget method channel with an in-memory map so we can assert
  // the value is mirrored to widget storage for the native provider.
  final Map<String, dynamic> homeWidgetData = {};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    homeWidgetData.clear();
  });

  group('ThemeService', () {
    test('defaults to system when nothing saved', () async {
      expect(await ThemeService().load(), ThemeMode.system);
    });

    test('round-trips each mode', () async {
      final service = ThemeService();
      for (final mode in ThemeMode.values) {
        await service.save(mode);
        expect(await service.load(), mode);
      }
    });

    test('falls back to system for an unknown stored value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'bogus'});
      expect(await ThemeService().load(), ThemeMode.system);
    });

    test('persists the serialized string under theme_mode', () async {
      await ThemeService().save(ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('mirrors the choice to HomeWidget storage for the widget', () async {
      await ThemeService().save(ThemeMode.dark);
      expect(homeWidgetData['theme_mode'], 'dark');

      await ThemeService().save(ThemeMode.system);
      expect(homeWidgetData['theme_mode'], 'system');
    });
  });
}
