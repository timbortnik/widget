package org.bortnik.meteogram

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.util.Log
import java.util.Locale

/**
 * Reverse-geocodes coordinates to a city name using the native Android [Geocoder].
 *
 * Replaces the `geocoding` Flutter plugin (which applies the Kotlin Gradle Plugin) with
 * the same underlying Android API, but in our own app module.
 */
object ReverseGeocoder {
    private const val TAG = "ReverseGeocoder"

    /**
     * Resolve [latitude]/[longitude] to a best-effort city name, or null if unavailable.
     *
     * Prefers `locality`, then `subAdminArea`, then `adminArea` (matching the prior
     * `Placemark.locality ?? subAdministrativeArea ?? administrativeArea` logic).
     *
     * On API 33+ this uses the async [Geocoder] API; on older versions it calls the
     * (blocking, deprecated) synchronous API, so callers should invoke it off the main
     * thread. [callback] may run on a binder/worker thread.
     */
    fun cityFromCoordinates(
        context: Context,
        latitude: Double,
        longitude: Double,
        callback: (String?) -> Unit
    ) {
        if (!Geocoder.isPresent()) {
            callback(null)
            return
        }
        val geocoder = Geocoder(context, Locale.getDefault())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    callback(pickCity(addresses))
                }

                override fun onError(errorMessage: String?) {
                    Log.w(TAG, "Geocode error: $errorMessage")
                    callback(null)
                }
            })
        } else {
            val addresses = try {
                @Suppress("DEPRECATION")
                geocoder.getFromLocation(latitude, longitude, 1)
            } catch (e: Exception) {
                Log.w(TAG, "Geocode failed", e)
                null
            }
            callback(pickCity(addresses))
        }
    }

    private fun pickCity(addresses: List<Address>?): String? {
        val address = addresses?.firstOrNull() ?: return null
        return address.locality?.takeIf { it.isNotEmpty() }
            ?: address.subAdminArea?.takeIf { it.isNotEmpty() }
            ?: address.adminArea?.takeIf { it.isNotEmpty() }
    }
}
