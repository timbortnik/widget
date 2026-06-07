# Claude AI Context

This file provides context for AI assistants working on this project.

**Detailed documentation:** See `docs/ai/` for in-depth guides:
- `architecture.md` - System architecture, data flow, component responsibilities
- `widget.md` - Home screen widget implementation, background refresh, event handling
- `api.md` - Open-Meteo API integration
- `design.md` - UI design principles
- `i18n.md` - Localization setup

## Project Overview

**Meteograph** - A Flutter mobile app with Android home screen widget displaying weather forecasts as a meteogram (temperature line + precipitation bars + daylight intensity).

## Quick Reference

| Aspect | Value |
|--------|-------|
| Framework | Flutter 3.44.1 (pinned — see "Before Coding") |
| Android SDK | minSdk 30 (Android 11), target 36 — do NOT lower minSdk, see Gotcha #9 |
| Weather API | Open-Meteo (free, no key) |
| Charting | Native SVG (SvgChartGenerator.kt + AndroidSVG) |
| Widget package | Native AppWidgetProvider + method-channel KV store (`widget_store.dart`) |
| i18n | flutter_localizations + intl (ARB files) |
| License | BSL 1.1 (converts to MIT 2029) |

## Key Design Decisions

- **Time range:** 6h past + 46h future with current time marker
- **Data:** Temperature (line with gradient fill), precipitation (bars), daylight (computed from cloud cover)
- **Theme:** System light/dark mode with custom color palette
- **Units:** Locale-aware (°F for US/Liberia/Myanmar, °C elsewhere)
- **Update:** Timer checks every minute in foreground (refreshes if data >15 min old, redraws at half-hour boundary). Background: AlarmManager (15 min), WorkManager (~30 min with network constraint), BOOT_COMPLETED, updatePeriodMillis (30 min fallback)
- **Languages:** 30+ languages via ARB files
- **Widget:** SVG rendered natively via AndroidSVG for pixel-perfect display
- **Edge-to-edge:** Enabled via `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` with transparent system bars (required for Android 15+)

## Architecture

