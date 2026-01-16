# Home Screen Widget Implementation

## Overview

Using the `home_widget` package with native Android widget provider. The chart is rendered as SVG in Dart, then rendered natively using AndroidSVG library on the Android side. Both the widget and the in-app chart use the same SVG → AndroidSVG → Bitmap pipeline for pixel-perfect consistency.

See `docs/NATIVE_SVG_RENDERING.md` for detailed architecture.

## Critical: RemoteViews Limitations

Android `RemoteViews` only supports a limited set of views:
- ✅ `TextView`
- ✅ `ImageView`
- ✅ `LinearLayout`
- ✅ `RelativeLayout`
- ✅ `FrameLayout`
- ❌ `View` (not allowed)
- ❌ `Space` (not allowed)
- ❌ Custom views (not allowed)

**If you get "Can't load widget" error, check for unsupported views in the layout XML.**

## Package Setup

### pubspec.yaml
```yaml
dependencies:
  home_widget: ^0.4.0
  workmanager: ^0.5.0
  path_provider: ^2.0.0
```

## Android Configuration

### AndroidManifest.xml
```xml
<!-- Widget provider -->
<receiver android:name=".MeteogramWidgetProvider"
          android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/meteogram_widget_info" />
</receiver>

<!-- HomeWidget background callback support (required for event-driven refresh) -->
<receiver android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver"
          android:exported="true">
    <intent-filter>
        <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
    </intent-filter>
</receiver>

<service android:name="es.antonborri.home_widget.HomeWidgetBackgroundService"
         android:permission="android.permission.BIND_JOB_SERVICE"
         android:exported="false" />
```

### res/xml/meteogram_widget_info.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="150dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/meteogram_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:previewImage="@mipmap/ic_launcher">
</appwidget-provider>
```

### res/layout/meteogram_widget.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:theme="@style/WidgetTheme"
    android:background="?android:attr/colorBackground"
    android:alpha="0.85">

    <!-- Two chart ImageViews for automatic theme switching -->
    <ImageView android:id="@+id/widget_chart_light"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:scaleType="fitCenter"
        android:visibility="@integer/chart_light_visibility" />
    <ImageView android:id="@+id/widget_chart_dark"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:scaleType="fitCenter"
        android:visibility="@integer/chart_dark_visibility" />

    <!-- Placeholder when no chart available -->
    <TextView android:id="@+id/widget_placeholder"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:text="Tap to load forecast"
        android:visibility="gone" />

    <!-- Refresh indicator for resize -->
    <TextView android:id="@+id/widget_refresh_indicator"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:text="↻"
        android:textSize="64sp"
        android:textColor="?android:attr/textColorPrimary"
        android:visibility="gone" />
</FrameLayout>
```

### res/values/integers.xml (Light Mode)
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Visibility: 0=visible, 1=invisible, 2=gone -->
    <integer name="chart_light_visibility">0</integer>
    <integer name="chart_dark_visibility">2</integer>
</resources>
```

### res/values-night/integers.xml (Dark Mode)
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Visibility: 0=visible, 1=invisible, 2=gone -->
    <integer name="chart_light_visibility">2</integer>
    <integer name="chart_dark_visibility">0</integer>
</resources>
```

### res/drawable/widget_background.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape android:shape="rectangle">
    <gradient
        android:startColor="#E81B2838"
        android:endColor="#E80D1B2A"
        android:angle="135" />
    <corners android:radius="24dp" />
</shape>
```

### Widget Provider (Kotlin)
```kotlin
package com.example.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetProvider

class MeteogramWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.meteogram_widget)

            // Tap to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Update temperature
            val temperature = widgetData.getString("current_temperature", "--°")
            views.setTextViewText(R.id.widget_temperature, temperature)

            // Update location
            val location = widgetData.getString("location_name", "")
            views.setTextViewText(R.id.widget_location, location)

            // Update chart image
            val imagePath = widgetData.getString("meteogram_image", null)
            if (imagePath != null) {
                try {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_chart, bitmap)
                        views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_placeholder, View.GONE)
                    }
                } catch (e: Exception) {
                    // Keep placeholder visible
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
```

## Flutter Integration

### SVG Chart Generator (`lib/services/svg_chart_generator.dart`)
Pure Dart SVG generation - no Flutter UI dependencies, works in background isolates.

**CRITICAL: Transparent Background Requirement**
The SVG MUST NOT have a background fill. The widget layout uses `?android:attr/colorBackground` with 80% alpha to match system widgets (like Google Search bar). If the SVG has a solid background, it will:
- Override the system background color
- Break visual consistency with other widgets
- Prevent the translucent effect

The chart elements (temperature line, precipitation bars, daylight bars) are drawn directly on the transparent canvas.

```dart
class SvgChartGenerator {
  String generate({
    required List<HourlyData> data,
    required int nowIndex,
    required double latitude,
    required double longitude,
    required SvgChartColors colors,
    required double width,
    required double height,
    String locale = 'en',
  }) {
    // Generates complete SVG string with:
    // - NO background rect (transparent - uses system widget background)
    // - Temperature line with gradient fill
    // - Precipitation bars
    // - Daylight intensity bars (requires latitude + longitude for solar position)
    // - Temperature labels (min/mid/max)
    // - Time labels (locale-aware via DateFormat.j())
  }
}
```

### Widget Service (`lib/services/widget_service.dart`)
```dart
Future<void> generateAndSaveSvgCharts({
  required List<HourlyData> displayData,
  required int nowIndex,
  required double latitude,
  required double longitude,
  String locale = 'en',
}) async {
  final generator = SvgChartGenerator();
  final dimensions = await getWidgetDimensions();

  // Generate both light and dark theme SVGs
  final svgLight = generator.generate(
    data: displayData,
    latitude: latitude,
    longitude: longitude,
    colors: SvgChartColors.light,
    width: dimensions.widthPx,
    height: dimensions.heightPx,
    locale: locale,
  );

  final svgDark = generator.generate(
    data: displayData,
    latitude: latitude,
    longitude: longitude,
    colors: SvgChartColors.dark,
    // ... same dimensions
  );

  // Save SVG files using atomic writes (write to .tmp, then rename)
  // This prevents race conditions when native widget reads while Flutter writes
  await File('$lightPath.tmp').writeAsString(svgLight);
  await File('$darkPath.tmp').writeAsString(svgDark);
  await File('$lightPath.tmp').rename(lightPath);
  await File('$darkPath.tmp').rename(darkPath);

  // Store paths for native widget
  await HomeWidget.saveWidgetData<String>('svg_path_light', lightPath);
  await HomeWidget.saveWidgetData<String>('svg_path_dark', darkPath);
}
```

### In-App Chart Display (`lib/widgets/native_svg_chart_view.dart`)
Uses PlatformView to embed native ImageView, bypassing Flutter's compositor:
```dart
class NativeSvgChartView extends StatefulWidget {
  final String svgString;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'svg_chart_view',
      creationParams: {'svg': svgString, 'width': width, 'height': height},
    );
  }
}
```

## Background Refresh

### Periodic Updates (WorkManager)
```dart
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'weatherUpdateTask':
      case 'periodicWeatherTask':
        await _updateWeatherData();  // Fetch + render
        return true;
      case 'chartRenderTask':
        await _reRenderCharts();     // Render only, no fetch
        return true;
      default:
        return true;
    }
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      'periodicWeatherTask',
      'periodicWeatherTask',
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
```

### Event-Driven Refresh

The widget responds to system events via broadcast receivers.

#### Events Handled

| Event | Android Action | Registration | Response |
|-------|----------------|--------------|----------|
| Screen unlock | `ACTION_USER_PRESENT` | Runtime | Fetch if stale (>15 min) |
| Network restored | `CONNECTIVITY_CHANGE` | Runtime | Fetch if stale (>15 min) |
| Widget resize | `onAppWidgetOptionsChanged` | N/A | Re-render immediately |
| Locale change | `ACTION_LOCALE_CHANGED` | Manifest | Re-render (no fetch) |
| Timezone change | `ACTION_TIMEZONE_CHANGED` | Manifest | Re-render (no fetch) |
| Half-hour (:30) | `HourlyAlarmReceiver` | Manifest | Re-render (no fetch) |

**Important:** `LOCALE_CHANGED` and `TIMEZONE_CHANGED` use manifest-declared receivers because the app process is killed when locale/timezone changes. Runtime-registered receivers are lost when the process dies. These broadcasts are exempt from Android 8.0+ implicit broadcast restrictions.

#### Two-Operation Pattern

**Key design:** Separate weather fetching from chart rendering to minimize unnecessary API calls.

```dart
// HomeWidget background callback (handles native events)
// IMPORTANT: URI hosts are always lowercase!
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();  // Required for headless execution
  switch (uri?.host.toLowerCase()) {
    case 'weatherupdate':
      await _updateWeatherData();  // Fetch + cache + render
      break;
    case 'chartrerender':
      await _reRenderCharts(uri);  // Render from cache only (pass URI for params)
      break;
  }
}

