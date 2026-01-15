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
 * BroadcastReceiver that triggers widget chart re-render at hour boundaries.
 * This updates the "now" indicator position without fetching new weather data.
 *
 * Uses a buffer + verification approach to ensure the alarm always fires
 * AFTER the hour change, never before:
 * 1. Schedule alarm for XX:00:15 (15 seconds after the hour)
 * 2. When alarm fires, verify minute <= MAX_VALID_MINUTE (early in hour = past boundary)
 * 3. If fired early (minute > 30, still in previous hour), retry after a short delay
 */
class HourlyAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "HourlyAlarmReceiver"
        const val ACTION_HOURLY_UPDATE = "org.bortnik.meteogram.HOURLY_UPDATE"

        // Buffer after hour boundary to ensure we're always past it (seconds)
        // Matches lib/constants.dart:AlarmConstants.hourBoundaryBufferSeconds
        private const val HOUR_BUFFER_SECONDS = 15

        // Maximum minute value to consider "early in the hour" (past the boundary)
        // Inexact alarms can drift significantly, so we use a generous threshold
        // Matches lib/constants.dart:AlarmConstants.maxValidMinute
        private const val MAX_VALID_MINUTE = 30

        /**
         * Schedule the next hourly alarm shortly after the next hour boundary.
         * Uses a 15-second buffer to ensure we're always past the hour change.
         */
        fun scheduleNextAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Calculate next hour boundary + buffer
            val calendar = Calendar.getInstance().apply {
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, HOUR_BUFFER_SECONDS)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.HOUR_OF_DAY, 1)
            }

            val intent = Intent(context, HourlyAlarmReceiver::class.java).apply {
                action = ACTION_HOURLY_UPDATE
                // Explicitly set component for security (prevents intent interception)
                component = android.content.ComponentName(context, HourlyAlarmReceiver::class.java)
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
                Log.d(TAG, "Scheduled inexact hourly alarm for ${calendar.time} (±5min window, may be adjusted by system)")
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
                Log.d(TAG, "Scheduled hourly alarm for ${calendar.time}")
            }
        }

        /**
         * Cancel any pending hourly alarm.
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, HourlyAlarmReceiver::class.java).apply {
                action = ACTION_HOURLY_UPDATE
                // Explicitly set component for security
                component = android.content.ComponentName(context, HourlyAlarmReceiver::class.java)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Cancelled hourly alarm")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_HOURLY_UPDATE -> {
                handleHourlyUpdate(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Device booted - scheduling hourly alarm")
                scheduleNextAlarm(context)
            }
        }
    }

    private fun handleHourlyUpdate(context: Context) {
        val calendar = Calendar.getInstance()
        val minute = calendar.get(Calendar.MINUTE)
        val second = calendar.get(Calendar.SECOND)

        Log.d(TAG, "Hourly alarm fired at ${calendar.time} (minute=$minute, second=$second)")

        // Verify we're actually past the hour boundary
        // If minute > MAX_VALID_MINUTE, we likely fired early (still in previous hour)
        if (minute > MAX_VALID_MINUTE) {
            Log.w(TAG, "Alarm fired early (minute=$minute > $MAX_VALID_MINUTE) - scheduling retry")
            scheduleRetry(context)
            return
        }

        // We're past the hour boundary - safe to re-render
        Log.d(TAG, "Hour boundary confirmed - re-rendering chart")
        rerenderChart(context)

        // Schedule next hourly alarm
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
