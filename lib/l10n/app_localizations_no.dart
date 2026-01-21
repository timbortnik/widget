// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian (`no`).
class AppLocalizationsNo extends AppLocalizations {
  AppLocalizationsNo([String locale = 'no']) : super(locale);

  @override
  String get appTitle => 'Meteograph';

  @override
  String get temperature => 'Temperatur';

  @override
  String get precipitation => 'Nedbør';

  @override
  String get cloudCover => 'Skydekke';

  @override
  String get now => 'Nå';

  @override
  String updatedAt(String time) {
    return 'Oppdatert $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min siden';
  }

  @override
  String get justNow => 'Akkurat nå';

  @override
  String get refresh => 'Oppdater';

  @override
  String get settings => 'Innstillinger';

  @override
  String get location => 'Plassering';

  @override
  String get currentLocation => 'Nåværende plassering';

  @override
  String get setManually => 'Angi manuelt';

  @override
  String get errorNoConnection => 'Ingen internettforbindelse';

  @override
  String get errorLocationUnavailable => 'Plassering utilgjengelig';

  @override
  String get errorLoadingData => 'Kunne ikke laste værdata';

  @override
  String get retry => 'Prøv igjen';

  @override
  String get offline => 'FRAKOBLET';

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
  String get locationSourceManual => 'Manuell';

  @override
  String get daylight => 'Dagslys';

  @override
  String weatherDataBy(String provider) {
    return 'Værdata fra $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Dagslys beregnet';

  @override
  String get sourceCode => 'Åpen kildekode på GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError => 'Kan ikke oppdatere - viser bufrede data';

  @override
  String get loadingWeather => 'Laster vær...';

  @override
  String get unableToLoadWeather => 'Kan ikke laste vær';

  @override
  String get unknownLocation => 'Ukjent';

  @override
  String get gpsPermissionDenied =>
      'GPS-tillatelse avslått. Aktiver i enhetsinnstillinger.';

  @override
  String get searchConnectionError => 'Kan ikke søke - sjekk tilkoblingen';

  @override
  String get selectLocation => 'Velg plassering';

  @override
  String get searchCityHint => 'Søk by...';
}
