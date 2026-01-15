// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get appTitle => 'Meteogrammi';

  @override
  String get temperature => 'Lämpötila';

  @override
  String get precipitation => 'Sademäärä';

  @override
  String get cloudCover => 'Pilvisyys';

  @override
  String get now => 'Nyt';

  @override
  String updatedAt(String time) {
    return 'Päivitetty $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min sitten';
  }

  @override
  String get justNow => 'Juuri nyt';

  @override
  String get refresh => 'Päivitä';

  @override
  String get settings => 'Asetukset';

  @override
  String get location => 'Sijainti';

  @override
  String get currentLocation => 'Nykyinen sijainti';

  @override
  String get setManually => 'Aseta manuaalisesti';

  @override
  String get errorNoConnection => 'Ei internet-yhteyttä';

  @override
  String get errorLocationUnavailable => 'Sijainti ei saatavilla';

  @override
  String get errorLoadingData => 'Säätietoja ei voitu ladata';

  @override
  String get retry => 'Yritä uudelleen';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return '$hours tunnin ennuste';
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
  String get locationSourceManual => 'Manuaalinen';

  @override
  String get daylight => 'Päivänvalo';

  @override
  String weatherDataBy(String provider) {
    return 'Säätiedot: $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Päivänvalo laskettu';

  @override
  String get sourceCode => 'Avoin lähdekoodi GitHubissa (BSL 1.1)';

  @override
  String get offlineRefreshError =>
      'Päivitys epäonnistui - näytetään välimuistissa olevat tiedot';

  @override
  String get loadingWeather => 'Ladataan säätä...';

  @override
  String get unableToLoadWeather => 'Säätä ei voida ladata';

  @override
  String get unknownLocation => 'Tuntematon';

  @override
  String get gpsPermissionDenied =>
      'GPS-lupa evätty. Ota käyttöön laitteen asetuksista.';

  @override
  String get searchConnectionError => 'Haku epäonnistui - tarkista yhteys';

  @override
  String get selectLocation => 'Valitse sijainti';

  @override
  String get searchCityHint => 'Hae kaupunkia...';
}
