package org.bortnik.meteogram

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Log

/**
 * Schedules inexact repeating alarms for widget updates.
 *
 * Complements WorkManager for more reliable "now" indicator updates:
 * - WorkManager: Network-dependent weather fetches, batched by OS
 * - AlarmManager: Time-based re-renders, fires on wake if missed during sleep
 *
 * Uses ELAPSED_REALTIME (not _WAKEUP) to avoid waking device from sleep,
 * but will fire promptly when device wakes for any reason.
 */
object WidgetAlarmScheduler {
    private const val TAG = "WidgetAlarmScheduler"
    private const val REQUEST_CODE = 1001

    // 15-minute interval for "now" indicator updates
    // Matches Android's INTERVAL_FIFTEEN_MINUTES
    private const val INTERVAL_MS = AlarmManager.INTERVAL_FIFTEEN_MINUTES

    /**
     * Schedule inexact repeating alarm for widget updates.
     * Safe to call multiple times - will update existing alarm.
     */
    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
            action = WidgetAlarmReceiver.ACTION_ALARM_UPDATE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Schedule inexact repeating alarm
        // ELAPSED_REALTIME: doesn't wake device, fires when already awake
        // setInexactRepeating: allows OS to batch with other alarms for battery efficiency
        alarmManager.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + INTERVAL_MS,
            INTERVAL_MS,
            pendingIntent
        )

        Log.d(TAG, "Widget update alarm scheduled (${INTERVAL_MS / 60000} min interval)")
    }

    /**
     * Cancel the widget update alarm.
     */
    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
            action = WidgetAlarmReceiver.ACTION_ALARM_UPDATE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Widget update alarm cancelled")
    }
}
