# Architecture

## Overview

The app follows a standard Flutter architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Screens   │  │   Widgets   │  │    Theme    │  │
│  │ (setState)  │  │NativeSvgChart│ │MeteogramColors│
│  └─────────────┘  └─────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────┤
│                   Dart Services                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Location │ │  Widget  │ │NativeSvg │            │
│  │ Service  │ │ Service  │ │ Service  │            │
│  └──────────┘ └──────────┘ └──────────┘            │
├─────────────────────────────────────────────────────┤
│              Native Kotlin (android/)                │
│  ┌─────────────────────────────────────────────────┐│
│  │  WeatherFetcher, SvgChartGenerator, WidgetUtils ││
│  │  AlarmScheduler, AlarmReceiver, BootReceiver    ││
│  │  WeatherDataParser, MaterialYouColorExtractor   ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

## Data Flow

### App Launch
1. Location service gets current coordinates (GPS or fallback)
2. Weather service fetches data from Open-Meteo
3. Data is parsed into `WeatherData` model
4. SVG chart generated via `SvgChartGenerator`
5. In-app: SVG rendered via PlatformView (AndroidView → native ImageView)
6. Widget: SVG saved to file, native provider renders via AndroidSVG

### Widget Updates
Background updates use layered mechanisms for reliability:
1. **AlarmManager (15 min)**: Inexact alarm catches up on wake if missed during sleep
2. **WorkManager (~30 min)**: Network-constrained periodic task (fetches when network available)
3. **BOOT_COMPLETED**: Immediate refresh after device boot
4. **updatePeriodMillis (30 min)**: System fallback, OEM-resistant

All paths use the same native flow:
1. Check staleness (>15 min) → fetch weather if needed via `WeatherFetcher`
2. Check re-render needed (30-min boundary crossed) → generate SVG via `SvgChartGenerator.kt`
3. Render via AndroidSVG → Bitmap → update widget ImageView

### Foreground App Updates
1. Timer checks every minute while app is in foreground
2. If data >15 minutes old: triggers full weather refresh
3. If half-hour boundary crossed (e.g., 2:29 → 2:30): redraws chart as "now" indicator snaps to next hour
4. Also checks on first build (cold start) for immediate staleness detection
5. On app resume: existing lifecycle handler checks widget sync

## State Management

Using simple `setState` in StatefulWidget (no Provider/Riverpod):

```dart
class _HomeScreenState extends State<HomeScreen> {
  WeatherData? _weatherData;
  String? _locationName;
  bool _loading = true;
  String? _error;

  Future<void> _loadWeather() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch data...
      setState(() { _weatherData = weather; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }
}
```

## Key Components

### SvgChartGenerator (`android/.../SvgChartGenerator.kt`)
Native Kotlin SVG generation - single source of truth for both widget and in-app. Responsibilities:
- Generate complete SVG string for meteogram
- Temperature line with gradient fill
- Precipitation bars
- Daylight intensity bars (computed from cloud cover + solar elevation)
- Temperature labels (min/mid/max) with proper alignment
- Time labels with locale-aware formatting
- Width-based font sizing for consistent proportions

**Key benefit:** Works in background without Dart/Flutter engine

### NativeSvgChartView (`lib/widgets/native_svg_chart_view.dart`)
PlatformView wrapper for in-app SVG display. Responsibilities:
- Embed native Android ImageView via AndroidView
- Pass SVG string to native side via MethodChannel
- Bypass Flutter's image compositor for 1:1 pixel rendering

### WeatherFetcher (`android/.../WeatherFetcher.kt`)
Native HTTP client for Open-Meteo API. Responsibilities:
- Build API URL with parameters
- Request 6 hours of past data + 2 days forecast
- Make HTTP request with timeout (10s)
- Parse JSON response and cache to SharedPreferences
- Handle errors (network, API, parsing)

**Data Range:** 6 hours past + 48 hours future (~54 hours total)

**Key benefit:** Works without Dart/Flutter engine for true background updates

### LocationService (`lib/services/location_service.dart`)
Device location handling with fallback. Responsibilities:
- Get GPS coordinates via geolocator
- Handle permissions gracefully (no exceptions thrown)
- Reverse geocoding for city name resolution
- City search via Open-Meteo geocoding API
- Recent cities storage (last 5 selections)
- Persist location preference in SharedPreferences
- Return `LocationData` with coordinates, city name, and source

**Location Resolution Order:**
1. GPS position → reverse geocode for localized city name
2. Last known GPS position → reverse geocode
3. Default fallback: Berlin (52.52, 13.405)

All city names are localized via reverse geocoding based on device locale.

**City Search:**
- Uses Open-Meteo geocoding API (free, no key)
- Endpoint: `https://geocoding-api.open-meteo.com/v1/search`
- Returns city name, country, region, coordinates
- Debounced search (300ms) in UI

