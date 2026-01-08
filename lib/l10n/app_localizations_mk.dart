// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Macedonian (`mk`).
class AppLocalizationsMk extends AppLocalizations {
  AppLocalizationsMk([String locale = 'mk']) : super(locale);

  @override
  String get appTitle => 'Метеограм';

  @override
  String get temperature => 'Температура';

  @override
  String get precipitation => 'Врнежи';

  @override
  String get cloudCover => 'Облачност';

  @override
  String get now => 'Сега';

  @override
  String updatedAt(String time) {
    return 'Ажурирано $time';
  }

  @override
  String minutesAgo(int count) {
    return 'пред $count мин';
  }

  @override
  String get justNow => 'Токму сега';

  @override
  String get refresh => 'Освежи';

  @override
  String get settings => 'Поставки';

  @override
  String get location => 'Локација';

  @override
  String get currentLocation => 'Тековна локација';

  @override
  String get setManually => 'Постави рачно';

  @override
  String get errorNoConnection => 'Нема интернет конекција';

  @override
  String get errorLocationUnavailable => 'Локацијата е недостапна';

  @override
  String get errorLoadingData =>
      'Не можеше да се вчитаат податоците за времето';

  @override
  String get retry => 'Обиди се повторно';

  @override
  String get offline => 'ОФЛАЈН';

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
  String get locationSourceManual => 'Рачно';

  @override
  String get daylight => 'Дневна светлина';

  @override
  String weatherDataBy(String provider) {
    return 'Податоци за времето од $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Дневна светлина пресметана';

  @override
  String get offlineRefreshError =>
      'Не може да се освежи - се прикажуваат кеширани податоци';

  @override
  String get loadingWeather => 'Се вчитува времето...';

  @override
  String get unableToLoadWeather => 'Не може да се вчита времето';

  @override
  String get unknownLocation => 'Непознато';

  @override
  String get gpsPermissionDenied =>
      'GPS дозволата е одбиена. Овозможете во поставките.';

  @override
  String get searchConnectionError =>
      'Не може да се пребарува - проверете ја врската';

  @override
  String get selectLocation => 'Изберете локација';

  @override
  String get searchCityHint => 'Пребарај град...';
}
