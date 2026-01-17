package org.bortnik.meteogram

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * Constants matching Dart weather_data.dart.
 */
object WeatherConstants {
    /** Hours of past data to request from API. */
    const val PAST_HOURS = 6

    /** Hours of future data to display on chart. */
    const val FORECAST_HOURS = 46

    /** Total display range in hours (past + forecast). */
    const val DISPLAY_RANGE_HOURS = PAST_HOURS + FORECAST_HOURS
}

/**
 * Parsed weather data from cache.
 */
data class WeatherData(
    val timezone: String,
    val latitude: Double,
    val longitude: Double,
    val hourly: List<HourlyData>,
    val fetchedAt: Long  // milliseconds
) {
    /**
     * Get data for display range (limited to DISPLAY_RANGE_HOURS).
     */
    fun getDisplayRange(): List<HourlyData> {
        val endIndex = WeatherConstants.DISPLAY_RANGE_HOURS.coerceAtMost(hourly.size)
        return hourly.subList(0, endIndex)
    }

    /**
     * Get index of "now" in the display range.
     * Returns PAST_HOURS (clamped to valid range).
     */
    fun getNowIndex(): Int {
        return WeatherConstants.PAST_HOURS.coerceIn(0, hourly.size - 1)
    }
}

/**
 * Parses cached weather data from SharedPreferences.
 */
object WeatherDataParser {
    private const val TAG = "WeatherDataParser"

    /**
     * Parse cached weather JSON from SharedPreferences.
     * @return WeatherData or null if not available/invalid
     */
    fun parseFromPrefs(context: Context): WeatherData? {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("cached_weather", null)
        if (jsonStr == null) {
            Log.d(TAG, "No cached weather data")
            return null
        }

        return try {
            parseJson(jsonStr)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing weather data", e)
            null
        }
    }

    /**
     * Parse weather JSON string.
     */
    fun parseJson(jsonStr: String): WeatherData {
        val json = JSONObject(jsonStr)
        val timezone = json.getString("timezone")
        val latitude = json.getDouble("latitude")
        val longitude = json.getDouble("longitude")
        val fetchedAtStr = json.getString("fetchedAt")
        val fetchedAt = parseIso8601(fetchedAtStr)

        val hourlyJson = json.getJSONObject("hourly")
        val times = hourlyJson.getJSONArray("time")
        val temperatures = hourlyJson.getJSONArray("temperature_2m")
        val precipitation = hourlyJson.getJSONArray("precipitation")
        val cloudCover = hourlyJson.getJSONArray("cloud_cover")

        // Find minimum length to prevent index errors
        val minLength = minOf(
            times.length(),
            temperatures.length(),
            precipitation.length(),
            cloudCover.length()
        )

        val hourlyData = mutableListOf<HourlyData>()
        for (i in 0 until minLength) {
            if (times.isNull(i) || temperatures.isNull(i)) continue

            val timeStr = times.getString(i)
            val timeMs = parseIso8601(timeStr)

            hourlyData.add(
                HourlyData(
                    time = timeMs,
                    temperature = temperatures.getDouble(i),
                    precipitation = precipitation.optDouble(i, 0.0),
                    cloudCover = cloudCover.optInt(i, 0)
                )
            )
        }

        Log.d(TAG, "Parsed ${hourlyData.size} hourly data points")
        return WeatherData(
            timezone = timezone,
            latitude = latitude,
            longitude = longitude,
            hourly = hourlyData,
            fetchedAt = fetchedAt
        )
    }

    /**
     * Parse ISO 8601 timestamp to milliseconds.
     * Handles formats with or without milliseconds/microseconds and Z suffix.
     */
    private fun parseIso8601(str: String): Long {
        // Remove trailing Z if present
        var normalized = str.removeSuffix("Z")

        // Truncate microseconds to milliseconds if present (Dart may output 6 digits)
        // Pattern: "2023-01-01T12:00:00.123456" -> "2023-01-01T12:00:00.123"
        val dotIndex = normalized.lastIndexOf('.')
        if (dotIndex > 0 && normalized.length - dotIndex > 4) {
            normalized = normalized.substring(0, dotIndex + 4)
        }

        // Try parsing with milliseconds first, then without
        val formats = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm"
        )

        for (pattern in formats) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US)
                format.timeZone = TimeZone.getTimeZone("UTC")
                return format.parse(normalized)?.time ?: continue
            } catch (e: Exception) {
                // Try next format
            }
        }

        Log.w(TAG, "Failed to parse timestamp: $str")
        return 0L
    }
}
