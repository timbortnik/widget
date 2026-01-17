package org.bortnik.meteogram

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver for system events that trigger widget updates.
 *
 * Handles manifest-registered broadcasts:
 * - LOCALE_CHANGED: Re-render with new units/format
 * - TIMEZONE_CHANGED: Re-render with new time labels
 *
 * Note: CONNECTIVITY_CHANGE was removed - WorkManager with NetworkType.CONNECTED
 * constraint handles network availability more efficiently without redundant updates.
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
        }
    }

    private fun triggerReRender(context: Context) {
        // Use native widget update (no Dart/Flutter involved)
        WidgetUtils.rerenderAllWidgetsNative(context)
    }
}
