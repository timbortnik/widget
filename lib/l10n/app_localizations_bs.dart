// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bosnian (`bs`).
class AppLocalizationsBs extends AppLocalizations {
  AppLocalizationsBs([String locale = 'bs']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Padavine';

  @override
  String get cloudCover => 'Oblačnost';

  @override
  String get now => 'Sada';

  @override
  String updatedAt(String time) {
    return 'Ažurirano $time';
  }

  @override
  String minutesAgo(int count) {
    return 'prije $count min';
  }

  @override
  String get justNow => 'Upravo sada';

  @override
  String get refresh => 'Osvježi';

  @override
  String get settings => 'Postavke';

  @override
  String get location => 'Lokacija';

  @override
  String get currentLocation => 'Trenutna lokacija';

  @override
  String get setManually => 'Postavi ručno';

  @override
  String get errorNoConnection => 'Nema internet veze';

  @override
  String get errorLocationUnavailable => 'Lokacija nedostupna';

  @override
  String get errorLoadingData => 'Nije moguće učitati podatke o vremenu';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Prognoza za $hours sati';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Maks $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Maks $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'IP lokacija';

  @override
  String get locationSourceManual => 'Ručno';

  @override
  String get daylight => 'Dnevno svjetlo';

  @override
  String weatherDataBy(String provider) {
    return 'Podaci o vremenu od $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Dnevno svjetlo izračunato';
}
