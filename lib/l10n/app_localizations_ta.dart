// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'வானிலை வரைபடம்';

  @override
  String get temperature => 'வெப்பநிலை';

  @override
  String get precipitation => 'மழைப்பொழிவு';

  @override
  String get cloudCover => 'மேக மூட்டம்';

  @override
  String get now => 'இப்போது';

  @override
  String updatedAt(String time) {
    return '$time புதுப்பிக்கப்பட்டது';
  }

  @override
  String minutesAgo(int count) {
    return '$count நிமிடங்கள் முன்';
  }

  @override
  String get justNow => 'இப்போதுதான்';

  @override
  String get refresh => 'புதுப்பி';

  @override
  String get settings => 'அமைப்புகள்';

  @override
  String get location => 'இடம்';

  @override
  String get currentLocation => 'தற்போதைய இடம்';

  @override
  String get setManually => 'கைமுறையாக அமை';

  @override
  String get errorNoConnection => 'இணைய இணைப்பு இல்லை';

  @override
  String get errorLocationUnavailable => 'இடம் கிடைக்கவில்லை';

  @override
  String get errorLoadingData => 'வானிலை தரவை ஏற்ற முடியவில்லை';

  @override
  String get retry => 'மீண்டும் முயற்சி';

  @override
  String get offline => 'ஆஃப்லைன்';

  @override
  String forecastHours(int hours) {
    return '$hours மணி நேர முன்னறிவிப்பு';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'அதிகபட்சம் $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'அதிகபட்சம் $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount மிமீ/மணி';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'IP இடம்';

  @override
  String get locationSourceManual => 'கைமுறை';

  @override
  String get daylight => 'பகல் ஒளி';

  @override
  String weatherDataBy(String provider) {
    return '$provider வானிலை தரவு (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'பகல் ஒளி கணக்கிடப்பட்டது';
}
