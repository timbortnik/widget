// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatur';

  @override
  String get precipitation => 'Nedbør';

  @override
  String get cloudCover => 'Skydække';

  @override
  String get now => 'Nu';

  @override
  String updatedAt(String time) {
    return 'Opdateret $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min siden';
  }

  @override
  String get justNow => 'Lige nu';

  @override
  String get refresh => 'Opdater';

  @override
  String get settings => 'Indstillinger';

  @override
  String get location => 'Placering';

  @override
  String get currentLocation => 'Nuværende placering';

  @override
  String get setManually => 'Indstil manuelt';

  @override
  String get errorNoConnection => 'Ingen internetforbindelse';

  @override
  String get errorLocationUnavailable => 'Placering ikke tilgængelig';

  @override
  String get errorLoadingData => 'Kunne ikke indlæse vejrdata';

  @override
  String get retry => 'Prøv igen';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return '$hours-timers prognose';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Maks $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Maks $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/t';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manuel';

  @override
  String get daylight => 'Dagslys';

  @override
  String weatherDataBy(String provider) {
    return 'Vejrdata fra $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Dagslys beregnet';

  @override
  String get offlineRefreshError =>
      'Kan ikke opdatere - viser cachelagrede data';

  @override
  String get loadingWeather => 'Indlæser vejr...';

  @override
  String get unableToLoadWeather => 'Kan ikke indlæse vejr';

  @override
  String get unknownLocation => 'Ukendt';

  @override
  String get gpsPermissionDenied =>
      'GPS-tilladelse afvist. Aktivér i enhedsindstillinger.';

  @override
  String get searchConnectionError => 'Kan ikke søge - tjek din forbindelse';

  @override
  String get selectLocation => 'Vælg placering';

  @override
  String get searchCityHint => 'Søg by...';
}
