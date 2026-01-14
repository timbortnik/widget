// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Biểu đồ thời tiết';

  @override
  String get temperature => 'Nhiệt độ';

  @override
  String get precipitation => 'Lượng mưa';

  @override
  String get cloudCover => 'Mây che phủ';

  @override
  String get now => 'Hiện tại';

  @override
  String updatedAt(String time) {
    return 'Cập nhật $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String get justNow => 'Vừa xong';

  @override
  String get refresh => 'Làm mới';

  @override
  String get settings => 'Cài đặt';

  @override
  String get location => 'Vị trí';

  @override
  String get currentLocation => 'Vị trí hiện tại';

  @override
  String get setManually => 'Đặt thủ công';

  @override
  String get errorNoConnection => 'Không có kết nối internet';

  @override
  String get errorLocationUnavailable => 'Không thể xác định vị trí';

  @override
  String get errorLoadingData => 'Không thể tải dữ liệu thời tiết';

  @override
  String get retry => 'Thử lại';

  @override
  String get offline => 'NGOẠI TUYẾN';

  @override
  String forecastHours(int hours) {
    return 'Dự báo $hours giờ';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Tối đa $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Tối đa $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/giờ';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Thủ công';

  @override
  String get daylight => 'Ánh sáng ban ngày';

  @override
  String weatherDataBy(String provider) {
    return 'Dữ liệu thời tiết từ $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Ánh sáng tính toán';

  @override
  String get offlineRefreshError =>
      'Không thể làm mới - hiển thị dữ liệu đã lưu';

  @override
  String get loadingWeather => 'Đang tải thời tiết...';

  @override
  String get unableToLoadWeather => 'Không thể tải thời tiết';

  @override
  String get unknownLocation => 'Không xác định';

  @override
  String get gpsPermissionDenied =>
      'Quyền GPS bị từ chối. Bật trong cài đặt thiết bị.';

  @override
  String get searchConnectionError =>
      'Không thể tìm kiếm - kiểm tra kết nối của bạn';

  @override
  String get selectLocation => 'Chọn vị trí';

  @override
  String get searchCityHint => 'Tìm thành phố...';
}
