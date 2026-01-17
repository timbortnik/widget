package org.bortnik.meteogram

import android.app.Application
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log

/**
 * Application class for Meteogram widget.
 * Registers broadcast receivers for system events that trigger widget updates.
 */
class MeteogramApplication : Application() {
    companion object {
        private const val TAG = "MeteogramApp"
        private const val THEME_CUSTOMIZATION_KEY = "theme_customization_overlay_packages"
    }

    private val widgetEventReceiver = WidgetEventReceiver()
    private var receiverRegistered = false
    private var themeObserver: ContentObserver? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application onCreate")
        registerEventReceiver()
        registerThemeObserver()
        enqueueMaterialYouColorObserver()
        enqueuePeriodicWeatherUpdate()
    }

    /**
     * Register ContentObserver for immediate Material You color change detection.
     * This fires instantly when colors change (while app process is alive).
     * WorkManager and USER_PRESENT provide fallback when app is killed.
     */
    private fun registerThemeObserver() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        try {
            val uri = Settings.Secure.getUriFor(THEME_CUSTOMIZATION_KEY)
            themeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    Log.d(TAG, "Theme customization changed (ContentObserver)")
                    if (MaterialYouColorExtractor.updateColorsIfChanged(applicationContext)) {
                        Log.d(TAG, "Material You colors changed - triggering native re-render for all widgets")
                        WidgetUtils.rerenderAllWidgetsNative(applicationContext)
                    }
                }
            }
            contentResolver.registerContentObserver(uri, false, themeObserver!!)
            Log.d(TAG, "Theme ContentObserver registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register theme observer", e)
        }
    }

    private fun enqueueMaterialYouColorObserver() {
        // WorkManager fallback for when app is killed (fires on next process start)
        MaterialYouColorWorker.enqueue(this)
    }

    private fun enqueuePeriodicWeatherUpdate() {
        // WorkManager periodic task for background weather updates
        // More battery-efficient than AlarmManager - OS batches work
        WeatherUpdateWorker.enqueue(this)
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
