package org.bortnik.meteogram

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log

/**
 * BroadcastReceiver for system events that trigger widget updates.
 *
 * Registration:
 * - CONNECTIVITY_CHANGE: Runtime (in MeteogramApplication)
 * - LOCALE_CHANGED, TIMEZONE_CHANGED: Manifest (app killed on change)
 *
 * Note: USER_PRESENT was removed because it only works when app process is running,
 * causing inconsistent behavior. Widget updates rely on updatePeriodMillis (30 min)
 * and WorkManager for consistent behavior regardless of app state.
 *
 * Note: CONNECTIVITY_CHANGE is deprecated since Android 7.0 (API 24).
 * On newer devices, connectivity changes may be delayed or batched.
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
                if (isNetworkAvailable(context)) {
                    // Fetch if stale, otherwise re-render if needed (30-min boundary crossed)
                    if (WidgetUtils.isWeatherDataStale(context)) {
                        Log.d(TAG, "Network available, data stale - fetching weather")
                        WidgetUtils.fetchWeather(context)
                    } else {
                        Log.d(TAG, "Network available, data fresh - checking if re-render needed")
                        WidgetUtils.rerenderAllWidgetsIfNeeded(context)
                    }
                }
            }
        }
    }

    private fun triggerReRender(context: Context) {
        // Use native widget update (no Dart/Flutter involved)
        WidgetUtils.rerenderAllWidgetsNative(context)
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
