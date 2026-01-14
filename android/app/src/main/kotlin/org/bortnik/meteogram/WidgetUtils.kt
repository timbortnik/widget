package org.bortnik.meteogram

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
     * Get current system locale as string for passing to Flutter.
     * Format: "language_COUNTRY" (e.g., "en_US", "uk_UA")
     */
    fun getLocaleString(): String {
        val locale = java.util.Locale.getDefault()
        return "${locale.language}_${locale.country}"
    }

    /**
     * Re-render chart via HomeWidget background intent.
     * Passes dimensions and locale in URI for cold-start reliability.
     */
    fun rerenderChart(context: Context) {
        try {
            val (widthPx, heightPx) = getWidgetDimensions(context)
            val localeStr = getLocaleString()

            es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homewidget://chartReRender?width=$widthPx&height=$heightPx&locale=$localeStr")
            ).send()
            Log.d(TAG, "Chart re-render triggered (${widthPx}x${heightPx}, locale=$localeStr)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger chart re-render", e)
        }
    }

    /**
     * Fetch weather via HomeWidget background intent.
     */
    fun fetchWeather(context: Context) {
        try {
            es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homewidget://weatherUpdate")
            ).send()
            Log.d(TAG, "Weather fetch triggered via HomeWidget")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger weather fetch", e)
        }
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
}
