# Claude AI Context

This file provides context for AI assistants working on this project.

**Detailed documentation:** See `docs/ai/` for in-depth guides:
- `architecture.md` - System architecture, data flow, component responsibilities
- `widget.md` - Home screen widget implementation, background refresh, event handling
- `api.md` - Open-Meteo API integration
- `design.md` - UI design principles
- `i18n.md` - Localization setup

## Project Overview

**Meteogram Widget** - A Flutter mobile app with Android home screen widget displaying weather forecasts as a meteogram (temperature line + precipitation bars + daylight intensity).

## Quick Reference

| Aspect | Value |
|--------|-------|
| Framework | Flutter 3.x |
| Weather API | Open-Meteo (free, no key) |
| Charting | Native SVG (SvgChartGenerator + AndroidSVG) |
| Widget package | home_widget |
| i18n | flutter_localizations + intl (ARB files) |
| License | BSL 1.1 (converts to MIT 2029) |

## Key Design Decisions

- **Time range:** 6h past + 46h future with current time marker
- **Data:** Temperature (line with gradient fill), precipitation (bars), daylight (computed from cloud cover)
- **Theme:** System light/dark mode with custom color palette
- **Units:** Locale-aware (°F for US/Liberia/Myanmar, °C elsewhere)
- **Update:** Timer checks every minute in foreground (refreshes if data >15 min old, redraws at half-hour boundary), WorkManager periodic task (~30 min) in background, event-driven (unlock, network, locale/timezone change)
- **Languages:** 30+ languages via ARB files
- **Widget:** SVG rendered natively via AndroidSVG for pixel-perfect display

## Architecture

```
lib/
├── main.dart                 # Entry point, widget/background init
├── l10n/                     # Generated + source ARB files
│   ├── app_en.arb           # English (template)
│   ├── app_*.arb            # Other languages
│   └── app_localizations.dart # Generated
├── models/
│   └── weather_data.dart    # WeatherData, HourlyData classes
├── services/
│   ├── location_service.dart     # Geolocator wrapper with fallback
│   ├── widget_service.dart       # home_widget integration
│   └── native_svg_service.dart   # Method channel to native (weather fetch, SVG gen, cache)
├── theme/
│   └── app_theme.dart       # MeteogramColors, WeatherGradients
├── widgets/
│   └── native_svg_chart_view.dart # Native SVG PlatformView
└── screens/
    └── home_screen.dart     # Main UI with SVG chart

android/app/src/main/
├── kotlin/.../
│   ├── MainActivity.kt
│   ├── MeteogramApplication.kt       # Registers event receivers, theme observer
│   ├── MeteogramWidgetProvider.kt    # Extends HomeWidgetProvider
│   ├── WidgetEventReceiver.kt        # Handles system broadcasts
│   ├── WidgetUtils.kt                # Widget helper functions
│   ├── WeatherUpdateWorker.kt        # WorkManager periodic refresh (~30 min)
│   ├── WeatherFetcher.kt             # Native HTTP client for Open-Meteo API
│   ├── WeatherDataParser.kt          # Parse cached weather JSON
│   ├── SvgChartGenerator.kt          # Native SVG generation (single source)
│   ├── MaterialYouColorExtractor.kt  # Native Material You color extraction
│   ├── SvgChartPlatformView.kt       # Native SVG rendering for in-app
│   └── SvgChartViewFactory.kt        # PlatformView factory
└── res/
    ├── layout/meteogram_widget.xml   # RemoteViews layout
    ├── xml/meteogram_widget_info.xml # Widget config
    ├── drawable/widget_background.xml
    └── values/strings.xml
```

## Color Palette

Default fallback colors (Material You overrides these on Android 12+):

```dart
// Light mode
temperatureLine: Color(0xFFFF6B6B)      // Coral red
precipitationBar: Color(0xFF4ECDC4)     // Teal
nowIndicator: Color(0xFFFFE66D)         // Golden yellow
clearSky: Color(0xFF74B9FF)             // Light blue
overcastSky: Color(0xFFB2BEC3)          // Gray

// Dark mode
temperatureLine: Color(0xFFFF7675)
precipitationBar: Color(0xFF00CEC9)
nowIndicator: Color(0xFFFDCB6E)
cardBackground: Color(0xFF2D2D2D)       // Neutral gray
```

