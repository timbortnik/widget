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

        // Try to fetch fresh data if stale (runs async, triggers re-render on success)
        if (WidgetUtils.isWeatherDataStale(context)) {
            Log.d(TAG, "Weather data stale - fetching fresh data")
            WidgetUtils.fetchWeather(context)
        }

        // Always re-render if needed (30-min boundary crossed, updates "now" marker)
        // This ensures widget updates even when offline
        WidgetUtils.rerenderAllWidgetsIfNeeded(context)
    }
}