// Re-render from cached data (no network call)
// URI params: width, height, locale (all optional, fallback to cached/Platform values)
Future<void> _reRenderCharts([Uri? uri]) async {
  // Extract params from URI (more reliable than Platform.localeName in cold-start)
  final uriWidth = int.tryParse(uri?.queryParameters['width'] ?? '');
  final uriHeight = int.tryParse(uri?.queryParameters['height'] ?? '');
  final uriLocale = uri?.queryParameters['locale'];

  final cachedJson = await HomeWidget.getWidgetData<String>('cached_weather');
  if (cachedJson == null) return;

  final weather = WeatherData.fromJson(jsonDecode(cachedJson));
  final latitude = await HomeWidget.getWidgetData<double>('cached_latitude') ?? 0.0;
  final longitude = await HomeWidget.getWidgetData<double>('cached_longitude') ?? 0.0;

  await _generateSvgCharts(weather, latitude, longitude,
    uriWidth: uriWidth, uriHeight: uriHeight, uriLocale: uriLocale);
  await HomeWidget.updateWidget(androidName: 'MeteogramWidgetProvider');
}
```

**CRITICAL: Locale Passing via URI**

`Platform.localeName` is stale in background isolates - it returns the locale from when the Flutter engine started, not the current system locale. When the system locale changes, native code must pass the current locale via URI query params:

```kotlin
// Native side: pass current locale in URI
val locale = java.util.Locale.getDefault()
val localeStr = "${locale.language}_${locale.country}"  // e.g., "en_US", "uk_UA"

HomeWidgetBackgroundIntent.getBroadcast(
    context,
    Uri.parse("homewidget://chartReRender?width=$widthPx&height=$heightPx&locale=$localeStr")
).send()
```

```dart
// Dart side: prefer URI locale over Platform.localeName
Locale systemLocale;
if (uriLocale != null && uriLocale.isNotEmpty) {
  final parts = uriLocale.split('_');
  systemLocale = parts.length >= 2
      ? Locale(parts[0], parts[1].toUpperCase())
      : Locale(parts[0]);
} else {
  systemLocale = _getSystemLocale();  // Fallback to Platform.localeName
}
final usesFahrenheit = UnitsService.usesFahrenheit(systemLocale);
```

#### Staleness Check (Native Side)

```kotlin
// WidgetEventReceiver.kt
private fun fetchWeatherIfStale(context: Context) {
    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val lastUpdate = prefs.getLong("last_weather_update", 0)
    val staleThreshold = 15 * 60 * 1000L // 15 minutes

    if (System.currentTimeMillis() - lastUpdate > staleThreshold) {
        triggerWeatherFetch(context)  // Via HomeWidgetBackgroundIntent
    }
}
```

#### Android Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     MeteogramApplication                      │
│  Registers WidgetEventReceiver at runtime for:                │
│  - USER_PRESENT, CONNECTIVITY_CHANGE (require runtime reg)    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     AndroidManifest.xml                       │
│  Declares WidgetEventReceiver for:                            │
│  - LOCALE_CHANGED, TIMEZONE_CHANGED (app killed on change)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    WidgetEventReceiver                        │
│  Handles: USER_PRESENT, CONNECTIVITY_CHANGE (runtime)         │
│           LOCALE_CHANGED, TIMEZONE_CHANGED (manifest)         │
│  Actions: fetchWeatherIfStale() or triggerReRender()          │
│  Passes: width, height, locale via URI query params           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              HomeWidgetBackgroundIntent                       │
│  URI: homewidget://chartReRender?width=X&height=Y&locale=Z    │
│  URI: homewidget://weatherUpdate                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                background_service.dart                        │
│  homeWidgetBackgroundCallback() → _updateWeatherData() or     │
│                                   _reRenderCharts(uri)        │
│  Parses URI params for dimensions and locale                  │
└─────────────────────────────────────────────────────────────┘
```

**Broadcast Registration Notes:**
- `USER_PRESENT`, `CONNECTIVITY_CHANGE`: Require runtime registration (Android 8.0+ restriction)
- `LOCALE_CHANGED`, `TIMEZONE_CHANGED`: Use manifest declaration (app process killed on change, runtime receivers lost; these are exempt from 8.0+ restrictions)

#### Half-Hour Alarm for "Now" Indicator

The "now" indicator snaps to the nearest hour at the 30-minute mark (e.g., 2:29 shows "now" at 2:00, 2:30 shows "now" at 3:00). The widget uses `AlarmManager` to re-render the chart at XX:30 when this snap occurs.

