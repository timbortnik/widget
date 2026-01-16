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
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.caverock.androidsvg.SVG
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import java.io.FileInputStream

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

    // Note: System events (USER_PRESENT, LOCALE_CHANGED, etc.) are handled
    // by WidgetEventReceiver which is registered at runtime in MeteogramApplication.
    // Implicit broadcasts cannot be received via manifest-declared receivers on Android 8.0+.

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

        // Also save as "current" dimensions for backward compatibility and app preview
        prefs.edit()
            .putInt(WidgetUtils.KEY_WIDGET_WIDTH_PX, widthPx)
            .putInt(WidgetUtils.KEY_WIDGET_HEIGHT_PX, heightPx)
            .putFloat("widget_density", density)
            .putBoolean("widget_resized", true)
            .commit()

        // Trigger chart re-render for this widget
        WidgetUtils.rerenderChartForWidget(context, appWidgetId, widthPx, heightPx)
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
        // This detects wallpaper/theme color changes and triggers SVG re-generation
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (MaterialYouColorExtractor.updateColorsIfChanged(context)) {
                Log.d(TAG, "Material You colors changed - triggering re-render for all widgets")
                WidgetUtils.rerenderAllWidgets(context)
                // Skip rendering with old SVGs - wait for background service to generate new ones
                // The re-render will trigger another onUpdate with correct colors
                return
            }
        }

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
                // Also save as "current" for backward compatibility
                widgetData.edit()
                    .putInt(WidgetUtils.KEY_WIDGET_WIDTH_PX, widthPx)
                    .putInt(WidgetUtils.KEY_WIDGET_HEIGHT_PX, heightPx)
                    .putFloat("widget_density", density)
                    .commit()
            } else {
                // Try to use saved per-widget dimensions first
                val savedDims = getWidgetDimensions(widgetData, appWidgetId)
                if (savedDims != null) {
                    widthPx = savedDims.first
                    heightPx = savedDims.second
                    Log.d(TAG, "Widget $appWidgetId using saved dimensions: ${widthPx}x${heightPx}px")
                } else {
                    // Fall back to global default
                    val (defaultWidth, defaultHeight) = WidgetUtils.getWidgetDimensions(context)
                    widthPx = defaultWidth
                    heightPx = defaultHeight
                    Log.d(TAG, "Widget $appWidgetId using default dimensions: ${widthPx}x${heightPx}px")
                }
            }

            // Set up tap to open app
            val intent = android.content.Intent(context, MainActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                component = android.content.ComponentName(context, MainActivity::class.java)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Get chart sources - prefer widget-specific SVG, fall back to generic
            val svgLightPath = widgetData.getString("svg_path_light_$appWidgetId", null)
                ?: widgetData.getString("svg_path_light", null)
            val svgDarkPath = widgetData.getString("svg_path_dark_$appWidgetId", null)
                ?: widgetData.getString("svg_path_dark", null)
            Log.d(TAG, "Widget $appWidgetId SVG paths - light: $svgLightPath, dark: $svgDarkPath")

            var hasChart = false

            // Load light theme chart
            val lightBitmap = loadChartBitmap(svgLightPath, null, widthPx, heightPx)
            if (lightBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                hasChart = true
                Log.d(TAG, "Widget $appWidgetId light chart loaded")
            }

            // Load dark theme chart
            val darkBitmap = loadChartBitmap(svgDarkPath, null, widthPx, heightPx)
            if (darkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                hasChart = true
                Log.d(TAG, "Widget $appWidgetId dark chart loaded")
            }

            // Show placeholder if no charts available
            if (!hasChart) {
                views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_placeholder, View.GONE)
            }

            views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Updated widget $appWidgetId")
        }
    }
}
