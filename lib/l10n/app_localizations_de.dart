// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Meteogramm';

  @override
  String get temperature => 'Temperatur';

  @override
  String get precipitation => 'Niederschlag';

  @override
  String get cloudCover => 'Bewölkung';

  @override
  String get now => 'Jetzt';

  @override
  String updatedAt(String time) {
    return 'Aktualisiert $time';
  }

  @override
  String minutesAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String get justNow => 'Gerade eben';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get settings => 'Einstellungen';

  @override
  String get location => 'Standort';

  @override
  String get currentLocation => 'Aktueller Standort';

  @override
  String get setManually => 'Manuell festlegen';

  @override
  String get errorNoConnection => 'Keine Internetverbindung';

  @override
  String get errorLocationUnavailable => 'Standort nicht verfügbar';

  @override
  String get errorLoadingData => 'Wetterdaten konnten nicht geladen werden';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get offline => 'OFFLINE';

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }
}
