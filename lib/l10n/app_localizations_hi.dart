// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'मौसम चार्ट';

  @override
  String get temperature => 'तापमान';

  @override
  String get precipitation => 'वर्षा';

  @override
  String get cloudCover => 'बादल';

  @override
  String get now => 'अभी';

  @override
  String updatedAt(String time) {
    return '$time को अपडेट किया गया';
  }

  @override
  String minutesAgo(int count) {
    return '$count मिनट पहले';
  }

  @override
  String get justNow => 'अभी-अभी';

  @override
  String get refresh => 'रीफ्रेश';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get location => 'स्थान';

  @override
  String get currentLocation => 'वर्तमान स्थान';

  @override
  String get setManually => 'मैन्युअल सेट करें';

  @override
  String get errorNoConnection => 'इंटरनेट कनेक्शन नहीं है';

  @override
  String get errorLocationUnavailable => 'स्थान उपलब्ध नहीं';

  @override
  String get errorLoadingData => 'मौसम डेटा लोड नहीं हो सका';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get offline => 'ऑफलाइन';

  @override
  String forecastHours(int hours) {
    return '$hours घंटे का पूर्वानुमान';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'अधिकतम $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'अधिकतम $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount मिमी/घंटा';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'IP स्थान';

  @override
  String get locationSourceManual => 'मैन्युअल';

  @override
  String get daylight => 'दिन का प्रकाश';

  @override
  String weatherDataBy(String provider) {
    return '$provider से मौसम डेटा (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'दिन का प्रकाश गणना';
}
