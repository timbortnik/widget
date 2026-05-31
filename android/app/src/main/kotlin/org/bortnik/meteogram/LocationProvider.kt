package org.bortnik.meteogram

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Native location access via the framework's [LocationManager] — no plugin, no
 * Google Play Services. Replaces the geolocator plugin's GPS surface.
 *
 * All fixes are foreground-only: the home-screen widget's background refresh
 * reuses the cached coordinates and never requests a fresh fix, so there is no
 * background-location or headless-permission path to handle here.
 */
object LocationProvider {
    private const val TAG = "LocationProvider"

    /** Providers tried in order: network (low-power, low-accuracy) before GPS. */
    private val PROVIDERS = listOf(
        LocationManager.NETWORK_PROVIDER,
        LocationManager.GPS_PROVIDER,
        LocationManager.PASSIVE_PROVIDER,
    )

    fun isLocationServiceEnabled(context: Context): Boolean {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            (lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
        }
    }

    /** "granted" if fine or coarse location is held, else "denied". */
    fun checkPermissionStatus(context: Context): String {
        val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        val granted = fine == PackageManager.PERMISSION_GRANTED ||
            coarse == PackageManager.PERMISSION_GRANTED
        return if (granted) "granted" else "denied"
    }

    private fun hasPermission(context: Context): Boolean =
        checkPermissionStatus(context) == "granted"

    /** Most-recent last-known fix across providers, or null. Caller must hold permission. */
    fun getLastKnownPosition(context: Context): DoubleArray? {
        if (!hasPermission(context)) return null
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        var best: Location? = null
        for (provider in PROVIDERS) {
            try {
                val loc = lm.getLastKnownLocation(provider) ?: continue
                if (best == null || loc.time > best.time) best = loc
            } catch (e: SecurityException) {
                Log.w(TAG, "No permission for provider $provider", e)
            } catch (e: IllegalArgumentException) {
                // Provider doesn't exist on this device — skip.
            }
        }
        return best?.let { doubleArrayOf(it.latitude, it.longitude) }
    }

    /**
     * One-shot current-location request (low accuracy). Invokes [callback] exactly
     * once on the main thread with `[lat, lon]`, or null on timeout/failure. Call
     * this on the main thread.
     */
    @Suppress("DEPRECATION") // onStatusChanged override is needed for minSdk 24 runtime safety.
    fun getCurrentPosition(context: Context, timeoutMs: Long, callback: (DoubleArray?) -> Unit) {
        if (!hasPermission(context)) { callback(null); return }
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) { callback(null); return }

        val provider = PROVIDERS.firstOrNull {
            try { lm.isProviderEnabled(it) } catch (e: Exception) { false }
        }
        if (provider == null) { callback(null); return }

        val handler = Handler(Looper.getMainLooper())
        var done = false

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (done) return
                done = true
                try { lm.removeUpdates(this) } catch (_: Exception) {}
                handler.removeCallbacksAndMessages(null)
                callback(doubleArrayOf(location.latitude, location.longitude))
            }

            // onStatusChanged/onProviderEnabled/onProviderDisabled gained default
            // implementations only in API 30; override them so the class is safe on
            // API 24 (where the framework still invokes them on the interface).
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        try {
            lm.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
        } catch (e: SecurityException) {
            callback(null)
            return
        } catch (e: Exception) {
            Log.w(TAG, "requestLocationUpdates failed", e)
            callback(null)
            return
        }

        handler.postDelayed({
            if (done) return@postDelayed
            done = true
            try { lm.removeUpdates(listener) } catch (_: Exception) {}
            callback(null)
        }, timeoutMs)
    }
}
