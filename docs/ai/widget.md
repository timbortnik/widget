# Home Screen Widget Implementation

## Overview

The app ships **two native Android home-screen widgets**, both backed by
`AppWidgetProvider` (no `home_widget` package):

- **`MeteogramWidgetProvider`** — the default 48-hour meteogram.
- **`MeteogramWeeklyWidgetProvider`** — a 7-day variant that `extends`
  `MeteogramWidgetProvider` and only overrides the layout, time range, and
  X-axis labels (`labelStepHours = 24`, `TimeLabelFormat.WEEKDAY`).

The chart is generated as an SVG string natively in Kotlin
(`SvgChartGenerator.kt`) and rasterised with the AndroidSVG library. The same
generator drives both widgets and the in-app chart, so they always match.

Flutter ↔ native key-value storage and the widget-refresh trigger go through
**`WidgetStore`** (`lib/services/widget_store.dart`) over the
`org.bortnik.meteogram/svg` method channel — see `MainActivity`
(`getWidgetData` / `saveWidgetData` / `updateWidget`). **All background refresh
is native Kotlin** (AlarmManager / WorkManager / boot receiver); there is no
Dart background callback and no Flutter engine involved in background updates.

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

## Android Configuration

### AndroidManifest.xml

The manifest declares the two widget providers plus the receivers that drive
background refresh (no `home_widget` receivers/services):

