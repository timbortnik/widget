# Home Screen Widget Implementation

## Overview

Using the `home_widget` package to create cross-platform home screen widgets. The package renders Flutter UI to an image that native widgets display.

## Package Setup

### pubspec.yaml
```yaml
dependencies:
  home_widget: ^0.4.0
```

## Android Configuration

### AndroidManifest.xml
```xml
<receiver android:name="MeteogramWidgetProvider"
          android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/widget_info" />
</receiver>
```

### res/xml/widget_info.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_layout"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen">
</appwidget-provider>
```

### Widget Size
- **4x2 cells** (approximately 250dp x 110dp)
- Resizable horizontally and vertically

### Background Updates (WorkManager)
```kotlin
class WeatherWidgetWorker(context: Context, params: WorkerParameters)
    : Worker(context, params) {

    override fun doWork(): Result {
        // Trigger Flutter background update
        HomeWidgetBackgroundIntent.getBroadcast(
            applicationContext,
            Uri.parse("meteogramwidget://refresh")
        )
        return Result.success()
    }
}
```

## iOS Configuration

### Info.plist (Widget Extension)
```xml
<key>NSWidgetWantsLocation</key>
<false/>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Widget Extension
Create iOS widget extension via Xcode:
1. File → New → Target → Widget Extension
2. Name: `MeteogramWidget`
3. Include Configuration Intent: No

### TimelineProvider
```swift
struct Provider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Get data from shared UserDefaults (via home_widget)
        let data = UserDefaults(suiteName: "group.com.example.meteogram")

        // Create entries
        let entry = MeteogramEntry(date: Date(), weatherData: data)

        // Refresh in 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}
```

### Widget Size
- **Medium** (systemMedium)
- Approximately 329 x 155 points

## Flutter Integration

### Rendering Widget UI
```dart
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String appGroupId = 'group.com.example.meteogram';
  static const String iOSWidgetName = 'MeteogramWidget';
  static const String androidWidgetName = 'MeteogramWidgetProvider';

  /// Update widget with new weather data
  static Future<void> updateWidget(WeatherData data) async {
    // Save data for native widget to read
    await HomeWidget.saveWidgetData('weatherData', jsonEncode(data.toJson()));
    await HomeWidget.saveWidgetData('lastUpdated', DateTime.now().toIso8601String());

    // Render Flutter widget to image
    await HomeWidget.renderFlutterWidget(
      const MeteogramWidgetView(),
      key: 'meteogramImage',
      logicalSize: const Size(400, 200),
    );

    // Trigger native widget update
    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
      androidName: androidWidgetName,
    );
  }
}
```

### Widget View (Flutter)
```dart
class MeteogramWidgetView extends StatelessWidget {
  const MeteogramWidgetView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: const MeteogramChart(
        compact: true,  // Widget-optimized layout
      ),
    );
  }
}
```

## Background Refresh

### Flutter Background Handler
```dart
@pragma('vm:entry-point')
void backgroundCallback(Uri? uri) async {
  if (uri?.host == 'refresh') {
    // Fetch new weather data
    final weatherService = WeatherService();
    final locationService = LocationService();

    final location = await locationService.getSavedLocation();
    final data = await weatherService.fetchWeather(location.lat, location.lon);

    // Update widget
    await WidgetService.updateWidget(data);
  }
}

// Register in main()
HomeWidget.registerBackgroundCallback(backgroundCallback);
```

## Theme Support

Widget respects system theme:

```dart
class MeteogramWidgetView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    return Container(
      color: isDark
        ? Colors.black.withOpacity(0.85)
        : Colors.white.withOpacity(0.85),
      child: MeteogramChart(
        colors: isDark ? darkChartColors : lightChartColors,
      ),
    );
  }
}
```

## Transparency

Widget background uses semi-transparent color:
- Light mode: `Colors.white.withOpacity(0.85)`
- Dark mode: `Colors.black.withOpacity(0.85)`

This allows the home screen wallpaper to show through slightly.

## Tap Actions

Handle widget taps to open app:

```dart
// In Flutter
HomeWidget.setAppGroupId(appGroupId);
HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
  if (uri != null) {
    // App launched from widget tap
    _handleWidgetAction(uri);
  }
});

HomeWidget.widgetClicked.listen((uri) {
  // Widget tapped while app running
  _handleWidgetAction(uri);
});
```
