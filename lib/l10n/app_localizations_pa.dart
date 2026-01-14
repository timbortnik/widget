// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Panjabi Punjabi (`pa`).
class AppLocalizationsPa extends AppLocalizations {
  AppLocalizationsPa([String locale = 'pa']) : super(locale);

  @override
  String get appTitle => 'ਮੌਸਮ ਚਾਰਟ';

  @override
  String get temperature => 'ਤਾਪਮਾਨ';

  @override
  String get precipitation => 'ਵਰਖਾ';

  @override
  String get cloudCover => 'ਬੱਦਲ';

  @override
  String get now => 'ਹੁਣੇ';

  @override
  String updatedAt(String time) {
    return '$time ਅੱਪਡੇਟ ਕੀਤਾ';
  }

  @override
  String minutesAgo(int count) {
    return '$count ਮਿੰਟ ਪਹਿਲਾਂ';
  }

  @override
  String get justNow => 'ਹੁਣੇ-ਹੁਣੇ';

  @override
  String get refresh => 'ਰਿਫ੍ਰੈਸ਼';

  @override
  String get settings => 'ਸੈਟਿੰਗਾਂ';

  @override
  String get location => 'ਸਥਾਨ';

  @override
  String get currentLocation => 'ਮੌਜੂਦਾ ਸਥਾਨ';

  @override
  String get setManually => 'ਹੱਥੀਂ ਸੈੱਟ ਕਰੋ';

  @override
  String get errorNoConnection => 'ਇੰਟਰਨੈੱਟ ਕਨੈਕਸ਼ਨ ਨਹੀਂ';

  @override
  String get errorLocationUnavailable => 'ਸਥਾਨ ਉਪਲਬਧ ਨਹੀਂ';

  @override
  String get errorLoadingData => 'ਮੌਸਮ ਡਾਟਾ ਲੋਡ ਨਹੀਂ ਹੋ ਸਕਿਆ';

  @override
  String get retry => 'ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼';

  @override
  String get offline => 'ਆਫਲਾਈਨ';

  @override
  String forecastHours(int hours) {
    return '$hours ਘੰਟੇ ਦੀ ਭਵਿੱਖਬਾਣੀ';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'ਵੱਧ $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'ਵੱਧ $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount ਮਿਮੀ/ਘੰਟਾ';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'ਹੱਥੀਂ';

  @override
  String get daylight => 'ਦਿਨ ਦੀ ਰੌਸ਼ਨੀ';

  @override
  String weatherDataBy(String provider) {
    return '$provider ਤੋਂ ਮੌਸਮ ਡਾਟਾ (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'ਦਿਨ ਦੀ ਰੌਸ਼ਨੀ ਗਣਨਾ';

  @override
  String get offlineRefreshError =>
      'ਤਾਜ਼ਾ ਨਹੀਂ ਹੋ ਸਕਦਾ - ਕੈਸ਼ ਕੀਤਾ ਡਾਟਾ ਦਿਖਾ ਰਿਹਾ ਹੈ';

  @override
  String get loadingWeather => 'ਮੌਸਮ ਲੋਡ ਹੋ ਰਿਹਾ ਹੈ...';

  @override
  String get unableToLoadWeather => 'ਮੌਸਮ ਲੋਡ ਨਹੀਂ ਹੋ ਸਕਦਾ';

  @override
  String get unknownLocation => 'ਅਣਜਾਣ';

  @override
  String get gpsPermissionDenied =>
      'GPS ਇਜਾਜ਼ਤ ਰੱਦ। ਡਿਵਾਈਸ ਸੈਟਿੰਗਾਂ ਵਿੱਚ ਯੋਗ ਕਰੋ।';

  @override
  String get searchConnectionError =>
      'ਖੋਜ ਨਹੀਂ ਹੋ ਸਕਦੀ - ਆਪਣਾ ਕਨੈਕਸ਼ਨ ਚੈੱਕ ਕਰੋ';

  @override
  String get selectLocation => 'ਟਿਕਾਣਾ ਚੁਣੋ';

  @override
  String get searchCityHint => 'ਸ਼ਹਿਰ ਲੱਭੋ...';
}
