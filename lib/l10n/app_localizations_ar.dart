// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مخطط الطقس';

  @override
  String get temperature => 'درجة الحرارة';

  @override
  String get precipitation => 'هطول الأمطار';

  @override
  String get cloudCover => 'الغطاء السحابي';

  @override
  String get now => 'الآن';

  @override
  String updatedAt(String time) {
    return 'تم التحديث $time';
  }

  @override
  String minutesAgo(int count) {
    return 'منذ $count دقيقة';
  }

  @override
  String get justNow => 'الآن';

  @override
  String get refresh => 'تحديث';

  @override
  String get settings => 'الإعدادات';

  @override
  String get location => 'الموقع';

  @override
  String get currentLocation => 'الموقع الحالي';

  @override
  String get setManually => 'تعيين يدوياً';

  @override
  String get errorNoConnection => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorLocationUnavailable => 'الموقع غير متاح';

  @override
  String get errorLoadingData => 'تعذر تحميل بيانات الطقس';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get offline => 'غير متصل';

  @override
  String forecastHours(int hours) {
    return 'توقعات $hours ساعة';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'الحد الأقصى $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'الحد الأقصى $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount مم/ساعة';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'يدوي';

  @override
  String get daylight => 'ضوء النهار';

  @override
  String weatherDataBy(String provider) {
    return 'بيانات الطقس من $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'ضوء النهار محسوب';

  @override
  String get sourceCode => 'مفتوح المصدر على GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError =>
      'تعذر التحديث - يتم عرض البيانات المخزنة مؤقتًا';

  @override
  String get loadingWeather => 'جارٍ تحميل الطقس...';

  @override
  String get unableToLoadWeather => 'تعذر تحميل الطقس';

  @override
  String get unknownLocation => 'غير معروف';

  @override
  String get gpsPermissionDenied =>
      'تم رفض إذن GPS. قم بتمكينه في إعدادات الجهاز.';

  @override
  String get searchConnectionError => 'تعذر البحث - تحقق من اتصالك';

  @override
  String get selectLocation => 'اختر الموقع';

  @override
  String get searchCityHint => 'ابحث عن مدينة...';
}
