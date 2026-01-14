# Native SVG Rendering Architecture

## ⚠️ Critical Rule: SVG Dimensions Must Match Render Dimensions

**To achieve native-quality rendering, the SVG must be generated at the exact pixel dimensions it will be rendered at. No scaling.**

```
CORRECT (native quality):
  SVG at 1140×669 device pixels → Render bitmap at 1140×669 → Display 1:1

WRONG (quality loss):
  SVG at 274×161 logical → Scale up to 1140×669 → Different rendering
  SVG at 1140×669 → Flutter Image widget → Compositor degrades quality
```

### Why This Matters

| Approach | Result |
|----------|--------|
| SVG dimensions = render dimensions | AndroidSVG renders at native resolution, no scaling artifacts |
| SVG dimensions ≠ render dimensions | AndroidSVG scales during render, subtle quality differences |
| Flutter Image widget | Compositor pipeline degrades bitmap quality regardless of resolution |

### Implementation

```dart
// CORRECT: Generate SVG at device pixel dimensions
final dpr = MediaQuery.of(context).devicePixelRatio;
final deviceWidth = logicalWidth * dpr;
final deviceHeight = logicalHeight * dpr;

generator.generate(
  width: deviceWidth,   // e.g., 1140
  height: deviceHeight, // e.g., 669
  // NO scale parameter
);
// Native view renders at same 1140×669

// WRONG: Generate at logical pixels with scale
generator.generate(
  width: logicalWidth,  // 274
  height: logicalHeight, // 161
  scale: dpr, // Scales fonts/strokes but SVG is still 274×161
);
// Native renders 274×161 SVG to 1140×669 bitmap = scaling occurs
```

### PlatformView Required

Flutter's `Image.memory()` degrades quality even with `MemoryImage(scale: dpr)`. Use `AndroidView` with native `ImageView` to bypass Flutter's compositor:

```dart
// Flutter side: AndroidView embeds native ImageView
AndroidView(viewType: 'svg_chart_view', ...)

// Native side: ImageView displays bitmap directly
imageView.setImageBitmap(bitmap)  // 1:1 pixel display
```

### Known Flutter Issues (This Is Not a New Bug)

Flutter's bitmap image quality degradation is a **known issue** documented in multiple GitHub reports:

