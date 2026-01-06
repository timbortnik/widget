// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Albanian (`sq`).
class AppLocalizationsSq extends AppLocalizations {
  AppLocalizationsSq([String locale = 'sq']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Reshjet';

  @override
  String get cloudCover => 'Vranësira';

  @override
  String get now => 'Tani';

  @override
  String updatedAt(String time) {
    return 'Përditësuar $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min më parë';
  }

  @override
  String get justNow => 'Pikërisht tani';

  @override
  String get refresh => 'Rifresko';

  @override
  String get settings => 'Cilësimet';

  @override
  String get location => 'Vendndodhja';

  @override
  String get currentLocation => 'Vendndodhja aktuale';

  @override
  String get setManually => 'Cakto manualisht';

  @override
  String get errorNoConnection => 'Nuk ka lidhje interneti';

  @override
  String get errorLocationUnavailable => 'Vendndodhja e padisponueshme';

  @override
  String get errorLoadingData => 'Nuk mund të ngarkoheshin të dhënat e motit';

  @override
  String get retry => 'Provo përsëri';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Parashikim $hours orë';
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
    return '$amount mm/orë';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manual';

  @override
  String get daylight => 'Drita e ditës';

  @override
  String weatherDataBy(String provider) {
    return 'Të dhënat e motit nga $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Drita e ditës e llogaritur';
}
