# Material You Color Detection

## Overview

The widget automatically updates when the user changes Material You (dynamic) colors in Android Settings. This works on Android 12+ (API 31+).

## How It Works

Material You colors are stored in `Settings.Secure.THEME_CUSTOMIZATION_OVERLAY_PACKAGES`. When the user changes their color selection, this setting updates.

### Color Mapping

| Widget Element | System Color | Light Variant | Dark Variant |
|----------------|--------------|---------------|--------------|
| Temperature line | system_accent1 (primary) | _600 | _200 |
| Time labels | system_accent3 (tertiary) | _600 | _200 |

### Detection Mechanisms

The widget detects color changes through multiple layered mechanisms:

| Mechanism | Speed | When It Works |
|-----------|-------|---------------|
| **ContentObserver** | Immediate | App process alive (in background) |
| **WorkManager ContentUriTrigger** | Delayed (batched) | Fallback when app killed |
| **USER_PRESENT broadcast** | On unlock | App was force-closed |
| **WeatherUpdateWorker** | ~30 min | Periodic WorkManager task |
| **onUpdate()** | On interaction | Widget resize/tap |

**Primary mechanism:** ContentObserver in `MeteogramApplication` fires instantly when `Settings.Secure.THEME_CUSTOMIZATION_OVERLAY_PACKAGES` changes. This works as long as the app process is alive (even in background).

**Fallbacks:** When the app is force-closed, WorkManager and USER_PRESENT catch the change on next process start or screen unlock.

## Files

| File | Purpose |
|------|---------|
| `MeteogramApplication.kt` | Registers ContentObserver for immediate detection |
| `MaterialYouColorExtractor.kt` | Extracts colors from system, compares with cached values |
| `MaterialYouColorWorker.kt` | WorkManager fallback with content URI trigger |
| `WeatherUpdateWorker.kt` | Periodic WorkManager task, checks colors |
| `MeteogramWidgetProvider.kt` | Checks colors in onUpdate() |
| `WidgetEventReceiver.kt` | Checks colors on USER_PRESENT |

## Data Flow

```
User changes Material You colors in Settings
         │
         ▼
Settings.Secure.THEME_CUSTOMIZATION_OVERLAY_PACKAGES changes
         │
         ├──────────────────────┬──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
   ContentObserver        WorkManager            (App killed)
   (immediate)            (batched delay)              │
         │                      │                      ▼
         │                      │               USER_PRESENT
         │                      │               on next unlock
         │                      │                      │
         └──────────────────────┴──────────────────────┘
                                │
                                ▼
         MaterialYouColorExtractor.checkAndUpdateColors()
                                │
                           ┌────┴────┐
                           │ Changed?│
                           └────┬────┘
                                │ Yes
                                ▼
         Save new colors to SharedPreferences
         (keys: material_you_light_temp, etc.)
                                │
                                ▼
         WidgetUtils.triggerChartReRender()
                                │
                                ▼
         Flutter background callback
         Reads colors from SharedPreferences
         Generates new SVGs with updated colors
                                │
                                ▼
         HomeWidget.updateWidget()
         Widget displays new colors
```

## SharedPreferences Keys

Colors are stored in `HomeWidgetPreferences` for Flutter to read:

- `material_you_light_temp` - Light theme temperature line color (ARGB int)
- `material_you_light_time` - Light theme time label color (ARGB int)
- `material_you_dark_temp` - Dark theme temperature line color (ARGB int)
- `material_you_dark_time` - Dark theme time label color (ARGB int)
- `material_you_colors_hash` - XOR hash for quick change detection

## Why Standard Broadcasts Don't Work

### ACTION_CONFIGURATION_CHANGED

A common question is whether `Intent.ACTION_CONFIGURATION_CHANGED` can detect Material You color changes. **It cannot.**

`ACTION_CONFIGURATION_CHANGED` fires for changes to Android's `Configuration` class:
- ✅ Dark ↔ Light mode (`uiMode`)
- ✅ Locale changes
- ✅ Screen orientation
- ✅ Font scale
- ❌ **Material You accent colors**

Material You palette colors (blue → green → purple) are stored in `Settings.Secure.THEME_CUSTOMIZATION_OVERLAY_PACKAGES`, which is a **system setting**, not part of the `Configuration` class. Android does not broadcast when this setting changes.

### Dark/Light Mode vs Material You Colors

These are two separate concerns:

| Aspect | Dark/Light Mode | Material You Colors |
|--------|-----------------|---------------------|
| Storage | `Configuration.uiMode` | `Settings.Secure` |
| Broadcast | `ACTION_CONFIGURATION_CHANGED` | None |
| Our solution | Dual SVGs with XML visibility | ContentObserver + fallbacks |

**Dark/light mode** is handled automatically by Android. The widget XML uses:
```xml
<ImageView android:visibility="@{isNightMode ? gone : visible}" />  <!-- light -->
<ImageView android:visibility="@{isNightMode ? visible : gone}" />  <!-- dark -->
```
RemoteViews switches visibility instantly when system theme changes - no app code needed.

**Material You accent colors** require active detection because Android provides no broadcast. This is why we use the multi-layered approach (ContentObserver, WorkManager, USER_PRESENT, etc.).

### Why Themed Icons Update Instantly

Android adaptive/themed icons update instantly when Material You colors change because the **launcher renders them**, not the app. The launcher:
1. Receives the icon as a monochrome drawable
2. Applies current Material You colors at render time
3. Re-renders when colors change (launcher observes the setting)

Widgets are different - the **app pre-renders** the content as RemoteViews/bitmaps. The launcher just displays what the app provides. This is why widgets need explicit change detection.

## Dependencies

WorkManager is used for content URI observation:

```kotlin
// android/app/build.gradle.kts
implementation("androidx.work:work-runtime-ktx:2.9.0")
```

Note: This is separate from home_widget's WorkManager usage (which we avoid due to delayed execution - see HOME_WIDGET_VERSION_ISSUE.md).

## Testing

1. **App in background**: Change colors → widget updates immediately
2. **App force-closed**: Change colors → lock/unlock phone → widget updates
3. **Fallback**: Change colors → wait up to 30 min → widget updates on half-hour alarm
