# Lessons Learned

Architectural decisions and insights discovered during development.

## Battery Efficiency: Native-Only Widget Updates

**Problem:** Initial implementation used Flutter for widget background updates, causing high battery drain (6+ hours of background activity reported).

**Root cause:** Every widget update required spinning up the Flutter engine:
- Dart VM initialization
- Isolate spawning
- Platform channel overhead
- Flutter framework bootstrap

**Solution:** Move all widget update logic to native Kotlin:

| Component | Before (Flutter) | After (Native) |
|-----------|-----------------|----------------|
| Weather fetch | Dart HTTP | OkHttp |
| SVG generation | Dart strings | Kotlin strings |
| Rendering | Platform channel | AndroidSVG direct |
| Engine startup | Required | Not needed |

**Result:** App dropped from "6 hours background activity" to not appearing in top 15 battery consumers. The Flutter app now only runs when the user opens it.

**Key insight:** For Android widgets, avoid Flutter in background updates entirely. Native code is dramatically lighter for periodic tasks.

**Related commits:**
- `daecf01` - Move weather fetching and SVG generation to native Kotlin
- `e007d88` - Replace AlarmManager with WorkManager for battery efficiency

**Related docs:**
- [NATIVE_SVG_RENDERING.md](NATIVE_SVG_RENDERING.md) - Technical architecture details

---

## Scheduling: Combining WorkManager and AlarmManager

**Problem:** Finding the right balance between timely widget updates and battery efficiency.

**Failed approaches:**

| Approach | Issue |
|----------|-------|
| `setAndAllowWhileIdle()` | System batched aggressively (40+ min delays) |
| `setWindow()` with hourly alarms | More predictable but still battery-heavy |
| AlarmManager alone | Not Doze-aware, poor for network tasks |
| WorkManager alone | Too heavily batched for "now" indicator |

**Solution:** Use both schedulers for their strengths:

| Scheduler | Purpose | Config |
|-----------|---------|--------|
| **WorkManager** | Weather fetches (network) | 30 min, `NetworkType.CONNECTED` |
| **AlarmManager** | "Now" indicator re-renders | 15 min, `ELAPSED_REALTIME`, `setInexactRepeating()` |

**Key configurations:**

```kotlin
// WorkManager - Doze-aware, batched by OS, requires network
val constraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .build()
PeriodicWorkRequestBuilder<WeatherUpdateWorker>(30, TimeUnit.MINUTES)
    .setConstraints(constraints)
    .build()

// AlarmManager - non-waking, fires when device already awake
alarmManager.setInexactRepeating(
    AlarmManager.ELAPSED_REALTIME,  // NOT _WAKEUP
    SystemClock.elapsedRealtime() + INTERVAL_MS,
    INTERVAL_MS,
    pendingIntent
)
```

**Why this works:**
- `ELAPSED_REALTIME` (not `_WAKEUP`) - doesn't wake device from sleep
- `setInexactRepeating()` - allows OS to batch with other alarms
- WorkManager handles Doze mode automatically
- No wake locks held

**Result:** Device can deep sleep undisturbed. Updates happen opportunistically when device wakes for other reasons.

**Related commits:**
- `441948b` - Add AlarmManager and BOOT_COMPLETED for reliable widget updates
- `e007d88` - Replace HourlyAlarmReceiver with WorkManager

---

## Broadcast Receivers: Avoid USER_PRESENT for Widgets

**Problem:** Using `ACTION_USER_PRESENT` (screen unlock) to trigger widget updates seemed like a good way to ensure fresh data when the user looks at their home screen.

**Why it failed:**

Since Android 8.0 (Oreo), implicit broadcasts like `USER_PRESENT` require **runtime registration** - they cannot be declared in the manifest. This means:

| App State | USER_PRESENT Works? |
|-----------|---------------------|
| App running | Yes |
| App in background (cached) | Yes |
| App killed by OS | No |

**The inconsistency problem:**
- User unlocks phone → widget updates (app was cached)
- OS kills app to reclaim memory
- User unlocks phone → nothing happens (no process to receive broadcast)
- User opens app, closes it
- User unlocks phone → widget updates again (process restored)

This creates unpredictable behavior that's hard to debug and confuses users.

**Better alternatives:**
- `AlarmManager` with `ELAPSED_REALTIME` - fires on wake regardless of app state
- `WorkManager` - system manages scheduling, survives app death
- Widget's `updatePeriodMillis` - system-guaranteed minimum updates

**Key insight:** For widgets, prefer scheduling mechanisms that work independently of app process state. Avoid implicit broadcasts that require runtime registration.

