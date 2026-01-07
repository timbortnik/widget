import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'weather_service.dart';
import 'location_service.dart';
import 'svg_chart_generator.dart';

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
    final weather = await weatherService.fetchWeatherWithRetry(
      location.latitude,
      location.longitude,
    );

    final currentHour = weather.getCurrentHour();
    final tempString = currentHour != null
        ? '${currentHour.temperature.round()}°'
        : '--°';

    await HomeWidget.saveWidgetData<String>('current_temperature', tempString);
    await HomeWidget.saveWidgetData<String>('location_name', location.city ?? '');

    // Generate SVG charts for widget display
    await _generateSvgCharts(weather, location.latitude);

    await HomeWidget.updateWidget(
      androidName: 'MeteogramWidgetProvider',
      iOSName: 'MeteogramWidget',
    );
  } catch (e) {
    // Silently fail in background
  }
}

/// Generate SVG chart images for the widget.
Future<void> _generateSvgCharts(dynamic weather, double latitude) async {
  try {
    final generator = SvgChartGenerator();
    final displayData = weather.getDisplayRange();
    final nowIndex = weather.getNowIndex();

    // Get widget dimensions and time format preference
    final widthPx = await HomeWidget.getWidgetData<int>('widget_width_px') ?? 400;
    final heightPx = await HomeWidget.getWidgetData<int>('widget_height_px') ?? 200;
    final use24Hour = await HomeWidget.getWidgetData<bool>('use_24_hour_format') ?? false;

    // Generate light and dark theme SVGs
    final svgLight = generator.generate(
      data: displayData,
      nowIndex: nowIndex,
      latitude: latitude,
      colors: SvgChartColors.light,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      use24HourFormat: use24Hour,
    );

    final svgDark = generator.generate(
      data: displayData,
      nowIndex: nowIndex,
      latitude: latitude,
      colors: SvgChartColors.dark,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      use24HourFormat: use24Hour,
    );

    // Save SVG files to app documents directory
    final docsDir = await getApplicationDocumentsDirectory();
    final lightPath = '${docsDir.path}/meteogram_light.svg';
    final darkPath = '${docsDir.path}/meteogram_dark.svg';

    await File(lightPath).writeAsString(svgLight);
    await File(darkPath).writeAsString(svgDark);

    // Store paths for native widget to read
    await HomeWidget.saveWidgetData<String>('svg_path_light', lightPath);
    await HomeWidget.saveWidgetData<String>('svg_path_dark', darkPath);
  } catch (e) {
    // SVG generation failed - widget will use previous chart or fallback
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
