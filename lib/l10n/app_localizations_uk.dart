// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Meteograph';

  @override
  String get temperature => 'Температура';

  @override
  String get precipitation => 'Опади';

  @override
  String get cloudCover => 'Хмарність';

  @override
  String get now => 'Зараз';

  @override
  String updatedAt(String time) {
    return 'Оновлено $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count хв тому';
  }

  @override
  String get justNow => 'Щойно';

  @override
  String get refresh => 'Оновити';

  @override
  String get settings => 'Налаштування';

  @override
  String get location => 'Місцезнаходження';

  @override
  String get currentLocation => 'Поточне місце';

  @override
  String get setManually => 'Вказати вручну';

  @override
  String get errorNoConnection => 'Немає з\'єднання з інтернетом';

  @override
  String get errorLocationUnavailable => 'Місцезнаходження недоступне';

  @override
  String get errorLoadingData => 'Не вдалося завантажити дані погоди';

  @override
  String get retry => 'Повторити';

  @override
  String get offline => 'ОФЛАЙН';

  @override
  String forecastHours(int hours) {
    return 'Прогноз на $hours год';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Макс $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Макс $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount мм/год';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Вручну';

  @override
  String get daylight => 'Денне світло';

  @override
  String weatherDataBy(String provider) {
    return 'Дані погоди від $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Денне світло розраховано';

  @override
  String get sourceCode => 'Відкритий код на GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError =>
      'Не вдалося оновити - показуються кешовані дані';

  @override
  String get loadingWeather => 'Завантаження погоди...';

  @override
  String get unableToLoadWeather => 'Не вдалося завантажити погоду';

  @override
  String get unknownLocation => 'Невідомо';

  @override
  String get gpsPermissionDenied =>
      'Дозвіл GPS відхилено. Увімкніть у налаштуваннях пристрою.';

  @override
  String get searchConnectionError =>
      'Не вдалося знайти - перевірте підключення';

  @override
  String get selectLocation => 'Оберіть місце';

  @override
  String get searchCityHint => 'Пошук міста...';
}
