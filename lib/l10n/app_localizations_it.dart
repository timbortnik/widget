// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Meteogramma';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Precipitazioni';

  @override
  String get cloudCover => 'Copertura nuvolosa';

  @override
  String get now => 'Ora';

  @override
  String updatedAt(String time) {
    return 'Aggiornato $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min fa';
  }

  @override
  String get justNow => 'Proprio ora';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get settings => 'Impostazioni';

  @override
  String get location => 'Posizione';

  @override
  String get currentLocation => 'Posizione attuale';

  @override
  String get setManually => 'Imposta manualmente';

  @override
  String get errorNoConnection => 'Nessuna connessione internet';

  @override
  String get errorLocationUnavailable => 'Posizione non disponibile';

  @override
  String get errorLoadingData => 'Impossibile caricare i dati meteo';

  @override
  String get retry => 'Riprova';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Previsioni $hours ore';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Max $amount';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }
}
