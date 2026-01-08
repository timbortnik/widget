package com.meteogram.meteogram_widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
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
        const val ACTION_HOURLY_UPDATE = "com.meteogram.meteogram_widget.HOURLY_UPDATE"

        // Buffer after hour boundary to ensure we're always past it
        private const val HOUR_BUFFER_SECONDS = 15
        // Maximum minute value to consider "early in the hour" (past the boundary)
        // Inexact alarms can drift significantly, so we use a generous threshold
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
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Use setAndAllowWhileIdle for battery-efficient scheduling
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }

            Log.d(TAG, "Scheduled next hourly alarm for ${calendar.time}")
        }

        /**
         * Cancel any pending hourly alarm.
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, HourlyAlarmReceiver::class.java).apply {
                action = ACTION_HOURLY_UPDATE
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
        Log.d(TAG, "Hour boundary confirmed - triggering chart re-render")
        triggerChartReRender(context)

        // Schedule next hourly alarm
        scheduleNextAlarm(context)
    }

    private fun scheduleRetry(context: Context) {
        // Calculate delay until next hour boundary + buffer
        val now = Calendar.getInstance()
        val nextHour = Calendar.getInstance().apply {
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, HOUR_BUFFER_SECONDS)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.HOUR_OF_DAY, 1)
        }
        val delayMs = nextHour.timeInMillis - now.timeInMillis

        Log.d(TAG, "Scheduling retry in ${delayMs}ms (at ${nextHour.time})")

        Handler(Looper.getMainLooper()).postDelayed({
            Log.d(TAG, "Retry: checking hour boundary again")
            handleHourlyUpdate(context)
        }, delayMs)
    }

    private fun triggerChartReRender(context: Context) {
        try {
            // Read dimensions from SharedPreferences and pass in URI for cold-start reliability
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            var widthPx = prefs.getInt("widget_width_px", 0)
            var heightPx = prefs.getInt("widget_height_px", 0)

            // Use fallback dimensions if SharedPreferences has invalid values
            // Default to ~4x4 grid widget at ~3x density: 300dp * 3 = 900px
            if (widthPx <= 0) widthPx = 1000
            if (heightPx <= 0) heightPx = 500

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
}
