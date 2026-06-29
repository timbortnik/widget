package org.bortnik.meteogram

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.os.Build
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.os.Bundle
import android.text.format.DateFormat
import android.util.Log
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.View
import android.widget.RemoteViews
import com.caverock.androidsvg.SVG
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileInputStream
import java.util.Locale

/**
 * Default (48-hour) meteogram widget provider. Also serves as the base class
 * for variants (e.g. the 7-day weekly widget) — subclasses override the
 * extension points to change layout, time range, or time labels without
 * re-implementing the full RemoteViews update cycle.
 */
open class MeteogramWidgetProvider : AppWidgetProvider() {
    /** Layout resource used for this widget's RemoteViews. */
    protected open val layoutRes: Int = R.layout.meteogram_widget

    /** Logcat tag for this provider. */
    protected open val logTag: String = "MeteogramWidget"

    /** Spacing between X-axis labels and grid lines, in hours. */
    protected open val labelStepHours: Int = 12

    /** Format used for X-axis labels. */
    protected open val labelFormat: TimeLabelFormat = TimeLabelFormat.HOUR

    /** Slice of weather data to render in the chart. */
    protected open fun chartView(weatherData: WeatherData): ChartView =
        weatherData.getHourlyView()

    companion object {
        private const val KEY_WIDGET_IDS = "widget_ids"

        // Recovery bounds for updateWidgetWithRetry: how many times to shrink the
        // chart bitmaps when the launcher rejects an over-budget update, and the
        // pixel floor below which retrying is pointless.
        private const val MAX_UPDATE_ATTEMPTS = 4
        private const val MIN_CHART_DIMENSION_PX = 64
    }

    private fun saveWidgetDimensions(prefs: SharedPreferences, widgetId: Int, widthPx: Int, heightPx: Int, density: Float) {
        prefs.edit()
            .putInt("widget_${widgetId}_width_px", widthPx)
            .putInt("widget_${widgetId}_height_px", heightPx)
            .putFloat("widget_${widgetId}_density", density)
            .commit()
    }

    private fun getWidgetDimensions(prefs: SharedPreferences, widgetId: Int): Pair<Int, Int>? {
        val width = prefs.getInt("widget_${widgetId}_width_px", 0)
        val height = prefs.getInt("widget_${widgetId}_height_px", 0)
        return if (width > 0 && height > 0) Pair(width, height) else null
    }

    /**
     * Check if device uses Fahrenheit based on locale.
     * US, Liberia, and Myanmar use Fahrenheit.
     */
    private fun usesFahrenheit(): Boolean {
        val country = Locale.getDefault().country
        return country in listOf("US", "LR", "MM")
    }

    /**
     * Generate SVG chart natively and render to bitmap.
     * @return Bitmap or null if generation fails
     */
    private fun generateChartBitmap(
        context: Context,
        weatherData: WeatherData,
        colors: SvgChartColors,
        width: Int,
        height: Int
    ): Bitmap? {
        if (width <= 0 || height <= 0) {
            Log.e(logTag, "Invalid dimensions for native SVG generation: ${width}x${height}")
            return null
        }

        return try {
            val view = chartView(weatherData)

            val generator = SvgChartGenerator()
            val svgString = generator.generate(
                data = view.data,
                nowIndex = view.nowIndex,
                latitude = weatherData.latitude,
                longitude = weatherData.longitude,
                colors = colors,
                width = width.toDouble(),
                height = height.toDouble(),
                locale = Locale.getDefault(),
                usesFahrenheit = usesFahrenheit(),
                use24HourFormat = DateFormat.is24HourFormat(context),
                labelStepHours = labelStepHours,
                labelFormat = labelFormat
            )

            renderSvgStringToBitmap(svgString, width, height)
        } catch (e: Exception) {
            Log.e(logTag, "Error generating native chart", e)
            null
        }
    }

    private fun renderSvgStringToBitmap(svgString: String, width: Int, height: Int): Bitmap? {
        return try {
            ByteArrayInputStream(svgString.toByteArray()).use { inputStream ->
                val svg = SVG.getFromInputStream(inputStream)
                svg.documentWidth = width.toFloat()
                svg.documentHeight = height.toFloat()

                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                svg.renderToCanvas(canvas)
                bitmap
            }
        } catch (e: Exception) {
            Log.e(logTag, "Error rendering SVG string to bitmap", e)
            null
        } catch (e: OutOfMemoryError) {
            // A too-large bitmap allocation is an Error, not an Exception, so it
            // would escape the catch above and crash the in-process receiver.
            // Degrade to null (caller falls back to a smaller render/placeholder).
            Log.e(logTag, "Out of memory rendering SVG string to bitmap (${width}x$height)", e)
            null
        }
    }