**Buffer + Verification Approach:**
To ensure the alarm fires AFTER the :30 boundary:

1. Schedule alarm for XX:30:15 (15-second buffer after the half-hour)
2. When alarm fires, verify minute >= 30 (past the :30 boundary)
3. If fired early (minute < 30), reschedule for the next half-hour

```kotlin
// HourlyAlarmReceiver.kt
private const val HOUR_BUFFER_SECONDS = 15

fun scheduleNextAlarm(context: Context) {
    val calendar = Calendar.getInstance().apply {
        val currentMinute = get(Calendar.MINUTE)
        if (currentMinute < 30) {
            set(Calendar.MINUTE, 30)
        } else {
            set(Calendar.MINUTE, 30)
            add(Calendar.HOUR_OF_DAY, 1)
        }
        set(Calendar.SECOND, HOUR_BUFFER_SECONDS)
    }
    alarmManager.setWindow(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, windowMs, pendingIntent)
}

fun handleHourlyUpdate(context: Context) {
    val minute = Calendar.getInstance().get(Calendar.MINUTE)
    if (minute < 30) {
        // Fired early - reschedule
        scheduleNextAlarm(context)
        return
    }
    // Safe to re-render
    triggerChartReRender(context)
    scheduleNextAlarm(context)
}
```

The alarm triggers `chartReRender` (no weather fetch), updating only the "now" indicator position. Additionally, `USER_PRESENT` always re-renders to ensure the indicator is current when users unlock their phone.

### main.dart setup
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.initialize();
  await BackgroundService.registerPeriodicTask();
  runApp(const MyApp());
}
```

## Data Flow

1. **App loads weather** from Open-Meteo API
2. **SVG generated** in Dart via `SvgChartGenerator` (both light AND dark themes)
3. **SVG files saved** to app documents folder (`meteogram_light.svg`, `meteogram_dark.svg`)
4. **Widget data saved** via HomeWidget.saveWidgetData → SharedPreferences (SVG paths)
5. **Native provider** reads SVG, renders via AndroidSVG → Bitmap → ImageView
6. **In-app display** uses same pipeline via PlatformView (AndroidView)
7. **Theme switching** handled automatically by Android resource system

**Key benefit:** SVG generation works in background isolates (no Flutter UI required), enabling true background updates.

## Automatic Theme Switching

Android widgets cannot receive `ACTION_CONFIGURATION_CHANGED` when the app is not running. Solution: dual bitmaps with night-qualified resources.

### How It Works
1. **Flutter renders both themes** - Light and dark charts are captured on every update
2. **Widget has two ImageViews** - One for light (`widget_chart_light`), one for dark (`widget_chart_dark`)
3. **Visibility via resources** - `values/integers.xml` shows light, `values-night/integers.xml` shows dark
4. **Launcher handles switching** - When system theme changes, launcher re-inflates widget with new visibility values

### Color System
```dart
// lib/theme/app_theme.dart
class MeteogramColors {
  static const light = MeteogramColors(
    temperatureLine: Color(0xFFFF6B6B),
    precipitationBar: Color(0xFF4ECDC4),
    // ... full palette for light theme
  );

  static const dark = MeteogramColors(
    temperatureLine: Color(0xFFFF7675),
    precipitationBar: Color(0xFF00CEC9),
    // ... full palette for dark theme
  );
}
```

### Trade-off
Doubles storage (two PNG files instead of one), but enables instant theme switching without any app code running.

## Daylight Calculation

The meteogram displays daylight intensity as yellow bars, calculated using scientifically-grounded formulas.

### Solar Elevation (Astronomical)

Sun's angle above the horizon, based on latitude, longitude, time of day, and day of year:

```
δ = 23.45° × sin(360/365 × (284 + dayOfYear))   // Solar declination
solarHour = utcHour + longitude/15              // Convert UTC to local solar time
h = 15° × (solarHour - 12)                      // Hour angle
sin(α) = sin(lat)×sin(δ) + cos(lat)×cos(δ)×cos(h)  // Elevation angle
```

**Longitude correction:** Solar noon (when h=0) occurs at 12:00 local solar time, not 12:00 UTC. For every 15° of longitude east, solar noon shifts 1 hour earlier in UTC. For example:
- At longitude 0° (Greenwich): solar noon at 12:00 UTC
- At longitude 30°E (Kyiv): solar noon at ~10:00 UTC
- At longitude 120°E (Beijing): solar noon at ~04:00 UTC

- α < -6°: Below civil twilight (no visible light)
- α = 0°: Sunrise/sunset (~400-800 lux)
- α = 90°: Sun directly overhead (~130,000 lux)

Reference: Meeus, J. (1991). *Astronomical Algorithms*. Willmann-Bell.

### Clear-Sky Illuminance (Atmospheric Model)

The simple `elevation / 90°` formula gives zero light at sunrise/sunset, which is incorrect. Instead, we use an atmospheric model that accounts for optical air mass:

```dart
// Atmospheric refraction constant
x = 753.66156

