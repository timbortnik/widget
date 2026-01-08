// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Meteogramă';

  @override
  String get temperature => 'Temperatură';

  @override
  String get precipitation => 'Precipitații';

  @override
  String get cloudCover => 'Acoperire noroasă';

  @override
  String get now => 'Acum';

  @override
  String updatedAt(String time) {
    return 'Actualizat $time';
  }

  @override
  String minutesAgo(int count) {
    return 'acum $count min';
  }

  @override
  String get justNow => 'Chiar acum';

  @override
  String get refresh => 'Reîmprospătare';

  @override
  String get settings => 'Setări';

  @override
  String get location => 'Locație';

  @override
  String get currentLocation => 'Locația curentă';

  @override
  String get setManually => 'Setare manuală';

  @override
  String get errorNoConnection => 'Fără conexiune la internet';

  @override
  String get errorLocationUnavailable => 'Locație indisponibilă';

  @override
  String get errorLoadingData => 'Nu s-au putut încărca datele meteo';

  @override
  String get retry => 'Reîncearcă';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Prognoză $hours ore';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Max $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Max $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manual';

  @override
  String get daylight => 'Lumina zilei';

  @override
  String weatherDataBy(String provider) {
    return 'Date meteo de la $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Lumina zilei calculată';

  @override
  String get offlineRefreshError =>
      'Nu se poate reîmprospăta - se afișează date din cache';

  @override
  String get loadingWeather => 'Se încarcă vremea...';

  @override
  String get unableToLoadWeather => 'Nu se poate încărca vremea';

  @override
  String get unknownLocation => 'Necunoscut';

  @override
  String get gpsPermissionDenied =>
      'Permisiunea GPS refuzată. Activați din setările dispozitivului.';

  @override
  String get searchConnectionError =>
      'Nu se poate căuta - verificați conexiunea';

  @override
  String get selectLocation => 'Selectați locația';

  @override
  String get searchCityHint => 'Căutați oraș...';
}