    /**
     * Apply the user's in-app theme choice to the widget. By default the layout
     * switches the light/dark charts via night-mode resource qualifiers and the
     * card uses ?android:attr/colorBackground (the "system" option); a manual
     * Light/Dark choice overrides both here so the widget matches the app.
     */
    private fun applyThemeOverride(context: Context, views: RemoteViews) {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val mode = prefs.getString(WidgetUtils.KEY_THEME_MODE, null)
        val visibility = WidgetUtils.chartVisibilityForThemeMode(mode) ?: return
        views.setViewVisibility(R.id.widget_chart_light, visibility.first)
        views.setViewVisibility(R.id.widget_chart_dark, visibility.second)
        // The visible "card" is the widget root background, which otherwise only
        // tracks the system night mode — force it to match the chosen theme.
        views.setInt(
            R.id.widget_root,
            "setBackgroundColor",
            resolveColorBackground(context, night = mode == "dark")
        )
    }

    /**
     * Resolve ?android:attr/colorBackground as it would be inflated under the
     * given night mode, so a forced theme's card matches the system look.
     */
    private fun resolveColorBackground(context: Context, night: Boolean): Int {
        val config = Configuration(context.resources.configuration)
        val nightFlag = if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        // Split the mask and the set onto separate statements so no single line
        // mixes `and`/`or` (avoids CodeQL's operator-precedence-whitespace alert).
        val modeWithoutNight = config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()
        config.uiMode = modeWithoutNight or nightFlag
        val themed = ContextThemeWrapper(
            context.createConfigurationContext(config),
            R.style.WidgetTheme
        )
        val tv = TypedValue()
        themed.theme.resolveAttribute(android.R.attr.colorBackground, tv, true)
        return if (tv.resourceId != 0) themed.getColor(tv.resourceId) else tv.data
    }

    private fun updateWidgetIdsList(context: Context, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val idsString = widgetIds.joinToString(",")
        prefs.edit().putString(KEY_WIDGET_IDS, idsString).commit()
        Log.d(logTag, "Updated widget IDs list: $idsString")
    }

    private fun cleanupDeletedWidgets(context: Context, deletedIds: IntArray) {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (widgetId in deletedIds) {
            editor.remove("widget_${widgetId}_width_px")
            editor.remove("widget_${widgetId}_height_px")
            editor.remove("widget_${widgetId}_density")
            editor.remove("svg_path_light_$widgetId")
            editor.remove("svg_path_dark_$widgetId")
            Log.d(logTag, "Cleaned up data for deleted widget $widgetId")
        }
        editor.commit()
    }

    private fun renderSvgToBitmap(svgPath: String, width: Int, height: Int): Bitmap? {
        if (width <= 0 || height <= 0) {
            Log.e(logTag, "Invalid dimensions for SVG rendering: ${width}x${height}")
            return null
        }

        return try {
            FileInputStream(svgPath).use { inputStream ->
                val svg = SVG.getFromInputStream(inputStream)
                svg.documentWidth = width.toFloat()
                svg.documentHeight = height.toFloat()

                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                svg.renderToCanvas(canvas)
                bitmap
            }
        } catch (e: Exception) {
            Log.e(logTag, "Error rendering SVG", e)
            null
        } catch (e: OutOfMemoryError) {
            // See renderSvgStringToBitmap: OOM is an Error, caught here so an
            // over-budget allocation degrades to null instead of crashing.
            Log.e(logTag, "Out of memory rendering SVG (${width}x$height)", e)
            null
        }
    }

    private fun loadChartBitmap(svgPath: String?, pngPath: String?, width: Int, height: Int): Bitmap? {
        if (svgPath != null) {
            val svgFile = File(svgPath)
            if (svgFile.exists()) {
                val bitmap = renderSvgToBitmap(svgPath, width, height)
                if (bitmap != null) {
                    Log.d(logTag, "Loaded chart from SVG: $svgPath")
                    return bitmap
                }
            }
        }

        if (pngPath != null) {
            val pngFile = File(pngPath)
            if (pngFile.exists()) {
                try {
                    val bitmap = BitmapFactory.decodeFile(pngFile.absolutePath)
                    if (bitmap != null) {
                        Log.d(logTag, "Loaded chart from PNG: $pngPath")
                        return bitmap
                    }
                } catch (e: Exception) {
                    Log.e(logTag, "Error loading PNG: ${e.message}")
                }
            }
        }

        return null
    }

