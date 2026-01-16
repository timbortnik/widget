import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../constants.dart';
import '../utils/locale_utils.dart';
import 'weather_service.dart';
import 'location_service.dart';
import 'svg_chart_generator.dart';
import 'units_service.dart';
import 'widget_service.dart' show kLightSvgFileName, kDarkSvgFileName;
import '../models/weather_data.dart';

void _log(String message) {
  developer.log(message, name: 'BackgroundService');
}

/// Get current system locale from Platform.localeName.
/// Returns Locale with language and country code (e.g., en_US -> Locale('en', 'US'))
Locale _getSystemLocale() {
  final localeName = Platform.localeName;
  _log('System locale: $localeName');
  return LocaleUtils.getSystemLocale();
}

// Default fallback dimensions - must match WidgetUtils.kt
const int kDefaultWidthPx = 1000;
const int kDefaultHeightPx = 500;

/// Background callback for HomeWidget (handles native events)
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  // Initialize Flutter bindings for headless execution
  WidgetsFlutterBinding.ensureInitialized();
  _log('homeWidgetBackgroundCallback called with uri: $uri');

  if (uri == null) {
    _log('homeWidgetBackgroundCallback: uri is null');
    return;
  }

  _log('homeWidgetBackgroundCallback: host=${uri.host}');
  // Note: URI host is always lowercase
  switch (uri.host.toLowerCase()) {
    case 'weatherupdate':
      // Fetch weather data if stale
      _log('homeWidgetBackgroundCallback: executing weatherUpdate');
      await _updateWeatherData();
      break;
    case 'chartrerender':
      // Re-render charts from cached data (no network call)
      // Dimensions may be passed in URI query params for cold-start reliability
      _log('homeWidgetBackgroundCallback: executing chartReRender');
      await _reRenderCharts(uri);
      break;
    default:
      _log('homeWidgetBackgroundCallback: unknown host ${uri.host}');
  }
}

/// Update weather data in background
Future<void> _updateWeatherData() async {
  _log('_updateWeatherData started');

  // Initialize locale data for DateFormat (required in background isolate)
  await initializeDateFormatting();

  final locationService = LocationService();
  final weatherService = WeatherService();

  try {
    _log('Getting location...');
    final location = await locationService.getLocation();
    _log('Location: ${location.latitude}, ${location.longitude} (${location.city})');

    _log('Fetching weather...');
    final weather = await weatherService.fetchWeatherWithRetry(
      location.latitude,
      location.longitude,
    );
    _log('Weather fetched: ${weather.hourly.length} hours');

    // Cache weather data and location for re-rendering
    await HomeWidget.saveWidgetData<String>(
      'cached_weather',
      jsonEncode(weather.toJson()),
    );
    await HomeWidget.saveWidgetData<double>('cached_latitude', location.latitude);
    await HomeWidget.saveWidgetData<double>('cached_longitude', location.longitude);

    // Save timestamp for staleness checks
    await HomeWidget.saveWidgetData<int>(
      'last_weather_update',
      DateTime.now().millisecondsSinceEpoch,
    );
    _log('Cached weather data and timestamp');

    // Get current system locale for temperature formatting
    final systemLocale = _getSystemLocale();
    final usesFahrenheit = UnitsService.usesFahrenheit(systemLocale);
    _log('Using locale: ${systemLocale.toLanguageTag()}, usesFahrenheit: $usesFahrenheit');

    final currentHour = weather.getCurrentHour();
    final tempString = currentHour != null
        ? UnitsService.formatTemperatureFromBool(currentHour.temperature, usesFahrenheit)
        : '--°';

    await HomeWidget.saveWidgetData<String>('current_temperature', tempString);
    await HomeWidget.saveWidgetData<String>('location_name', location.city ?? '');
    _log('Saved temperature: $tempString');

    // Generate SVG charts for widget display
    _log('Generating SVG charts...');
    await _generateSvgCharts(weather, location.latitude, location.longitude);
    _log('SVG charts generated');

    _log('Updating widget...');
    await HomeWidget.updateWidget(
      androidName: 'MeteogramWidgetProvider',
      iOSName: 'MeteogramWidget',
    );
    _log('Widget updated successfully');
  } catch (e, stack) {
    _log('_updateWeatherData failed: $e\n$stack');
    rethrow; // Propagate error so WorkManager knows task failed and can retry
  }
}

