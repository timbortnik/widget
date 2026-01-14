package org.bortnik.meteogram

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
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

    private fun checkThemeMismatchAndShowIndicator(context: Context) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val imagePath = prefs.getString("meteogram_image", null)
        if (imagePath == null) return

        val currentNightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        val isCurrentlyDark = currentNightMode == Configuration.UI_MODE_NIGHT_YES
        val renderedDark = prefs.getBoolean("rendered_dark_mode", false)

        if (isCurrentlyDark != renderedDark) {
            Log.d(TAG, "Theme mismatch detected: current=$isCurrentlyDark, rendered=$renderedDark")
            val views = RemoteViews(context.packageName, R.layout.meteogram_widget)
            views.setViewVisibility(R.id.widget_refresh_indicator, View.VISIBLE)

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, MeteogramWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in widgetIds) {
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }
            Log.d(TAG, "Theme mismatch indicator shown")
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        Log.d(TAG, "Widget resized")

        // Save new dimensions
        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val maxHeight = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val density = context.resources.displayMetrics.density
        val widthPx = (minWidth * density).toInt()
        val heightPx = (maxHeight * density).toInt()

        Log.d(TAG, "New dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px")

        // Update SharedPreferences with new dimensions (commit synchronously before triggering callback)
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(WidgetUtils.KEY_WIDGET_WIDTH_PX, widthPx)
            .putInt(WidgetUtils.KEY_WIDGET_HEIGHT_PX, heightPx)
            .putFloat("widget_density", density)
            .commit()

        // Trigger chart re-render with new dimensions
        WidgetUtils.rerenderChart(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")

        // Check for Material You color changes (Android 12+)
        // This detects wallpaper/theme color changes and triggers SVG re-generation
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (MaterialYouColorExtractor.updateColorsIfChanged(context)) {
                Log.d(TAG, "Material You colors changed - triggering re-render")
                WidgetUtils.rerenderChart(context)
                // Continue with current render using old SVGs
                // New SVGs will trigger another onUpdate when ready
            }
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.meteogram_widget)

            // Get widget dimensions and save to SharedPreferences for Flutter
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            val density = context.resources.displayMetrics.density

            // Convert dp to pixels
            var widthPx = (minWidth * density).toInt()
            var heightPx = (maxHeight * density).toInt()

            Log.d(TAG, "Widget dimensions from options: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px (density: $density)")

            // Save dimensions to SharedPreferences for Flutter to read (only if valid)
            // getAppWidgetOptions can return 0 in some scenarios - don't overwrite valid dimensions
            // Use commit() (synchronous) to ensure dimensions are saved before any callbacks
            if (widthPx > 0 && heightPx > 0) {
                widgetData.edit()
                    .putInt(WidgetUtils.KEY_WIDGET_WIDTH_PX, widthPx)
                    .putInt(WidgetUtils.KEY_WIDGET_HEIGHT_PX, heightPx)
                    .putFloat("widget_density", density)
                    .commit()
            } else {
                // getAppWidgetOptions returned invalid dimensions - use saved or default
                Log.d(TAG, "Invalid dimensions from options - using saved/default")
                val (savedWidth, savedHeight) = WidgetUtils.getWidgetDimensions(context)
                widthPx = savedWidth
                heightPx = savedHeight
                Log.d(TAG, "Using fallback dimensions: ${widthPx}x${heightPx}px")
            }

            // Set up tap to open app
            val intent = android.content.Intent(context, MainActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                // Explicitly set component for security (prevents intent interception)
                component = android.content.ComponentName(context, MainActivity::class.java)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Get chart sources - prefer SVG, fall back to PNG
            val svgLightPath = widgetData.getString("svg_path_light", null)
            val svgDarkPath = widgetData.getString("svg_path_dark", null)
            val pngLightPath = widgetData.getString("meteogram_image_light", null)
            val pngDarkPath = widgetData.getString("meteogram_image_dark", null)
            Log.d(TAG, "SVG paths - light: $svgLightPath, dark: $svgDarkPath")
            Log.d(TAG, "PNG paths - light: $pngLightPath, dark: $pngDarkPath")

            var hasChart = false

            // Load light theme chart (prefer SVG)
            val lightBitmap = loadChartBitmap(svgLightPath, pngLightPath, widthPx, heightPx)
            if (lightBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_light, lightBitmap)
                // Don't recycle - RemoteViews needs bitmap during IPC serialization
                // Let GC handle cleanup after RemoteViews is done with it
                hasChart = true
                Log.d(TAG, "Light chart loaded")
            }

            // Load dark theme chart (prefer SVG)
            val darkBitmap = loadChartBitmap(svgDarkPath, pngDarkPath, widthPx, heightPx)
            if (darkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_chart_dark, darkBitmap)
                // Don't recycle - let GC handle cleanup
                hasChart = true
                Log.d(TAG, "Dark chart loaded")
            }

            // Show placeholder if no charts available
            if (!hasChart) {
                views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_placeholder, View.GONE)
            }

            // Hide refresh indicator - with dual charts, theme switching is automatic
            views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Updated widget $appWidgetId")
        }
    }
}
