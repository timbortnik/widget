// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatur';

  @override
  String get precipitation => 'Nederbörd';

  @override
  String get cloudCover => 'Molnighet';

  @override
  String get now => 'Nu';

  @override
  String updatedAt(String time) {
    return 'Uppdaterad $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min sedan';
  }

  @override
  String get justNow => 'Just nu';

  @override
  String get refresh => 'Uppdatera';

  @override
  String get settings => 'Inställningar';

  @override
  String get location => 'Plats';

  @override
  String get currentLocation => 'Nuvarande plats';

  @override
  String get setManually => 'Ange manuellt';

  @override
  String get errorNoConnection => 'Ingen internetanslutning';

  @override
  String get errorLocationUnavailable => 'Plats otillgänglig';

  @override
  String get errorLoadingData => 'Kunde inte ladda väderdata';

  @override
  String get retry => 'Försök igen';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return '$hours-timmarsprognos';
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
    return '$amount mm/tim';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manuell';

  @override
  String get daylight => 'Dagsljus';

  @override
  String weatherDataBy(String provider) {
    return 'Väderdata från $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Dagsljus beräknat';

  @override
  String get sourceCode => 'Öppen källkod på GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError => 'Kan inte uppdatera - visar cachad data';

  @override
  String get loadingWeather => 'Laddar väder...';

  @override
  String get unableToLoadWeather => 'Kan inte ladda väder';

  @override
  String get unknownLocation => 'Okänd';

  @override
  String get gpsPermissionDenied =>
      'GPS-behörighet nekad. Aktivera i enhetsinställningar.';

  @override
  String get searchConnectionError =>
      'Kan inte söka - kontrollera anslutningen';

  @override
  String get selectLocation => 'Välj plats';

  @override
  String get searchCityHint => 'Sök stad...';
}