```xml
<!-- 48h widget -->
<receiver android:name=".MeteogramWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/meteogram_widget_info" />
</receiver>

<!-- 7-day weekly widget -->
<receiver android:name=".MeteogramWeeklyWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/meteogram_widget_weekly_info" />
</receiver>

<!-- Locale / timezone changes (manifest receivers: app process is killed on change,
     and these broadcasts are exempt from the Android 8.0+ implicit-broadcast ban) -->
<receiver android:name=".WidgetEventReceiver" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.LOCALE_CHANGED" />
        <action android:name="android.intent.action.TIMEZONE_CHANGED" />
    </intent-filter>
</receiver>

<!-- 15-min inexact alarm -->
<receiver android:name=".WidgetAlarmReceiver" android:exported="false">
    <intent-filter>
        <action android:name="org.bortnik.meteogram.ACTION_ALARM_UPDATE" />
    </intent-filter>
</receiver>

<!-- Refresh on device boot (requires RECEIVE_BOOT_COMPLETED) -->
<receiver android:name=".BootCompletedReceiver" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

### res/xml/meteogram_widget_info.xml

`updatePeriodMillis="1800000"` (30 min) is the OEM-resistant system fallback.
The API-31+ attributes (`targetCellWidth/Height`, `maxResize*`, `previewLayout`)
are ignored on older devices. The weekly variant uses
`meteogram_widget_weekly_info.xml` with the same shape but its own
`initialLayout`/`previewLayout`/`description`.

### res/layout/meteogram_widget.xml

The root `FrameLayout` carries `android:theme="@style/WidgetTheme"` and paints
`?android:attr/colorBackground` at 80% alpha so the widget matches system
chrome (Search bar, Clock). It contains two chart `ImageView`s (light + dark),
a placeholder `TextView` ("Tap to load forecast"), and a hidden refresh
indicator. The weekly layout (`meteogram_widget_weekly.xml`) mirrors it.

> **minSdk note:** `WidgetTheme`'s parent `android:Theme.DeviceDefault.DayNight`
> requires **API 29**, which is why `minSdk` is pinned ≥ 29 (currently 30). On
> API 24–28 the launcher can't inflate the widget. See CLAUDE.md Gotcha #9.

### Chart theme visibility (light vs dark)

There is no per-widget bitmap caching of "the current theme"; instead the
layout holds **both** charts and the system/launcher decides which is visible:

- `res/values/integers.xml` → `chart_light_visibility=0` (visible),
  `chart_dark_visibility=2` (gone).
- `res/values-night/integers.xml` → the inverse.

When the system theme changes, the launcher re-inflates the RemoteViews and the
night-qualified integers flip which `ImageView` shows — no app code required.
A manual in-app theme choice (System/Light/Dark, mirrored to the
`theme_mode` pref) overrides this in `MeteogramWidgetProvider.applyThemeOverride()`
via `WidgetUtils.chartVisibilityForThemeMode()`, which also forces the card
background to match the chosen mode.

### Provider rendering (Kotlin)

`onUpdate()` (in `MeteogramWidgetProvider`, inherited by the weekly provider):

1. Reads the cached weather via `WeatherDataParser.parseFromPrefs(context)`.
2. Picks the slice for this provider via `chartView(weatherData)` —
   `getHourlyView()` for 48h, `getWeeklyView()` for the weekly subclass.
3. Generates light **and** dark SVGs with `SvgChartGenerator.generate(...)` and
   rasterises each to a `Bitmap` in memory (`generateChartBitmap`), then
   `setImageViewBitmap` on the two `ImageView`s.
4. Falls back to any previously-saved SVG file paths (`svg_path_light_<id>` /
   `svg_path_dark_<id>`) if in-memory generation fails.
5. If there's still no chart (e.g. no weather cached yet), shows the
   "Tap to load forecast" placeholder; tapping opens `MainActivity`, which
   fetches and refreshes both widgets.

`onAppWidgetOptionsChanged()` handles resize: it stores the new pixel
dimensions and regenerates immediately (or triggers a fetch if there's no data).

## Flutter Integration

All SVG generation and weather fetching happen in Kotlin. The Flutter side only
displays the generated SVG and triggers refreshes.

### Method channel (`org.bortnik.meteogram/svg`)

Dart talks to Kotlin over a single channel. Relevant methods (see
`MainActivity.configureFlutterEngine`):

| Method | Purpose |
|--------|---------|
| `fetchWeather(latitude, longitude)` | `WeatherFetcher` calls Open-Meteo and writes the result to SharedPreferences |
| `generateSvg(mode, width, height, isLight, usesFahrenheit)` | Reads the cache and returns an SVG string for `hourly` or `weekly` |
| `renderSvg(svg, width, height)` | Rasterises an SVG string to PNG bytes |
| `reverseGeocode(latitude, longitude)` | `android.location.Geocoder` → city name |
| `getWidgetData` / `saveWidgetData` | KV read/write to the shared prefs file (used by `WidgetStore`) |
| `updateWidget(name)` | Sends `ACTION_APPWIDGET_UPDATE` to the named provider |
| `isLocationServiceEnabled` / `checkLocationPermission` / `requestLocationPermission` / `getCurrentPosition` / `getLastKnownPosition` / `openLocationSettings` | Native location surface (`LocationProvider`, used by `LocationBridge`) |

### WidgetStore (`lib/services/widget_store.dart`)

Thin KV bridge plus `updateWidget`. It writes to the shared
**`HomeWidgetPreferences`** SharedPreferences file — that filename is retained
for backward compatibility, and the native side replicates the old
`home_widget` serialization (a companion `home_widget.double.<key>` flag and
`doubleToRawLongBits` for doubles) so data from pre-migration installs survives
an upgrade.

```dart
await WidgetStore.saveWidgetData<bool>('use_gps', true);
final lat = await WidgetStore.getWidgetData<double>('cached_latitude');
await WidgetStore.updateWidget(androidName: 'MeteogramWidgetProvider');
```

`WidgetService.triggerWidgetUpdate()` refreshes **both** providers
(`MeteogramWidgetProvider` and `MeteogramWeeklyWidgetProvider`).

### In-app chart display (`lib/screens/home_screen.dart`)

The chart is a plain Flutter `Image.memory`, **not** a PlatformView.
`NativeSvgService.renderSvgToPng()` sends the generated SVG + target pixel size
to `MainActivity`'s `renderSvg` channel, which rasterizes it (AndroidSVG →
Bitmap → PNG) off the platform thread; `_buildChart` displays the returned bytes
with `gaplessPlayback`.

This replaced an `AndroidView` PlatformView (viewType `svg_chart_view`). That
view was composited by Impeller as a `TextureLayer` / external texture, whose
`Image.getHardwareBuffer()` JNI call fatally aborts on some Vulkan devices
(Adreno / Android 12 — flutter/flutter#175267). Rendering bytes in pure Flutter
removes the only `TextureLayer` in the app and the entire crash path, with
identical AndroidSVG rasterization (same as the widget).

## Background Refresh (fully native)

No Dart runs in the background. Updates are driven by layered native
mechanisms, all coordinated through `WidgetUtils`:

| Source | Cadence | Behaviour |
|--------|---------|-----------|
| `WidgetAlarmReceiver` (AlarmManager) | ~15 min, inexact | Fetch if stale, re-render if needed; catches up on wake |
| `WeatherUpdateWorker` (WorkManager) | ~30 min | `NetworkType.CONNECTED` constraint; fetch if stale, re-render |
| `BootCompletedReceiver` | On boot | Immediate refresh, reschedule alarm |
| `updatePeriodMillis` | 30 min | System fallback, OEM-resistant |
| `WidgetEventReceiver` | On event | `LOCALE_CHANGED` / `TIMEZONE_CHANGED` → re-render all (no fetch) |
| `onAppWidgetOptionsChanged` | On resize | Re-render immediately |

`MeteogramApplication.onCreate()` registers the Material You `ContentObserver`,
schedules the alarm (`WidgetAlarmScheduler`), and enqueues the worker.

### WidgetUtils helpers (`WidgetUtils.kt`)

- `isWeatherDataStale(context)` — true if `last_weather_update` is older than
  the 15-min threshold (`STALE_THRESHOLD_MS`).
- `isRerenderNeeded(context)` — true if a 30-min boundary was crossed since the
  last render (the "now" indicator moved) **or** weather was fetched since.
- `fetchWeather(context, pendingResult?)` — async fetch on a background
  executor via `WeatherFetcher.fetchAndUpdateSync`; `fetchWeatherSync` is the
  blocking variant for `WorkManager.doWork()`.
- `rerenderAllWidgetsNative(context)` — sends `ACTION_APPWIDGET_UPDATE` to
  **every** provider in `WIDGET_PROVIDERS` (48h + weekly).
- `rerenderAllWidgetsIfNeeded(context)` — `rerenderAllWidgetsNative` guarded by
  `isRerenderNeeded`.

### "Now" indicator updates

The "now" indicator snaps to the nearest hour at the 30-minute mark (2:29 →
"now" at 2:00; 2:30 → "now" at 3:00). Re-render fires only when the 30-min slot
changes or weather was refreshed, so the indicator stays correct whether or not
the app process is alive.

## Data Flow

1. **App fetches weather**: `home_screen.dart` resolves location
   (`LocationService` → native `LocationBridge`), then calls
   `NativeSvgService.fetchWeather(lat, lon)` → Kotlin `WeatherFetcher` hits
   Open-Meteo and caches the JSON to SharedPreferences.
2. **In-app chart**: Dart calls `generateSvg` → Kotlin reads the cache and
   returns an SVG string → Dart calls `renderSvg` → Kotlin rasterizes it to PNG
   bytes → `home_screen.dart` shows them with `Image.memory`.
3. **Widget chart**: native `onUpdate` reads the cache, generates light+dark
   SVGs with `SvgChartGenerator`, rasterises via AndroidSVG → `Bitmap` →
   `ImageView`.
4. **Theme switching**: handled by night-qualified resources (system) or
   `applyThemeOverride` (explicit choice).

**Key benefit:** SVG generation runs entirely in Kotlin, so background updates
need no Flutter engine.

## Daylight Calculation

The meteogram displays daylight intensity as yellow bars, calculated using
scientifically-grounded formulas (implemented natively in `SvgChartGenerator.kt`).

### Solar Elevation (Astronomical)

Sun's angle above the horizon, based on latitude, longitude, time of day, and day of year:

```
δ = 23.45° × sin(360/365 × (284 + dayOfYear))   // Solar declination
solarHour = utcHour + longitude/15              // Convert UTC to local solar time
h = 15° × (solarHour - 12)                      // Hour angle
sin(α) = sin(lat)×sin(δ) + cos(lat)×cos(δ)×cos(h)  // Elevation angle
```

**Longitude correction:** Solar noon (when h=0) occurs at 12:00 local solar time, not 12:00 UTC. For every 15° of longitude east, solar noon shifts 1 hour earlier in UTC. For example:
- At longitude 0° (Greenwich): solar noon at 12:00 UTC
- At longitude 30°E (Kyiv): solar noon at ~10:00 UTC
- At longitude 120°E (Beijing): solar noon at ~04:00 UTC

- α < -6°: Below civil twilight (no visible light)
- α = 0°: Sunrise/sunset (~400-800 lux)
- α = 90°: Sun directly overhead (~130,000 lux)

Reference: Meeus, J. (1991). *Astronomical Algorithms*. Willmann-Bell.

### Clear-Sky Illuminance (Atmospheric Model)

The simple `elevation / 90°` formula gives zero light at sunrise/sunset, which is incorrect. Instead, we use an atmospheric model that accounts for optical air mass:

```
// Atmospheric refraction constant
x = 753.66156

