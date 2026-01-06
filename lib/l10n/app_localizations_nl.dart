// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatuur';

  @override
  String get precipitation => 'Neerslag';

  @override
  String get cloudCover => 'Bewolking';

  @override
  String get now => 'Nu';

  @override
  String updatedAt(String time) {
    return 'Bijgewerkt $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min geleden';
  }

  @override
  String get justNow => 'Zojuist';

  @override
  String get refresh => 'Vernieuwen';

  @override
  String get settings => 'Instellingen';

  @override
  String get location => 'Locatie';

  @override
  String get currentLocation => 'Huidige locatie';

  @override
  String get setManually => 'Handmatig instellen';

  @override
  String get errorNoConnection => 'Geen internetverbinding';

  @override
  String get errorLocationUnavailable => 'Locatie niet beschikbaar';

  @override
  String get errorLoadingData => 'Kan weergegevens niet laden';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return '$hours-uurs voorspelling';
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
    return '$amount mm/u';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'IP-locatie';

  @override
  String get locationSourceManual => 'Handmatig';

  @override
  String get daylight => 'Daglicht';

  @override
  String weatherDataBy(String provider) {
    return 'Weergegevens van $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Daglicht berekend';
}
