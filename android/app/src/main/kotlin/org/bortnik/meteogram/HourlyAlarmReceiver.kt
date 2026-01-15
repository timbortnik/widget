package org.bortnik.meteogram

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * BroadcastReceiver that triggers widget chart re-render at half-hour marks.
 * The "now" indicator snaps to the nearest hour at :30, so we re-render then.
 *
 * Uses a buffer + verification approach to ensure the alarm fires AFTER :30:
 * 1. Schedule alarm for XX:30:15 (15 seconds after the half-hour)
 * 2. When alarm fires, verify minute >= 30 (past the :30 boundary)
 * 3. If fired early (minute < 30), retry after a short delay
 */
class HourlyAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "HourlyAlarmReceiver"
        const val ACTION_HOURLY_UPDATE = "org.bortnik.meteogram.HOURLY_UPDATE"

        // Buffer after half-hour boundary to ensure we're always past it (seconds)
        private const val HOUR_BUFFER_SECONDS = 15

        /**
         * Schedule the next alarm at the half-hour mark (XX:30).
         * The "now" indicator snaps to nearest hour at :30, so we re-render then.
         * Uses a 15-second buffer to ensure we're past the boundary.
         */
        fun scheduleNextAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Calculate next half-hour boundary + buffer
            // The "now" indicator snaps at :30, so we re-render then
            val calendar = Calendar.getInstance().apply {
                val currentMinute = get(Calendar.MINUTE)
                if (currentMinute < 30) {
                    // Next half-hour is :30 of current hour
                    set(Calendar.MINUTE, 30)
                } else {
                    // Next half-hour is :30 of next hour
                    set(Calendar.MINUTE, 30)
                    add(Calendar.HOUR_OF_DAY, 1)
                }
                set(Calendar.SECOND, HOUR_BUFFER_SECONDS)
                set(Calendar.MILLISECOND, 0)
            }

            val intent = Intent(ACTION_HOURLY_UPDATE).apply {
                setClassName(context.packageName, HourlyAlarmReceiver::class.java.name)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Use setWindow for inexact alarm (no SCHEDULE_EXACT_ALARM permission needed)
            // Fires within a window after the target time (5 minutes requested)
            // Note: Android may enforce minimum window (e.g., 10 min on Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val windowLengthMs = 5 * 60 * 1000L // 5 minute window (may be clipped to 10 min by system)
                alarmManager.setWindow(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    windowLengthMs,
                    pendingIntent
                )
                Log.d(TAG, "Scheduled half-hour alarm for ${calendar.time} (±5min window, may be adjusted by system)")
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
                Log.d(TAG, "Scheduled half-hour alarm for ${calendar.time}")
            }
        }

        /**
         * Cancel any pending alarm.
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(ACTION_HOURLY_UPDATE).apply {
                setClassName(context.packageName, HourlyAlarmReceiver::class.java.name)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Cancelled half-hour alarm")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_HOURLY_UPDATE -> {
                handleHourlyUpdate(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Device booted - scheduling half-hour alarm")
                scheduleNextAlarm(context)
            }
        }
    }

    private fun handleHourlyUpdate(context: Context) {
        val calendar = Calendar.getInstance()
        val minute = calendar.get(Calendar.MINUTE)
        val second = calendar.get(Calendar.SECOND)

        Log.d(TAG, "Half-hour alarm fired at ${calendar.time} (minute=$minute, second=$second)")

        // Verify we're past the :30 boundary
        // If minute < 30, we fired early (before the target XX:30)
        if (minute < 30) {
            Log.w(TAG, "Alarm fired early (minute=$minute < 30) - scheduling retry")
            scheduleRetry(context)
            return
        }

        // We're past the :30 boundary - safe to re-render
        Log.d(TAG, "Half-hour boundary confirmed - re-rendering chart")
        rerenderChart(context)

        // Schedule next half-hour alarm
        scheduleNextAlarm(context)
    }

    private fun scheduleRetry(context: Context) {
        // Use AlarmManager instead of Handler.postDelayed to avoid memory leaks
        // (Handler captures context in long-delayed callback)
        Log.d(TAG, "Alarm fired early - rescheduling via AlarmManager")
        scheduleNextAlarm(context)
    }

    private fun rerenderChart(context: Context) {
        // Check for Material You color changes (Android 12+)
        // This catches changes made while app was force-closed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (MaterialYouColorExtractor.updateColorsIfChanged(context)) {
                Log.d(TAG, "Material You colors changed - will re-render with new colors")
            }
        }

        WidgetUtils.rerenderChart(context)
    }
}
