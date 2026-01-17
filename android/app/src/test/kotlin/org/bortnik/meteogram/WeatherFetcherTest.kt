package org.bortnik.meteogram

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.lang.reflect.Method

/**
 * Unit tests for WeatherFetcher.
 *
 * Tests cover timestamp parsing, URL building, and JSON transformation.
 * Network operations are not tested (would require mocking HttpURLConnection).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WeatherFetcherTest {

    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences

    // Reflection helpers for private methods
    private lateinit var parseIso8601ToMillis: Method
    private lateinit var normalizeTimestamp: Method
    private lateinit var buildUrl: Method
    private lateinit var transformApiResponse: Method
    private lateinit var extractCurrentTemperature: Method

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().commit()

        // Get access to private methods via reflection
        parseIso8601ToMillis = WeatherFetcher::class.java.getDeclaredMethod("parseIso8601ToMillis", String::class.java)
        parseIso8601ToMillis.isAccessible = true

        normalizeTimestamp = WeatherFetcher::class.java.getDeclaredMethod("normalizeTimestamp", String::class.java)
        normalizeTimestamp.isAccessible = true

        buildUrl = WeatherFetcher::class.java.getDeclaredMethod("buildUrl", Double::class.java, Double::class.java)
        buildUrl.isAccessible = true

        transformApiResponse = WeatherFetcher::class.java.getDeclaredMethod("transformApiResponse", JSONObject::class.java)
        transformApiResponse.isAccessible = true

        extractCurrentTemperature = WeatherFetcher::class.java.getDeclaredMethod("extractCurrentTemperature", JSONObject::class.java)
        extractCurrentTemperature.isAccessible = true
    }

    // ==================== parseIso8601ToMillis Tests ====================

    @Test
    fun `parseIso8601ToMillis handles full format with milliseconds`() {
        val result = parseIso8601ToMillis.invoke(WeatherFetcher, "2024-01-15T10:30:45.123Z") as Long
        assertTrue(result > 0)
        // 2024-01-15T10:30:45.123Z in milliseconds
        assertEquals(1705314645123L, result)
    }

    @Test
    fun `parseIso8601ToMillis handles format without milliseconds`() {
        val result = parseIso8601ToMillis.invoke(WeatherFetcher, "2024-01-15T10:30:45Z") as Long
        assertTrue(result > 0)
        assertEquals(1705314645000L, result)
    }

    @Test
    fun `parseIso8601ToMillis handles format without seconds`() {
        val result = parseIso8601ToMillis.invoke(WeatherFetcher, "2024-01-15T10:30") as Long
        assertTrue(result > 0)
        assertEquals(1705314600000L, result)
    }

    @Test
    fun `parseIso8601ToMillis handles format without Z suffix`() {
        val result = parseIso8601ToMillis.invoke(WeatherFetcher, "2024-01-15T10:30:45") as Long
        assertTrue(result > 0)
        assertEquals(1705314645000L, result)
    }

    @Test
    fun `parseIso8601ToMillis returns 0 for invalid format`() {
        val result = parseIso8601ToMillis.invoke(WeatherFetcher, "invalid") as Long
        assertEquals(0L, result)
    }

    @Test
    fun `parseIso8601ToMillis truncates extra millisecond digits`() {
        // API might return microseconds
        val result = parseIso8601ToMillis.invoke(WeatherFetcher, "2024-01-15T10:30:45.123456Z") as Long
        assertTrue(result > 0)
    }

    // ==================== normalizeTimestamp Tests ====================

    @Test
    fun `normalizeTimestamp handles API format without seconds`() {
        val result = normalizeTimestamp.invoke(WeatherFetcher, "2024-01-15T10:30") as String
        assertEquals("2024-01-15T10:30:00.000Z", result)
    }

    @Test
    fun `normalizeTimestamp handles format with seconds`() {
        val result = normalizeTimestamp.invoke(WeatherFetcher, "2024-01-15T10:30:45") as String
        assertEquals("2024-01-15T10:30:45.000Z", result)
    }

    @Test
    fun `normalizeTimestamp handles format with milliseconds`() {
        val result = normalizeTimestamp.invoke(WeatherFetcher, "2024-01-15T10:30:45.123") as String
        assertEquals("2024-01-15T10:30:45.123Z", result)
    }

    @Test
    fun `normalizeTimestamp preserves Z suffix`() {
        val result = normalizeTimestamp.invoke(WeatherFetcher, "2024-01-15T10:30:45.123Z") as String
        assertEquals("2024-01-15T10:30:45.123Z", result)
    }

    // ==================== buildUrl Tests ====================

    @Test
    fun `buildUrl constructs correct URL`() {
        val result = buildUrl.invoke(WeatherFetcher, 52.52, 13.405) as String

        assertTrue(result.contains("api.open-meteo.com"))
        assertTrue(result.contains("latitude=52.52"))
        assertTrue(result.contains("longitude=13.405"))
        assertTrue(result.contains("hourly=temperature_2m,precipitation,cloud_cover"))
        assertTrue(result.contains("timezone=UTC"))
        assertTrue(result.contains("past_hours=6"))
        assertTrue(result.contains("forecast_days=2"))
    }

    @Test
    fun `buildUrl handles negative coordinates`() {
        val result = buildUrl.invoke(WeatherFetcher, -33.87, -151.21) as String

        assertTrue(result.contains("latitude=-33.87"))
        assertTrue(result.contains("longitude=-151.21"))
    }

    // ==================== transformApiResponse Tests ====================

    @Test
    fun `transformApiResponse creates correct structure`() {
        val apiJson = createMockApiResponse()
        val result = transformApiResponse.invoke(WeatherFetcher, apiJson) as JSONObject?

        assertNotNull(result)
        assertTrue(result!!.has("timezone"))
        assertTrue(result.has("latitude"))
        assertTrue(result.has("longitude"))
        assertTrue(result.has("fetchedAt"))
        assertTrue(result.has("hourly"))

        val hourly = result.getJSONObject("hourly")
        assertTrue(hourly.has("time"))
        assertTrue(hourly.has("temperature_2m"))
        assertTrue(hourly.has("precipitation"))
        assertTrue(hourly.has("cloud_cover"))
    }

    @Test
    fun `transformApiResponse normalizes timestamps`() {
        val apiJson = createMockApiResponse()
        val result = transformApiResponse.invoke(WeatherFetcher, apiJson) as JSONObject?

        assertNotNull(result)
        val times = result!!.getJSONObject("hourly").getJSONArray("time")

        // All times should end with Z
        for (i in 0 until times.length()) {
            val time = times.getString(i)
            assertTrue("Time should end with Z: $time", time.endsWith("Z"))
        }
    }

    @Test
    fun `transformApiResponse preserves data values`() {
        val apiJson = createMockApiResponse()
        val result = transformApiResponse.invoke(WeatherFetcher, apiJson) as JSONObject?

        assertNotNull(result)
        assertEquals(52.52, result!!.getDouble("latitude"), 0.01)
        assertEquals(13.405, result.getDouble("longitude"), 0.01)

        val hourly = result.getJSONObject("hourly")
        assertEquals(15.5, hourly.getJSONArray("temperature_2m").getDouble(0), 0.01)
        // Index 0: i % 3 == 0 is true, so precipitation is 1.0
        assertEquals(1.0, hourly.getJSONArray("precipitation").getDouble(0), 0.01)
        assertEquals(50, hourly.getJSONArray("cloud_cover").getInt(0))
    }

    @Test
    fun `transformApiResponse returns null for malformed JSON`() {
        val malformed = JSONObject().apply {
            put("invalid", "data")
        }

        val result = transformApiResponse.invoke(WeatherFetcher, malformed) as JSONObject?
        assertNull(result)
    }

    // ==================== extractCurrentTemperature Tests ====================

    @Test
    fun `extractCurrentTemperature returns temperature from data`() {
        val cachedJson = createMockCachedResponse()
        val result = extractCurrentTemperature.invoke(WeatherFetcher, cachedJson) as Double?

        assertNotNull(result)
        // Should find a temperature value from the mock data
        assertTrue(result!! >= 15.5 && result <= 20.5)
    }

    @Test
    fun `extractCurrentTemperature returns null for empty hourly data`() {
        val cachedJson = JSONObject().apply {
            put("hourly", JSONObject().apply {
                put("time", JSONArray())
                put("temperature_2m", JSONArray())
            })
        }

        val result = extractCurrentTemperature.invoke(WeatherFetcher, cachedJson) as Double?
        assertNull(result)
    }

    @Test
    fun `extractCurrentTemperature handles malformed JSON`() {
        val malformed = JSONObject().apply {
            put("invalid", "data")
        }

        val result = extractCurrentTemperature.invoke(WeatherFetcher, malformed) as Double?
        assertNull(result)
    }

    // ==================== fetchAndUpdateSync Tests ====================

    @Test
    fun `fetchAndUpdateSync returns early without cached location`() {
        // No location cached - should return without crashing
        prefs.edit().clear().commit()

        // This will log "No cached location available" and return
        // We can't easily verify the return since it's void, but it shouldn't crash
        try {
            WeatherFetcher.fetchAndUpdateSync(context)
        } catch (e: Exception) {
            fail("Should not throw: ${e.message}")
        }
    }

    @Test
    fun `fetchAndUpdateSync returns early with zero coordinates`() {
        // 0,0 location is treated as "no location"
        prefs.edit()
            .putFloat("cached_latitude", 0f)
            .putFloat("cached_longitude", 0f)
            .commit()

        try {
            WeatherFetcher.fetchAndUpdateSync(context)
        } catch (e: Exception) {
            fail("Should not throw: ${e.message}")
        }
    }

    // ==================== Helper Methods ====================

    private fun createMockApiResponse(): JSONObject {
        return JSONObject().apply {
            put("timezone", "UTC")
            put("latitude", 52.52)
            put("longitude", 13.405)
            put("hourly", JSONObject().apply {
                put("time", JSONArray().apply {
                    for (i in 0 until 10) {
                        put("2024-01-15T${String.format("%02d", i)}:00")
                    }
                })
                put("temperature_2m", JSONArray().apply {
                    for (i in 0 until 10) {
                        put(15.5 + i * 0.5)
                    }
                })
                put("precipitation", JSONArray().apply {
                    for (i in 0 until 10) {
                        put(if (i % 3 == 0) 1.0 else 0.0)
                    }
                })
                put("cloud_cover", JSONArray().apply {
                    for (i in 0 until 10) {
                        put(50 + i * 5)
                    }
                })
            })
        }
    }

    private fun createMockCachedResponse(): JSONObject {
        return JSONObject().apply {
            put("timezone", "UTC")
            put("latitude", 52.52)
            put("longitude", 13.405)
            put("fetchedAt", "2024-01-15T10:00:00.000Z")
            put("hourly", JSONObject().apply {
                put("time", JSONArray().apply {
                    for (i in 0 until 10) {
                        put("2024-01-15T${String.format("%02d", i)}:00:00.000Z")
                    }
                })
                put("temperature_2m", JSONArray().apply {
                    for (i in 0 until 10) {
                        put(15.5 + i * 0.5)
                    }
                })
                put("precipitation", JSONArray().apply {
                    for (i in 0 until 10) {
                        put(if (i % 3 == 0) 1.0 else 0.0)
                    }
                })
                put("cloud_cover", JSONArray().apply {
                    for (i in 0 until 10) {
                        put(50 + i * 5)
                    }
                })
            })
        }
    }
}
