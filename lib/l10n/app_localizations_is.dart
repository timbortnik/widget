// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Icelandic (`is`).
class AppLocalizationsIs extends AppLocalizations {
  AppLocalizationsIs([String locale = 'is']) : super(locale);

  @override
  String get appTitle => 'Veðurrit';

  @override
  String get temperature => 'Hitastig';

  @override
  String get precipitation => 'Úrkoma';

  @override
  String get cloudCover => 'Skýjahula';

  @override
  String get now => 'Núna';

  @override
  String updatedAt(String time) {
    return 'Uppfært $time';
  }

  @override
  String minutesAgo(int count) {
    return 'fyrir $count mín';
  }

  @override
  String get justNow => 'Rétt í þessu';

  @override
  String get refresh => 'Uppfæra';

  @override
  String get settings => 'Stillingar';

  @override
  String get location => 'Staðsetning';

  @override
  String get currentLocation => 'Núverandi staðsetning';

  @override
  String get setManually => 'Stilla handvirkt';

  @override
  String get errorNoConnection => 'Engin nettenging';

  @override
  String get errorLocationUnavailable => 'Staðsetning ekki tiltæk';

  @override
  String get errorLoadingData => 'Gat ekki hlaðið veðurgögnum';

  @override
  String get retry => 'Reyna aftur';

  @override
  String get offline => 'ÓTENGT';

  @override
  String forecastHours(int hours) {
    return '$hours tíma spá';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Hám $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Hám $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/klst';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Handvirkt';

  @override
  String get daylight => 'Dagsbirta';

  @override
  String weatherDataBy(String provider) {
    return 'Veðurgögn frá $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Dagsbirta reiknuð';

  @override
  String get offlineRefreshError => 'Ekki tókst að uppfæra - sýni vistuð gögn';

  @override
  String get loadingWeather => 'Hleð veðri...';

  @override
  String get unableToLoadWeather => 'Ekki tókst að hlaða veðri';

  @override
  String get unknownLocation => 'Óþekkt';

  @override
  String get gpsPermissionDenied =>
      'GPS heimild hafnað. Virkja í stillingar tækis.';

  @override
  String get searchConnectionError => 'Ekki tókst að leita - athugaðu tengingu';

  @override
  String get selectLocation => 'Veldu staðsetningu';

  @override
  String get searchCityHint => 'Leita að borg...';
}
