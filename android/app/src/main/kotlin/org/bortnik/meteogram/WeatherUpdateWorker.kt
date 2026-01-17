package org.bortnik.meteogram

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * WorkManager Worker for periodic weather updates.
 * More battery-efficient than AlarmManager as work is batched by the OS.
 *
 * Runs approximately every 30 minutes when network is available.
 * Fetches weather if data is stale (>15 min old), otherwise just re-renders chart.
 */
class WeatherUpdateWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "WeatherUpdateWorker"
        private const val WORK_NAME = "periodic_weather_update"

        /**
         * Enqueue periodic weather update work.
         * Uses KEEP policy to avoid re-enqueuing if already scheduled.
         */
        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            // 30 minute interval - WorkManager will batch with other work for battery efficiency
            val workRequest = PeriodicWorkRequestBuilder<WeatherUpdateWorker>(
                30, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
            Log.d(TAG, "Periodic weather update work enqueued (30 min interval)")
        }
    }

    override fun doWork(): Result {
        Log.d(TAG, "Periodic weather update running")

        try {
            // Check for Material You color changes (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (MaterialYouColorExtractor.updateColorsIfChanged(applicationContext)) {
                    Log.d(TAG, "Material You colors changed - will re-render with new colors")
                }
            }

            // Fetch weather if stale, otherwise just re-render
            if (WidgetUtils.isWeatherDataStale(applicationContext)) {
                Log.d(TAG, "Weather data stale - fetching fresh data")
                WidgetUtils.fetchWeather(applicationContext)
            } else {
                Log.d(TAG, "Weather data fresh - re-rendering all widgets")
                WidgetUtils.rerenderAllWidgets(applicationContext)
            }

            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Weather update failed", e)
            return Result.retry()
        }
    }
}
