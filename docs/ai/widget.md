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
<LinearLayout android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="@drawable/widget_background">

    <!-- Header: Temperature + Location using RelativeLayout for positioning -->
    <RelativeLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content">

        <TextView android:id="@+id/widget_temperature"
            android:layout_alignParentStart="true"
            android:textSize="42sp"
            android:textColor="#FFFFFF" />

        <TextView android:id="@+id/widget_location"
            android:layout_alignParentEnd="true"
            android:layout_centerVertical="true" />
    </RelativeLayout>

    <!-- Chart container -->
    <FrameLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1">

        <ImageView android:id="@+id/widget_chart"
            android:visibility="gone" />

        <TextView android:id="@+id/widget_placeholder"
            android:text="Tap to load forecast" />
    </FrameLayout>
</LinearLayout>
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
2. **Chart renders** in Flutter using fl_chart
3. **Chart captured** via RepaintBoundary → toImage() → PNG bytes
4. **Image saved** to app documents folder
5. **Widget data saved** via HomeWidget.saveWidgetData → SharedPreferences
6. **Native provider** reads SharedPreferences and loads bitmap
7. **WorkManager** triggers refresh every 30 minutes

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
