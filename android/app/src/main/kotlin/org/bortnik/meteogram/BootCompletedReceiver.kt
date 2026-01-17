package org.bortnik.meteogram

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver for BOOT_COMPLETED to refresh widget immediately after device boot.
 *
 * Actions:
 * 1. Schedule the periodic alarm (ensures it's set up after reboot)
 * 2. Fetch weather data if stale
 * 3. Re-render widgets with fresh "now" indicator
 *
 * Note: Requires RECEIVE_BOOT_COMPLETED permission in manifest.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootCompletedReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        Log.d(TAG, "Boot completed - refreshing widget")

        // Schedule the periodic alarm
        WidgetAlarmScheduler.schedule(context)

        // Fetch weather if stale, otherwise just re-render
        if (WidgetUtils.isWeatherDataStale(context)) {
            Log.d(TAG, "Weather data stale - fetching fresh data")
            WidgetUtils.fetchWeather(context)
        } else {
            Log.d(TAG, "Weather data fresh - re-rendering widgets")
            WidgetUtils.rerenderAllWidgetsNative(context)
        }
    }
}
