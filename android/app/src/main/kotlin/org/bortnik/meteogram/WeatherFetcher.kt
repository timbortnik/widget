package org.bortnik.meteogram

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * Native weather fetcher for Open-Meteo API.
 * Replaces the Dart-based HomeWidgetBackgroundIntent approach for more reliable background updates.
 */
object WeatherFetcher {
    private const val TAG = "WeatherFetcher"
    private const val BASE_URL = "https://api.open-meteo.com/v1/forecast"
    private const val TIMEOUT_MS = 10_000
    private const val PAST_HOURS = 6

    private val executor = Executors.newSingleThreadExecutor()

    /**
     * Fetch weather data asynchronously and save to SharedPreferences.
     * Triggers widget update on success.
     */
    fun fetchAndUpdate(context: Context) {
        executor.execute {
            try {
                fetchAndUpdateSync(context)
            } catch (e: Exception) {
                Log.e(TAG, "Background fetch failed", e)
            }
        }
    }

    /**
     * Fetch weather data synchronously and save to SharedPreferences.
     * Uses cached location from SharedPreferences.
     * Call from background thread only.
     */
    fun fetchAndUpdateSync(context: Context) {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

        // Get cached location
        val latitude = prefs.getFloat("cached_latitude", 0f).toDouble()
        val longitude = prefs.getFloat("cached_longitude", 0f).toDouble()

        if (latitude == 0.0 && longitude == 0.0) {
            Log.w(TAG, "No cached location available")
            return
        }

        if (fetchWeatherSync(context, latitude, longitude)) {
            // Trigger widget update
            WidgetUtils.rerenderAllWidgetsNative(context)
        }
    }

    /**
     * Fetch weather data synchronously for given coordinates.
     * Saves to SharedPreferences. Does NOT trigger widget update (caller's responsibility).
     * Call from background thread only.
     * @return true on success, false on failure
     */
    fun fetchWeatherSync(context: Context, latitude: Double, longitude: Double): Boolean {
        Log.d(TAG, "Fetching weather for $latitude, $longitude")

        val jsonResponse = fetchFromApi(latitude, longitude)
        if (jsonResponse == null) {
            Log.e(TAG, "Failed to fetch weather from API")
            return false
        }

        // Transform API response to cached format (matching Dart's toJson())
        val cachedJson = transformApiResponse(jsonResponse)
        if (cachedJson == null) {
            Log.e(TAG, "Failed to transform API response")
            return false
        }

        // Save to SharedPreferences
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        prefs.edit()
            .putString("cached_weather", cachedJson.toString())
            .putFloat("cached_latitude", latitude.toFloat())
            .putFloat("cached_longitude", longitude.toFloat())
            .putLong(WidgetUtils.KEY_LAST_WEATHER_UPDATE, now)
            .apply()

        Log.d(TAG, "Weather data cached successfully")
        return true
    }

    /**
     * Fetch weather data from Open-Meteo API.
     * @return JSON response or null on failure
     */
    private fun fetchFromApi(latitude: Double, longitude: Double): JSONObject? {
        val url = URL(buildUrl(latitude, longitude))
        var connection: HttpURLConnection? = null

        return try {
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS

            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                Log.e(TAG, "API returned $responseCode")
                return null
            }

            val reader = BufferedReader(InputStreamReader(connection.inputStream))
            val response = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                response.append(line)
            }
            reader.close()

            JSONObject(response.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Network error", e)
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun buildUrl(latitude: Double, longitude: Double): String {
        return "$BASE_URL?" +
                "latitude=$latitude" +
                "&longitude=$longitude" +
                "&hourly=temperature_2m,precipitation,cloud_cover" +
                "&timezone=UTC" +
                "&past_hours=$PAST_HOURS" +
                "&forecast_days=2"
    }

    /**
     * Transform Open-Meteo API response to cached format (matching Dart's WeatherData.toJson()).
     * Main difference: API times don't have Z suffix, we need to add it and add fetchedAt.
     */
    private fun transformApiResponse(apiJson: JSONObject): JSONObject? {
        return try {
            val hourly = apiJson.getJSONObject("hourly")
            val times = hourly.getJSONArray("time")

            // Convert times to ISO 8601 with Z suffix
            val normalizedTimes = JSONArray()
            for (i in 0 until times.length()) {
                val time = times.getString(i)
                // API returns "2023-01-01T00:00", we need "2023-01-01T00:00:00.000Z"
                val normalized = normalizeTimestamp(time)
                normalizedTimes.put(normalized)
            }

            // Create cached format
            val cachedHourly = JSONObject().apply {
                put("time", normalizedTimes)
                put("temperature_2m", hourly.getJSONArray("temperature_2m"))
                put("precipitation", hourly.getJSONArray("precipitation"))
                put("cloud_cover", hourly.getJSONArray("cloud_cover"))
            }

            JSONObject().apply {
                put("timezone", apiJson.optString("timezone", "UTC"))
                put("latitude", apiJson.getDouble("latitude"))
                put("longitude", apiJson.getDouble("longitude"))
                put("fetchedAt", formatIso8601(System.currentTimeMillis()))
                put("hourly", cachedHourly)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error transforming API response", e)
            null
        }
    }

    /**
     * Normalize API timestamp to ISO 8601 format with milliseconds and Z suffix.
     * "2023-01-01T00:00" -> "2023-01-01T00:00:00.000Z"
     */
    private fun normalizeTimestamp(apiTime: String): String {
        // Handle various formats the API might return
        return when {
            apiTime.endsWith("Z") -> apiTime
            apiTime.contains(".") -> "${apiTime}Z"
            apiTime.length == 16 -> "${apiTime}:00.000Z" // "2023-01-01T00:00"
            apiTime.length == 19 -> "${apiTime}.000Z"    // "2023-01-01T00:00:00"
            else -> "${apiTime}Z"
        }
    }

    /**
     * Format timestamp as ISO 8601 with milliseconds.
     */
    private fun formatIso8601(millis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(millis)
    }
}