// Optical air mass calculation
s = arcsin((x × cos(elevation)) / (x + 1))
m = x × (cos(s) - sin(elevation)) + cos(s)

// Illuminance with atmospheric extinction
factor = exp(-0.2 × m) × sin(elevation) +
         0.0289 × exp(-0.042 × m) × (1 + (elevation + 90) × sin(elevation) / 57.3)

illuminance = 133775 × factor  // Result in lux
```

| Solar Elevation | Clear-Sky Illuminance |
|-----------------|----------------------|
| -6° (civil twilight) | 0 lux |
| 0° (sunrise/sunset) | ~400-800 lux |
| 30° | ~60,000 lux |
| 60° | ~100,000 lux |
| 90° (zenith) | ~130,000 lux |

Reference: Kasten, F. & Young, A.T. (1989). "Revised optical air mass tables and approximation formula." *Applied Optics*, 28(22), 4735-4738.

Implementation based on: ha-illuminance project https://github.com/pnbruckner/ha-illuminance

### Cloud Attenuation (ha-illuminance model)

Logarithmic model from the ha-illuminance project, designed for perceived brightness rather than solar irradiance:

```
divisor = 10^(cloudCover / 100)
factor = 1 / divisor
```

| Cloud Cover | Light Factor |
|-------------|--------------|
| 0% | 100% |
| 50% | 32% |
| 75% | 18% |
| 100% | 10% |

More aggressive than irradiance-based formulas (like Kasten & Czeplak), better matching perceived brightness reduction from cloud cover.

Reference: ha-illuminance project https://github.com/pnbruckner/ha-illuminance

### Precipitation Attenuation

Based on extinction coefficient research relating meteorological optical range (MOR) to rainfall rate:

```
σ = a × R^b        (extinction coefficient)
MOR = 3/σ          (Koschmieder's law)
```

Simplified to a divisor formula:

```
divisor = 1 + 0.5 × R^0.6
```

Where R is precipitation in mm/h.

| Precipitation | Divisor | Light Factor |
|---------------|---------|--------------|
| 0 mm/h | 1.0 | 100% |
| 1 mm/h (light) | 1.5 | 67% |
| 5 mm/h (moderate) | 2.5 | 40% |
| 10 mm/h (heavy) | 3.0 | 33% |
| 20 mm/h (very heavy) | 3.9 | 26% |

Reference: Rainfall-MOR relationship studies, e.g., https://doi.org/10.20937/ATM.53297

### Combined Formula

```
// Clear-sky illuminance from atmospheric model (0 to ~130,000 lux)
clearSkyLux = clearSkyIlluminance(solarElevation)

// Normalize to 0-1 range
potential = clearSkyLux / 130000

// Cloud attenuation (ha-illuminance logarithmic model)
cloudDivisor = 10^(cloudCover / 100)

// Precipitation attenuation (extinction coefficient model)
precipDivisor = 1 + 0.5 × R^0.6

// Combined attenuation
linear = potential / cloudDivisor / precipDivisor

// Square root scale for display (makes small values visible)
scaled = sqrt(linear)
```

The square root scaling provides a gentle boost to small values so winter/overcast conditions remain visible.

## Debugging

### Logcat Commands
```bash
# 48h widget
adb logcat | grep -i "MeteogramWidget"

# Weekly widget
adb logcat | grep -i "MeteogramWeeklyWidget"

# Layout inflation errors
adb logcat | grep -i "Error inflating"
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Can't load widget" | Unsupported view in layout, or `WidgetTheme` unavailable below API 29 | Remove `View`/`Space`; keep `minSdk ≥ 29` |
| Widget shows "Tap to load forecast" | No weather cached yet | Open the app once (or wait for a background fetch with a stored location) |
| Widget not updating | Alarm/worker not scheduled | Check `MeteogramApplication.onCreate` scheduled the alarm and enqueued `WeatherUpdateWorker` |
| Weekly widget blank but 48h works | Weekly view slice empty | Check `WeatherData.getWeeklyView()` and that the fetch covers the full forecast window |

## Platform

Android-only. There is no iOS widget; an iOS port would require a WidgetKit
extension, a `TimelineProvider`, and an App Group for shared storage.
