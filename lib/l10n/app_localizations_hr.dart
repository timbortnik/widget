// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Oborine';

  @override
  String get cloudCover => 'Naoblaka';

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
  String get errorNoConnection => 'Nema internetske veze';

  @override
  String get errorLocationUnavailable => 'Lokacija nedostupna';

  @override
  String get errorLoadingData => 'Nije moguće učitati vremenske podatke';

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
  String get locationSourceManual => 'Ručno';

  @override
  String get daylight => 'Dnevno svjetlo';

  @override
  String weatherDataBy(String provider) {
    return 'Vremenski podaci od $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Dnevno svjetlo izračunato';
}
