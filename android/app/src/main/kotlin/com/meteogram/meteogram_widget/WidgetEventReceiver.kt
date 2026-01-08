package com.meteogram.meteogram_widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log

/**
 * BroadcastReceiver for system events that trigger widget updates.
 * Registered at runtime to handle implicit broadcasts (Android 8.0+).
 */
class WidgetEventReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "WidgetEventReceiver"
        private const val STALE_THRESHOLD_MS = 15 * 60 * 1000L // 15 minutes
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_USER_PRESENT -> {
                // Screen unlocked - fetch only if stale
                Log.d(TAG, "User present - checking staleness")
                fetchWeatherIfStale(context)
            }
            Intent.ACTION_LOCALE_CHANGED -> {
                // Locale changed - re-render with new units/format
                Log.d(TAG, "Locale changed - triggering re-render")
                triggerReRender(context)
            }
            Intent.ACTION_TIMEZONE_CHANGED -> {
                // Timezone changed - re-render with new time labels
                Log.d(TAG, "Timezone changed - triggering re-render")
                triggerReRender(context)
            }
            "android.net.conn.CONNECTIVITY_CHANGE" -> {
                // Check network immediately - staleness check prevents duplicate fetches
                if (isNetworkAvailable(context)) {
                    Log.d(TAG, "Network available - checking staleness")
                    fetchWeatherIfStale(context)
                }
            }
        }
    }

    private fun fetchWeatherIfStale(context: Context) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val lastUpdate = prefs.getLong("last_weather_update", 0)

        if (System.currentTimeMillis() - lastUpdate > STALE_THRESHOLD_MS) {
            val ageMinutes = (System.currentTimeMillis() - lastUpdate) / 60000
            Log.d(TAG, "Data stale (${ageMinutes} min old) - triggering weather fetch")
            triggerWeatherFetch(context)
        } else {
            val ageMinutes = (System.currentTimeMillis() - lastUpdate) / 60000
            Log.d(TAG, "Data fresh (${ageMinutes} min old) - skipping fetch")
        }
    }

    private fun triggerWeatherFetch(context: Context) {
        try {
            es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homewidget://weatherUpdate")
            ).send()
            Log.d(TAG, "Weather fetch triggered via HomeWidget")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger weather fetch: ${e.message}")
        }
    }

    private fun triggerReRender(context: Context) {
        try {
            // Read dimensions from SharedPreferences and pass in URI for cold-start reliability
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val widthPx = prefs.getInt("widget_width_px", 400)
            val heightPx = prefs.getInt("widget_height_px", 200)

            // Get current system locale (Platform.localeName in Dart may be stale in background)
            val locale = java.util.Locale.getDefault()
            val localeStr = "${locale.language}_${locale.country}"

            es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homewidget://chartReRender?width=$widthPx&height=$heightPx&locale=$localeStr")
            ).send()
            Log.d(TAG, "Chart re-render triggered via HomeWidget (${widthPx}x${heightPx}, locale=$localeStr)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger chart re-render: ${e.message}")
        }
    }

    private fun isNetworkAvailable(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork
        if (network == null) {
            Log.d(TAG, "No active network")
            return false
        }
        val capabilities = cm.getNetworkCapabilities(network)
        if (capabilities == null) {
            Log.d(TAG, "No network capabilities")
            return false
        }
        val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        Log.d(TAG, "Network check: internet=$hasInternet")
        // Just check for INTERNET capability - VALIDATED may not be available immediately
        return hasInternet
    }
}
