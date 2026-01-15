import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/utils/locale_utils.dart';

void main() {
  group('LocaleUtils.parseLocaleString', () {
    test('parses simple language code', () {
      expect(LocaleUtils.parseLocaleString('en'), const Locale('en'));
      expect(LocaleUtils.parseLocaleString('de'), const Locale('de'));
      expect(LocaleUtils.parseLocaleString('uk'), const Locale('uk'));
    });

    test('parses language_COUNTRY format', () {
      final locale = LocaleUtils.parseLocaleString('en_US');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('parses language-COUNTRY format', () {
      final locale = LocaleUtils.parseLocaleString('en-US');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('parses language_COUNTRY.UTF-8 format', () {
      final locale = LocaleUtils.parseLocaleString('en_US.UTF-8');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('parses language-COUNTRY.UTF-8 format', () {
      final locale = LocaleUtils.parseLocaleString('uk-UA.UTF-8');
      expect(locale.languageCode, 'uk');
      expect(locale.countryCode, 'UA');
    });

    test('handles lowercase country code', () {
      final locale = LocaleUtils.parseLocaleString('en_us');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US'); // Should be uppercase
    });

    test('handles empty string', () {
      expect(LocaleUtils.parseLocaleString(''), const Locale('en'));
    });

    test('handles invalid format', () {
      expect(LocaleUtils.parseLocaleString('___'), const Locale('en'));
      expect(LocaleUtils.parseLocaleString('...'), const Locale('en'));
    });

    test('handles complex UTF-8 suffix', () {
      final locale = LocaleUtils.parseLocaleString('zh_CN.GB2312');
      expect(locale.languageCode, 'zh');
      expect(locale.countryCode, 'CN');
    });

    test('handles multiple delimiters', () {
      final locale = LocaleUtils.parseLocaleString('en-US_foo');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('trims empty parts', () {
      final locale = LocaleUtils.parseLocaleString('en__US');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('handles real-world locale strings', () {
      // Single-letter codes are treated as language codes (not mapped to 'en')
      expect(LocaleUtils.parseLocaleString('C'), const Locale('C'));
      expect(LocaleUtils.parseLocaleString('POSIX'), const Locale('POSIX'));

      final uk = LocaleUtils.parseLocaleString('uk_UA');
      expect(uk.languageCode, 'uk');
      expect(uk.countryCode, 'UA');
    });
  });

  group('LocaleUtils.getSystemLocale', () {
    test('returns valid Locale object', () {
      final locale = LocaleUtils.getSystemLocale();

      // Should return a valid Locale
      expect(locale, isA<Locale>());
      expect(locale.languageCode, isNotEmpty);
    });

    test('handles edge cases gracefully', () {
      // This uses Platform.localeName which we can't mock easily,
      // but we can verify it doesn't crash and returns fallback
      final locale = LocaleUtils.getSystemLocale();

      // Should never be null
      expect(locale, isNotNull);

      // Language code should be valid (2-3 letter code)
      expect(locale.languageCode.length, greaterThanOrEqualTo(2));
      expect(locale.languageCode.length, lessThanOrEqualTo(3));
    });
  });
}
