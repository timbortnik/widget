import 'dart:ui';

/// Service for locale-based unit conversion.
class UnitsService {
  /// Countries that use Fahrenheit.
  static const _fahrenheitCountries = {'US', 'LR', 'MM'};

  /// Check if the locale uses Fahrenheit.
  static bool usesFahrenheit(Locale locale) {
    return _fahrenheitCountries.contains(locale.countryCode);
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
}
