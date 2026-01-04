// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Метеограма';

  @override
  String get temperature => 'Температура';

  @override
  String get precipitation => 'Опади';

  @override
  String get cloudCover => 'Хмарність';

  @override
  String get now => 'Зараз';

  @override
  String updatedAt(String time) {
    return 'Оновлено $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count хв тому';
  }

  @override
  String get justNow => 'Щойно';

  @override
  String get refresh => 'Оновити';

  @override
  String get settings => 'Налаштування';

  @override
  String get location => 'Місцезнаходження';

  @override
  String get currentLocation => 'Поточне місце';

  @override
  String get setManually => 'Вказати вручну';

  @override
  String get errorNoConnection => 'Немає з\'єднання з інтернетом';

  @override
  String get errorLocationUnavailable => 'Місцезнаходження недоступне';

  @override
  String get errorLoadingData => 'Не вдалося завантажити дані погоди';

  @override
  String get retry => 'Повторити';
}
