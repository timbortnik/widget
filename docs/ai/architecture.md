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
5. In-app: SVG rasterized natively to PNG (`MainActivity.renderSvgToPng`), displayed with a plain Flutter `Image.memory` (no PlatformView)
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

### In-app chart display (`lib/screens/home_screen.dart`)
The chart is a plain Flutter `Image.memory`, NOT a PlatformView. Flow:
- `NativeSvgService.renderSvgToPng()` sends the generated SVG + target pixel
  size to native; `MainActivity.renderSvgToPng` rasterizes it (AndroidSVG →
  Bitmap → PNG) off the platform thread and returns the bytes.
- `_buildChart` caches the bytes and renders them with `Image.memory`
  (`gaplessPlayback`, stable instance so the bitmap isn't re-decoded).
- This keeps the chart out of Impeller's external-texture path (the old
  `AndroidView` PlatformView composited as a `TextureLayer`, which fatally
  aborted on some Vulkan devices — see `widget.md`).

### WeatherFetcher (`android/.../WeatherFetcher.kt`)
Native HTTP client for Open-Meteo API. Responsibilities:
- Build API URL with parameters
- Request 32 hours of past data + 7 days forecast (sized for the weekly chart)
- Make HTTP request with timeout (10s)
- Parse JSON response and cache to SharedPreferences
- Handle errors (network, API, parsing)

**Data Range:** 32 hours past + 168 hours future (~200 hours total). Both
widgets slice their own view from this cache — the 48h chart takes 6h past +
46h forecast, the weekly takes the full window.

**Key benefit:** Works without Dart/Flutter engine for true background updates

### LocationService (`lib/services/location_service.dart`)
Device location handling with fallback. Responsibilities:
- Get GPS coordinates via native `LocationProvider` (through `LocationBridge` over the method channel)
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
Home widget refresh coordination. Responsibilities:
- Trigger native widget update for all provider variants (via `WidgetStore.updateWidget`)
- Check/clear the resize flag

Shared key-value storage (the `HomeWidgetPreferences` SharedPreferences file) is accessed
through `WidgetStore` (`lib/services/widget_store.dart`), a method-channel bridge to native
Kotlin that replaced the `home_widget` package.

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
│   └── home_screen.dart         # Main screen; chart via Image.memory over native PNG
├── services/
│   ├── location_service.dart    # GPS/fallback location
│   ├── widget_service.dart      # Home widget integration
│   └── native_svg_service.dart  # Method channel to native
└── theme/
    └── app_theme.dart           # Colors, light/dark themes

android/app/src/main/kotlin/.../
├── MainActivity.kt              # SVG generate + rasterize-to-PNG channel, Material You colors
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
└── MaterialYouColorExtractor.kt # Native Material You color extraction

scripts/
└── generate_version.sh          # Generates version.dart from git
```

## Platform-Specific

### Android Widget
- `MeteogramWidgetProvider` extends `AppWidgetProvider`
- Layout in `res/layout/meteogram_widget.xml`
- Uses RemoteViews (limited to TextView, ImageView, LinearLayout, RelativeLayout, FrameLayout)
- Background in `res/drawable/widget_background.xml` (gradient + rounded corners)
- Chart: reads SVG file → AndroidSVG → Bitmap → ImageView

### Android In-App (render-to-image)
- `MainActivity` exposes a `renderSvg` method channel
- Receives SVG string + pixel size, rasterizes via AndroidSVG → Bitmap → PNG
- Returns PNG bytes to Dart, which displays them with `Image.memory`
- No PlatformView / `TextureLayer`, so it avoids Impeller's external-texture
  crash path on Vulkan devices (the reason this replaced the old `AndroidView`)

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
| http | API requests (weather fetch, city search) |
| intl | Locale-aware time formatting (DateFormat.j) |
| flutter_localizations | i18n framework |
| mocktail / flutter_lints | dev: test mocks and lints |

GPS, reverse geocoding, the widget KV bridge, and persistent storage are all
**native** (over the `org.bortnik.meteogram/svg` method channel) — there are no
`geolocator`, `geocoding`, `home_widget`, `path_provider`, or
`shared_preferences` packages. This keeps the project free of any
Kotlin-Gradle-Plugin plugin, as required by AGP-9 built-in Kotlin. Material You
theming uses native color extraction (`MaterialYouColorExtractor.kt`).

### Android Native
| Library | Purpose |
|---------|---------|
| com.caverock:androidsvg-aar | SVG parsing and rendering |

See `docs/ai/widget.md` for the widget rendering pipeline and background refresh.
