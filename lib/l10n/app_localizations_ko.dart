// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '기상 차트';

  @override
  String get temperature => '기온';

  @override
  String get precipitation => '강수량';

  @override
  String get cloudCover => '구름량';

  @override
  String get now => '현재';

  @override
  String updatedAt(String time) {
    return '$time 업데이트';
  }

  @override
  String minutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String get justNow => '방금';

  @override
  String get refresh => '새로고침';

  @override
  String get settings => '설정';

  @override
  String get location => '위치';

  @override
  String get currentLocation => '현재 위치';

  @override
  String get setManually => '수동 설정';

  @override
  String get errorNoConnection => '인터넷 연결 없음';

  @override
  String get errorLocationUnavailable => '위치를 사용할 수 없음';

  @override
  String get errorLoadingData => '날씨 데이터를 불러올 수 없습니다';

  @override
  String get retry => '다시 시도';

  @override
  String get offline => '오프라인';

  @override
  String forecastHours(int hours) {
    return '$hours시간 예보';
  }

  @override
  String maxPrecipitation(String amount) {
    return '최대 $amount';
  }

  @override
  String maxSunshine(int percent) {
    return '최대 $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/시';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'IP 위치';

  @override
  String get locationSourceManual => '수동';

  @override
  String get daylight => '일광';

  @override
  String weatherDataBy(String provider) {
    return '$provider 날씨 데이터 (CC BY 4.0)';
  }

  @override
  String get daylightDerived => '일광 계산값';
}