| Issue | Description |
|-------|-------------|
| [#98953](https://github.com/flutter/flutter/issues/98953) | `PictureRecorder` → `Image.memory()` loses quality - thin lines disappear, text not sharp |
| [#109637](https://github.com/flutter/flutter/issues/109637) | `FilterQuality` not working as expected for hi-res images |
| [#127174](https://github.com/flutter/flutter/issues/127174) | Impeller renders images blurry even with `FilterQuality.high` |
| [#73714](https://github.com/flutter/flutter/issues/73714) | Request for higher quality filter than `FilterQuality.high` |
| [#76737](https://github.com/flutter/flutter/issues/76737) | Need better image filter quality controls |

**Key insight from [Flutter Engine PR #24582](https://github.com/flutter/engine/pull/24582):**
> "The algorithm used for `FilterQuality.high` is frequently *worse* than `medium` when scaling down. Only when scaling images *up* do you get increased quality as you go none → low → medium → high."

**What Flutter handles well:**
- Text, icons, vector shapes (rendered directly via Skia/Impeller)
- `CustomPainter` drawing operations
- `flutter_svg` vector rendering

**What has quality issues:**
- Bitmap images via `Image.memory()`, `Image.network()`, etc.
- Images passing through the compositor with scaling/transforms
- `PictureRecorder` capture → display pipeline

**Our solution:** Use `AndroidView` (PlatformView) to embed a native `ImageView` that displays the bitmap directly, bypassing Flutter's compositor entirely.

---

## SVG Font Sizing

Font sizes in the SVG are **relative to width** to ensure consistent appearance across different device resolutions and widget sizes.

| Element | Formula | Example (1044px width) |
|---------|---------|------------------------|
| Temperature labels | width × 4.5% | ~47px |
| Time labels | width × 4% | ~42px |
| Time label area | timeFontSize × 1.5 | ~63px reserved |

```dart
// Temperature labels - relative to width
final fontSize = (width * 0.045).round();

// Time labels - relative to width
final fontSize = (width * 0.04).round();

// Chart area reserves space for time labels based on font size
final timeFontSize = width * 0.04;
final chartHeight = height - timeFontSize * 1.5;
```

**Why width-based sizing:**
- Ensures consistent text proportions regardless of widget aspect ratio
- Time labels spread horizontally, so width determines available space
- Prevents label overlap on narrow widgets

### Locale-Aware Time Formatting

Time labels use `DateFormat.j(locale)` from the `intl` package for proper localization:

```dart
// System handles 12h/24h and AM/PM translation automatically
final timeStr = DateFormat.j(_locale).format(data[i].time);
```

This automatically provides:
- **24-hour format** for locales that prefer it (German: `10:00`, `22:00`)
- **12-hour with localized AM/PM** for others (English: `10 AM`, Arabic: `10 ص`)

The locale is obtained from `Localizations.localeOf(context)` and saved to HomeWidget storage for background service access.

---

## Overview

This document describes the architecture that enables **exact visual matching** between the in-app meteogram chart and the Android home screen widget. Both use the same SVG generation and native rendering pipeline, ensuring pixel-perfect consistency regardless of display context or size.

## Problem Statement

### Background Rendering Challenge

The home screen widget needs to update its meteogram chart in the background (via WorkManager) without requiring the app to be open. However, Dart's WorkManager tasks run in background isolates that **cannot access `dart:ui`**, which means:

- No Flutter widget rendering
- No `Canvas` operations
- No `CustomPainter`
- No `RepaintBoundary` image capture

### Initial Approach: fl_chart

The app originally used [fl_chart](https://pub.dev/packages/fl_chart) for rendering the meteogram. While fl_chart provides excellent interactive charts, it:

1. Requires `dart:ui` (unavailable in background isolates)
2. Cannot be used for widget background updates
3. Would result in visual differences between app and widget

### Solution: Pure-Dart SVG + Native Rendering

The solution uses a two-part architecture:

1. **SVG Generation** - Pure Dart code (no `dart:ui`) generates SVG strings
2. **Native Rendering** - AndroidSVG library renders SVG to bitmap on the native side

This approach works because:
- SVG generation is just string manipulation (works in any isolate)
- AndroidSVG is available in both the widget provider and via platform channels
- Same renderer = exact visual match

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DART LAYER                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              SvgChartGenerator                           │    │
│  │         lib/services/svg_chart_generator.dart            │    │
│  │                                                          │    │
│  │  • Pure Dart (no dart:ui imports)                        │    │
│  │  • Generates complete SVG strings                        │    │
│  │  • Calculates solar elevation, illuminance               │    │
│  │  • Creates temperature lines, daylight/precip bars       │    │
│  │  • Works in any isolate (main, background, compute)      │    │
│  └─────────────────────┬───────────────────────────────────┘    │
│                        │                                         │
│            ┌───────────┴───────────┐                            │
│            ▼                       ▼                            │
│  ┌─────────────────────┐ ┌─────────────────────┐                │
│  │   In-App Display    │ │  Background Service │                │
│  │  (home_screen.dart) │ │ (background_service)│                │
│  │                     │ │                     │                │
│  │  NativeSvgRenderer  │ │  Saves SVG to file  │                │
│  │  (platform channel) │ │  for widget to load │                │
│  └──────────┬──────────┘ └──────────┬──────────┘                │
│             │                       │                            │
└─────────────┼───────────────────────┼────────────────────────────┘
              │                       │
              │    PLATFORM CHANNEL   │
              │                       │
┌─────────────┼───────────────────────┼────────────────────────────┐
│             ▼                       ▼         NATIVE LAYER       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐ ┌─────────────────────┐                │
│  │   MainActivity.kt   │ │ MeteogramWidget     │                │
│  │                     │ │ Provider.kt         │                │
│  │  renderSvg method   │ │                     │                │
│  │  via MethodChannel  │ │  Loads SVG from     │                │
│  │                     │ │  SharedPreferences  │                │
│  └──────────┬──────────┘ └──────────┬──────────┘                │
│             │                       │                            │
│             └───────────┬───────────┘                            │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   AndroidSVG Library                     │    │
│  │              com.caverock:androidsvg-aar:1.4             │    │
│  │                                                          │    │
│  │  • Parses SVG string/file                                │    │
│  │  • Renders to Android Canvas                             │    │
│  │  • Outputs Bitmap for display                            │    │
│  │  • Same renderer for both app and widget                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. SvgChartGenerator (`lib/services/svg_chart_generator.dart`)

Pure-Dart SVG generator that creates meteogram chart SVGs without any `dart:ui` dependencies.

#### Key Classes

```dart
/// SVG color representation (no dart:ui Color dependency)
class SvgColor {
  final int r, g, b, a;
  const SvgColor(this.r, this.g, this.b, [this.a = 255]);

  String toHex() => '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';

  double get opacity => a / 255.0;
}

/// Theme color sets for light and dark modes
class SvgChartColors {
  static const light = SvgChartColors(
    temperatureLine: SvgColor(0xFF, 0x6B, 0x6B),      // Coral red
    daylightBar: SvgColor(0xFF, 0xF0, 0xAA),          // Pastel yellow
    precipitationBar: SvgColor(0x4E, 0xCD, 0xC4),     // Teal
    cardBackground: SvgColor(0xFF, 0xFF, 0xFF),       // White
    // ...
  );

  static const dark = SvgChartColors(
    temperatureLine: SvgColor(0xFF, 0x76, 0x75),      // Coral
    daylightBar: SvgColor(0xFF, 0xF0, 0xAA),          // Pastel yellow
    precipitationBar: SvgColor(0x00, 0xCE, 0xC9),     // Cyan
    cardBackground: SvgColor(0x1B, 0x28, 0x38),       // Dark blue-gray
    // ...
  );
}
```

#### SVG Generation

```dart
class SvgChartGenerator {
  String generate({
    required List<HourlyData> data,
    required int nowIndex,
    required double latitude,
    required SvgChartColors colors,
    required double width,
    required double height,
  }) {
    final svg = StringBuffer();

    // SVG header with integer dimensions (flutter_svg compatibility)
    svg.write('<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 ${width.round()} ${height.round()}">');

    // Background
    svg.write('<rect width="100%" height="100%" '
        'fill="${colors.cardBackground.toHex()}"/>');

    // Chart layers (bottom to top)
    _writeDaylightBars(svg, ...);      // Yellow bars from top
    _writePrecipitationBars(svg, ...); // Teal bars from top
    _writeTemperatureLine(svg, ...);   // Curved line with fill
    _writeNowIndicator(svg, ...);      // Vertical "now" line
    _writeTimeGridLines(svg, ...);     // 12h interval lines
    _writeTempLabels(svg, ...);        // Min/mid/max labels
    _writeTimeLabels(svg, ...);        // Time axis labels

    svg.write('</svg>');
    return svg.toString();
  }
}
```

#### Scientific Calculations (Pure Dart)

The generator includes astronomical calculations for daylight display:

```dart
/// Solar elevation angle in degrees
double _solarElevation(double latitude, DateTime time) {
  final dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays + 1;
  final hour = time.hour + time.minute / 60.0;

  // Solar declination
  final declination = 23.45 * math.sin(2 * math.pi / 365 * (284 + dayOfYear));
  final hourAngle = 15.0 * (hour - 12);

  // Convert to radians and calculate elevation
  final latRad = latitude * math.pi / 180;
  final decRad = declination * math.pi / 180;
  final haRad = hourAngle * math.pi / 180;

  final sinElevation = math.sin(latRad) * math.sin(decRad) +
      math.cos(latRad) * math.cos(decRad) * math.cos(haRad);

  return math.asin(sinElevation.clamp(-1.0, 1.0)) * 180 / math.pi;
}

/// Clear-sky illuminance in lux
double _clearSkyIlluminance(double elevation) {
  if (elevation < -6) return 0; // Below civil twilight

  final elevRad = elevation * math.pi / 180;
  final u = math.sin(elevRad);
  const x = 753.66156; // Atmospheric refraction constant

  final s = math.asin((x * math.cos(elevRad) / (x + 1)).clamp(-1.0, 1.0));
  final m = x * (math.cos(s) - u) + math.cos(s); // Optical air mass

  final factor = math.exp(-0.2 * m) * u +
      0.0289 * math.exp(-0.042 * m) * (1 + (elevation + 90) * u / 57.29577951);

  return 133775 * factor.clamp(0.0, double.infinity);
}

/// Combined daylight value with cloud and precipitation attenuation
double _calculateDaylight(HourlyData data, double latitude) {
  final elevation = _solarElevation(latitude, data.time);
  final clearSkyLux = _clearSkyIlluminance(elevation);
  if (clearSkyLux <= 0) return 0;

  final potential = (clearSkyLux / 130000.0).clamp(0.0, 1.0);
  final cloudDivisor = math.pow(10, data.cloudCover / 100.0);
  final precipDivisor = 1 + 0.5 * math.pow(data.precipitation, 0.6);

  return math.sqrt(potential / cloudDivisor / precipDivisor);
}
```

### 2. NativeSvgRenderer (`lib/services/native_svg_renderer.dart`)

Platform channel interface for rendering SVG using native AndroidSVG.

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeSvgRenderer {
  static const _channel = MethodChannel('com.meteogram.meteogram_widget/svg');

  /// Render SVG string to PNG bitmap bytes.
  static Future<Uint8List?> renderSvgToPng({
    required String svgString,
    required int width,
    required int height,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('renderSvg', {
        'svg': svgString,
        'width': width,
        'height': height,
      });
      return result;
    } on PlatformException catch (e) {
      print('Native SVG render error: ${e.message}');
      return null;
    }
  }
}
```

### 3. MainActivity.kt (Platform Channel Handler)

Native Android implementation that handles the platform channel calls.

```kotlin
package com.meteogram.meteogram_widget

import android.graphics.Bitmap
import android.graphics.Canvas
import com.caverock.androidsvg.SVG
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.meteogram.meteogram_widget/svg"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "renderSvg" -> {
                        val svgString = call.argument<String>("svg")
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0

                        if (svgString == null || width <= 0 || height <= 0) {
                            result.error("INVALID_ARGS", "Invalid arguments", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val pngBytes = renderSvgToPng(svgString, width, height)
                            result.success(pngBytes)
                        } catch (e: Exception) {
                            result.error("RENDER_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun renderSvgToPng(svgString: String, width: Int, height: Int): ByteArray {
        // Parse SVG from string
        val svg = SVG.getFromInputStream(ByteArrayInputStream(svgString.toByteArray()))
        svg.documentWidth = width.toFloat()
        svg.documentHeight = height.toFloat()

        // Create bitmap and render
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        svg.renderToCanvas(canvas)

        // Compress to PNG bytes
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        bitmap.recycle()

        return outputStream.toByteArray()
    }
}
```

### 4. MeteogramWidgetProvider.kt (Widget Rendering)

The home screen widget uses the same AndroidSVG library directly.

```kotlin
class MeteogramWidgetProvider : HomeWidgetProvider() {

    private fun renderSvgToBitmap(svgPath: String, width: Int, height: Int): Bitmap? {
        return try {
            val svg = SVG.getFromInputStream(FileInputStream(svgPath))
            svg.documentWidth = width.toFloat()
            svg.documentHeight = height.toFloat()

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            svg.renderToCanvas(canvas)

            bitmap
        } catch (e: Exception) {
            Log.e(TAG, "Error rendering SVG: ${e.message}")
            null
        }
    }

    override fun onUpdate(...) {
        // Load SVG path from SharedPreferences
        val svgPath = widgetData.getString("svg_path_dark", null)

        // Render SVG to bitmap
        val bitmap = renderSvgToBitmap(svgPath, widthPx, heightPx)

        // Set bitmap on RemoteViews
        views.setImageViewBitmap(R.id.widget_chart_dark, bitmap)
    }
}
```

### 5. _NativeSvgChart Widget (`lib/screens/home_screen.dart`)

Flutter widget that uses native rendering for display.

```dart
class _NativeSvgChart extends StatefulWidget {
  final List<HourlyData> data;
  final int nowIndex;
  final double latitude;
  final int width;
  final int height;
  final bool isLight;
  final GlobalKey lightKey;
  final GlobalKey darkKey;

  const _NativeSvgChart({...});

  @override
  State<_NativeSvgChart> createState() => _NativeSvgChartState();
}

class _NativeSvgChartState extends State<_NativeSvgChart> {
  Uint8List? _lightPng;
  Uint8List? _darkPng;
  bool _isRendering = false;

  @override
  void initState() {
    super.initState();
    _renderCharts();
  }

  Future<void> _renderCharts() async {
    if (_isRendering || widget.width <= 0 || widget.height <= 0) return;
    _isRendering = true;

    final generator = SvgChartGenerator();

    // Generate SVG for both themes
    final svgLight = generator.generate(
      data: widget.data,
      nowIndex: widget.nowIndex,
      latitude: widget.latitude,
      colors: SvgChartColors.light,
      width: widget.width.toDouble(),
      height: widget.height.toDouble(),
    );

    final svgDark = generator.generate(
      data: widget.data,
      nowIndex: widget.nowIndex,
      latitude: widget.latitude,
      colors: SvgChartColors.dark,
      width: widget.width.toDouble(),
      height: widget.height.toDouble(),
    );

    // Render using native AndroidSVG
    final lightPng = await NativeSvgRenderer.renderSvgToPng(
      svgString: svgLight,
      width: widget.width,
      height: widget.height,
    );

    final darkPng = await NativeSvgRenderer.renderSvgToPng(
      svgString: svgDark,
      width: widget.width,
      height: widget.height,
    );

    _isRendering = false;
    if (mounted) {
      setState(() {
        _lightPng = lightPng;
        _darkPng = darkPng;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPng = widget.isLight ? _lightPng : _darkPng;

    return currentPng != null
        ? Image.memory(
            currentPng,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          )
        : CircularProgressIndicator();
  }
}
```

## Data Flow

### In-App Rendering

```
1. User opens app
2. Weather data loaded from API/cache
3. LayoutBuilder provides dimensions (e.g., 274x161)
4. SvgChartGenerator.generate() creates SVG string (~10KB)
5. NativeSvgRenderer.renderSvgToPng() sends SVG to native via MethodChannel
6. MainActivity receives SVG string
7. AndroidSVG parses and renders to Bitmap
8. Bitmap compressed to PNG bytes (~30KB)
9. PNG bytes returned to Dart
10. Image.memory() displays the bitmap
```

### Widget Background Update

```
1. WorkManager triggers background task (every 30 min)
2. BackgroundService fetches weather data
3. SvgChartGenerator.generate() creates SVG strings (light + dark)
4. SVG strings saved to app documents directory
5. Paths stored in SharedPreferences via HomeWidget
6. HomeWidget.updateWidget() triggers native refresh
7. MeteogramWidgetProvider.onUpdate() called
8. Provider reads SVG path from SharedPreferences
9. AndroidSVG loads and renders SVG file to Bitmap
10. Bitmap set on RemoteViews ImageView
11. Widget displays updated chart
```

## Dependencies

### Flutter (pubspec.yaml)

```yaml
dependencies:
  home_widget: ^0.7.0      # SharedPreferences bridge for widgets
  path_provider: ^2.1.0    # App documents directory access
```

### Android (android/app/build.gradle.kts)

```kotlin
dependencies {
    implementation("com.caverock:androidsvg-aar:1.4")
}
```

## File Summary

| File | Purpose |
|------|---------|
| `lib/services/svg_chart_generator.dart` | Pure-Dart SVG generation |
| `lib/services/native_svg_renderer.dart` | Platform channel interface |
| `lib/screens/home_screen.dart` | `_NativeSvgChart` widget |
| `android/.../MainActivity.kt` | Platform channel handler |
| `android/.../MeteogramWidgetProvider.kt` | Widget SVG rendering |
| `android/app/build.gradle.kts` | AndroidSVG dependency |

## Benefits

1. **Exact Visual Match** - Same SVG generator + same renderer = identical output
2. **Background Capable** - SVG generation works in isolates (no `dart:ui`)
3. **Scalable** - SVG scales perfectly to any widget size
4. **Efficient** - SVG strings are ~10KB vs ~75KB PNG
5. **Theme Support** - Both light and dark themes generated and cached
6. **Cross-Context** - Works in app, widget, and background service

## Rendering Synchronization

To ensure correct rendering, several synchronization mechanisms are in place:

### Dimension Consistency

All code paths use the same default dimensions to avoid aspect ratio mismatches:

| Location | Default Dimensions |
|----------|-------------------|
| `WidgetUtils.kt` | 1000×500 |
| `background_service.dart` | 1000×500 |
| `widget_service.dart` | 1000×500 |

When `getAppWidgetOptions()` returns invalid dimensions (0×0), the widget falls back to saved dimensions from SharedPreferences.

### App Initialization Order

The app waits for dimensions before rendering the chart:

```dart
Future<void> _initialize() async {
  await _loadWidgetDimensions();  // Wait for aspect ratio
  await _initializeData();        // Then load weather data
}
```

This ensures the chart renders with the correct aspect ratio from the start, avoiding visual jumps.

### Color Change Re-rendering

When Material You colors change while the native view is being created, the `NativeSvgChartView` tracks pending updates:

```dart
void _onPlatformViewCreated(int viewId) {
  // If SVG changed while view was being created, render the latest
  if (_lastRenderedSvg != null && _lastRenderedSvg != widget.svgString) {
    _channel!.invokeMethod('renderSvg', {...});
  }
  _lastRenderedSvg = widget.svgString;
}
```

This handles the race condition where `DynamicColorBuilder` provides new colors before the native view is ready.

### Stale Data Protection

When re-rendering charts (e.g., for color changes), the background service checks data staleness:

```dart
if (ageMs > staleThresholdMs) {  // 15 minutes
  await _updateWeatherData();    // Fetch fresh data
  return;
}
```

This prevents displaying charts with outdated time labels.

## Limitations

1. **Android Only** - iOS would need similar implementation with SVGKit or Core Graphics
2. **Platform Channel Overhead** - Small latency for in-app rendering (~50-100ms)
3. **No Interactivity** - Unlike fl_chart, SVG bitmap has no touch interactions
4. **Memory** - Both theme bitmaps kept in memory for widget capture

## Future Improvements

1. **iOS Support** - Implement SVGKit-based rendering for iOS widgets
2. **Caching** - Cache rendered bitmaps to avoid re-rendering on scroll
3. **Incremental Updates** - Only re-render changed portions
4. **WebP Compression** - Smaller bitmap size with WebP format
