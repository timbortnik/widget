// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'আবহাওয়া চার্ট';

  @override
  String get temperature => 'তাপমাত্রা';

  @override
  String get precipitation => 'বৃষ্টিপাত';

  @override
  String get cloudCover => 'মেঘাচ্ছন্নতা';

  @override
  String get now => 'এখন';

  @override
  String updatedAt(String time) {
    return '$time আপডেট হয়েছে';
  }

  @override
  String minutesAgo(int count) {
    return '$count মিনিট আগে';
  }

  @override
  String get justNow => 'এইমাত্র';

  @override
  String get refresh => 'রিফ্রেশ';

  @override
  String get settings => 'সেটিংস';

  @override
  String get location => 'অবস্থান';

  @override
  String get currentLocation => 'বর্তমান অবস্থান';

  @override
  String get setManually => 'ম্যানুয়ালি সেট করুন';

  @override
  String get errorNoConnection => 'ইন্টারনেট সংযোগ নেই';

  @override
  String get errorLocationUnavailable => 'অবস্থান পাওয়া যায়নি';

  @override
  String get errorLoadingData => 'আবহাওয়ার ডেটা লোড করা যায়নি';

  @override
  String get retry => 'পুনরায় চেষ্টা';

  @override
  String get offline => 'অফলাইন';

  @override
  String forecastHours(int hours) {
    return '$hours ঘণ্টার পূর্বাভাস';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'সর্বোচ্চ $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'সর্বোচ্চ $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount মিমি/ঘণ্টা';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'ম্যানুয়াল';

  @override
  String get daylight => 'দিনের আলো';

  @override
  String weatherDataBy(String provider) {
    return '$provider থেকে আবহাওয়া ডেটা (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'দিনের আলো গণনাকৃত';
}
