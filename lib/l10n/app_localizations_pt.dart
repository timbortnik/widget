// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Meteograma';

  @override
  String get temperature => 'Temperatura';

  @override
  String get precipitation => 'Precipitação';

  @override
  String get cloudCover => 'Cobertura de nuvens';

  @override
  String get now => 'Agora';

  @override
  String updatedAt(String time) {
    return 'Atualizado $time';
  }

  @override
  String minutesAgo(int count) {
    return 'há $count min';
  }

  @override
  String get justNow => 'Agora mesmo';

  @override
  String get refresh => 'Atualizar';

  @override
  String get settings => 'Configurações';

  @override
  String get location => 'Localização';

  @override
  String get currentLocation => 'Localização atual';

  @override
  String get setManually => 'Definir manualmente';

  @override
  String get errorNoConnection => 'Sem conexão com a internet';

  @override
  String get errorLocationUnavailable => 'Localização indisponível';

  @override
  String get errorLoadingData =>
      'Não foi possível carregar dados meteorológicos';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get offline => 'OFFLINE';

  @override
  String forecastHours(int hours) {
    return 'Previsão de $hours horas';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Máx $amount';
  }

  @override
  String maxDaylight(int percent) {
    return 'Máx $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/h';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Manual';

  @override
  String get daylight => 'Luz do dia';

  @override
  String weatherDataBy(String provider) {
    return 'Dados meteorológicos de $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Luz do dia calculada';

  @override
  String get sourceCode => 'Código aberto no GitHub (BSL 1.1)';

  @override
  String get offlineRefreshError =>
      'Não foi possível atualizar - mostrando dados em cache';

  @override
  String get loadingWeather => 'Carregando clima...';

  @override
  String get unableToLoadWeather => 'Não foi possível carregar o clima';

  @override
  String get unknownLocation => 'Desconhecido';

  @override
  String get gpsPermissionDenied =>
      'Permissão GPS negada. Ative nas configurações do dispositivo.';

  @override
  String get searchConnectionError =>
      'Não foi possível pesquisar - verifique sua conexão';

  @override
  String get selectLocation => 'Selecionar local';

  @override
  String get searchCityHint => 'Pesquisar cidade...';
}
