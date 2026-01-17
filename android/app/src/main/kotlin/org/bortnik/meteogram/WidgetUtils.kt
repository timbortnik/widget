package org.bortnik.meteogram

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log

/**
 * Shared utility functions and constants for widget operations.
 * Centralizes common patterns to avoid code duplication.
 */
object WidgetUtils {
    private const val TAG = "WidgetUtils"

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
     * Runs asynchronously and updates widget on completion.
     */
    fun fetchWeather(context: Context) {
        Log.d(TAG, "Triggering native weather fetch")
        WeatherFetcher.fetchAndUpdate(context)
    }

    /**
     * Check if weather data is stale (older than STALE_THRESHOLD_MS).
     * @return true if data should be refreshed
     */
    fun isWeatherDataStale(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastUpdate = prefs.getLong(KEY_LAST_WEATHER_UPDATE, 0)
        val ageMs = System.currentTimeMillis() - lastUpdate
        val isStale = ageMs > STALE_THRESHOLD_MS

        val ageMinutes = ageMs / 60000
        Log.d(TAG, "Weather data age: ${ageMinutes}min, stale: $isStale")

        return isStale
    }

    /**
     * Fetch weather data only if stale. Otherwise skip to avoid unnecessary API calls.
     */
    fun fetchWeatherIfStale(context: Context) {
        if (isWeatherDataStale(context)) {
            Log.d(TAG, "Data stale - fetching weather")
            fetchWeather(context)
        } else {
            Log.d(TAG, "Data fresh - skipping fetch")
        }
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
        val lastWeatherUpdate = prefs.getLong(KEY_LAST_WEATHER_UPDATE, 0)
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
     * Trigger native widget update for all widgets.
     * This calls AppWidgetManager directly, which invokes MeteogramWidgetProvider.onUpdate()
     * and uses native SVG generation (no Dart/Flutter involved).
     */
    fun rerenderAllWidgetsNative(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, MeteogramWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)

            if (widgetIds.isEmpty()) {
                Log.d(TAG, "No widgets to update")
                return
            }

            Log.d(TAG, "Triggering native update for ${widgetIds.size} widgets")

            // notifyAppWidgetViewDataChanged triggers onUpdate
            for (widgetId in widgetIds) {
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, android.R.id.list)
            }

            // Also send explicit update intent
            val intent = android.content.Intent(context, MeteogramWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            }
            context.sendBroadcast(intent)

            Log.d(TAG, "Native widget update triggered for ${widgetIds.joinToString()}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger native widget update", e)
        }
    }
}
