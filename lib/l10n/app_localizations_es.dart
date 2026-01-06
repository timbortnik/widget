// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Meteograma';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Precipitación';

  @override
  String get cloudCover => 'Nubosidad';

  @override
  String get now => 'Ahora';

  @override
  String updatedAt(String time) {
    return 'Actualizado $time';
  }

  @override
  String minutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String get justNow => 'Ahora mismo';

  @override
  String get refresh => 'Actualizar';

  @override
  String get settings => 'Ajustes';

  @override
  String get location => 'Ubicación';

  @override
  String get currentLocation => 'Ubicación actual';

  @override
  String get setManually => 'Establecer manualmente';

  @override
  String get errorNoConnection => 'Sin conexión a internet';

  @override
  String get errorLocationUnavailable => 'Ubicación no disponible';

  @override
  String get errorLoadingData => 'No se pudieron cargar los datos del tiempo';

  @override
  String get retry => 'Reintentar';

  @override
  String get offline => 'SIN CONEXIÓN';

  @override
  String forecastHours(int hours) {
    return 'Pronóstico de $hours horas';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Máx $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Máx $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceIp => 'Ubicación IP';

  @override
  String get locationSourceManual => 'Manual';

  @override
  String get daylight => 'Luz diurna';

  @override
  String weatherDataBy(String provider) {
    return 'Datos meteorológicos de $provider';
  }
}
