import 'dart:convert';
import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'weather_service.dart';
import 'location_service.dart';
import 'svg_chart_generator.dart';
import 'units_service.dart';
import '../models/weather_data.dart';

const String weatherUpdateTask = 'weatherUpdateTask';
const String periodicWeatherTask = 'periodicWeatherTask';
const String chartRenderTask = 'chartRenderTask';

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
        case chartRenderTask:
          await _reRenderCharts();
          return true;
        default:
          return true;
      }
    } catch (e) {
      return false;
    }
  });
}

/// Background callback for HomeWidget (handles native events)
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;

  switch (uri.host) {
    case 'weatherUpdate':
      // Fetch weather data if stale
      await _updateWeatherData();
      break;
    case 'chartReRender':
      // Re-render charts from cached data (no network call)
      await _reRenderCharts();
      break;
  }
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

    // Cache weather data and location for re-rendering
    await HomeWidget.saveWidgetData<String>(
      'cached_weather',
      jsonEncode(weather.toJson()),
    );
    await HomeWidget.saveWidgetData<double>('cached_latitude', location.latitude);

    // Save timestamp for staleness checks
    await HomeWidget.saveWidgetData<int>(
      'last_weather_update',
      DateTime.now().millisecondsSinceEpoch,
    );

    // Get locale preference from SharedPreferences
    final usesFahrenheit = await HomeWidget.getWidgetData<bool>('usesFahrenheit') ?? false;

    final currentHour = weather.getCurrentHour();
    final tempString = currentHour != null
        ? UnitsService.formatTemperatureFromBool(currentHour.temperature, usesFahrenheit)
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

/// Re-render charts from cached weather data (no network call).
/// Used for locale/timezone/theme changes where data doesn't need refreshing.
Future<void> _reRenderCharts() async {
  try {
    // Load cached weather data
    final cachedJson = await HomeWidget.getWidgetData<String>('cached_weather');
    if (cachedJson == null) {
      // No cached data available - can't re-render
      return;
    }

    final weather = WeatherData.fromJson(jsonDecode(cachedJson));
    final latitude = await HomeWidget.getWidgetData<double>('cached_latitude') ?? 0.0;

    // Regenerate SVG charts
    await _generateSvgCharts(weather, latitude);

    // Update widget
    await HomeWidget.updateWidget(
      androidName: 'MeteogramWidgetProvider',
      iOSName: 'MeteogramWidget',
    );
  } catch (e) {
    // Silently fail in background
  }
}

/// Generate SVG chart images for the widget.
Future<void> _generateSvgCharts(WeatherData weather, double latitude) async {
  try {
    final generator = SvgChartGenerator();
    final displayData = weather.getDisplayRange();
    final nowIndex = weather.getNowIndex();

    // Get widget dimensions, locale, and temperature unit preference
    final widthPx = await HomeWidget.getWidgetData<int>('widget_width_px') ?? 400;
    final heightPx = await HomeWidget.getWidgetData<int>('widget_height_px') ?? 200;
    final locale = await HomeWidget.getWidgetData<String>('locale') ?? 'en';
    final usesFahrenheit = await HomeWidget.getWidgetData<bool>('usesFahrenheit') ?? false;

    // Get persisted Material You colors (fall back to defaults if not set)
    final lightTempColor = await HomeWidget.getWidgetData<int>('material_you_light_temp');
    final lightTimeColor = await HomeWidget.getWidgetData<int>('material_you_light_time');
    final darkTempColor = await HomeWidget.getWidgetData<int>('material_you_dark_temp');
    final darkTimeColor = await HomeWidget.getWidgetData<int>('material_you_dark_time');

    // Apply Material You colors if available
    final lightColors = (lightTempColor != null && lightTimeColor != null)
        ? SvgChartColors.light.withDynamicColors(
            temperatureLine: SvgColor.fromArgb(lightTempColor),
            timeLabel: SvgColor.fromArgb(lightTimeColor),
          )
        : SvgChartColors.light;

    final darkColors = (darkTempColor != null && darkTimeColor != null)
        ? SvgChartColors.dark.withDynamicColors(
            temperatureLine: SvgColor.fromArgb(darkTempColor),
            timeLabel: SvgColor.fromArgb(darkTimeColor),
          )
        : SvgChartColors.dark;

    // Generate light and dark theme SVGs
    final svgLight = generator.generate(
      data: displayData,
      nowIndex: nowIndex,
      latitude: latitude,
      colors: lightColors,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      locale: locale,
      usesFahrenheit: usesFahrenheit,
    );

    final svgDark = generator.generate(
      data: displayData,
      nowIndex: nowIndex,
      latitude: latitude,
      colors: darkColors,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      locale: locale,
      usesFahrenheit: usesFahrenheit,
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
    // Initialize WorkManager for periodic tasks
    await Workmanager().initialize(callbackDispatcher);

    // Register HomeWidget background callback for native event handling
    await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
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