// Optical air mass calculation
s = arcsin((x × cos(elevation)) / (x + 1))
m = x × (cos(s) - sin(elevation)) + cos(s)

// Illuminance with atmospheric extinction
factor = exp(-0.2 × m) × sin(elevation) +
         0.0289 × exp(-0.042 × m) × (1 + (elevation + 90) × sin(elevation) / 57.3)

illuminance = 133775 × factor  // Result in lux
```

| Solar Elevation | Clear-Sky Illuminance |
|-----------------|----------------------|
| -6° (civil twilight) | 0 lux |
| 0° (sunrise/sunset) | ~400-800 lux |
| 30° | ~60,000 lux |
| 60° | ~100,000 lux |
| 90° (zenith) | ~130,000 lux |

Reference: Kasten, F. & Young, A.T. (1989). "Revised optical air mass tables and approximation formula." *Applied Optics*, 28(22), 4735-4738.

Implementation based on: ha-illuminance project https://github.com/pnbruckner/ha-illuminance

### Cloud Attenuation (ha-illuminance model)

Logarithmic model from the ha-illuminance project, designed for perceived brightness rather than solar irradiance:

```
divisor = 10^(cloudCover / 100)
factor = 1 / divisor
```

| Cloud Cover | Light Factor |
|-------------|--------------|
| 0% | 100% |
| 50% | 32% |
| 75% | 18% |
| 100% | 10% |

More aggressive than irradiance-based formulas (like Kasten & Czeplak), better matching perceived brightness reduction from cloud cover.

Reference: ha-illuminance project https://github.com/pnbruckner/ha-illuminance

### Precipitation Attenuation

Based on extinction coefficient research relating meteorological optical range (MOR) to rainfall rate:

```
σ = a × R^b        (extinction coefficient)
MOR = 3/σ          (Koschmieder's law)
```

Simplified to a divisor formula:

```
divisor = 1 + 0.5 × R^0.6
```

Where R is precipitation in mm/h.

| Precipitation | Divisor | Light Factor |
|---------------|---------|--------------|
| 0 mm/h | 1.0 | 100% |
| 1 mm/h (light) | 1.5 | 67% |
| 5 mm/h (moderate) | 2.5 | 40% |
| 10 mm/h (heavy) | 3.0 | 33% |
| 20 mm/h (very heavy) | 3.9 | 26% |

Reference: Rainfall-MOR relationship studies, e.g., https://doi.org/10.20937/ATM.53297

### Combined Formula

```dart
// Clear-sky illuminance from atmospheric model (0 to ~130,000 lux)
clearSkyLux = _clearSkyIlluminance(solarElevation)

// Normalize to 0-1 range
potential = clearSkyLux / 130000

// Cloud attenuation (ha-illuminance logarithmic model)
cloudDivisor = 10^(cloudCover / 100)

// Precipitation attenuation (extinction coefficient model)
precipDivisor = 1 + 0.5 × R^0.6

// Combined attenuation
linear = potential / cloudDivisor / precipDivisor

// Square root scale for display (makes small values visible)
scaled = sqrt(linear)
```

The square root scaling provides a gentle boost to small values so winter/overcast conditions remain visible.

## Debugging

### Logcat Commands
```bash
# Widget errors
adb logcat | grep -i "MeteogramWidget"

# Layout inflation errors
adb logcat | grep -i "Error inflating"

# Home widget messages
adb logcat | grep -i "HomeWidget"
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Can't load widget" | Unsupported view in layout | Remove View/Space elements |
| Widget shows placeholder | Image path not saved | Check saveWidgetData call |
| Temperature shows "--°" | No weather data | Check API call |
| Widget not updating | WorkManager not registered | Call registerPeriodicTask |

## iOS Widget (Not Implemented)

iOS widget extension would require:
1. Create WidgetKit extension in Xcode
2. Add App Groups capability
3. Implement TimelineProvider in Swift
4. Share data via UserDefaults with shared app group

The current implementation focuses on Android.
