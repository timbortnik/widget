// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '気象グラフ';

  @override
  String get temperature => '気温';

  @override
  String get precipitation => '降水量';

  @override
  String get cloudCover => '雲量';

  @override
  String get now => '現在';

  @override
  String updatedAt(String time) {
    return '$timeに更新';
  }

  @override
  String minutesAgo(int count) {
    return '$count分前';
  }

  @override
  String get justNow => 'たった今';

  @override
  String get refresh => '更新';

  @override
  String get settings => '設定';

  @override
  String get location => '場所';

  @override
  String get currentLocation => '現在地';

  @override
  String get setManually => '手動で設定';

  @override
  String get errorNoConnection => 'インターネット接続がありません';

  @override
  String get errorLocationUnavailable => '位置情報を取得できません';

  @override
  String get errorLoadingData => '天気データを読み込めませんでした';

  @override
  String get retry => '再試行';

  @override
  String get offline => 'オフライン';

  @override
  String forecastHours(int hours) {
    return '$hours時間予報';
  }

  @override
  String maxPrecipitation(String amount) {
    return '最大 $amount';
  }

  @override
  String maxSunshine(int percent) {
    return '最大 $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/時';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'IP位置情報';

  @override
  String get locationSourceManual => '手動';

  @override
  String get daylight => '日光';

  @override
  String weatherDataBy(String provider) {
    return '$providerの気象データ (CC BY 4.0)';
  }

  @override
  String get daylightDerived => '日光は計算値';
}
