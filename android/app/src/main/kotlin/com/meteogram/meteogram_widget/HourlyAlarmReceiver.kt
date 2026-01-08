package com.meteogram.meteogram_widget

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
 */
class HourlyAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "HourlyAlarmReceiver"
        const val ACTION_HOURLY_UPDATE = "com.meteogram.meteogram_widget.HOURLY_UPDATE"

        /**
         * Schedule the next hourly alarm at the start of the next hour.
         * Uses inexact alarms to avoid requiring SCHEDULE_EXACT_ALARM permission.
         * The alarm may fire up to a few minutes before/after the hour boundary,
         * which is acceptable for updating the "now" indicator.
         */
        fun scheduleNextAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Calculate next hour boundary
            val calendar = Calendar.getInstance().apply {
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
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
            // This doesn't require SCHEDULE_EXACT_ALARM permission
            // The alarm may be delayed by up to a few minutes, which is fine for our use case
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
                Log.d(TAG, "Hourly alarm fired - triggering chart re-render")
                triggerChartReRender(context)
                // Schedule next hourly alarm
                scheduleNextAlarm(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Device booted - scheduling hourly alarm")
                scheduleNextAlarm(context)
            }
        }
    }

    private fun triggerChartReRender(context: Context) {
        try {
            es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homewidget://chartReRender")
            ).send()
            Log.d(TAG, "Chart re-render triggered via HomeWidget")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger chart re-render: ${e.message}")
        }
    }
}
