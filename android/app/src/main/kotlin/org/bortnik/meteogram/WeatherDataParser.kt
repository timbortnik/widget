package org.bortnik.meteogram

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Constants matching Dart weather_data.dart.
 */
object WeatherConstants {
    /** Hours of past data shown by the 48h chart. */
    const val PAST_HOURS = 6

    /** Hours of forecast data shown by the 48h chart. */
    const val FORECAST_HOURS = 46

    /** Total hours shown by the 48h chart (past + forecast). */
    const val DISPLAY_RANGE_HOURS = PAST_HOURS + FORECAST_HOURS

    /** Hours of forecast data shown by the weekly (7-day) chart. */
    const val WEEKLY_FORECAST_HOURS = 7 * 24

    /**
     * Past window for the weekly chart, sized so the "now" line sits at the
     * same fraction of chart width as the 48h chart.
     *
     * SvgChartGenerator positions points as `index / (size - 1)`, so we want
     * `past / (past + forecast - 1)` to equal `PAST_HOURS / (PAST_HOURS +
     * FORECAST_HOURS - 1)`. Solving gives
     * `past = PAST_HOURS * (forecast - 1) / (FORECAST_HOURS - 1)`; rounded to
     * the nearest integer for discrete hourly data. Doubling numerator and
     * denominator plus denominator lets us round-half-up in integer math.
     */
    const val WEEKLY_PAST_HOURS =
        (PAST_HOURS * (WEEKLY_FORECAST_HOURS - 1) * 2 + (FORECAST_HOURS - 1)) /
            (2 * (FORECAST_HOURS - 1))

    /** Total hours shown by the weekly chart. */
    const val WEEKLY_RANGE_HOURS = WEEKLY_PAST_HOURS + WEEKLY_FORECAST_HOURS
}

/**
 * A view on weather data for chart rendering: the slice of hourly data to plot
 * plus the index within that slice where "now" sits.
 */
data class ChartView(val data: List<HourlyData>, val nowIndex: Int)

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
     * Chart view for the 48h meteogram: 6h past + 46h forecast centred on
     * the current hour, with nowIndex adjusted to the returned slice.
     */
    fun getHourlyView(): ChartView = sliceView(
        pastHours = WeatherConstants.PAST_HOURS,
        totalHours = WeatherConstants.DISPLAY_RANGE_HOURS
    )

    /**
     * Chart view for the weekly meteogram: proportional past + 14d forecast.
     */
    fun getWeeklyView(): ChartView = sliceView(
        pastHours = WeatherConstants.WEEKLY_PAST_HOURS,
        totalHours = WeatherConstants.WEEKLY_RANGE_HOURS
    )

    private fun sliceView(pastHours: Int, totalHours: Int): ChartView {
        if (hourly.isEmpty()) return ChartView(emptyList(), 0)
        val fullNow = getNowIndex()
        val start = (fullNow - pastHours).coerceAtLeast(0)
        val end = (start + totalHours).coerceAtMost(hourly.size)
        return ChartView(hourly.subList(start, end), fullNow - start)
    }

    /**
     * Get index of "now" in the hourly data.
     * Rounds to nearest hour (at :30 boundary) to match chart display.
     */
    fun getNowIndex(): Int {
        if (hourly.isEmpty()) return 0

        // Get current time rounded to nearest hour (same logic as former Dart getNowIndex)
        val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        val minute = calendar.get(Calendar.MINUTE)
        if (minute >= 30) {
            calendar.add(Calendar.HOUR_OF_DAY, 1)
        }
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val roundedNowMs = calendar.timeInMillis

        // Find matching hour in data
        for (i in hourly.indices) {
            // Compare truncated to hour (within 30 min window)
            if (kotlin.math.abs(hourly[i].time - roundedNowMs) < 30 * 60 * 1000) {
                return i
            }
        }

        // Fallback: find closest hour before now
        val nowMs = System.currentTimeMillis()
        for (i in hourly.indices.reversed()) {
            if (hourly[i].time < nowMs) {
                return i
            }
        }

        // Ultimate fallback
        return WeatherConstants.PAST_HOURS.coerceIn(0, hourly.size - 1)
    }

    /**
     * Get current hour's temperature (at nowIndex).
     */
    fun getCurrentTemperature(): Double? {
        val idx = getNowIndex()
        return if (idx in hourly.indices) hourly[idx].temperature else null
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
