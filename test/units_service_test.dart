import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:meteogram_widget/services/units_service.dart';

void main() {
  group('UnitsService.usesFahrenheit', () {
    test('US uses Fahrenheit', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.usesFahrenheit(locale), isTrue);
    });

    test('Liberia uses Fahrenheit', () {
      const locale = Locale('en', 'LR');
      expect(UnitsService.usesFahrenheit(locale), isTrue);
    });

    test('Myanmar uses Fahrenheit', () {
      const locale = Locale('my', 'MM');
      expect(UnitsService.usesFahrenheit(locale), isTrue);
    });

    test('UK uses Celsius', () {
      const locale = Locale('en', 'GB');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });

    test('Germany uses Celsius', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });

    test('Ukraine uses Celsius', () {
      const locale = Locale('uk', 'UA');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });

    test('Japan uses Celsius', () {
      const locale = Locale('ja', 'JP');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });

    test('Canada uses Celsius', () {
      const locale = Locale('en', 'CA');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });

    test('language-only locale defaults to Celsius', () {
      const locale = Locale('en');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });

    test('null country code defaults to Celsius', () {
      const locale = Locale('en');
      expect(locale.countryCode, isNull);
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });
  });

  group('UnitsService.formatTemperature', () {
    test('formats Celsius for metric locales', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatTemperature(20.0, locale), '20°C');
      expect(UnitsService.formatTemperature(-5.0, locale), '-5°C');
      expect(UnitsService.formatTemperature(0.0, locale), '0°C');
    });

    test('formats Fahrenheit for US locale', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.formatTemperature(0.0, locale), '32°F');
      expect(UnitsService.formatTemperature(100.0, locale), '212°F');
      expect(UnitsService.formatTemperature(-40.0, locale), '-40°F'); // Same in both
    });

    test('rounds to nearest integer', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatTemperature(20.4, locale), '20°C');
      expect(UnitsService.formatTemperature(20.5, locale), '21°C');
      expect(UnitsService.formatTemperature(20.6, locale), '21°C');
    });

    test('handles very cold temperatures', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatTemperature(-50.0, locale), '-50°C');

      const usLocale = Locale('en', 'US');
      expect(UnitsService.formatTemperature(-50.0, usLocale), '-58°F');
    });

    test('handles very hot temperatures', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatTemperature(50.0, locale), '50°C');

      const usLocale = Locale('en', 'US');
      expect(UnitsService.formatTemperature(50.0, usLocale), '122°F');
    });
  });

  group('UnitsService.formatTemperatureFromBool', () {
    test('formats Celsius when useFahrenheit is false', () {
      expect(UnitsService.formatTemperatureFromBool(20.0, false), '20°C');
      expect(UnitsService.formatTemperatureFromBool(-5.0, false), '-5°C');
    });

    test('formats Fahrenheit when useFahrenheit is true', () {
      expect(UnitsService.formatTemperatureFromBool(0.0, true), '32°F');
      expect(UnitsService.formatTemperatureFromBool(100.0, true), '212°F');
    });

    test('rounds correctly in both units', () {
      expect(UnitsService.formatTemperatureFromBool(20.4, false), '20°C');
      expect(UnitsService.formatTemperatureFromBool(20.6, false), '21°C');
      // 20.4°C = 68.72°F → rounds to 69
      expect(UnitsService.formatTemperatureFromBool(20.4, true), '69°F');
    });
  });
}
