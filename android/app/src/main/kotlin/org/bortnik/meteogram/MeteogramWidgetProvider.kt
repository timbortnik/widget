package org.bortnik.meteogram

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.os.Build
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.os.Bundle
import android.text.format.DateFormat
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.caverock.androidsvg.SVG
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileInputStream
import java.util.Locale

/**
 * Default (48-hour) meteogram widget provider. Also serves as the base class
 * for variants (e.g. the 14-day weekly widget) — subclasses override the
 * extension points to change layout, time range, or time labels without
 * re-implementing the full RemoteViews update cycle.
 */
open class MeteogramWidgetProvider : HomeWidgetProvider() {
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
        }
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
        val widthPx = (minWidth * density).toInt()
        val heightPx = (maxHeight * density).toInt()

        Log.d(logTag, "Widget $appWidgetId new dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

        saveWidgetDimensions(prefs, appWidgetId, widthPx, heightPx, density)

        prefs.edit()
            .putBoolean("widget_resized", true)
            .commit()

        val weatherData = WeatherDataParser.parseFromPrefs(context)
        if (weatherData != null && widthPx > 0 && heightPx > 0) {
            Log.d(logTag, "Generating native chart for resize")

            val views = RemoteViews(context.packageName, layoutRes)

            val lightColors = WidgetChartColors.get(context, isLight = true)
            val lightBitmap = generateChartBitmap(context, weatherData, lightColors, widthPx, heightPx)
            if (lightBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                Log.d(logTag, "Native light chart generated")
            }

            val darkColors = WidgetChartColors.get(context, isLight = false)
            val darkBitmap = generateChartBitmap(context, weatherData, darkColors, widthPx, heightPx)
            if (darkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                Log.d(logTag, "Native dark chart generated")
            }

            if (lightBitmap != null || darkBitmap != null) {
                views.setViewVisibility(R.id.widget_placeholder, View.GONE)
                views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)

                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    setPackage(context.packageName)
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(logTag, "Widget $appWidgetId updated with native charts")
                return
            }
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
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(logTag, "onUpdate called for ${appWidgetIds.size} widgets: ${appWidgetIds.joinToString()}")

        updateWidgetIdsList(context, appWidgetIds)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MaterialYouColorExtractor.updateColorsIfChanged(context)
        }

        val weatherData = WeatherDataParser.parseFromPrefs(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutRes)

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            val density = context.resources.displayMetrics.density

            var widthPx = (minWidth * density).toInt()
            var heightPx = (maxHeight * density).toInt()

            Log.d(logTag, "Widget $appWidgetId dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

            if (widthPx > 0 && heightPx > 0) {
                saveWidgetDimensions(widgetData, appWidgetId, widthPx, heightPx, density)
            } else {
                val savedDims = getWidgetDimensions(widgetData, appWidgetId)
                if (savedDims != null) {
                    widthPx = savedDims.first
                    heightPx = savedDims.second
                    Log.d(logTag, "Widget $appWidgetId using saved dimensions: ${widthPx}x${heightPx}px")
                } else {
                    widthPx = WidgetUtils.DEFAULT_WIDTH_PX
                    heightPx = WidgetUtils.DEFAULT_HEIGHT_PX
                    Log.d(logTag, "Widget $appWidgetId using default dimensions: ${widthPx}x${heightPx}px")
                }
            }

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

            if (!hasChart) {
                val svgLightPath = widgetData.getString("svg_path_light_$appWidgetId", null)
                    ?: widgetData.getString("svg_path_light", null)
                val svgDarkPath = widgetData.getString("svg_path_dark_$appWidgetId", null)
                    ?: widgetData.getString("svg_path_dark", null)
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

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(logTag, "Updated widget $appWidgetId")
        }

        WidgetUtils.updateLastRenderTime(context)
    }
}
