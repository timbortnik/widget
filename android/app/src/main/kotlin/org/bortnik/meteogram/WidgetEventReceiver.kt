package org.bortnik.meteogram

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver for system events that trigger widget updates.
 *
 * Registration:
 * - USER_PRESENT, CONNECTIVITY_CHANGE: Runtime (in MeteogramApplication)
 * - LOCALE_CHANGED, TIMEZONE_CHANGED: Manifest (app killed on change)
 *
 * Note: CONNECTIVITY_CHANGE is deprecated since Android 7.0 (API 24).
 * On newer devices, connectivity changes may be delayed or batched.
 * For more reliable network monitoring, consider using:
 * - ConnectivityManager.registerNetworkCallback() for API 21+
 * - WorkManager with NetworkType.CONNECTED constraint
 * Current implementation uses WorkManager periodic task as primary mechanism,
 * with CONNECTIVITY_CHANGE as supplementary for faster response on older devices.
 */
class WidgetEventReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "WidgetEventReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_USER_PRESENT -> {
                // Screen unlocked - always re-render to update "now" indicator position
                // Check Material You colors first (updates stored colors if changed)
                Log.d(TAG, "User present - re-rendering chart and checking staleness")
                updateMaterialYouColors(context)
                WidgetUtils.rerenderChart(context)
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

    private fun updateMaterialYouColors(context: Context) {
        // Update Material You colors if changed (Android 12+)
        // Does NOT trigger re-render - caller handles that
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (MaterialYouColorExtractor.updateColorsIfChanged(context)) {
                Log.d(TAG, "Material You colors updated")
            }
        }
    }

    private fun fetchWeatherIfStale(context: Context) {
        WidgetUtils.fetchWeatherIfStale(context)
    }

    private fun triggerReRender(context: Context) {
        WidgetUtils.rerenderChart(context)
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
