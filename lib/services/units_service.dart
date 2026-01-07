import 'dart:ui';

/// Service for locale-based unit conversion.
class UnitsService {
  /// Countries that use Fahrenheit.
  static const _fahrenheitCountries = {'US', 'LR', 'MM'};

  /// Countries that use inches for precipitation.
  static const _inchesCountries = {'US', 'GB'};

  /// Check if the locale uses Fahrenheit.
  static bool usesFahrenheit(Locale locale) {
    return _fahrenheitCountries.contains(locale.countryCode);
  }

  /// Check if the locale uses inches for precipitation.
  static bool usesInches(Locale locale) {
    return _inchesCountries.contains(locale.countryCode);
  }

  /// Format temperature for display.
  static String formatTemperature(double celsius, Locale locale) {
    return formatTemperatureFromBool(celsius, usesFahrenheit(locale));
  }

  /// Format temperature for display using a boolean flag.
  /// Useful for background services that cache the preference.
  static String formatTemperatureFromBool(double celsius, bool useFahrenheit) {
    if (useFahrenheit) {
      final fahrenheit = celsius * 9 / 5 + 32;
      return '${fahrenheit.round()}°F';
    }
    return '${celsius.round()}°C';
  }

  /// Format temperature value only (without unit).
  static String formatTemperatureValue(double celsius, Locale locale) {
    if (usesFahrenheit(locale)) {
      final fahrenheit = celsius * 9 / 5 + 32;
      return fahrenheit.round().toString();
    }
    return celsius.round().toString();
  }

  /// Get temperature unit string.
  static String getTemperatureUnit(Locale locale) {
    return usesFahrenheit(locale) ? '°F' : '°C';
  }

  /// Format precipitation for display.
  static String formatPrecipitation(double mm, Locale locale) {
    if (usesInches(locale)) {
      final inches = mm / 25.4;
      return '${inches.toStringAsFixed(2)}"';
    }
    return '${mm.toStringAsFixed(1)} mm';
  }

  /// Get precipitation unit string.
  static String getPrecipitationUnit(Locale locale) {
    return usesInches(locale) ? 'in' : 'mm';
  }

  /// Convert temperature to locale unit.
  static double convertTemperature(double celsius, Locale locale) {
    if (usesFahrenheit(locale)) {
      return celsius * 9 / 5 + 32;
    }
    return celsius;
  }

  /// Convert precipitation to locale unit.
  static double convertPrecipitation(double mm, Locale locale) {
    if (usesInches(locale)) {
      return mm / 25.4;
    }
    return mm;
  }
}
