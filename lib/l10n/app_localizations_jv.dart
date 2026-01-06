// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Javanese (`jv`).
class AppLocalizationsJv extends AppLocalizations {
  AppLocalizationsJv([String locale = 'jv']) : super(locale);

  @override
  String get appTitle => 'Grafik Cuaca';

  @override
  String get temperature => 'Suhu';

  @override
  String get precipitation => 'Udan';

  @override
  String get cloudCover => 'Mendhung';

  @override
  String get now => 'Saiki';

  @override
  String updatedAt(String time) {
    return 'Dianyari $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count menit kepungkur';
  }

  @override
  String get justNow => 'Lagi wae';

  @override
  String get refresh => 'Anyari';

  @override
  String get settings => 'Setelan';

  @override
  String get location => 'Lokasi';

  @override
  String get currentLocation => 'Lokasi saiki';

  @override
  String get setManually => 'Atur manual';

  @override
  String get errorNoConnection => 'Ora ana sambungan internet';

  @override
  String get errorLocationUnavailable => 'Lokasi ora kasedhiya';

  @override
  String get errorLoadingData => 'Ora bisa ngemot data cuaca';

  @override
  String get retry => 'Coba maneh';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Ramalan $hours jam';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Maks $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Maks $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/jam';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manual';

  @override
  String get daylight => 'Cahya awan';

  @override
  String weatherDataBy(String provider) {
    return 'Data cuaca saka $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Cahya awan dietung';
}