## API Reference

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &hourly=temperature_2m,precipitation,cloud_cover
  &timezone=UTC
  &past_hours=6
  &forecast_days=2
```

Response: `{ hourly: { time: [], temperature_2m: [], precipitation: [], cloud_cover: [] } }`

## Widget Implementation Notes

### RemoteViews Restrictions
Android widgets use RemoteViews which only support:
- FrameLayout, LinearLayout, RelativeLayout
- TextView, ImageView, Button, ProgressBar

**NOT supported:** View, Space, custom views, most Material widgets

### Data Flow
1. **In-app**: `home_screen.dart` gets location → calls `NativeSvgService.fetchWeather()` → Kotlin fetches from Open-Meteo → caches to SharedPreferences → Dart reads cache → Kotlin generates SVG → rendered via `NativeSvgChartView`
2. **Widget**: Native code reads cached weather from SharedPreferences → `SvgChartGenerator.kt` generates SVG → AndroidSVG renders to bitmap → ImageView

### Background Refresh (fully native)
- **WorkManager periodic**: `WeatherUpdateWorker.kt` runs ~30 min (battery-efficient, OS batches work)
- **Weather fetching**: `WeatherFetcher.kt` calls Open-Meteo API directly (no Dart involved)
- **Event-driven**: `WidgetEventReceiver.kt` handles unlock, network, locale/timezone changes
- **Material You**: `ContentObserver` + `MaterialYouColorWorker.kt` detect theme changes

## Build Commands

```bash
make debug          # x86_64 only (68MB) - for emulator
make release        # arm64 only (19MB) - for phones
make install        # Build release + install on device
make install-debug  # Build debug + install on emulator
make clean          # Clean build artifacts
```

## Pre-Commit Checklist

**MANDATORY** before committing any code changes:

```bash
flutter analyze     # Must show "No issues found!"
flutter test        # Must pass all tests
```

Do not commit code with analyzer warnings or test failures.

## Common Tasks

### Modify chart appearance
Edit `android/.../SvgChartGenerator.kt`:
- `writeTemperatureLine()` - line style, gradient fill
- `writePrecipitationBars()` - bar colors, width
- `writeSunshineBars()` - daylight intensity display
- `SvgChartColors` - color definitions for light/dark themes

### Modify widget layout
Edit `android/app/src/main/res/layout/meteogram_widget.xml`
- Only use allowed RemoteViews elements!
- Test on device after changes

### Add new weather data
1. Add field to `HourlyData` class
2. Update `WeatherData.fromJson()` parsing
3. Add to API query in `weather_service.dart`
4. Display in chart or UI

### Debug widget issues
```bash
adb logcat | grep -i "MeteogramWidget"
adb logcat | grep -i "Error inflating"
```

## Files to Know

| File | Purpose |
|------|---------|
| `android/.../SvgChartGenerator.kt` | Native SVG generation (single source of truth) |
| `android/.../WeatherFetcher.kt` | Native HTTP client for background weather fetching |
| `android/.../WeatherDataParser.kt` | Parse cached weather JSON from SharedPreferences |
| `android/.../MeteogramWidgetProvider.kt` | Widget update handling |
| `android/.../WeatherUpdateWorker.kt` | WorkManager periodic refresh (~30 min) |
| `android/.../MaterialYouColorExtractor.kt` | Native Material You color extraction |
| `android/.../WidgetEventReceiver.kt` | System event handler (unlock, network, etc.) |
| `lib/services/native_svg_service.dart` | Method channel to native (weather, SVG, cache) |
| `lib/services/location_service.dart` | GPS/manual location with city search |
| `lib/theme/app_theme.dart` | All colors and gradients |

## Gotchas

1. **RemoteViews errors** - Check logcat for "Class not allowed to be inflated"
2. **Widget not updating** - Ensure `HomeWidget.updateWidget()` called with correct names
3. **SVG not rendering** - Check logcat for AndroidSVG errors, validate SVG string
4. **Location timeout** - Has 15s timeout with Berlin fallback
5. **Null API values** - Use `?.toDouble() ?? 0.0` pattern for nullable JSON
6. **Implicit broadcasts** - Android 8.0+ requires runtime receiver registration (not manifest)
7. **Event staleness** - Widget checks `last_weather_update` timestamp (15 min threshold)
