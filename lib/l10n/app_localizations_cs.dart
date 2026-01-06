// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Teplota';

  @override
  String get precipitation => 'Srážky';

  @override
  String get cloudCover => 'Oblačnost';

  @override
  String get now => 'Nyní';

  @override
  String updatedAt(String time) {
    return 'Aktualizováno $time';
  }

  @override
  String minutesAgo(int count) {
    return 'před $count min';
  }

  @override
  String get justNow => 'Právě teď';

  @override
  String get refresh => 'Obnovit';

  @override
  String get settings => 'Nastavení';

  @override
  String get location => 'Poloha';

  @override
  String get currentLocation => 'Aktuální poloha';

  @override
  String get setManually => 'Nastavit ručně';

  @override
  String get errorNoConnection => 'Žádné připojení k internetu';

  @override
  String get errorLocationUnavailable => 'Poloha není dostupná';

  @override
  String get errorLoadingData => 'Nelze načíst data o počasí';

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Předpověď na $hours hod';
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
    return '$amount mm/hod';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Ručně';

  @override
  String get daylight => 'Denní světlo';

  @override
  String weatherDataBy(String provider) {
    return 'Data o počasí od $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Denní světlo vypočteno';
}
