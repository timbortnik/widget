# Claude AI Context

This file provides context for AI assistants working on this project.

## Project Overview

**Meteogram Widget** - A Flutter mobile app with Android home screen widget displaying weather forecasts as a meteogram (temperature line + precipitation bars + cloud cover gradient background).

## Quick Reference

| Aspect | Value |
|--------|-------|
| Framework | Flutter 3.x |
| Weather API | Open-Meteo (free, no key) |
| Charting | fl_chart |
| Widget package | home_widget + workmanager |
| i18n | flutter_localizations + intl (ARB files) |
| License | MIT |

## Key Design Decisions

- **Time range:** 2h past + 48h future with current time marker
- **Data:** Temperature (line with gradient fill), precipitation (bars), cloudiness (sky gradient)
- **Theme:** System light/dark mode with custom color palette
- **Units:** Celsius (hardcoded for now)
- **Update:** 30 minute background refresh via WorkManager
- **Languages:** EN, DE, FR, ES, IT (extensible via ARB)
- **Widget:** Captures Flutter chart as PNG for native Android RemoteViews

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
│   ├── weather_service.dart      # Open-Meteo API client
│   ├── location_service.dart     # Geolocator wrapper with fallback
│   ├── widget_service.dart       # home_widget integration
│   └── background_service.dart   # WorkManager periodic tasks
├── theme/
│   └── app_theme.dart       # MeteogramColors, WeatherGradients
├── widgets/
│   └── meteogram_chart.dart # fl_chart + custom sky painter
└── screens/
    └── home_screen.dart     # Main UI with chart capture

android/app/src/main/
├── kotlin/.../
│   ├── MainActivity.kt
│   └── MeteogramWidgetProvider.kt  # Extends HomeWidgetProvider
└── res/
    ├── layout/meteogram_widget.xml  # RemoteViews layout
    ├── xml/meteogram_widget_info.xml # Widget config (4x2, 30min)
    ├── drawable/widget_background.xml # Gradient + rounded corners
    └── values/strings.xml
```

## Color Palette

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
background: Color(0xFF0D1B2A)           // Deep navy
cardBackground: Color(0xFF1B2838)       // Dark slate
```

## API Reference

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &hourly=temperature_2m,precipitation,cloud_cover
  &timezone=auto
  &past_hours=2
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
1. `home_screen.dart` loads weather → renders chart
2. `RepaintBoundary` captures chart as image
3. `widget_service.dart` saves PNG, updates SharedPreferences
4. `HomeWidget.updateWidget()` triggers native update
5. `MeteogramWidgetProvider.kt` reads prefs, loads image, updates RemoteViews

### Background Refresh
```dart
// background_service.dart
Workmanager().registerPeriodicTask(
  'periodicWeatherTask',
  'periodicWeatherTask',
  frequency: Duration(minutes: 30),
);
```

## Common Tasks

### Modify chart appearance
Edit `lib/widgets/meteogram_chart.dart`:
- `_buildTemperatureChart()` - line style, gradient, dots
- `_buildPrecipitationBars()` - bar colors, width
- `_SkyGradientPainter` - background gradient

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
| `lib/widgets/meteogram_chart.dart` | The core chart widget |
| `lib/theme/app_theme.dart` | All colors and gradients |
| `lib/services/widget_service.dart` | Widget update logic |
| `android/.../MeteogramWidgetProvider.kt` | Native widget code |
| `android/.../meteogram_widget.xml` | Widget layout |

## Gotchas

1. **RemoteViews errors** - Check logcat for "Class not allowed to be inflated"
2. **Widget not updating** - Ensure `HomeWidget.updateWidget()` called with correct names
3. **Chart not captured** - Add delay before capture, check RepaintBoundary key
4. **Location timeout** - Has 15s timeout with Berlin fallback
5. **Null API values** - Use `?.toDouble() ?? 0.0` pattern for nullable JSON
