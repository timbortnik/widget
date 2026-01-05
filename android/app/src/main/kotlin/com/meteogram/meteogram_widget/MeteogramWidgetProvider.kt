package com.meteogram.meteogram_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class MeteogramWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "MeteogramWidget"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        // Handle configuration changes (including theme changes)
        if (intent.action == Intent.ACTION_CONFIGURATION_CHANGED) {
            Log.d(TAG, "Configuration changed - checking theme mismatch")
            checkThemeMismatchAndShowIndicator(context)
        }
    }

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

        // Update SharedPreferences with new dimensions
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putInt("widget_width_px", widthPx)
            .putInt("widget_height_px", heightPx)
            .putFloat("widget_density", density)
            .putBoolean("widget_resized", true)
            .apply()

        // Show refresh indicator on widget
        val views = RemoteViews(context.packageName, R.layout.meteogram_widget)
        views.setViewVisibility(R.id.widget_refresh_indicator, View.VISIBLE)

        // Update all widgets with the indicator
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = android.content.ComponentName(context, MeteogramWidgetProvider::class.java)
        val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
        for (id in widgetIds) {
            appWidgetManager.partiallyUpdateAppWidget(id, views)
        }

        Log.d(TAG, "Resize indicator shown - tap widget to update chart")
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.meteogram_widget)

            // Get widget dimensions and save to SharedPreferences for Flutter
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            val density = context.resources.displayMetrics.density

            // Convert dp to pixels
            val widthPx = (minWidth * density).toInt()
            val heightPx = (maxHeight * density).toInt()

            Log.d(TAG, "Widget dimensions: ${minWidth}dp x ${maxHeight}dp = ${widthPx}px x ${heightPx}px (density: $density)")

            // Save dimensions to SharedPreferences for Flutter to read
            widgetData.edit()
                .putInt("widget_width_px", widthPx)
                .putInt("widget_height_px", heightPx)
                .putFloat("widget_density", density)
                .apply()

            // Set up tap to open app
            val intent = android.content.Intent(context, MainActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Get chart image
            val imagePath = widgetData.getString("meteogram_image", null)
            Log.d(TAG, "Image path from data: $imagePath")

            if (imagePath != null) {
                val imageFile = File(imagePath)
                if (imageFile.exists()) {
                    try {
                        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_chart, bitmap)
                            views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
                            views.setViewVisibility(R.id.widget_placeholder, View.GONE)
                            Log.d(TAG, "Chart image loaded successfully")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error loading chart image: ${e.message}")
                    }
                } else {
                    Log.d(TAG, "Image file does not exist: $imagePath")
                }
            }

            // Show placeholder if no chart
            if (imagePath == null) {
                views.setViewVisibility(R.id.widget_chart, View.GONE)
                views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
            }

            // Check if current theme matches rendered theme
            val currentNightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            val isCurrentlyDark = currentNightMode == Configuration.UI_MODE_NIGHT_YES
            val renderedDark = widgetData.getBoolean("rendered_dark_mode", false)
            val themeMismatch = imagePath != null && isCurrentlyDark != renderedDark
            Log.d(TAG, "Theme check: current=$isCurrentlyDark, rendered=$renderedDark, mismatch=$themeMismatch")

            if (themeMismatch) {
                // Theme changed since last render - show refresh indicator
                views.setViewVisibility(R.id.widget_refresh_indicator, View.VISIBLE)
                Log.d(TAG, "Theme mismatch: current=$isCurrentlyDark, rendered=$renderedDark - showing refresh indicator")
            } else {
                // Theme matches - hide refresh indicator
                views.setViewVisibility(R.id.widget_refresh_indicator, View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Updated widget $appWidgetId")
        }
    }
}
