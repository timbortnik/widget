package org.bortnik.meteogram

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver for alarm-triggered widget updates.
 *
 * Handles periodic updates triggered by AlarmManager:
 * - Fetches weather if data is stale (>15 min old)
 * - Re-renders widget if 30-min boundary crossed (now indicator moved)
 *
 * This receiver is manifest-registered so it can receive broadcasts
 * even when the app process is not running.
 */
class WidgetAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "WidgetAlarmReceiver"
        const val ACTION_ALARM_UPDATE = "org.bortnik.meteogram.ACTION_ALARM_UPDATE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ALARM_UPDATE) {
            Log.w(TAG, "Unexpected action: ${intent.action}")
            return
        }

        Log.d(TAG, "Alarm triggered - checking for updates")

        // Check if weather data is stale and fetch if needed
        if (WidgetUtils.isWeatherDataStale(context)) {
            Log.d(TAG, "Weather data stale - fetching fresh data")
            // fetchWeather triggers re-render on success
            WidgetUtils.fetchWeather(context)
        } else {
            // Data is fresh - just re-render if needed (30-min boundary crossed)
            Log.d(TAG, "Weather data fresh - checking if re-render needed")
            WidgetUtils.rerenderAllWidgetsIfNeeded(context)
        }
    }
}