    /**
     * Push [buildViews]'s RemoteViews to the launcher, shrinking the chart
     * bitmaps and retrying if the launcher rejects the update for exceeding its
     * per-widget bitmap-memory budget (`updateAppWidget` throws
     * IllegalArgumentException).
     *
     * [WidgetUtils.clampChartDimensions] should keep us under the budget, but the
     * launcher's budget basis can differ from our displayMetrics (split-screen,
     * multi-window, third-party launchers). Without recovery a single rejection
     * freezes the widget permanently — every later update recomputes the same
     * over-budget size and is rejected again, fixable only by re-creating the
     * widget. The chart is vector, so a lower-res raster stretched FIT_XY looks
     * identical; halving both dimensions quarters the bitmap memory and almost
     * always fits on the first retry.
     *
     * @param buildViews builds the complete RemoteViews for the given pixel size,
     *   or null if there's nothing to show at that size (caller handles it).
     */
    private fun updateWidgetWithRetry(
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widthPx: Int,
        heightPx: Int,
        buildViews: (width: Int, height: Int) -> RemoteViews?
    ) {
        var w = widthPx
        var h = heightPx
        for (attempt in 0 until MAX_UPDATE_ATTEMPTS) {
            val views = buildViews(w, h) ?: return
            try {
                appWidgetManager.updateAppWidget(appWidgetId, views)
                if (attempt == 0) {
                    Log.d(logTag, "Updated widget $appWidgetId")
                } else {
                    Log.w(logTag, "Updated widget $appWidgetId at reduced ${w}x$h after $attempt retr${if (attempt == 1) "y" else "ies"}")
                }
                return
            } catch (e: Exception) {
                Log.e(logTag, "Widget $appWidgetId update rejected at ${w}x$h (attempt ${attempt + 1}/$MAX_UPDATE_ATTEMPTS)", e)
                w /= 2
                h /= 2
                if (w < MIN_CHART_DIMENSION_PX || h < MIN_CHART_DIMENSION_PX) break
            }
        }
        Log.e(logTag, "Gave up updating widget $appWidgetId — could not fit launcher bitmap budget")
    }

    /**
     * Build the complete RemoteViews for one widget at the given pixel size:
     * click intent, native light/dark charts (falling back to saved SVG files,
     * then a "tap to load" placeholder), refresh indicator, and theme override.
     * Deterministic for the given inputs and safe to re-invoke at a smaller size,
     * so [updateWidgetWithRetry] can rebuild it when the launcher rejects an
     * over-budget update.
     *
     * @param nativeOnly when true (the resize path), skip the saved-SVG-file
     *   fallback and the placeholder and return null if no native chart could be
     *   generated, so the caller can trigger a weather fetch instead.
     */
    private fun buildWidgetViews(
        context: Context,
        appWidgetId: Int,
        prefs: SharedPreferences,
        weatherData: WeatherData?,
        widthPx: Int,
        heightPx: Int,
        nativeOnly: Boolean = false
    ): RemoteViews? {
        val views = RemoteViews(context.packageName, layoutRes)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            setPackage(context.packageName)
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        var hasChart = false

        if (weatherData != null && widthPx > 0 && heightPx > 0) {
            val lightColors = WidgetChartColors.get(context, isLight = true)
            val lightBitmap = generateChartBitmap(context, weatherData, lightColors, widthPx, heightPx)
            if (lightBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                hasChart = true
                Log.d(logTag, "Widget $appWidgetId native light chart generated")
            }

            val darkColors = WidgetChartColors.get(context, isLight = false)
            val darkBitmap = generateChartBitmap(context, weatherData, darkColors, widthPx, heightPx)
            if (darkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                hasChart = true
                Log.d(logTag, "Widget $appWidgetId native dark chart generated")
            }
        }

        // Resize wants a freshly generated chart only: skip the stale-file
        // fallback/placeholder and signal the caller to fetch instead.
        if (nativeOnly) {
            if (!hasChart) return null
        } else if (!hasChart) {
            val svgLightPath = prefs.getString("svg_path_light_$appWidgetId", null)
                ?: prefs.getString("svg_path_light", null)
            val svgDarkPath = prefs.getString("svg_path_dark_$appWidgetId", null)
                ?: prefs.getString("svg_path_dark", null)
            Log.d(logTag, "Widget $appWidgetId falling back to SVG files - light: $svgLightPath, dark: $svgDarkPath")

            val lightBitmap = loadChartBitmap(svgLightPath, null, widthPx, heightPx)
            if (lightBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                hasChart = true
                Log.d(logTag, "Widget $appWidgetId light chart loaded from file")
            }

            val darkBitmap = loadChartBitmap(svgDarkPath, null, widthPx, heightPx)
            if (darkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                hasChart = true
                Log.d(logTag, "Widget $appWidgetId dark chart loaded from file")
            }
        }

        if (!hasChart) {
            views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
            Log.d(logTag, "Widget $appWidgetId showing placeholder - no weather data")
        } else {
            views.setViewVisibility(R.id.widget_placeholder, View.GONE)
        }

        views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)
        if (hasChart) {
            applyThemeOverride(context, views)
        }

