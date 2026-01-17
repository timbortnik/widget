package org.bortnik.meteogram

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * WorkManager Worker that detects Material You color changes.
 *
 * Uses content URI observation to trigger when Settings.Secure.THEME_CUSTOMIZATION_OVERLAY_PACKAGES
 * changes (user selects different Material You color in Settings).
 *
 * Flow:
 * 1. Worker is enqueued with content URI trigger
 * 2. When setting changes, WorkManager runs this worker
 * 3. Worker checks if colors actually changed (using MaterialYouColorExtractor)
 * 4. If changed, triggers chart re-render
 * 5. Re-enqueues itself to listen for next change
 */
class MaterialYouColorWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "MaterialYouColorWorker"
        private const val WORK_NAME = "material_you_color_observer"
        private const val THEME_CUSTOMIZATION_KEY = "theme_customization_overlay_packages"

        /**
         * Enqueue the color observer work request.
         * Uses content URI trigger to observe theme_customization_overlay_packages changes.
         */
        fun enqueue(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                Log.d(TAG, "Material You not supported on this Android version")
                return
            }

            try {
                val uri = Settings.Secure.getUriFor(THEME_CUSTOMIZATION_KEY)
                Log.d(TAG, "Setting up content URI observer for: $uri")

                val constraints = Constraints.Builder()
                    .addContentUriTrigger(uri, true)
                    .build()

                val workRequest = OneTimeWorkRequestBuilder<MaterialYouColorWorker>()
                    .setConstraints(constraints)
                    .build()

                WorkManager.getInstance(context).enqueueUniqueWork(
                    WORK_NAME,
                    ExistingWorkPolicy.REPLACE,
                    workRequest
                )

                Log.d(TAG, "Material You color observer enqueued")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enqueue color observer", e)
            }
        }
    }

    override fun doWork(): Result {
        Log.d(TAG, "Color observer triggered - checking for changes")

        try {
            // Check if colors actually changed
            if (MaterialYouColorExtractor.updateColorsIfChanged(applicationContext)) {
                Log.d(TAG, "Material You colors changed - triggering re-render for all widgets")
                WidgetUtils.rerenderAllWidgets(applicationContext)
            } else {
                Log.d(TAG, "Colors unchanged or already up to date")
            }

            // Re-enqueue to listen for next change
            enqueue(applicationContext)

            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error processing color change", e)
            // Re-enqueue even on failure to keep listening
            enqueue(applicationContext)
            return Result.failure()
        }
    }
}
