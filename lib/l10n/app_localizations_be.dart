// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Belarusian (`be`).
class AppLocalizationsBe extends AppLocalizations {
  AppLocalizationsBe([String locale = 'be']) : super(locale);

  @override
  String get appTitle => 'Meteograph';

  @override
  String get temperature => 'Тэмпература';

  @override
  String get precipitation => 'Ападкі';

  @override
  String get cloudCover => 'Воблачнасць';

  @override
  String get now => 'Зараз';

  @override
  String updatedAt(String time) {
    return 'Абноўлена $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count хв таму';
  }

  @override
  String get justNow => 'Толькі што';

  @override
  String get refresh => 'Абнавіць';

  @override
  String get settings => 'Налады';

  @override
  String get location => 'Месцазнаходжанне';

  @override
  String get currentLocation => 'Бягучае месцазнаходжанне';

  @override
  String get setManually => 'Задаць уручную';

  @override
  String get errorNoConnection => 'Няма злучэння з інтэрнэтам';

  @override
  String get errorLocationUnavailable => 'Месцазнаходжанне недаступнае';

  @override
  String get errorLoadingData => 'Не ўдалося загрузіць даныя надвор\'я';

  @override
  String get retry => 'Паўтарыць';

  @override
  String get offline => 'АФЛАЙН';

  @override
  String forecastHours(int hours) {
    return 'Прагноз на $hours гадзін';
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
    return '$amount мм/гадз';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Уручную';

  @override
  String get daylight => 'Дзённае святло';

  @override
  String weatherDataBy(String provider) {
    return 'Даныя надвор\'я ад $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Дзённае святло разлічана';

  @override
  String get sourceCode => 'Адкрыты код на GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError =>
      'Немагчыма абнавіць - паказваюцца кэшаваныя даныя';

  @override
  String get loadingWeather => 'Загрузка надвор\'я...';

  @override
  String get unableToLoadWeather => 'Немагчыма загрузіць надвор\'е';

  @override
  String get unknownLocation => 'Невядома';

  @override
  String get gpsPermissionDenied =>
      'Дазвол GPS адхілены. Уключыце ў наладах прылады.';

  @override
  String get searchConnectionError => 'Немагчыма шукаць - праверце падключэнне';

  @override
  String get selectLocation => 'Выбраць месца';

  @override
  String get searchCityHint => 'Пошук горада...';
}
