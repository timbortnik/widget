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
| **HourlyAlarmReceiver** | ≤1 hour | Backup/fallback |
| **onUpdate()** | On interaction | Widget resize/tap |

**Primary mechanism:** ContentObserver in `MeteogramApplication` fires instantly when `Settings.Secure.THEME_CUSTOMIZATION_OVERLAY_PACKAGES` changes. This works as long as the app process is alive (even in background).

**Fallbacks:** When the app is force-closed, WorkManager and USER_PRESENT catch the change on next process start or screen unlock.

## Files

| File | Purpose |
|------|---------|
| `MeteogramApplication.kt` | Registers ContentObserver for immediate detection |
| `MaterialYouColorExtractor.kt` | Extracts colors from system, compares with cached values |
| `MaterialYouColorWorker.kt` | WorkManager fallback with content URI trigger |
| `MeteogramWidgetProvider.kt` | Checks colors in onUpdate() |
| `WidgetEventReceiver.kt` | Checks colors on USER_PRESENT |
| `HourlyAlarmReceiver.kt` | Checks colors on hourly alarm |

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
3. **Fallback**: Change colors → wait up to 1 hour → widget updates on hourly alarm
