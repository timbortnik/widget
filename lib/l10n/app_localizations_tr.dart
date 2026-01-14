// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Meteogram';

  @override
  String get temperature => 'Sıcaklık';

  @override
  String get precipitation => 'Yağış';

  @override
  String get cloudCover => 'Bulutluluk';

  @override
  String get now => 'Şimdi';

  @override
  String updatedAt(String time) {
    return '$time güncellendi';
  }

  @override
  String minutesAgo(int count) {
    return '$count dk önce';
  }

  @override
  String get justNow => 'Az önce';

  @override
  String get refresh => 'Yenile';

  @override
  String get settings => 'Ayarlar';

  @override
  String get location => 'Konum';

  @override
  String get currentLocation => 'Mevcut konum';

  @override
  String get setManually => 'Manuel ayarla';

  @override
  String get errorNoConnection => 'İnternet bağlantısı yok';

  @override
  String get errorLocationUnavailable => 'Konum kullanılamıyor';

  @override
  String get errorLoadingData => 'Hava durumu verileri yüklenemedi';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get offline => 'ÇEVRİMDIŞI';

  @override
  String forecastHours(int hours) {
    return '$hours saatlik tahmin';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Maks $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Maks $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/sa';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manuel';

  @override
  String get daylight => 'Gün ışığı';

  @override
  String weatherDataBy(String provider) {
    return '$provider hava durumu verileri (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Gün ışığı hesaplanmış';

  @override
  String get offlineRefreshError =>
      'Yenilenemiyor - önbelleğe alınmış veriler gösteriliyor';

  @override
  String get loadingWeather => 'Hava durumu yükleniyor...';

  @override
  String get unableToLoadWeather => 'Hava durumu yüklenemiyor';

  @override
  String get unknownLocation => 'Bilinmiyor';

  @override
  String get gpsPermissionDenied =>
      'GPS izni reddedildi. Cihaz ayarlarından etkinleştirin.';

  @override
  String get searchConnectionError =>
      'Arama yapılamıyor - bağlantınızı kontrol edin';

  @override
  String get selectLocation => 'Konum seçin';

  @override
  String get searchCityHint => 'Şehir ara...';
}
