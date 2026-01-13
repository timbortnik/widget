# Expedited WorkManager: Replacing home_widget

## Background

The `home_widget` package provides Flutter ↔ native bridging for widget callbacks. However:

- **v0.7.0+1 / v0.8.0**: Uses `JobIntentService` (immediate execution, but deprecated API 30)
- **v0.8.1+**: Uses `WorkManager` without `setExpedited()` (delayed execution)

We're currently pinned to v0.8.0 for immediate execution. This document outlines how to replace home_widget entirely with our own expedited WorkManager implementation.

## Why Replace home_widget?

1. **JobIntentService is deprecated** - May be removed in future Android versions
2. **Full control** - Can use `setExpedited()` for immediate execution
3. **Reduced dependencies** - One less package to maintain
4. **Modern API** - WorkManager is the recommended approach

## Implementation Plan

### New Files to Create

#### 1. FlutterBackgroundWorker.kt

Expedited `CoroutineWorker` that starts a `FlutterEngine` and executes Dart callbacks.

```kotlin
class FlutterBackgroundWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // 1. Get callback handle from SharedPreferences
        // 2. Start FlutterEngine if not running
        // 3. Execute Dart callback via MethodChannel
        // 4. Wait for completion
        return Result.success()
    }

    // Required for Android < 12 backward compatibility
    override suspend fun getForegroundInfo(): ForegroundInfo {
        return ForegroundInfo(
            NOTIFICATION_ID,
            createNotification()  // Silent notification
        )
    }

    companion object {
        fun enqueue(context: Context, uri: Uri) {
            val data = Data.Builder()
                .putString("uri", uri.toString())
                .build()

            val request = OneTimeWorkRequestBuilder<FlutterBackgroundWorker>()
                .setInputData(data)
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork("flutter_callback", ExistingWorkPolicy.APPEND, request)
        }
    }
}
```

Key difference from home_widget 0.9.0: **`setExpedited()`** for immediate execution.

#### 2. FlutterBackgroundIntent.kt

Replacement for `HomeWidgetBackgroundIntent`:

```kotlin
object FlutterBackgroundIntent {
    fun trigger(context: Context, uri: Uri) {
        FlutterBackgroundWorker.enqueue(context, uri)
    }
}
```

### Files to Modify

#### 1. MeteogramWidgetProvider.kt

Change from:
```kotlin
class MeteogramWidgetProvider : HomeWidgetProvider()
```

To:
```kotlin
class MeteogramWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Direct implementation without HomeWidgetProvider
    }
}
```

#### 2. WidgetUtils.kt

Replace:
```kotlin
es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
```

With:
```kotlin
FlutterBackgroundIntent.trigger(context, uri)
```

#### 3. background_service.dart

Replace:
```dart
await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
```

With custom registration that stores callback handle in SharedPreferences.

#### 4. All Flutter files using HomeWidget

| Old (home_widget) | New (direct) |
|-------------------|--------------|
| `HomeWidget.saveWidgetData<T>(key, value)` | `SharedPreferences.setX(key, value)` |
| `HomeWidget.getWidgetData<T>(key)` | `SharedPreferences.getX(key)` |
| `HomeWidget.updateWidget(androidName: ...)` | `MethodChannel` → native `AppWidgetManager.updateAppWidget()` |

### Dependencies

```kotlin
// android/app/build.gradle.kts
implementation("androidx.work:work-runtime-ktx:2.9.0")  // Already added
```

```yaml
# pubspec.yaml
# Remove: home_widget: 0.8.0
# Add: shared_preferences (already have)
```

## FlutterEngine in Background

The key challenge is starting a `FlutterEngine` in a background worker. Here's how home_widget does it:

```kotlin
// From HomeWidgetBackgroundWorker.kt (0.9.0)
private suspend fun initializeFlutterEngine() {
    val callbackHandle = getDispatcherHandle(context)  // From SharedPreferences
    val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

    withContext(Dispatchers.Main) {
        engine = FlutterEngine(context)
        val callback = DartExecutor.DartCallback(
            context.assets,
            FlutterInjector.instance().flutterLoader().findAppBundlePath(),
            callbackInfo,
        )
        engine?.dartExecutor?.executeDartCallback(callback)
    }
}
```

This pattern:
1. Stores Dart callback handle during app initialization
2. Looks up callback info when worker runs
3. Creates FlutterEngine on main thread
4. Executes Dart callback

## Backward Compatibility (Android < 12)

On Android 11 and earlier, expedited work runs as a **foreground service**. This requires:

1. `getForegroundInfo()` implementation in worker
2. Notification channel setup
3. `FOREGROUND_SERVICE` permission in manifest

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

The notification can be silent/low-priority to minimize user disruption.

## Estimated Effort

| Task | Complexity |
|------|------------|
| FlutterBackgroundWorker.kt | Medium - adapt from home_widget source |
| FlutterBackgroundIntent.kt | Low - simple wrapper |
| MeteogramWidgetProvider changes | Low - mostly removing base class |
| WidgetUtils changes | Low - change import/call |
| Dart side changes | Medium - replace HomeWidget calls |
| Testing | Medium - verify all triggers work |

**Total: ~1-2 days of focused work**

## References

- [WorkManager expedited jobs](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work)
- [home_widget 0.8.0 source](https://github.com/ABausG/home_widget/tree/v0.8.0)
- [home_widget 0.9.0 source](https://github.com/ABausG/home_widget/tree/v0.9.0)
- [FlutterEngine background execution](https://docs.flutter.dev/packages-and-plugins/background-processes)

## Decision

**Current state:** Using home_widget 0.8.0 (JobIntentService) - works but uses deprecated API.

**Future:** When JobIntentService stops working or we want to modernize, implement this plan.
