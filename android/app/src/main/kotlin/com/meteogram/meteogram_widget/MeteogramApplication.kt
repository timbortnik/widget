package com.meteogram.meteogram_widget

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
        scheduleHourlyAlarm()
    }

    private fun scheduleHourlyAlarm() {
        HourlyAlarmReceiver.scheduleNextAlarm(this)
    }

    private fun registerEventReceiver() {
        if (receiverRegistered) return

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_LOCALE_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
            addAction("android.net.conn.CONNECTIVITY_CHANGE")
        }

        // Use RECEIVER_EXPORTED to receive system broadcasts (USER_PRESENT, etc.)
        registerReceiver(widgetEventReceiver, filter, RECEIVER_EXPORTED)
        receiverRegistered = true
        Log.d(TAG, "Widget event receiver registered")
    }
}