### WidgetService (`lib/services/widget_service.dart`)
Home widget data management. Responsibilities:
- Save chart image to app documents folder
- Save widget data via HomeWidget.saveWidgetData
- Trigger native widget update

### Native Background Updates
All background updates are handled natively in Kotlin (no Dart/Flutter involved):
- `WidgetAlarmReceiver` - Handles 15-min alarm triggers
- `BootCompletedReceiver` - Handles device boot
- `WidgetEventReceiver` - Handles connectivity and locale changes
- `WeatherUpdateWorker` - WorkManager periodic updates

Each checks staleness (via `WidgetUtils.isWeatherDataStale()`) and triggers fetch/re-render as needed.

### MeteogramColors (`lib/theme/app_theme.dart`)
Theme-aware color palette. Responsibilities:
- Provide light/dark color variants
- Color for temperature line, precipitation, daylight, now indicator
- Card backgrounds and text colors

## File Structure

```
lib/
├── main.dart                    # App entry point
├── generated/
│   └── version.dart             # Git version info (generated, gitignored)
├── l10n/                        # Localization ARB files (30+ languages)
│   ├── app_en.arb               # English
│   ├── app_de.arb               # German
│   ├── app_ar.arb               # Arabic
│   └── ...                      # 30+ locales
├── screens/
│   └── home_screen.dart         # Main screen with NativeSvgChartView
├── services/
│   ├── location_service.dart    # GPS/fallback location
│   ├── widget_service.dart      # Home widget integration
│   └── native_svg_service.dart  # Method channel to native
├── theme/
│   └── app_theme.dart           # Colors, light/dark themes
└── widgets/
    └── native_svg_chart_view.dart # PlatformView SVG display

android/app/src/main/kotlin/.../
├── MainActivity.kt              # PlatformView factory, Material You colors
├── MeteogramApplication.kt      # Registers receivers, schedules alarm
├── MeteogramWidgetProvider.kt   # Home screen widget provider
├── WidgetEventReceiver.kt       # Handles locale/timezone changes
├── WidgetAlarmScheduler.kt      # Schedules 15-min inexact alarm
├── WidgetAlarmReceiver.kt       # Handles alarm-triggered updates
├── BootCompletedReceiver.kt     # Refreshes widget on device boot
├── WidgetUtils.kt               # Widget helper functions
├── WeatherUpdateWorker.kt       # WorkManager periodic weather refresh
├── WeatherFetcher.kt            # Native HTTP client for Open-Meteo
├── WeatherDataParser.kt         # Parse cached weather JSON
├── SvgChartGenerator.kt         # Native SVG generation
├── MaterialYouColorExtractor.kt # Native Material You color extraction
├── SvgChartViewFactory.kt       # Creates PlatformView instances
└── SvgChartPlatformView.kt      # Native ImageView + AndroidSVG rendering

scripts/
└── generate_version.sh          # Generates version.dart from git
```

## Platform-Specific

### Android Widget
- `MeteogramWidgetProvider` extends `HomeWidgetProvider`
- Layout in `res/layout/meteogram_widget.xml`
- Uses RemoteViews (limited to TextView, ImageView, LinearLayout, RelativeLayout, FrameLayout)
- Background in `res/drawable/widget_background.xml` (gradient + rounded corners)
- Chart: reads SVG file → AndroidSVG → Bitmap → ImageView

### Android In-App (PlatformView)
- `SvgChartViewFactory` registered in MainActivity
- `SvgChartPlatformView` embeds native ImageView
- Receives SVG string via MethodChannel
- Renders via AndroidSVG → Bitmap → ImageView
- Bypasses Flutter's image compositor for 1:1 pixel rendering

### iOS Widget
Not yet implemented. Would require:
- WidgetKit extension
- TimelineProvider
- App Groups for data sharing

## Error Handling

```dart
// Location errors
on LocationException catch (e) {
  // e.message: "Location permission denied" / "Location timeout"
}

// Weather errors
on WeatherException catch (e) {
  // e.message: "Failed to fetch weather data"
}

// Generic errors shown to user
catch (e) {
  setState(() { _error = e.toString(); });
}
```

## Dependencies

### Flutter/Dart
| Package | Purpose |
|---------|---------|
| home_widget | Flutter ↔ native widget bridge |
| geolocator | GPS location |
| geocoding | Reverse geocoding (coordinates → city name) |
| http | API requests (weather, city search) |
| path_provider | App documents for SVG files |
| shared_preferences | Settings storage |
| flutter_localizations | i18n framework |
| intl | Locale-aware time formatting (DateFormat.j) |

Material You theming uses native Android color extraction (`MaterialYouColorExtractor.kt`).

### Android Native
| Library | Purpose |
|---------|---------|
| com.caverock:androidsvg-aar | SVG parsing and rendering |

See `docs/NATIVE_SVG_RENDERING.md` for detailed rendering architecture.
