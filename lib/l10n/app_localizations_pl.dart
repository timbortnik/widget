// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Opady';

  @override
  String get cloudCover => 'Zachmurzenie';

  @override
  String get now => 'Teraz';

  @override
  String updatedAt(String time) {
    return 'Zaktualizowano $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min temu';
  }

  @override
  String get justNow => 'Przed chwilą';

  @override
  String get refresh => 'Odśwież';

  @override
  String get settings => 'Ustawienia';

  @override
  String get location => 'Lokalizacja';

  @override
  String get currentLocation => 'Bieżąca lokalizacja';

  @override
  String get setManually => 'Ustaw ręcznie';

  @override
  String get errorNoConnection => 'Brak połączenia z internetem';

  @override
  String get errorLocationUnavailable => 'Lokalizacja niedostępna';

  @override
  String get errorLoadingData => 'Nie można załadować danych pogodowych';

  @override
  String get retry => 'Ponów';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Prognoza na $hours godz.';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Maks. $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Maks. $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/godz.';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Ręcznie';

  @override
  String get daylight => 'Światło dzienne';

  @override
  String weatherDataBy(String provider) {
    return 'Dane pogodowe od $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Światło dzienne obliczone';

  @override
  String get offlineRefreshError =>
      'Nie można odświeżyć - wyświetlam dane z pamięci podręcznej';

  @override
  String get loadingWeather => 'Ładowanie pogody...';

  @override
  String get unableToLoadWeather => 'Nie można załadować pogody';

  @override
  String get unknownLocation => 'Nieznane';

  @override
  String get gpsPermissionDenied =>
      'Odmowa dostępu do GPS. Włącz w ustawieniach urządzenia.';

  @override
  String get searchConnectionError => 'Nie można wyszukać - sprawdź połączenie';

  @override
  String get selectLocation => 'Wybierz lokalizację';

  @override
  String get searchCityHint => 'Szukaj miasta...';
}
