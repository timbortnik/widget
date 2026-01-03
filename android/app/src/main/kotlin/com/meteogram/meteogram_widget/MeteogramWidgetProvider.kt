package com.meteogram.meteogram_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

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

            // Get temperature text
            val temperature = widgetData.getString("current_temperature", null)
            Log.d(TAG, "Temperature from data: $temperature")

            if (temperature != null) {
                views.setTextViewText(R.id.widget_temperature, temperature)
                views.setTextViewText(R.id.widget_placeholder, "Tap to refresh")
            } else {
                views.setTextViewText(R.id.widget_temperature, "--°")
                views.setTextViewText(R.id.widget_placeholder, "Open app to load weather")
            }

            // Get location text
            val location = widgetData.getString("location_name", null)
            Log.d(TAG, "Location from data: $location")
            views.setTextViewText(R.id.widget_location, location ?: "")

            // Log all keys in SharedPreferences for debugging
            val allEntries = widgetData.all
            Log.d(TAG, "All widget data keys: ${allEntries.keys}")

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Updated widget $appWidgetId")
        }
    }
}
