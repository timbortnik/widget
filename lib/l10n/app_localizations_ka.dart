// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class AppLocalizationsKa extends AppLocalizations {
  AppLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get appTitle => 'მეტეოგრამა';

  @override
  String get temperature => 'ტემპერატურა';

  @override
  String get precipitation => 'ნალექი';

  @override
  String get cloudCover => 'ღრუბლიანობა';

  @override
  String get now => 'ახლა';

  @override
  String updatedAt(String time) {
    return 'განახლდა $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count წუთის წინ';
  }

  @override
  String get justNow => 'ახლახან';

  @override
  String get refresh => 'განახლება';

  @override
  String get settings => 'პარამეტრები';

  @override
  String get location => 'მდებარეობა';

  @override
  String get currentLocation => 'მიმდინარე მდებარეობა';

  @override
  String get setManually => 'ხელით დაყენება';

  @override
  String get errorNoConnection => 'ინტერნეტ კავშირი არ არის';

  @override
  String get errorLocationUnavailable => 'მდებარეობა მიუწვდომელია';

  @override
  String get errorLoadingData => 'ამინდის მონაცემები ვერ ჩაიტვირთა';

  @override
  String get retry => 'ხელახლა ცდა';

  @override
  String get offline => 'ᲝᲤᲚᲐᲘᲜ';

  @override
  String forecastHours(int hours) {
    return '$hours საათის პროგნოზი';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'მაქს $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'მაქს $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount მმ/სთ';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'ხელით';

  @override
  String get daylight => 'დღის სინათლე';

  @override
  String weatherDataBy(String provider) {
    return 'ამინდის მონაცემები $provider-დან (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'დღის სინათლე გამოთვლილი';

  @override
  String get offlineRefreshError =>
      'განახლება ვერ მოხერხდა - ნაჩვენებია ქეშირებული მონაცემები';

  @override
  String get loadingWeather => 'ამინდის ჩატვირთვა...';

  @override
  String get unableToLoadWeather => 'ამინდის ჩატვირთვა ვერ მოხერხდა';

  @override
  String get unknownLocation => 'უცნობი';

  @override
  String get gpsPermissionDenied =>
      'GPS ნებართვა უარყოფილია. ჩართეთ მოწყობილობის პარამეტრებში.';

  @override
  String get searchConnectionError => 'ძიება ვერ მოხერხდა - შეამოწმეთ კავშირი';

  @override
  String get selectLocation => 'აირჩიეთ მდებარეობა';

  @override
  String get searchCityHint => 'მოძებნე ქალაქი...';
}