        return views
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        Log.d(logTag, "Widget $appWidgetId resized")

        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val maxHeight = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val density = context.resources.displayMetrics.density
        val (widthPx, heightPx) = WidgetUtils.clampChartDimensions(
            context,
            (minWidth * density).toInt(),
            (maxHeight * density).toInt()
        )

        Log.d(logTag, "Widget $appWidgetId new dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

        saveWidgetDimensions(prefs, appWidgetId, widthPx, heightPx, density)

        prefs.edit()
            .putBoolean("widget_resized", true)
            .commit()

        val weatherData = WeatherDataParser.parseFromPrefs(context)
        if (weatherData != null && widthPx > 0 && heightPx > 0) {
            Log.d(logTag, "Generating native chart for resize")

            var rendered = false
            // Clamping should keep us under the launcher's bitmap budget; if a
            // host rejects the update anyway, updateWidgetWithRetry shrinks and
            // retries rather than letting the throw freeze the widget forever.
            // nativeOnly: on resize we want only a freshly generated chart (no
            // stale-file/placeholder fallback), so a null result falls through to
            // the weather fetch below.
            updateWidgetWithRetry(appWidgetManager, appWidgetId, widthPx, heightPx) { w, h ->
                buildWidgetViews(context, appWidgetId, prefs, weatherData, w, h, nativeOnly = true)
                    ?.also { rendered = true }
            }
            if (rendered) return
        }

        Log.d(logTag, "Native generation failed or no weather data, triggering weather fetch")
        WidgetUtils.fetchWeather(context, goAsync())
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        Log.d(logTag, "Widgets deleted: ${appWidgetIds.joinToString()}")
        cleanupDeletedWidgets(context, appWidgetIds)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Open the shared store directly (previously supplied by HomeWidgetProvider).
        val widgetData = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        Log.d(logTag, "onUpdate called for ${appWidgetIds.size} widgets: ${appWidgetIds.joinToString()}")

        updateWidgetIdsList(context, appWidgetIds)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MaterialYouColorExtractor.updateColorsIfChanged(context)
        }

        val weatherData = WeatherDataParser.parseFromPrefs(context)

        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            val density = context.resources.displayMetrics.density

            val clamped = WidgetUtils.clampChartDimensions(
                context,
                (minWidth * density).toInt(),
                (maxHeight * density).toInt()
            )
            var widthPx = clamped.first
            var heightPx = clamped.second

            Log.d(logTag, "Widget $appWidgetId dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

            if (widthPx > 0 && heightPx > 0) {
                saveWidgetDimensions(widgetData, appWidgetId, widthPx, heightPx, density)
            } else {
                val savedDims = getWidgetDimensions(widgetData, appWidgetId)
                if (savedDims != null) {
                    // Saved dims can predate clampChartDimensions (e.g. upgraded
                    // from a build that stored the raw launcher size), so clamp
                    // them too — a stale over-budget value here would otherwise
                    // OOM Bitmap.createBitmap and crash the in-process receiver.
                    val clampedSaved = WidgetUtils.clampChartDimensions(context, savedDims.first, savedDims.second)
                    widthPx = clampedSaved.first
                    heightPx = clampedSaved.second
                    Log.d(logTag, "Widget $appWidgetId using saved dimensions: ${widthPx}x${heightPx}px")
                } else {
                    widthPx = WidgetUtils.DEFAULT_WIDTH_PX
                    heightPx = WidgetUtils.DEFAULT_HEIGHT_PX
                    Log.d(logTag, "Widget $appWidgetId using default dimensions: ${widthPx}x${heightPx}px")
                }
            }

            // Clamping should keep the two chart bitmaps under the launcher's
            // budget; if a host rejects the update anyway, updateWidgetWithRetry
            // shrinks and retries so the widget never freezes permanently.
            updateWidgetWithRetry(appWidgetManager, appWidgetId, widthPx, heightPx) { w, h ->
                buildWidgetViews(context, appWidgetId, widgetData, weatherData, w, h)
            }
        }

        WidgetUtils.updateLastRenderTime(context)
    }
}
