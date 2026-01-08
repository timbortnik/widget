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
  - Cloud cover sky gradient background
  - Current time indicator
- **Home screen widget** with live chart
- **Auto-refresh** every 30 minutes
- **Flexible location**:
  - GPS with reverse geocoding
  - IP geolocation fallback
  - City search (any city worldwide)
  - Recent cities remembered
- **Light/dark theme** following system preference
- **Multi-language** support (English, German, French, Spanish, Italian, Ukrainian)
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
- Elegant color palette (coral red temp line, teal precipitation)

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

# Run on device
flutter run
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
├── l10n/                     # Localization files
│   ├── app_en.arb           # English
│   ├── app_de.arb           # German
│   ├── app_fr.arb           # French
│   ├── app_es.arb           # Spanish
│   ├── app_it.arb           # Italian
│   └── app_uk.arb           # Ukrainian
├── models/
│   └── weather_data.dart    # Weather data models
├── screens/
│   └── home_screen.dart     # Main app screen
├── services/
│   ├── weather_service.dart      # Open-Meteo API client
│   ├── location_service.dart     # GPS/IP/manual location
│   ├── widget_service.dart       # Home widget updates
│   └── background_service.dart   # WorkManager refresh
├── theme/
│   └── app_theme.dart       # Colors and themes
└── widgets/
    └── native_svg_chart_view.dart # Native SVG chart display

android/
├── app/src/main/
│   ├── kotlin/.../
│   │   ├── MainActivity.kt
│   │   └── MeteogramWidgetProvider.kt  # Widget provider
│   └── res/
│       ├── layout/meteogram_widget.xml # Widget layout
│       ├── xml/meteogram_widget_info.xml
│       └── drawable/widget_background.xml
```

## API

Uses [Open-Meteo](https://open-meteo.com/) free APIs (no API key required):

### Weather Forecast
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &hourly=temperature_2m,precipitation,cloud_cover
  &timezone=auto
  &past_hours=6
  &forecast_days=2
```

Returns hourly data for:
- `temperature_2m` - Temperature in Celsius
- `precipitation` - Rain/snow in mm
- `cloud_cover` - Cloud coverage percentage (0-100)

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
- Chart captured as PNG image from Flutter
- WorkManager for 30-minute background refresh

**RemoteViews Limitations:**
- Only supports: TextView, ImageView, LinearLayout, RelativeLayout, FrameLayout
- Does NOT support: View, Space, custom views

### Data Flow

1. App loads weather from Open-Meteo API
2. SVG chart generated via `SvgChartGenerator` (pure Dart)
3. In-app: SVG rendered via native Android PlatformView
4. Widget: SVG saved to file, rendered by native provider
5. WorkManager triggers refresh every 30 minutes

## Customization

### Colors

Edit `lib/theme/app_theme.dart`:

```dart
static const light = MeteogramColors(
  temperatureLine: Color(0xFFFF6B6B),    // Coral red
  precipitationBar: Color(0xFF4ECDC4),   // Teal
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
3. Add locale to `lib/main.dart`:
   ```dart
   supportedLocales: const [
     Locale('en'),
     Locale('xx'),  // Add new locale
   ],
   ```
4. Run `flutter gen-l10n`

## Dependencies

| Package | Purpose |
|---------|---------|
| home_widget | Android/iOS widget support |
| workmanager | Background refresh |
| geolocator | GPS location |
| geocoding | Reverse geocoding (city names) |
| http | API requests |
| path_provider | File storage |
| shared_preferences | Settings storage |
| dynamic_color | Material You theming |
| intl | Locale-aware formatting |

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
