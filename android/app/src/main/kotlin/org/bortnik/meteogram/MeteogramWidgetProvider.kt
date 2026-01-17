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

class MeteogramWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "MeteogramWidget"
        private const val KEY_WIDGET_IDS = "widget_ids"
    }

    /**
     * Save widget dimensions for a specific widget ID.
     */
    private fun saveWidgetDimensions(prefs: SharedPreferences, widgetId: Int, widthPx: Int, heightPx: Int, density: Float) {
        prefs.edit()
            .putInt("widget_${widgetId}_width_px", widthPx)
            .putInt("widget_${widgetId}_height_px", heightPx)
            .putFloat("widget_${widgetId}_density", density)
            .commit()
    }

    /**
     * Get widget dimensions for a specific widget ID.
     * Returns null if not found.
     */
    private fun getWidgetDimensions(prefs: SharedPreferences, widgetId: Int): Pair<Int, Int>? {
        val width = prefs.getInt("widget_${widgetId}_width_px", 0)
        val height = prefs.getInt("widget_${widgetId}_height_px", 0)
        return if (width > 0 && height > 0) Pair(width, height) else null
    }

    /**
     * Get chart colors for a theme, applying Material You colors if available.
     */
    private fun getChartColors(context: Context, isLight: Boolean): SvgChartColors {
        val baseColors = if (isLight) SvgChartColors.light else SvgChartColors.dark

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return baseColors
        }

        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

        // Get Material You colors from SharedPreferences (saved by MaterialYouColorExtractor)
        val tempColorKey = if (isLight) "material_you_light_on_primary_container" else "material_you_dark_primary"
        val timeColorKey = if (isLight) "material_you_light_tertiary" else "material_you_dark_tertiary"

        val tempColor = prefs.getInt(tempColorKey, 0)
        val timeColor = prefs.getInt(timeColorKey, 0)

        if (tempColor == 0 || timeColor == 0) {
            Log.d(TAG, "Material You colors not available, using defaults")
            return baseColors
        }

        Log.d(TAG, "Applying Material You colors: temp=${Integer.toHexString(tempColor)}, time=${Integer.toHexString(timeColor)}")
        return baseColors.withDynamicColors(
            temperatureLine = SvgColor.fromArgb(tempColor),
            timeLabel = SvgColor.fromArgb(timeColor)
        )
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
            Log.e(TAG, "Invalid dimensions for native SVG generation: ${width}x${height}")
            return null
        }

        return try {
            val displayData = weatherData.getDisplayRange()
            val nowIndex = weatherData.getNowIndex()

            val generator = SvgChartGenerator()
            val svgString = generator.generate(
                data = displayData,
                nowIndex = nowIndex,
                latitude = weatherData.latitude,
                longitude = weatherData.longitude,
                colors = colors,
                width = width.toDouble(),
                height = height.toDouble(),
                locale = Locale.getDefault(),
                usesFahrenheit = usesFahrenheit(),
                use24HourFormat = DateFormat.is24HourFormat(context)
            )

            // Render SVG string to bitmap
            renderSvgStringToBitmap(svgString, width, height)
        } catch (e: Exception) {
            Log.e(TAG, "Error generating native chart", e)
            null
        }
    }

    /**
     * Render an SVG string to a Bitmap.
     */
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
            Log.e(TAG, "Error rendering SVG string to bitmap", e)
            null
        }
    }

    /**
     * Update the list of active widget IDs.
     */
    private fun updateWidgetIdsList(context: Context, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val idsString = widgetIds.joinToString(",")
        prefs.edit().putString(KEY_WIDGET_IDS, idsString).commit()
        Log.d(TAG, "Updated widget IDs list: $idsString")
    }

    /**
     * Remove dimensions for deleted widgets.
     */
    private fun cleanupDeletedWidgets(context: Context, deletedIds: IntArray) {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (widgetId in deletedIds) {
            editor.remove("widget_${widgetId}_width_px")
            editor.remove("widget_${widgetId}_height_px")
            editor.remove("widget_${widgetId}_density")
            editor.remove("svg_path_light_$widgetId")
            editor.remove("svg_path_dark_$widgetId")
            Log.d(TAG, "Cleaned up data for deleted widget $widgetId")
        }
        editor.commit()
    }

    /**
     * Render an SVG file to a Bitmap.
     * @param svgPath Path to the SVG file
     * @param width Target width in pixels
     * @param height Target height in pixels
     * @return Bitmap or null if rendering fails
     */
    private fun renderSvgToBitmap(svgPath: String, width: Int, height: Int): Bitmap? {
        if (width <= 0 || height <= 0) {
            Log.e(TAG, "Invalid dimensions for SVG rendering: ${width}x${height}")
            return null
        }

        return try {
            FileInputStream(svgPath).use { inputStream ->
                val svg = SVG.getFromInputStream(inputStream)

                // Set document dimensions to scale SVG
                svg.documentWidth = width.toFloat()
                svg.documentHeight = height.toFloat()

                // Create bitmap and canvas
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)

                // Render SVG to canvas
                svg.renderToCanvas(canvas)

                bitmap
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error rendering SVG", e)
            null
        }
    }

    /**
     * Load chart bitmap, preferring SVG over PNG.
     * @param svgPath Optional path to SVG file
     * @param pngPath Optional path to PNG file
     * @param width Target width in pixels
     * @param height Target height in pixels
     * @return Bitmap or null if no chart available
     */
    private fun loadChartBitmap(svgPath: String?, pngPath: String?, width: Int, height: Int): Bitmap? {
        // Try SVG first
        if (svgPath != null) {
            val svgFile = File(svgPath)
            if (svgFile.exists()) {
                val bitmap = renderSvgToBitmap(svgPath, width, height)
                if (bitmap != null) {
                    Log.d(TAG, "Loaded chart from SVG: $svgPath")
                    return bitmap
                }
            }
        }

        // Fall back to PNG
        if (pngPath != null) {
            val pngFile = File(pngPath)
            if (pngFile.exists()) {
                try {
                    val bitmap = BitmapFactory.decodeFile(pngFile.absolutePath)
                    if (bitmap != null) {
                        Log.d(TAG, "Loaded chart from PNG: $pngPath")
                        return bitmap
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error loading PNG: ${e.message}")
                }
            }
        }

        return null
    }

    // Note: LOCALE_CHANGED and TIMEZONE_CHANGED are handled by WidgetEventReceiver
    // (manifest-registered). Network changes are handled by WorkManager with
    // NetworkType.CONNECTED constraint.

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        Log.d(TAG, "Widget $appWidgetId resized")

        // Save new dimensions for this specific widget
        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val maxHeight = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val density = context.resources.displayMetrics.density
        val widthPx = (minWidth * density).toInt()
        val heightPx = (maxHeight * density).toInt()

        Log.d(TAG, "Widget $appWidgetId new dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

        // Save per-widget dimensions
        saveWidgetDimensions(prefs, appWidgetId, widthPx, heightPx, density)

        // Set flag for app to detect resize on resume
        prefs.edit()
            .putBoolean("widget_resized", true)
            .commit()

        // Try to generate chart natively for immediate update
        val weatherData = WeatherDataParser.parseFromPrefs(context)
        if (weatherData != null && widthPx > 0 && heightPx > 0) {
            Log.d(TAG, "Generating native chart for resize")

            val views = RemoteViews(context.packageName, R.layout.meteogram_widget)

            // Generate light theme chart
            val lightColors = getChartColors(context, isLight = true)
            val lightBitmap = generateChartBitmap(context, weatherData, lightColors, widthPx, heightPx)
            if (lightBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                Log.d(TAG, "Native light chart generated")
            }

            // Generate dark theme chart
            val darkColors = getChartColors(context, isLight = false)
            val darkBitmap = generateChartBitmap(context, weatherData, darkColors, widthPx, heightPx)
            if (darkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                Log.d(TAG, "Native dark chart generated")
            }

            if (lightBitmap != null || darkBitmap != null) {
                views.setViewVisibility(R.id.widget_placeholder, View.GONE)
                views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)

                // Set up tap to open app (explicit intent with package for security)
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
                Log.d(TAG, "Widget $appWidgetId updated with native charts")
                return
            }
        }

        // Fallback: trigger weather fetch which will cache data and update widget
        Log.d(TAG, "Native generation failed or no weather data, triggering weather fetch")
        WidgetUtils.fetchWeather(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        Log.d(TAG, "Widgets deleted: ${appWidgetIds.joinToString()}")
        cleanupDeletedWidgets(context, appWidgetIds)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets: ${appWidgetIds.joinToString()}")

        // Update list of active widget IDs
        updateWidgetIdsList(context, appWidgetIds)

        // Check for Material You color changes (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MaterialYouColorExtractor.updateColorsIfChanged(context)
        }

        // Try to load weather data for native generation
        val weatherData = WeatherDataParser.parseFromPrefs(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.meteogram_widget)

            // Get widget dimensions
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            val density = context.resources.displayMetrics.density

            // Convert dp to pixels
            var widthPx = (minWidth * density).toInt()
            var heightPx = (maxHeight * density).toInt()

            Log.d(TAG, "Widget $appWidgetId dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

            // Save per-widget dimensions (only if valid)
            if (widthPx > 0 && heightPx > 0) {
                saveWidgetDimensions(widgetData, appWidgetId, widthPx, heightPx, density)
            } else {
                // Try to use saved per-widget dimensions first
                val savedDims = getWidgetDimensions(widgetData, appWidgetId)
                if (savedDims != null) {
                    widthPx = savedDims.first
                    heightPx = savedDims.second
                    Log.d(TAG, "Widget $appWidgetId using saved dimensions: ${widthPx}x${heightPx}px")
                } else {
                    // Fall back to defaults
                    widthPx = WidgetUtils.DEFAULT_WIDTH_PX
                    heightPx = WidgetUtils.DEFAULT_HEIGHT_PX
                    Log.d(TAG, "Widget $appWidgetId using default dimensions: ${widthPx}x${heightPx}px")
                }
            }

            // Set up tap to open app (explicit intent with package for security)
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

            // Try native generation first (works without file dependencies)
            if (weatherData != null && widthPx > 0 && heightPx > 0) {
                // Generate light theme chart
                val lightColors = getChartColors(context, isLight = true)
                val lightBitmap = generateChartBitmap(context, weatherData, lightColors, widthPx, heightPx)
                if (lightBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                    hasChart = true
                    Log.d(TAG, "Widget $appWidgetId native light chart generated")
                }

                // Generate dark theme chart
                val darkColors = getChartColors(context, isLight = false)
                val darkBitmap = generateChartBitmap(context, weatherData, darkColors, widthPx, heightPx)
                if (darkBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                    hasChart = true
                    Log.d(TAG, "Widget $appWidgetId native dark chart generated")
                }
            }

            // Fallback: try loading from SVG files (backward compat with Dart-generated charts)
            if (!hasChart) {
                val svgLightPath = widgetData.getString("svg_path_light_$appWidgetId", null)
                    ?: widgetData.getString("svg_path_light", null)
                val svgDarkPath = widgetData.getString("svg_path_dark_$appWidgetId", null)
                    ?: widgetData.getString("svg_path_dark", null)
                Log.d(TAG, "Widget $appWidgetId falling back to SVG files - light: $svgLightPath, dark: $svgDarkPath")

                // Load light theme chart from file
                val lightBitmap = loadChartBitmap(svgLightPath, null, widthPx, heightPx)
                if (lightBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                    hasChart = true
                    Log.d(TAG, "Widget $appWidgetId light chart loaded from file")
                }

                // Load dark theme chart from file
                val darkBitmap = loadChartBitmap(svgDarkPath, null, widthPx, heightPx)
                if (darkBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                    hasChart = true
                    Log.d(TAG, "Widget $appWidgetId dark chart loaded from file")
                }
            }

            // Show placeholder if no charts available
            if (!hasChart) {
                views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
                Log.d(TAG, "Widget $appWidgetId showing placeholder - no weather data")
            } else {
                views.setViewVisibility(R.id.widget_placeholder, View.GONE)
            }

            views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Updated widget $appWidgetId")
        }

        // Update last render time
        WidgetUtils.updateLastRenderTime(context)
    }
}
