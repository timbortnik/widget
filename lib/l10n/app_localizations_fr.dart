// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Météogramme';

  @override
  String get temperature => 'Température';

  @override
  String get precipitation => 'Précipitations';

  @override
  String get cloudCover => 'Couverture nuageuse';

  @override
  String get now => 'Maintenant';

  @override
  String updatedAt(String time) {
    return 'Mis à jour $time';
  }

  @override
  String minutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String get justNow => 'À l\'instant';

  @override
  String get refresh => 'Actualiser';

  @override
  String get settings => 'Paramètres';

  @override
  String get location => 'Emplacement';

  @override
  String get currentLocation => 'Position actuelle';

  @override
  String get setManually => 'Définir manuellement';

  @override
  String get errorNoConnection => 'Pas de connexion internet';

  @override
  String get errorLocationUnavailable => 'Position non disponible';

  @override
  String get errorLoadingData => 'Impossible de charger les données météo';

  @override
  String get retry => 'Réessayer';

  @override
  String get offline => 'HORS LIGNE';

  @override
  String forecastHours(int hours) {
    return 'Prévisions ${hours}h';
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
  String get locationSourceIp => 'Localisation IP';

  @override
  String get locationSourceManual => 'Manuel';

  @override
  String get daylight => 'Lumière du jour';

  @override
  String weatherDataBy(String provider) {
    return 'Données météo de $provider';
  }
}