**Related commits:**
- `e771d92` - Remove USER_PRESENT handler for consistent widget behavior

---

## Rendering: Why SVG Over Other Options

**Problem:** Need a chart rendering approach that works for both the in-app display and Android widget background updates.

**Options considered:**

| Approach | Pros | Cons |
|----------|------|------|
| **fl_chart** | Rich interactivity, easy API | Requires `dart:ui`, won't work in background |
| **Flutter CustomPainter** | Full control | Same `dart:ui` limitation |
| **Pre-rendered PNGs** | Simple | Not scalable, huge file sizes for all resolutions |
| **Native Canvas (Kotlin)** | Fast | Complex drawing code, harder to maintain |
| **SVG generation (Kotlin)** | Readable, scalable, debuggable | Slight string-building complexity |

**Why SVG won:**

1. **Resolution independent** - Same SVG scales perfectly to any widget size
2. **Debuggable** - Can inspect SVG string directly, paste into browser to visualize
3. **Small payload** - SVG strings are ~10KB vs ~75KB for equivalent PNG
4. **Native rendering** - AndroidSVG library efficiently renders to bitmap
5. **No Flutter engine** - Entire pipeline runs in native Kotlin

**The native-only pipeline:**

```
Kotlin: WeatherFetcher
         ↓
    JSON weather data
         ↓
Kotlin: SvgChartGenerator
         ↓
    SVG string (~10KB)
         ↓
Kotlin: AndroidSVG
         ↓
    Bitmap → ImageView
```

No Flutter, no Dart, no platform channels for widget updates.

**Key insight:** SVG as an intermediate format gives you human-readable, scalable graphics that can be generated with simple string operations and rendered natively.

**Related docs:**
- [NATIVE_SVG_RENDERING.md](NATIVE_SVG_RENDERING.md) - Full technical implementation details

---

## Security: CodeQL and Explicit Intent Patterns

**Problem:** CodeQL flagged `implicit-pendingintents` warning even though the Intent was explicitly targeting a specific class.

**The code that triggered the warning:**

```kotlin
// CodeQL doesn't recognize this as explicit
val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
    action = WidgetAlarmReceiver.ACTION_ALARM_UPDATE
    setPackage(context.packageName)
}
```

**Why CodeQL complained:**

CodeQL's static analysis looks for specific patterns to determine if an Intent is explicit. The `Intent(Context, Class)` constructor, while functionally explicit, isn't pattern-matched by CodeQL's query.

**The fix:**

```kotlin
// CodeQL recognizes setClass() as making the Intent explicit
val intent = Intent().setClass(context, WidgetAlarmReceiver::class.java).apply {
    action = WidgetAlarmReceiver.ACTION_ALARM_UPDATE
    setPackage(context.packageName)
}
```

Both are functionally identical - the difference is purely in how CodeQL's static analysis recognizes explicit component targeting.

**Key insight:** When security scanners flag false positives, sometimes the fix is using an equivalent pattern the scanner recognizes, rather than suppressing the warning.

**Related commits:**
- `d446717` - Use setClass() for explicit Intent to fix CodeQL warning

---

## Event Detection: Layered Observers for Reliability

**Problem:** Detecting Material You color changes to update widget appearance. Need instant response when possible, but also reliability when app is killed.

**The challenge:**

`ContentObserver` watching `Settings.Secure` fires instantly when wallpaper/theme changes, but requires a live process. If Android kills the app, the observer dies with it.

**Solution:** Layer multiple detection mechanisms:

| Mechanism | When it works | Latency |
|-----------|---------------|---------|
| **ContentObserver** | App process alive | Instant |
| **WorkManager** | Always (survives app death) | Up to 30 min |

```kotlin
// Instant detection while alive
contentResolver.registerContentObserver(
    Settings.Secure.getUriFor("theme_customization_overlay_packages"),
    false,
    themeObserver
)

// Fallback when killed - checks on next periodic run
class WeatherUpdateWorker : Worker() {
    override fun doWork(): Result {
        if (MaterialYouColorExtractor.updateColorsIfChanged(context)) {
            WidgetUtils.rerenderAllWidgetsNative(context)
        }
        // ... rest of work
    }
}
```

**Why this pattern:**
- Best case: User changes wallpaper → widget updates in <1 second
- Worst case: App was killed → widget updates within 30 minutes
- No battery drain from polling

**Key insight:** For system events that require runtime registration, layer a fast observer (for responsiveness) with a scheduled fallback (for reliability). Accept that the fallback may have higher latency.

**Related docs:**
- [MATERIAL_YOU_COLORS.md](MATERIAL_YOU_COLORS.md) - Full implementation details