```
lib/
├── main.dart                 # Entry point, edge-to-edge setup
├── generated/
│   └── version.dart         # Generated git version info (gitignored)
├── l10n/                     # Generated + source ARB files
│   ├── app_en.arb           # English (template)
│   ├── app_*.arb            # Other languages
│   └── app_localizations.dart # Generated
├── services/
│   ├── location_service.dart     # Native location (LocationBridge) with fallback
│   ├── widget_service.dart       # Triggers native widget refresh + resize flag
│   ├── widget_store.dart         # Method-channel KV bridge to HomeWidgetPreferences (replaces home_widget)
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
│   ├── MeteogramApplication.kt       # Registers receivers, theme observer, alarm
│   ├── MeteogramWidgetProvider.kt    # Extends AppWidgetProvider
│   ├── WidgetEventReceiver.kt        # Handles locale/timezone changes
│   ├── WidgetAlarmScheduler.kt       # Schedules 15-min inexact alarm
│   ├── WidgetAlarmReceiver.kt        # Handles alarm broadcasts
│   ├── BootCompletedReceiver.kt      # Refreshes widget on device boot
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
    ├── values/styles.xml             # Base themes
    ├── values-v27/styles.xml         # Edge-to-edge cutout mode (API 27+)
    └── values-night-v27/styles.xml   # Dark mode edge-to-edge (API 27+)

scripts/
└── generate_version.sh      # Generates version.dart + outputs VERSION_CODE/VERSION_NAME for builds
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
- **AlarmManager**: `WidgetAlarmScheduler.kt` schedules 15-min inexact alarm (catches up on wake)
- **WorkManager**: `WeatherUpdateWorker.kt` runs ~30 min with `NetworkType.CONNECTED` constraint
- **BOOT_COMPLETED**: `BootCompletedReceiver.kt` refreshes immediately after device boot
- **updatePeriodMillis**: System-managed 30-min fallback (OEM-resistant)
- **Weather fetching**: `WeatherFetcher.kt` calls Open-Meteo API directly (no Dart involved)
- **Material You**: `ContentObserver` + `MaterialYouColorWorker.kt` detect theme changes

## Before Coding — AGP-9 built-in Kotlin: keep the plugin set KGP-free

This project runs **AGP-9 built-in Kotlin** (`android.builtInKotlin=true`), and AGP-9 rejects
the legacy Kotlin Gradle Plugin (KGP) **globally** — a single KGP-applying module breaks the
build. The project therefore has **zero Flutter plugins with native code**
(`GeneratedPluginRegistrant` is empty): `home_widget` and `geolocator` were both removed in
favour of native implementations (`WidgetStore`/`LocationProvider` over the method channel).

**With no KGP plugin present, Flutter 3.44.1 builds clean** (unpinned from 3.41.7 to 3.44.0
2026-05; bumped to the 3.44.1 patch 2026-06). Flutter 3.44.1 still *tries* to force-apply
`kotlin-android` to `:app` and logs a
benign warning — `Applying the Kotlin Android Plugin (KGP) was unsuccessful. KGP was not found
on the classpath.` — but the apply is caught (`FlutterPluginUtils.kt:633`) and the build
succeeds. That one warning line is expected; ignore it (Flutter plans to drop the force-apply,
flutter/flutter#184837).

- **Before coding, check the toolchain & deps.** Confirm `flutter --version` is **3.44.1** (the
  pinned version — don't unintentionally build on another); run `flutter pub outdated` to review
  dependency updates and note any Flutter release past 3.44.1. Treat **any** Flutter or dependency
  bump as a *deliberate, verified* change — it can re-break the built-in-Kotlin setup (see history
  below) — not a casual upgrade.
- **CRITICAL:** do **not** add any Flutter plugin that applies KGP (most native plugins do) — it
  will break the build under built-in Kotlin. Prefer a native implementation over the method
  channel, or a plugin version that supports built-in Kotlin. If a KGP plugin is unavoidable,
  you must switch to the legacy path: `android.builtInKotlin=false` + re-add `id("kotlin-android")`
  to `app/build.gradle.kts` (KGP is already declared `apply false` in `settings.gradle.kts`).
- **CI:** `flutter-version: '3.44.1'` in `.github/workflows/`.
- **Verify after any toolchain/plugin change:** `make analyze` + `make test` + a debug build.
  After switching the local Flutter SDK version, run `flutter clean` first (stale kernel caches
  from a different Dart version cause spurious `dot-shorthands` framework-compile errors).
- `android.newDsl=false` is still required (removed in AGP 10.0 — a separate future deadline).

## Build Commands

```bash
make version        # Generate lib/generated/version.dart from git
make debug          # x86_64 only (68MB) - for emulator (runs version first)
make release        # arm64 only (19MB) - for phones (runs version first)
make install        # Build release + install on device
make install-debug  # Build debug + install on emulator
make clean          # Clean build artifacts
```

Note: All build targets run `make version` first to embed git tag/commit hash.

## Versioning

Version is derived from git, not hardcoded in pubspec.yaml:

| Component | Source | Example |
|-----------|--------|---------|
| VERSION_NAME | Git tag without `v` prefix | `v1.0.3` → `1.0.3` |
| VERSION_CODE | Semver as integer: major×10000 + minor×100 + patch | `v1.0.3` → `10003` |

**How it works:**
- `scripts/generate_version.sh` outputs `VERSION_CODE` and `VERSION_NAME` to stdout
- **Local builds:** Makefile extracts version from git and passes `--build-name` / `--build-number` to flutter
- **CI builds:** Release workflow captures script output via `$GITHUB_OUTPUT` and passes to flutter
- **Shallow clones:** Falls back to `GITHUB_REF_NAME` when git tag isn't available

**Creating a release:**
```bash
git tag v1.0.4
git push origin v1.0.4  # Triggers release workflow
```

VERSION_CODE increases with each version bump (1.0.3→10003, 1.0.4→10004, 1.1.0→10100).

## Pre-Commit Checklist

**MANDATORY** before committing any code changes:

```bash
make analyze        # Must show "No issues found!"
make test           # Must pass all tests (Dart + Kotlin)
```

Individual test commands:
```bash
make test-dart      # Flutter/Dart tests only
make test-kotlin    # Kotlin unit tests only
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
1. Add to API query in `WeatherFetcher.kt` buildUrl()
2. Parse in `WeatherDataParser.kt` and add to `HourlyData` data class
3. Display in `SvgChartGenerator.kt` chart rendering
4. If needed in Dart, save to SharedPreferences in `WeatherFetcher.kt`

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
| `android/.../WidgetAlarmScheduler.kt` | 15-min inexact alarm scheduling |
| `android/.../WidgetAlarmReceiver.kt` | Handles alarm-triggered updates |
| `android/.../BootCompletedReceiver.kt` | Refreshes widget on device boot |
| `android/.../WeatherUpdateWorker.kt` | WorkManager periodic refresh (~30 min) |
| `android/.../MaterialYouColorExtractor.kt` | Native Material You color extraction |
| `android/.../WidgetEventReceiver.kt` | System event handler (network, locale/timezone) |
| `lib/services/native_svg_service.dart` | Method channel to native (weather, SVG, cache) |
| `lib/services/location_service.dart` | GPS/manual location with city search |
| `lib/theme/app_theme.dart` | All colors and gradients |
| `scripts/generate_version.sh` | Generates version.dart from git tag/commit |

## Gotchas

1. **RemoteViews errors** - Check logcat for "Class not allowed to be inflated"
2. **Widget not updating** - Ensure `WidgetStore.updateWidget()` called with correct provider names
3. **SVG not rendering** - Check logcat for AndroidSVG errors, validate SVG string
4. **Location timeout** - Has 15s timeout with Berlin fallback
5. **Null API values** - Use `?.toDouble() ?? 0.0` pattern for nullable JSON
6. **Implicit broadcasts** - Android 8.0+ requires runtime receiver registration (not manifest)
7. **Event staleness** - Widget checks `last_weather_update` timestamp (15 min threshold)
8. **Edge-to-edge warning** - Play Console may warn about deprecated APIs (setStatusBarColor etc.) - this is Flutter engine code, not app code; tracked in flutter/flutter#160328
9. **minSdk is pinned to 30 (`app/build.gradle.kts`), NOT Flutter's default 24** - hard floor is 29: the widget's `WidgetTheme` parent `android:Theme.DeviceDefault.DayNight` requires API 29; on API 24-28 the launcher can't inflate the widget (blank/broken widget → Google Play "Broken Functionality" rejection, fixed 2026-06). 30 also gives `LocationListener` default callbacks (so `LocationProvider` needs no `onStatusChanged`/`onProviderEnabled`/`onProviderDisabled` stubs). Run `cd android && ./gradlew :app:lintDebug` and check for `NewApi` errors before shipping any resource/theme change. If you must support <29, give `WidgetTheme` an API-24-safe parent and add a `values-v29/styles.xml` DayNight override instead of lowering minSdk blindly; below API 30, restore the `LocationListener` stubs.
