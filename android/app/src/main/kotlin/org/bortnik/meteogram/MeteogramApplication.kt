package org.bortnik.meteogram

import android.app.Application
import android.content.Intent
import android.content.IntentFilter
import android.util.Log

/**
 * Application class for Meteogram widget.
 * Registers broadcast receivers for system events that trigger widget updates.
 */
class MeteogramApplication : Application() {
    companion object {
        private const val TAG = "MeteogramApp"
    }

    private val widgetEventReceiver = WidgetEventReceiver()
    private var receiverRegistered = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application onCreate")
        registerEventReceiver()
        enqueueMaterialYouColorObserver()
        scheduleHourlyAlarm()
    }

    private fun enqueueMaterialYouColorObserver() {
        // Use WorkManager to observe Material You color changes via content URI trigger
        MaterialYouColorWorker.enqueue(this)
    }

    private fun scheduleHourlyAlarm() {
        HourlyAlarmReceiver.scheduleNextAlarm(this)
    }

    private fun registerEventReceiver() {
        if (receiverRegistered) return

        // LOCALE_CHANGED and TIMEZONE_CHANGED are handled by manifest-declared receiver
        // (required because app process is killed on locale change)
        // USER_PRESENT and CONNECTIVITY_CHANGE require runtime registration
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction("android.net.conn.CONNECTIVITY_CHANGE")
        }

        // Use RECEIVER_EXPORTED to receive system broadcasts (USER_PRESENT, etc.)
        registerReceiver(widgetEventReceiver, filter, RECEIVER_EXPORTED)
        receiverRegistered = true
        Log.d(TAG, "Widget event receiver registered (runtime: USER_PRESENT, CONNECTIVITY_CHANGE)")
    }
}
