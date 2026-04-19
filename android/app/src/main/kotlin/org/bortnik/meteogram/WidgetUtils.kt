package org.bortnik.meteogram

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.util.Log
import java.util.concurrent.Executors

/**
 * Shared utility functions and constants for widget operations.
 * Centralizes common patterns to avoid code duplication.
 */
object WidgetUtils {
    private const val TAG = "WidgetUtils"
    private val executor = Executors.newSingleThreadExecutor()

    // Default fallback dimensions for chart rendering when SharedPreferences unavailable
    // Based on typical 4x4 grid widget at ~3x density: 300dp * 3 ≈ 900px
    const val DEFAULT_WIDTH_PX = 1000
    const val DEFAULT_HEIGHT_PX = 500

    // Staleness threshold for weather data (15 minutes)
    const val STALE_THRESHOLD_MS = 15 * 60 * 1000L

    // SharedPreferences keys (contract between native and Flutter)
    const val PREFS_NAME = "HomeWidgetPreferences"
    const val KEY_WIDGET_WIDTH_PX = "widget_width_px"
    const val KEY_WIDGET_HEIGHT_PX = "widget_height_px"
    const val KEY_LAST_WEATHER_UPDATE = "last_weather_update"
    const val KEY_LAST_RENDER_TIME = "last_render_time"

    // 30-minute boundary for "now" indicator updates
    private const val HALF_HOUR_MS = 30 * 60 * 1000L

    /**
     * All widget provider classes the app ships. rerenderAllWidgetsNative
     * iterates this list so every provider type receives an update broadcast.
     */
    private val WIDGET_PROVIDERS: List<Class<out AppWidgetProvider>> = listOf(
        MeteogramWidgetProvider::class.java,
        MeteogramWeeklyWidgetProvider::class.java
    )

    /**
     * Get widget dimensions from SharedPreferences with fallback defaults.
     * @return Pair of (width, height) in pixels
     */
    fun getWidgetDimensions(context: Context): Pair<Int, Int> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var width = prefs.getInt(KEY_WIDGET_WIDTH_PX, 0)
        var height = prefs.getInt(KEY_WIDGET_HEIGHT_PX, 0)

        if (width <= 0) width = DEFAULT_WIDTH_PX
        if (height <= 0) height = DEFAULT_HEIGHT_PX

        return Pair(width, height)
    }

    /**
     * Fetch weather natively via Open-Meteo API.
     * Runs asynchronously on a background thread and updates widget on completion.
     *
     * @param pendingResult PendingResult from goAsync() to keep the
     *   calling BroadcastReceiver's process alive until the fetch completes.
     */
    fun fetchWeather(context: Context, pendingResult: BroadcastReceiver.PendingResult? = null) {
        Log.d(TAG, "Triggering native weather fetch")
        executor.execute {
            try {
                WeatherFetcher.fetchAndUpdateSync(context)
            } catch (e: Exception) {
                Log.e(TAG, "Weather fetch failed", e)
            } finally {
                pendingResult?.finish()
            }
        }
    }

    /**
     * Fetch weather synchronously via Open-Meteo API.
     * Blocks until fetch completes. Call from a background thread only
     * (e.g., WorkManager's doWork()).
     */
    fun fetchWeatherSync(context: Context) {
        Log.d(TAG, "Triggering native weather fetch (sync)")
        WeatherFetcher.fetchAndUpdateSync(context)
    }

    /**
     * Check if weather data is stale (older than STALE_THRESHOLD_MS).
     * @return true if data should be refreshed
     */
    fun isWeatherDataStale(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // Read as string (stored for home_widget compatibility)
        val lastUpdate = prefs.getString(KEY_LAST_WEATHER_UPDATE, null)?.toLongOrNull() ?: 0L
        val ageMs = System.currentTimeMillis() - lastUpdate
        val isStale = ageMs > STALE_THRESHOLD_MS

        val ageMinutes = ageMs / 60000
        Log.d(TAG, "Weather data age: ${ageMinutes}min, stale: $isStale")

        return isStale
    }

    /**
     * Check if chart re-render is needed based on:
     * 1. 30-minute boundary crossed since last render (now indicator moved)
     * 2. Weather data updated since last render (background fetch while locked)
     * @return true if re-render is needed
     */
    fun isRerenderNeeded(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastRenderTime = prefs.getLong(KEY_LAST_RENDER_TIME, 0)
        // Read as string (stored for home_widget compatibility)
        val lastWeatherUpdate = prefs.getString(KEY_LAST_WEATHER_UPDATE, null)?.toLongOrNull() ?: 0L
        val now = System.currentTimeMillis()

        // Check if weather was updated since last render
        if (lastWeatherUpdate > lastRenderTime) {
            Log.d(TAG, "Re-render needed: weather updated since last render")
            return true
        }

        // Check if we crossed a 30-minute boundary
        // Floor divide by 30 min to get the "slot" number
        val lastSlot = lastRenderTime / HALF_HOUR_MS
        val currentSlot = now / HALF_HOUR_MS
        if (currentSlot > lastSlot) {
            Log.d(TAG, "Re-render needed: crossed 30-min boundary (slot $lastSlot -> $currentSlot)")
            return true
        }

        val minutesSinceRender = (now - lastRenderTime) / 60000
        Log.d(TAG, "Re-render not needed: ${minutesSinceRender}min since last render, same 30-min slot")
        return false
    }

    /**
     * Update the last render timestamp.
     * Call this after successful render.
     */
    fun updateLastRenderTime(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong(KEY_LAST_RENDER_TIME, System.currentTimeMillis()).apply()
    }

    /**
     * Re-render all widgets only if needed (30-min boundary crossed or weather updated).
     * More efficient than unconditional re-render on every screen unlock.
     */
    fun rerenderAllWidgetsIfNeeded(context: Context) {
        if (isRerenderNeeded(context)) {
            rerenderAllWidgetsNative(context)
        }
    }

    /**
     * Trigger native widget update for every registered provider type.
     * This calls AppWidgetManager directly, which invokes onUpdate()
     * on each provider and uses native SVG generation (no Dart/Flutter involved).
     */
    fun rerenderAllWidgetsNative(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        for (providerClass in WIDGET_PROVIDERS) {
            try {
                val componentName = ComponentName(context, providerClass)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)

                if (widgetIds.isEmpty()) {
                    Log.d(TAG, "No ${providerClass.simpleName} widgets to update")
                    continue
                }

                Log.d(TAG, "Triggering native update for ${widgetIds.size} ${providerClass.simpleName} widgets")

                val intent = android.content.Intent(context, providerClass).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                }
                context.sendBroadcast(intent)

                Log.d(TAG, "Native widget update triggered for ${providerClass.simpleName}: ${widgetIds.joinToString()}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to trigger native widget update for ${providerClass.simpleName}", e)
            }
        }
    }
}
