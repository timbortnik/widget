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

  group('UnitsService.usesInches', () {
    test('US uses inches', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.usesInches(locale), isTrue);
    });

    test('UK uses inches', () {
      const locale = Locale('en', 'GB');
      expect(UnitsService.usesInches(locale), isTrue);
    });

    test('Germany uses mm', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.usesInches(locale), isFalse);
    });

    test('Japan uses mm', () {
      const locale = Locale('ja', 'JP');
      expect(UnitsService.usesInches(locale), isFalse);
    });

    test('language-only locale defaults to mm', () {
      const locale = Locale('en');
      expect(UnitsService.usesInches(locale), isFalse);
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

  group('UnitsService.formatTemperatureValue', () {
    test('returns value without unit for Celsius', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatTemperatureValue(20.0, locale), '20');
      expect(UnitsService.formatTemperatureValue(-5.0, locale), '-5');
    });

    test('returns converted value without unit for Fahrenheit', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.formatTemperatureValue(0.0, locale), '32');
      expect(UnitsService.formatTemperatureValue(100.0, locale), '212');
    });
  });

  group('UnitsService.getTemperatureUnit', () {
    test('returns °C for metric locales', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.getTemperatureUnit(locale), '°C');
    });

    test('returns °F for US locale', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.getTemperatureUnit(locale), '°F');
    });
  });

  group('UnitsService.formatPrecipitation', () {
    test('formats mm for metric locales', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatPrecipitation(10.0, locale), '10.0 mm');
      expect(UnitsService.formatPrecipitation(0.5, locale), '0.5 mm');
      expect(UnitsService.formatPrecipitation(0.0, locale), '0.0 mm');
    });

    test('formats inches for US locale', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.formatPrecipitation(25.4, locale), '1.00"');
      expect(UnitsService.formatPrecipitation(0.0, locale), '0.00"');
    });

    test('formats inches for UK locale', () {
      const locale = Locale('en', 'GB');
      expect(UnitsService.formatPrecipitation(25.4, locale), '1.00"');
    });

    test('handles small precipitation amounts', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatPrecipitation(0.1, locale), '0.1 mm');

      const usLocale = Locale('en', 'US');
      // 0.1mm ≈ 0.004 inches
      expect(UnitsService.formatPrecipitation(0.1, usLocale), '0.00"');
    });

    test('handles large precipitation amounts', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.formatPrecipitation(100.0, locale), '100.0 mm');

      const usLocale = Locale('en', 'US');
      // 100mm ≈ 3.94 inches
      expect(UnitsService.formatPrecipitation(100.0, usLocale), '3.94"');
    });
  });

  group('UnitsService.getPrecipitationUnit', () {
    test('returns mm for metric locales', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.getPrecipitationUnit(locale), 'mm');
    });

    test('returns in for US locale', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.getPrecipitationUnit(locale), 'in');
    });

    test('returns in for UK locale', () {
      const locale = Locale('en', 'GB');
      expect(UnitsService.getPrecipitationUnit(locale), 'in');
    });
  });

  group('UnitsService.convertTemperature', () {
    test('returns Celsius unchanged for metric locales', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.convertTemperature(20.0, locale), 20.0);
      expect(UnitsService.convertTemperature(-10.0, locale), -10.0);
    });

    test('converts to Fahrenheit for US locale', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.convertTemperature(0.0, locale), 32.0);
      expect(UnitsService.convertTemperature(100.0, locale), 212.0);
      expect(UnitsService.convertTemperature(-40.0, locale), -40.0);
    });

    test('conversion is accurate', () {
      const locale = Locale('en', 'US');
      // 20°C = 68°F
      expect(UnitsService.convertTemperature(20.0, locale), 68.0);
      // 37°C = 98.6°F (body temperature)
      expect(UnitsService.convertTemperature(37.0, locale), closeTo(98.6, 0.01));
    });
  });

  group('UnitsService.convertPrecipitation', () {
    test('returns mm unchanged for metric locales', () {
      const locale = Locale('de', 'DE');
      expect(UnitsService.convertPrecipitation(10.0, locale), 10.0);
    });

    test('converts to inches for US locale', () {
      const locale = Locale('en', 'US');
      expect(UnitsService.convertPrecipitation(25.4, locale), closeTo(1.0, 0.001));
      expect(UnitsService.convertPrecipitation(0.0, locale), 0.0);
    });

    test('converts to inches for UK locale', () {
      const locale = Locale('en', 'GB');
      expect(UnitsService.convertPrecipitation(50.8, locale), closeTo(2.0, 0.001));
    });
  });
}
