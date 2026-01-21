import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/l10n/app_localizations.dart';

void main() {
  group('Localizations', () {
    test('all supported locales can be loaded', () async {
      // Get all supported locales from AppLocalizations
      const supportedLocales = AppLocalizations.supportedLocales;

      expect(supportedLocales.length, greaterThan(30),
        reason: 'Should support 30+ languages');

      for (final locale in supportedLocales) {
        // Load localization for each locale
        final localizations = await AppLocalizations.delegate.load(locale);

        // Verify it's not null
        expect(localizations, isNotNull,
          reason: 'Failed to load localizations for $locale');

        // Basic sanity check - verify key properties are accessible
        expect(localizations.appTitle, isNotEmpty,
          reason: '$locale: appTitle should not be empty');
        expect(localizations.temperature, isNotEmpty,
          reason: '$locale: temperature should not be empty');
        expect(localizations.precipitation, isNotEmpty,
          reason: '$locale: precipitation should not be empty');
      }
    });

    test('all locales have required strings', () async {
      const supportedLocales = AppLocalizations.supportedLocales;

      for (final locale in supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);

        // Test all critical strings exist and are non-empty
        final requiredStrings = {
          'appTitle': l10n.appTitle,
          'temperature': l10n.temperature,
          'precipitation': l10n.precipitation,
          'daylight': l10n.daylight,
          'location': l10n.location,
          'currentLocation': l10n.currentLocation,
          'refresh': l10n.refresh,
          'settings': l10n.settings,
          'sourceCode': l10n.sourceCode,
          'weatherDataBy': l10n.weatherDataBy('Open-Meteo.com'),
          'daylightDerived': l10n.daylightDerived,
        };

        for (final entry in requiredStrings.entries) {
          expect(entry.value, isNotEmpty,
            reason: '$locale: ${entry.key} should not be empty');
        }
      }
    });

    test('sourceCode string includes license identifier', () async {
      const supportedLocales = AppLocalizations.supportedLocales;

      for (final locale in supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);

        // Verify BSL 1.1 is mentioned (license identifier should be in English)
        expect(l10n.sourceCode, contains('BSL 1.1'),
          reason: '$locale: sourceCode should include license identifier (BSL 1.1)');
      }
    });

    test('weatherDataBy includes license identifier', () async {
      const supportedLocales = AppLocalizations.supportedLocales;

      for (final locale in supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);

        final attribution = l10n.weatherDataBy('Open-Meteo.com');

        // Verify CC BY 4.0 is mentioned
        expect(attribution, contains('CC BY 4.0'),
          reason: '$locale: weatherDataBy should include license (CC BY 4.0)');
      }
    });

    test('specific locale translations are correct', () async {
      // Test a few key languages to ensure translations are actually different
      const enLocale = Locale('en');
      const deLocale = Locale('de');
      const ukLocale = Locale('uk');
      const jaLocale = Locale('ja');

      final en = await AppLocalizations.delegate.load(enLocale);
      final de = await AppLocalizations.delegate.load(deLocale);
      final uk = await AppLocalizations.delegate.load(ukLocale);
      final ja = await AppLocalizations.delegate.load(jaLocale);

      // Verify translations are actually different (not all English)
      // Note: appTitle is "Meteograph" in all languages (brand name)
      expect(en.temperature, isNot(equals(uk.temperature)),
        reason: 'English and Ukrainian should be different');
      expect(en.location, isNot(equals(ja.location)),
        reason: 'English and Japanese should be different');

      // Verify specific known translations
      expect(de.temperature, 'Temperatur');
      expect(uk.temperature, 'Температура');
      expect(ja.temperature, '気温');
    });

    test('all locales have consistent placeholder usage', () async {
      const supportedLocales = AppLocalizations.supportedLocales;

      for (final locale in supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);

        // Test methods with parameters work correctly
        expect(l10n.weatherDataBy('Test'), contains('Test'),
          reason: '$locale: weatherDataBy should include provider name');

        expect(l10n.maxDaylight(75), contains('75'),
          reason: '$locale: maxDaylight should include percentage');
      }
    });
  });
}
