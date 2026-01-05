# Home Screen Widget Implementation

## Overview

Using the `home_widget` package with native Android widget provider. The chart is captured as a PNG image from Flutter and displayed in the native widget using `RemoteViews`.

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
<receiver android:name=".MeteogramWidgetProvider"
          android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/meteogram_widget_info" />
</receiver>
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

### Widget Service
```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../models/weather_data.dart';

class WidgetService {
  /// Save chart image to app documents folder
  Future<String?> saveChartImage(Uint8List imageBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/meteogram_chart.png');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Update widget with weather data and chart image
  Future<void> updateWidget({
    required WeatherData weatherData,
    required String? locationName,
    String? chartImagePath,
  }) async {
    final currentHour = weatherData.getCurrentHour();
    final tempString = currentHour != null
        ? '${currentHour.temperature.round()}°'
        : '--°';

    await HomeWidget.saveWidgetData<String>('current_temperature', tempString);
    await HomeWidget.saveWidgetData<String>('location_name', locationName ?? '');

    if (chartImagePath != null) {
      await HomeWidget.saveWidgetData<String>('meteogram_image', chartImagePath);
    }

    await HomeWidget.updateWidget(
      androidName: 'MeteogramWidgetProvider',
      iOSName: 'MeteogramWidget',
    );
  }
}
```

### Chart Capture (in HomeScreen)
```dart
final _chartKey = GlobalKey();

// In build method - wrap chart with RepaintBoundary
RepaintBoundary(
  key: _chartKey,
  child: MeteogramChart(data: displayData),
)

// Capture method
Future<String?> _captureChart() async {
  try {
    await Future.delayed(const Duration(milliseconds: 500));

    final boundary = _chartKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    return _widgetService.saveChartImage(byteData.buffer.asUint8List());
  } catch (e) {
    debugPrint('Error capturing chart: $e');
    return null;
  }
}
```

## Background Refresh

### Background Service (Flutter)
```dart
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _updateWeatherData();
      return true;
    } catch (e) {
      return false;
    }
  });
}

Future<void> _updateWeatherData() async {
  final locationService = LocationService();
  final weatherService = WeatherService();
  final widgetService = WidgetService();

  final location = await locationService.getLocation();
  final weather = await weatherService.fetchWeather(
    location.latitude,
    location.longitude,
  );

  await widgetService.updateWidget(
    weatherData: weather,
    locationName: location.isGps ? null : 'Berlin',
    chartImagePath: null, // Background can't capture UI
  );
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      'periodicWeatherTask',
      'periodicWeatherTask',
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
```

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
2. **Chart renders** in Flutter using fl_chart (both light AND dark themes)
3. **Charts captured** via RepaintBoundary → toImage() → PNG bytes (2 images)
4. **Images saved** to app documents folder (`meteogram_chart_light.png`, `meteogram_chart_dark.png`)
5. **Widget data saved** via HomeWidget.saveWidgetData → SharedPreferences
6. **Native provider** loads both bitmaps into respective ImageViews
7. **Theme switching** handled automatically by Android resource system

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
