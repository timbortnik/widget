// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Meteograph';

  @override
  String get temperature => 'Temperature';

  @override
  String get precipitation => 'Precipitation';

  @override
  String get cloudCover => 'Cloud cover';

  @override
  String get now => 'Now';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String get justNow => 'Just now';

  @override
  String get refresh => 'Refresh';

  @override
  String get settings => 'Settings';

  @override
  String get location => 'Location';

  @override
  String get currentLocation => 'Current location';

  @override
  String get setManually => 'Set manually';

  @override
  String get errorNoConnection => 'No internet connection';

  @override
  String get errorLocationUnavailable => 'Location unavailable';

  @override
  String get errorLoadingData => 'Could not load weather data';

  @override
  String get retry => 'Retry';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return '$hours-Hour Forecast';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Max $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Max $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manual';

  @override
  String get daylight => 'Daylight';

  @override
  String weatherDataBy(String provider) {
    return 'Weather data by $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Daylight derived';

  @override
  String get sourceCode => 'Open source on GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError => 'Unable to refresh - showing cached data';

  @override
  String get loadingWeather => 'Loading weather...';

  @override
  String get unableToLoadWeather => 'Unable to load weather';

  @override
  String get unknownLocation => 'Unknown';

  @override
  String get gpsPermissionDenied =>
      'GPS permission denied. Enable in device settings.';

  @override
  String get searchConnectionError =>
      'Unable to search - check your connection';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get searchCityHint => 'Search city...';
}
