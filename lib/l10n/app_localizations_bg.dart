// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'Метеограма';

  @override
  String get temperature => 'Температура';

  @override
  String get precipitation => 'Валежи';

  @override
  String get cloudCover => 'Облачност';

  @override
  String get now => 'Сега';

  @override
  String updatedAt(String time) {
    return 'Обновено $time';
  }

  @override
  String minutesAgo(int count) {
    return 'преди $count мин';
  }

  @override
  String get justNow => 'Току-що';

  @override
  String get refresh => 'Обнови';

  @override
  String get settings => 'Настройки';

  @override
  String get location => 'Местоположение';

  @override
  String get currentLocation => 'Текущо местоположение';

  @override
  String get setManually => 'Задай ръчно';

  @override
  String get errorNoConnection => 'Няма интернет връзка';

  @override
  String get errorLocationUnavailable => 'Местоположението не е налично';

  @override
  String get errorLoadingData => 'Неуспешно зареждане на метео данни';

  @override
  String get retry => 'Опитай отново';

  @override
  String get offline => 'ОФЛАЙН';

  @override
  String forecastHours(int hours) {
    return 'Прогноза за $hours часа';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Макс $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Макс $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount мм/ч';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Ръчно';

  @override
  String get daylight => 'Дневна светлина';

  @override
  String weatherDataBy(String provider) {
    return 'Метео данни от $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Дневна светлина изчислена';

  @override
  String get offlineRefreshError =>
      'Неуспешно обновяване - показват се кеширани данни';

  @override
  String get loadingWeather => 'Зареждане на времето...';

  @override
  String get unableToLoadWeather => 'Неуспешно зареждане на времето';

  @override
  String get unknownLocation => 'Неизвестно';

  @override
  String get gpsPermissionDenied =>
      'Достъпът до GPS е отказан. Активирайте в настройките.';

  @override
  String get searchConnectionError => 'Неуспешно търсене - проверете връзката';

  @override
  String get selectLocation => 'Изберете местоположение';

  @override
  String get searchCityHint => 'Търсене на град...';
}
