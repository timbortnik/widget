import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:meteogram_widget/services/units_service.dart';

// Test helpers that mirror the logic in background_service.dart
// (The actual functions are private, so we test the logic patterns)

/// Parse locale from URI query param (mirrors _reRenderCharts logic)
Locale? parseLocaleFromUri(String? uriLocale) {
  if (uriLocale == null || uriLocale.isEmpty) return null;

  final parts = uriLocale.split('_');
  return parts.length >= 2
      ? Locale(parts[0], parts[1].toUpperCase())
      : Locale(parts[0]);
}

/// Parse dimensions from URI (mirrors _reRenderCharts logic)
({int width, int height}) parseDimensionsFromUri(String? widthStr, String? heightStr) {
  var width = int.tryParse(widthStr ?? '') ?? 0;
  var height = int.tryParse(heightStr ?? '') ?? 0;

  // Apply fallback for invalid dimensions
  if (width <= 0) width = 1000;
  if (height <= 0) height = 500;

  return (width: width, height: height);
}

/// Parse system locale string (mirrors _getSystemLocale logic)
Locale parseSystemLocale(String localeName) {
  // Parse locale string (formats: "en", "en_US", "en-US", "en_US.UTF-8")
  final cleaned = localeName.split('.').first; // Remove .UTF-8 suffix
  final parts = cleaned.split(RegExp(r'[_-]'));

  if (parts.length >= 2) {
    return Locale(parts[0], parts[1].toUpperCase());
  }
  return Locale(parts[0]);
}

void main() {
  group('URI locale parsing', () {
    test('parses en_US correctly', () {
      final locale = parseLocaleFromUri('en_US');
      expect(locale?.languageCode, 'en');
      expect(locale?.countryCode, 'US');
    });

    test('parses uk_UA correctly', () {
      final locale = parseLocaleFromUri('uk_UA');
      expect(locale?.languageCode, 'uk');
      expect(locale?.countryCode, 'UA');
    });

    test('parses de_DE correctly', () {
      final locale = parseLocaleFromUri('de_DE');
      expect(locale?.languageCode, 'de');
      expect(locale?.countryCode, 'DE');
    });

    test('handles lowercase country code', () {
      final locale = parseLocaleFromUri('en_us');
      expect(locale?.languageCode, 'en');
      expect(locale?.countryCode, 'US'); // Should be uppercased
    });

    test('handles language-only locale', () {
      final locale = parseLocaleFromUri('en');
      expect(locale?.languageCode, 'en');
      expect(locale?.countryCode, isNull);
    });

    test('returns null for empty string', () {
      final locale = parseLocaleFromUri('');
      expect(locale, isNull);
    });

    test('returns null for null', () {
      final locale = parseLocaleFromUri(null);
      expect(locale, isNull);
    });
  });

  group('URI dimension parsing', () {
    test('parses valid dimensions', () {
      final dims = parseDimensionsFromUri('1319', '774');
      expect(dims.width, 1319);
      expect(dims.height, 774);
    });

    test('uses fallback for zero width', () {
      final dims = parseDimensionsFromUri('0', '774');
      expect(dims.width, 1000);
      expect(dims.height, 774);
    });

    test('uses fallback for zero height', () {
      final dims = parseDimensionsFromUri('1319', '0');
      expect(dims.width, 1319);
      expect(dims.height, 500);
    });

    test('uses fallback for both zero', () {
      final dims = parseDimensionsFromUri('0', '0');
      expect(dims.width, 1000);
      expect(dims.height, 500);
    });

    test('uses fallback for null values', () {
      final dims = parseDimensionsFromUri(null, null);
      expect(dims.width, 1000);
      expect(dims.height, 500);
    });

    test('uses fallback for invalid strings', () {
      final dims = parseDimensionsFromUri('abc', 'xyz');
      expect(dims.width, 1000);
      expect(dims.height, 500);
    });

    test('uses fallback for negative values', () {
      final dims = parseDimensionsFromUri('-100', '-50');
      expect(dims.width, 1000);
      expect(dims.height, 500);
    });
  });

  group('System locale parsing', () {
    test('parses en_US', () {
      final locale = parseSystemLocale('en_US');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('parses en-US (hyphen separator)', () {
      final locale = parseSystemLocale('en-US');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('parses en_US.UTF-8 (with encoding suffix)', () {
      final locale = parseSystemLocale('en_US.UTF-8');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('parses uk_UA.UTF-8', () {
      final locale = parseSystemLocale('uk_UA.UTF-8');
      expect(locale.languageCode, 'uk');
      expect(locale.countryCode, 'UA');
    });

    test('parses language-only', () {
      final locale = parseSystemLocale('en');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, isNull);
    });

    test('handles lowercase and uppercases country', () {
      final locale = parseSystemLocale('en_us');
      expect(locale.countryCode, 'US');
    });
  });

  group('Locale to temperature unit', () {
    test('US uses Fahrenheit', () {
      const locale = Locale('en', 'US');
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

    test('Liberia uses Fahrenheit', () {
      const locale = Locale('en', 'LR');
      expect(UnitsService.usesFahrenheit(locale), isTrue);
    });

    test('Myanmar uses Fahrenheit', () {
      const locale = Locale('my', 'MM');
      expect(UnitsService.usesFahrenheit(locale), isTrue);
    });

    test('Language-only locale defaults to Celsius', () {
      const locale = Locale('en');
      expect(UnitsService.usesFahrenheit(locale), isFalse);
    });
  });

  group('Temperature formatting', () {
    test('formats Celsius correctly', () {
      expect(UnitsService.formatTemperatureFromBool(20.0, false), '20°C');
      expect(UnitsService.formatTemperatureFromBool(-5.0, false), '-5°C');
      expect(UnitsService.formatTemperatureFromBool(0.0, false), '0°C');
    });

    test('formats Fahrenheit correctly', () {
      expect(UnitsService.formatTemperatureFromBool(0.0, true), '32°F');
      expect(UnitsService.formatTemperatureFromBool(100.0, true), '212°F');
      expect(UnitsService.formatTemperatureFromBool(-17.78, true), '0°F');
    });

    test('rounds to nearest integer', () {
      expect(UnitsService.formatTemperatureFromBool(20.4, false), '20°C');
      expect(UnitsService.formatTemperatureFromBool(20.6, false), '21°C');
    });
  });
}
