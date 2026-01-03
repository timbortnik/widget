package com.meteogram.meteogram_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class MeteogramWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "MeteogramWidget"
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

            // Set up tap to open app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Get temperature text
            val temperature = widgetData.getString("current_temperature", null)
            Log.d(TAG, "Temperature from data: $temperature")

            if (temperature != null) {
                views.setTextViewText(R.id.widget_temperature, temperature)
            } else {
                views.setTextViewText(R.id.widget_temperature, "--°")
            }

            // Get location text
            val location = widgetData.getString("location_name", null)
            Log.d(TAG, "Location from data: $location")
            views.setTextViewText(R.id.widget_location, location ?: "")

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
                views.setTextViewText(
                    R.id.widget_placeholder,
                    if (temperature != null) "Tap to refresh" else "Tap to load weather"
                )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Updated widget $appWidgetId")
        }
    }
}
