package org.bortnik.meteogram

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.util.Log
import android.view.View
import java.util.concurrent.Executors
import kotlin.math.sqrt

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

    // In-app theme choice, mirrored from Dart so the widget matches the app.
    // Values: "system" | "light" | "dark" (absent == follow system).
    const val KEY_THEME_MODE = "theme_mode"

    /**
     * Map the user's in-app theme choice to (lightVisibility, darkVisibility)
     * for the widget's two chart ImageViews, or null to defer to the system
     * (the night-mode resource qualifiers baked into the layout).
     */
    fun chartVisibilityForThemeMode(mode: String?): Pair<Int, Int>? = when (mode) {
        "light" -> Pair(View.VISIBLE, View.GONE)
        "dark" -> Pair(View.GONE, View.VISIBLE)
        else -> null
    }

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
     * Clamp chart bitmap dimensions so the widget's RemoteViews stay within the
     * launcher's per-widget bitmap budget.
     *
     * AppWidgetService rejects an update whose total bitmap memory exceeds
     * `1.5 x screenArea x 4` bytes, throwing IllegalArgumentException from
     * `updateAppWidget()`. We set TWO bitmaps per update (light + dark charts
     * toggled by night-mode qualifiers), so the two together must fit — i.e.
     * each may use at most `0.75 x screenArea`. Stock launchers cap widget size
     * below this, but some third-party launchers (e.g. Smart Launcher) allow
     * resizing past it, which crashed the whole app process (the widget receiver
     * runs in-process, taking the app and widget down together).
     *
     * When the requested size would overflow the budget, scale both dimensions
     * down proportionally (preserving aspect ratio). The ImageView stretches the
     * bitmap to the view (FIT_XY), so a slightly lower-resolution raster of the
     * same SVG chart is visually indistinguishable — and far better than a crash.
     * A 0.6 (not 0.75) target leaves margin for the small placeholder/indicator
     * bitmaps and for the system measuring against the full display while
     * `displayMetrics` may report a smaller (decor-excluded) area.
     *
     * @return (width, height) in pixels, guaranteed to fit the budget.
     */
    fun clampChartDimensions(context: Context, widthPx: Int, heightPx: Int): Pair<Int, Int> {
        if (widthPx <= 0 || heightPx <= 0) return Pair(widthPx, heightPx)

        val metrics = context.resources.displayMetrics
        val screenArea = metrics.widthPixels.toLong() * metrics.heightPixels.toLong()
        if (screenArea <= 0L) return Pair(widthPx, heightPx)

        val maxBitmapArea = (screenArea * 0.6).toLong()
        val requestedArea = widthPx.toLong() * heightPx.toLong()
        if (requestedArea <= maxBitmapArea) return Pair(widthPx, heightPx)

        val scale = sqrt(maxBitmapArea.toDouble() / requestedArea.toDouble())
        val clampedWidth = (widthPx * scale).toInt().coerceAtLeast(1)
        val clampedHeight = (heightPx * scale).toInt().coerceAtLeast(1)
        Log.d(
            TAG,
            "Clamped chart dimensions ${widthPx}x$heightPx -> ${clampedWidth}x$clampedHeight " +
                "(screen area $screenArea, max bitmap area $maxBitmapArea)"
        )
        return Pair(clampedWidth, clampedHeight)
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
