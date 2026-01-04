import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'weather_service.dart';
import 'location_service.dart';

const String weatherUpdateTask = 'weatherUpdateTask';
const String periodicWeatherTask = 'periodicWeatherTask';

/// Background task dispatcher for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case weatherUpdateTask:
        case periodicWeatherTask:
          await _updateWeatherData();
          return true;
        default:
          return true;
      }
    } catch (e) {
      return false;
    }
  });
}

/// Update weather data in background
Future<void> _updateWeatherData() async {
  final locationService = LocationService();
  final weatherService = WeatherService();

  try {
    final location = await locationService.getLocation();
    final weather = await weatherService.fetchWeather(
      location.latitude,
      location.longitude,
    );

    final currentHour = weather.getCurrentHour();
    final tempString = currentHour != null
        ? '${currentHour.temperature.round()}°'
        : '--°';

    await HomeWidget.saveWidgetData<String>('current_temperature', tempString);
    await HomeWidget.saveWidgetData<String>('location_name', location.city ?? '');

    await HomeWidget.updateWidget(
      androidName: 'MeteogramWidgetProvider',
      iOSName: 'MeteogramWidget',
    );
  } catch (e) {
    // Silently fail in background
  }
}

/// Initialize background service
class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      periodicWeatherTask,
      periodicWeatherTask,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
