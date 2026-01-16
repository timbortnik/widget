# Meteogram Widget

A beautiful, modern weather widget for Android showing temperature forecasts as a meteogram chart.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![License](https://img.shields.io/badge/License-BSL_1.1-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android-brightgreen.svg)

## Features

- **46-hour forecast** with 6 hours of history
- **Beautiful meteogram chart** with:
  - Temperature line with gradient fill
  - Precipitation bars
  - Daylight intensity (computed from cloud cover and sun position)
  - Current time indicator
- **Home screen widget** with native SVG rendering via AndroidSVG
- **Smart refresh**:
  - Auto-refresh in foreground (timer checks every minute for stale data >15 min, redraws at half-hour)
  - Half-hour alarms for background widget updates (synced with "now" indicator snapping)
  - Event-driven updates (screen unlock, network change, locale/timezone change)
- **Flexible location**:
  - GPS with reverse geocoding
  - City search (any city worldwide)
  - Recent cities remembered
  - Berlin default when GPS unavailable
- **Material You** dynamic color support (Android 12+)
- **Light/dark theme** following system preference
- **36 languages** supported
- **Locale-aware units** (°F for US/Liberia/Myanmar, °C elsewhere)
- **Offline support** with smart caching:
  - Automatic cache fallback when offline
  - Fibonacci retry backoff (1, 2, 3, 5, 8 min) for background refresh
  - Visual "OFFLINE" watermark on stale data (>1 hour old)
  - Cached location and city name preserved
- **No API key required** - uses free Open-Meteo API

## Screenshots

The app features a modern, card-based design with:
- Large temperature display
- Pull-to-refresh
- Smooth animations
- Elegant color palette (coral red temp line, teal precipitation, yellow daylight)

## Installation

### Prerequisites

- Flutter 3.x
- Android SDK
- Android device or emulator

### Build & Run

```bash
# Get dependencies
flutter pub get

# Generate localizations
flutter gen-l10n

# Build options (via Makefile)
make debug          # x86_64 only (68MB) - for emulator
make release        # arm64 only (19MB) - for phones
make install        # Build release + install on device
make install-debug  # Build debug + install on emulator
```

### Install Widget

1. Install the app on your device
2. Open the app and let it load weather data
3. Long-press on home screen → Widgets
4. Find "Meteogram" and drag to home screen
5. Tap widget to refresh data

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── l10n/                     # Localization files (36 languages)
│   ├── app_en.arb           # English (template)
│   └── app_*.arb            # ar, be, bg, bn, bs, cs, da, de, el, es,
│                            # fi, fr, hi, hr, is, it, ja, jv, ka, ko,
│                            # mk, nl, no, pa, pl, pt, ro, sk, sq, sv,
│                            # ta, tr, uk, vi, zh
├── models/
│   └── weather_data.dart    # Weather data models
├── screens/
│   └── home_screen.dart     # Main app screen
├── services/
│   ├── weather_service.dart      # Open-Meteo API client
│   ├── location_service.dart     # GPS/IP/manual location
│   ├── widget_service.dart       # Home widget updates
│   ├── background_service.dart   # WorkManager refresh
│   ├── svg_chart_generator.dart  # Pure Dart SVG generation
│   ├── native_svg_renderer.dart  # Native PNG rendering
│   └── units_service.dart        # Temperature/precipitation units
├── theme/
│   └── app_theme.dart       # Colors, themes, Material You
└── widgets/
    └── native_svg_chart_view.dart # Native SVG chart display

android/app/src/main/
├── kotlin/.../
│   ├── MainActivity.kt              # Flutter activity
│   ├── MeteogramApplication.kt      # App initialization, event receivers
│   ├── MeteogramWidgetProvider.kt   # Widget provider
│   ├── WidgetEventReceiver.kt       # System event handler
│   ├── WidgetUtils.kt               # Widget helper functions
│   ├── HourlyAlarmReceiver.kt       # Half-hour refresh alarm
│   ├── SvgChartPlatformView.kt      # Native SVG rendering
│   ├── SvgChartViewFactory.kt       # PlatformView factory
│   ├── MaterialYouColorExtractor.kt # Dynamic color extraction
│   └── MaterialYouColorWorker.kt    # Background color updates
└── res/
    ├── layout/meteogram_widget.xml # Widget layout
    ├── xml/meteogram_widget_info.xml
    └── drawable/widget_background.xml
```

## API

Uses [Open-Meteo](https://open-meteo.com/) free APIs (no API key required):

### Weather Forecast
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &hourly=temperature_2m,precipitation,cloud_cover
  &timezone=UTC
  &past_hours=6
  &forecast_days=2
```

Returns hourly data for:
- `temperature_2m` - Temperature in Celsius
- `precipitation` - Rain/snow in mm
- `cloud_cover` - Cloud coverage percentage (0-100)

Daylight intensity is computed from cloud cover and solar position (latitude + time).

### City Search (Geocoding)
```
GET https://geocoding-api.open-meteo.com/v1/search
  ?name={query}
  &count=8
  &language=en
```

Returns matching cities with coordinates, country, and region.

## Widget Technical Details

### Android Widget

The home screen widget uses:
- `HomeWidgetProvider` from home_widget package
- `RemoteViews` for native Android widget rendering
- SVG chart rendered natively via AndroidSVG library
- Half-hour alarms (AlarmManager) for periodic refresh, synced with "now" indicator snapping
- Event receivers for unlock/network/locale changes

**RemoteViews Limitations:**
- Only supports: TextView, ImageView, LinearLayout, RelativeLayout, FrameLayout
- Does NOT support: View, Space, custom views

### Data Flow

1. App loads weather from Open-Meteo API
2. SVG chart generated via `SvgChartGenerator` (pure Dart)
3. In-app: SVG rendered via native Android PlatformView (AndroidSVG)
4. Widget: SVG saved to file, rendered by native provider via AndroidSVG
5. Half-hour alarms (AlarmManager) trigger periodic refresh
6. Event receivers trigger refresh on unlock/network/locale changes

## Customization

### Colors

Edit `lib/theme/app_theme.dart`:

```dart
static const light = MeteogramColors(
  temperatureLine: Color(0xFFFF6B6B),    // Coral red
  precipitationBar: Color(0xFF4ECDC4),   // Teal
  daylightBar: Color(0xFFFFF0AA),        // Light yellow (daylight bars)
  nowIndicator: Color(0xFFFFE66D),       // Golden yellow
  // ...
);
```

### Widget Background

Edit `android/app/src/main/res/drawable/widget_background.xml`:

```xml
<gradient
    android:startColor="#BA1B2838"
    android:endColor="#BA0D1B2A"
    android:angle="135" />
<corners android:radius="24dp" />
```

## Adding Languages

1. Create `lib/l10n/app_XX.arb` (copy from app_en.arb)
2. Translate all strings
3. Run `flutter gen-l10n`

Supported locales are auto-detected from ARB files.

## Dependencies

| Package | Purpose |
|---------|---------|
| home_widget | Android/iOS widget support |
| geolocator | GPS location |
| geocoding | Reverse geocoding (city names) |
| http | API requests |
| path_provider | File storage |
| shared_preferences | Settings storage |
| intl | Locale-aware formatting |

Material You theming uses native Android color extraction (`MaterialYouColorExtractor.kt`).

## License

Business Source License 1.1 - see [LICENSE](LICENSE)

- Free for non-commercial and personal use
- Commercial use requires a license
- Converts to MIT on 2029-01-01

## Contributing

Contributions welcome! Please read the existing code style and test your changes.

## Acknowledgments

- Weather data: [Open-Meteo](https://open-meteo.com/)
- Widget support: [home_widget](https://pub.dev/packages/home_widget)
- SVG rendering: [AndroidSVG](https://bigbadaboom.github.io/androidsvg/)
