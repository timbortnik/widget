// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '气象图';

  @override
  String get temperature => '温度';

  @override
  String get precipitation => '降水';

  @override
  String get cloudCover => '云量';

  @override
  String get now => '现在';

  @override
  String updatedAt(String time) {
    return '更新于 $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String get justNow => '刚刚';

  @override
  String get refresh => '刷新';

  @override
  String get settings => '设置';

  @override
  String get location => '位置';

  @override
  String get currentLocation => '当前位置';

  @override
  String get setManually => '手动设置';

  @override
  String get errorNoConnection => '无网络连接';

  @override
  String get errorLocationUnavailable => '无法获取位置';

  @override
  String get errorLoadingData => '无法加载天气数据';

  @override
  String get retry => '重试';

  @override
  String get offline => '离线';

  @override
  String forecastHours(int hours) {
    return '$hours小时预报';
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
    return '$amount 毫米/小时';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => '手动';

  @override
  String get daylight => '日光';

  @override
  String weatherDataBy(String provider) {
    return '天气数据由 $provider 提供 (CC BY 4.0)';
  }

  @override
  String get daylightDerived => '日光为计算值';
}
