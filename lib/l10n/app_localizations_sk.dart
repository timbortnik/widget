// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class AppLocalizationsSk extends AppLocalizations {
  AppLocalizationsSk([String locale = 'sk']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Teplota';

  @override
  String get precipitation => 'Zrážky';

  @override
  String get cloudCover => 'Oblačnosť';

  @override
  String get now => 'Teraz';

  @override
  String updatedAt(String time) {
    return 'Aktualizované $time';
  }

  @override
  String minutesAgo(int count) {
    return 'pred $count min';
  }

  @override
  String get justNow => 'Práve teraz';

  @override
  String get refresh => 'Obnoviť';

  @override
  String get settings => 'Nastavenia';

  @override
  String get location => 'Poloha';

  @override
  String get currentLocation => 'Aktuálna poloha';

  @override
  String get setManually => 'Nastaviť ručne';

  @override
  String get errorNoConnection => 'Žiadne internetové pripojenie';

  @override
  String get errorLocationUnavailable => 'Poloha nedostupná';

  @override
  String get errorLoadingData => 'Nepodarilo sa načítať údaje o počasí';

  @override
  String get retry => 'Skúsiť znova';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Predpoveď na $hours hod';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Max $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Max $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/hod';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Ručne';

  @override
  String get daylight => 'Denné svetlo';

  @override
  String weatherDataBy(String provider) {
    return 'Údaje o počasí od $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Denné svetlo vypočítané';

  @override
  String get sourceCode => 'Open source na GitHube (BSL 1.1)';

  @override
  String get offlineRefreshError =>
      'Nie je možné obnoviť - zobrazujú sa uložené údaje';

  @override
  String get loadingWeather => 'Načítava sa počasie...';

  @override
  String get unableToLoadWeather => 'Nie je možné načítať počasie';

  @override
  String get unknownLocation => 'Neznáme';

  @override
  String get gpsPermissionDenied =>
      'Povolenie GPS zamietnuté. Povoľte v nastaveniach zariadenia.';

  @override
  String get searchConnectionError =>
      'Nie je možné vyhľadávať - skontrolujte pripojenie';

  @override
  String get selectLocation => 'Vyberte umiestnenie';

  @override
  String get searchCityHint => 'Hľadať mesto...';
}
