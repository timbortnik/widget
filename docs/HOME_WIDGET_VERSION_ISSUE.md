# home_widget Version Issue: Background Callback Delays

## Summary

The `home_widget` package version 0.9.0 introduced a breaking change that affects widget resize handling. Background callbacks triggered via `HomeWidgetBackgroundIntent` are delayed or unreliable, causing widget resizes to not immediately regenerate SVG charts.

## Root Cause

| Version | Background Mechanism | Behavior |
|---------|---------------------|----------|
| 0.7.0+1 | `JobIntentService` | Executes immediately |
| 0.9.0 | `WorkManager` | Delayed execution (system-managed) |

In version 0.9.0, the library switched from `JobIntentService` to `WorkManager` for background task execution. WorkManager is designed for deferrable work and includes built-in delays ("Minimum latency" constraints) that prevent immediate execution.

## Affected Functionality

- **Widget resize**: When user resizes the widget, `onAppWidgetOptionsChanged` triggers `WidgetUtils.triggerChartReRender()` which sends a `HomeWidgetBackgroundIntent`. With 0.9.0, the Flutter callback may not execute promptly.

- **Half-hour updates**: Similar issue affects `HourlyAlarmReceiver` triggering chart re-renders at :30.

- **Theme/locale changes**: `WidgetEventReceiver` broadcasts may also be affected.

## Bisect Results

```
First bad commit: 49c18c1fa3b9aa8a2e557dd864aa92187b887ccb

    Update dependencies to latest versions

    - geocoding: 3.0.0 → 4.0.0
    - geolocator: 13.0.4 → 14.0.2
    - home_widget: 0.7.0+1 → 0.9.0
```

Tested commits:
- `5b82f63` (home_widget 0.7.0+1) - **GOOD** - Resize works immediately
- `48337e8` (home_widget 0.7.0+1) - **GOOD** - Resize works immediately
- `49c18c1` (home_widget 0.9.0) - **BAD** - Resize delayed/unreliable
- `817c817` (home_widget 0.9.0) - **BAD** - Resize delayed/unreliable

## Resolution

**Applied: Pinned to home_widget 0.8.0**

Version 0.8.0 is the last version using `JobIntentService` (immediate execution).
Version 0.8.1+ switched to `WorkManager` (delayed execution).

Changes made:
- Pinned `home_widget` to 0.8.0 in `pubspec.yaml`
- Removed `workmanager` dependency (not needed)
- Removed WorkManager-related code from `background_service.dart`

Widget resize now works immediately.

**Why 0.8.0 over 0.7.0+1**: Version 0.8.0 includes Android 15 runtime fix (#330) while still using JobIntentService.

**Note on deprecation**: `JobIntentService` is deprecated (API 30) but still functional. This doesn't affect Play Store publishing (targetSdk requirements are separate from internal API usage). Monitor for future Android versions that may remove the API.

---

## Alternative Workarounds (Not Used)

### Option 1: Downgrade home_widget ✓ APPLIED

Pin `home_widget` to version 0.7.0+1 in `pubspec.yaml`:

```yaml
dependencies:
  home_widget: 0.7.0+1  # Pinned - see docs/HOME_WIDGET_VERSION_ISSUE.md
```

### Option 2: Native-only resize handling

Since SVG is vector-based, the native `MeteogramWidgetProvider` already scales the SVG to current widget dimensions when rendering. The visual result is correct even without regenerating the SVG.

Only regenerate SVGs when:
- Weather data is fetched (already working)
- App goes to background (already working)
- Significant dimension change threshold exceeded

### Option 3: Direct native callback

Bypass `HomeWidgetBackgroundIntent` for resize events and use a different mechanism:
- Native broadcast receiver that triggers Flutter via method channel
- Or render charts entirely in native code

## Technical Details

### home_widget 0.7.0+1 (Working)

Uses `HomeWidgetBackgroundService` extending `JobIntentService`:
- Executes immediately when broadcast received
- No system-imposed delays

### home_widget 0.9.0 (Broken for our use case)

Uses `HomeWidgetBackgroundWorker` with `WorkManager`:
- Jobs enqueued with `ExistingWorkPolicy.APPEND`
- System manages execution timing
- May batch or delay work for battery optimization

## References

- home_widget changelog: https://pub.dev/packages/home_widget/changelog
- WorkManager documentation: https://developer.android.com/topic/libraries/architecture/workmanager
- Related issue investigation: 2026-01-13