/// Re-render charts from cached weather data (no network call).
/// Used for locale/timezone/theme changes where data doesn't need refreshing.
/// Dimensions and locale can be passed in URI query params for cold-start reliability.
/// If cached data is stale (>15 min old), fetches fresh data instead.
Future<void> _reRenderCharts([Uri? uri]) async {
  _log('_reRenderCharts started with uri: $uri');

  // Extract params from URI if provided (more reliable than SharedPreferences/Platform in cold-start)
  int? uriWidth;
  int? uriHeight;
  String? uriLocale;
  if (uri != null) {
    uriWidth = int.tryParse(uri.queryParameters['width'] ?? '');
    uriHeight = int.tryParse(uri.queryParameters['height'] ?? '');
    uriLocale = uri.queryParameters['locale'];
    _log('_reRenderCharts: URI dimensions=${uriWidth}x$uriHeight, locale=$uriLocale');
  }

  try {
    // Initialize locale data for DateFormat (required in background isolate)
    await initializeDateFormatting();

    // Check if cached data is stale (>15 minutes old)
    final lastUpdate = await HomeWidget.getWidgetData<int>('last_weather_update') ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    final staleThresholdMs = kWeatherStalenessThreshold.inMilliseconds;

    if (ageMs > staleThresholdMs) {
      _log('_reRenderCharts: cached data is stale (${ageMs ~/ 60000} min old), fetching fresh data');
      await _updateWeatherData();
      return;
    }

    // Load cached weather data
    final cachedJson = await HomeWidget.getWidgetData<String>('cached_weather');
    if (cachedJson == null) {
      _log('_reRenderCharts: no cached weather data, fetching fresh');
      await _updateWeatherData();
      return;
    }

    final weather = WeatherData.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
    final latitude = await HomeWidget.getWidgetData<double>('cached_latitude') ?? 0.0;
    final longitude = await HomeWidget.getWidgetData<double>('cached_longitude') ?? 0.0;
    final nowIndex = weather.getNowIndex();
    _log('_reRenderCharts: loaded weather with ${weather.hourly.length} hours, nowIndex=$nowIndex (${ageMs ~/ 60000} min old)');

    // Regenerate SVG charts (pass URI params if available)
    await _generateSvgCharts(weather, latitude, longitude, uriWidth: uriWidth, uriHeight: uriHeight, uriLocale: uriLocale);

    // Update widget
    await HomeWidget.updateWidget(
      androidName: 'MeteogramWidgetProvider',
      iOSName: 'MeteogramWidget',
    );
    _log('_reRenderCharts: widget updated');
  } catch (e, stack) {
    _log('_reRenderCharts failed: $e\n$stack');
    rethrow; // Propagate error for proper failure handling
  }
}

/// Generate SVG chart images for the widget.
/// Optional uriWidth/uriHeight/uriLocale can be passed for cold-start reliability.
Future<void> _generateSvgCharts(WeatherData weather, double latitude, double longitude, {int? uriWidth, int? uriHeight, String? uriLocale}) async {
  try {
    final generator = SvgChartGenerator();
    final displayData = weather.getDisplayRange();
    final nowIndex = weather.getNowIndex();

    // Get widget dimensions - prefer URI params (reliable in cold-start),
    // fall back to SharedPreferences, then defaults
    var widthPx = uriWidth ?? await HomeWidget.getWidgetData<int>('widget_width_px') ?? 0;
    var heightPx = uriHeight ?? await HomeWidget.getWidgetData<int>('widget_height_px') ?? 0;
    // Ensure valid dimensions (0 means not set)
    if (widthPx <= 0) widthPx = kDefaultWidthPx;
    if (heightPx <= 0) heightPx = kDefaultHeightPx;
    _log('_generateSvgCharts: using dimensions=${widthPx}x$heightPx (uri=${uriWidth}x$uriHeight)');

    // Get locale - prefer URI param (reliable when native passes it), fallback to Platform.localeName
    Locale systemLocale;
    if (uriLocale != null && uriLocale.isNotEmpty) {
      // Parse locale from URI (format: "en_US" or "uk_UA")
      final parts = uriLocale.split('_').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        systemLocale = Locale(parts[0], parts[1].toUpperCase());
      } else if (parts.isNotEmpty) {
        systemLocale = Locale(parts[0]);
      } else {
        systemLocale = const Locale('en');
      }
      _log('_generateSvgCharts: using URI locale: $uriLocale -> $systemLocale');
    } else {
      systemLocale = _getSystemLocale();
      _log('_generateSvgCharts: using Platform locale: $systemLocale');
    }
    final locale = systemLocale.toLanguageTag();
    final usesFahrenheit = UnitsService.usesFahrenheit(systemLocale);
    _log('_generateSvgCharts: locale=$locale, usesFahrenheit=$usesFahrenheit');

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
      longitude: longitude,
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
      longitude: longitude,
      colors: darkColors,
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
      locale: locale,
      usesFahrenheit: usesFahrenheit,
    );

    // Save SVG files to app documents directory using atomic writes
    // (write to temp file, then rename to avoid race conditions with native reader)
    final docsDir = await getApplicationDocumentsDirectory();
    final lightPath = '${docsDir.path}/$kLightSvgFileName';
    final darkPath = '${docsDir.path}/$kDarkSvgFileName';
    final lightTempPath = '${docsDir.path}/$kLightSvgFileName.tmp';
    final darkTempPath = '${docsDir.path}/$kDarkSvgFileName.tmp';

    _log('Writing SVG files to $lightPath');

    // Write to temp files first
    await File(lightTempPath).writeAsString(svgLight);
    await File(darkTempPath).writeAsString(svgDark);

    // Atomic rename to final paths
    await File(lightTempPath).rename(lightPath);
    await File(darkTempPath).rename(darkPath);

    _log('SVG files written successfully');

    // Store paths for native widget to read
    await HomeWidget.saveWidgetData<String>('svg_path_light', lightPath);
    await HomeWidget.saveWidgetData<String>('svg_path_dark', darkPath);
  } catch (e, stack) {
    _log('_generateSvgCharts failed: $e\n$stack');

    // Clean up orphaned temp files on failure
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      await File('${docsDir.path}/$kLightSvgFileName.tmp').delete();
      await File('${docsDir.path}/$kDarkSvgFileName.tmp').delete();
    } catch (_) {
      // Ignore cleanup errors (files may not exist)
    }

    rethrow; // Propagate error so caller knows chart generation failed
  }
}

/// Initialize background service
class BackgroundService {
  static Future<void> initialize() async {
    // Register HomeWidget background callback for native event handling
    // Note: Periodic weather updates are handled by native HourlyAlarmReceiver
    await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  }
}
