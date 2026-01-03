// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

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
}
