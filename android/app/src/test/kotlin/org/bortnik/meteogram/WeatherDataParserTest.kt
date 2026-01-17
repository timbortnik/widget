package org.bortnik.meteogram

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for WeatherDataParser using Robolectric to mock Android JSON classes.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WeatherDataParserTest {

    @Test
    fun `parseJson parses valid weather JSON`() {
        val json = """
        {
            "timezone": "UTC",
            "latitude": 52.52,
            "longitude": 13.405,
            "fetchedAt": "2024-01-15T12:00:00.000Z",
            "hourly": {
                "time": [
                    "2024-01-15T06:00:00.000Z",
                    "2024-01-15T07:00:00.000Z",
                    "2024-01-15T08:00:00.000Z"
                ],
                "temperature_2m": [5.0, 6.5, 8.0],
                "precipitation": [0.0, 0.5, 1.0],
                "cloud_cover": [20, 50, 80]
            }
        }
        """.trimIndent()

        val result = WeatherDataParser.parseJson(json)

        assertEquals("UTC", result.timezone)
        assertEquals(52.52, result.latitude, 0.001)
        assertEquals(13.405, result.longitude, 0.001)
        assertEquals(3, result.hourly.size)

        // Check first hourly entry
        assertEquals(5.0, result.hourly[0].temperature, 0.001)
        assertEquals(0.0, result.hourly[0].precipitation, 0.001)
        assertEquals(20, result.hourly[0].cloudCover)

        // Check last hourly entry
        assertEquals(8.0, result.hourly[2].temperature, 0.001)
        assertEquals(1.0, result.hourly[2].precipitation, 0.001)
        assertEquals(80, result.hourly[2].cloudCover)
    }

    @Test
    fun `parseJson handles timestamps without milliseconds`() {
        val json = """
        {
            "timezone": "UTC",
            "latitude": 0.0,
            "longitude": 0.0,
            "fetchedAt": "2024-01-15T12:00:00Z",
            "hourly": {
                "time": ["2024-01-15T06:00:00Z"],
                "temperature_2m": [10.0],
                "precipitation": [0.0],
                "cloud_cover": [0]
            }
        }
        """.trimIndent()

        val result = WeatherDataParser.parseJson(json)

        assertEquals(1, result.hourly.size)
        assertEquals(10.0, result.hourly[0].temperature, 0.001)
    }

    @Test
    fun `parseJson handles timestamps with short format`() {
        val json = """
        {
            "timezone": "UTC",
            "latitude": 0.0,
            "longitude": 0.0,
            "fetchedAt": "2024-01-15T12:00Z",
            "hourly": {
                "time": ["2024-01-15T06:00Z"],
                "temperature_2m": [10.0],
                "precipitation": [0.0],
                "cloud_cover": [0]
            }
        }
        """.trimIndent()

        val result = WeatherDataParser.parseJson(json)

        assertEquals(1, result.hourly.size)
    }

    @Test
    fun `parseJson handles missing optional precipitation values`() {
        val json = """
        {
            "timezone": "UTC",
            "latitude": 0.0,
            "longitude": 0.0,
            "fetchedAt": "2024-01-15T12:00:00.000Z",
            "hourly": {
                "time": ["2024-01-15T06:00:00.000Z"],
                "temperature_2m": [10.0],
                "precipitation": [null],
                "cloud_cover": [null]
            }
        }
        """.trimIndent()

        val result = WeatherDataParser.parseJson(json)

        assertEquals(1, result.hourly.size)
        assertEquals(0.0, result.hourly[0].precipitation, 0.001)
        assertEquals(0, result.hourly[0].cloudCover)
    }

    @Test
    fun `parseJson handles arrays of different lengths`() {
        val json = """
        {
            "timezone": "UTC",
            "latitude": 0.0,
            "longitude": 0.0,
            "fetchedAt": "2024-01-15T12:00:00.000Z",
            "hourly": {
                "time": ["2024-01-15T06:00:00.000Z", "2024-01-15T07:00:00.000Z", "2024-01-15T08:00:00.000Z"],
                "temperature_2m": [10.0, 11.0],
                "precipitation": [0.0],
                "cloud_cover": [0, 10, 20, 30]
            }
        }
        """.trimIndent()

        val result = WeatherDataParser.parseJson(json)

        // Should use minimum length (1 from precipitation)
        assertEquals(1, result.hourly.size)
    }

    @Test(expected = Exception::class)
    fun `parseJson throws on invalid JSON`() {
        WeatherDataParser.parseJson("not valid json")
    }

    @Test(expected = Exception::class)
    fun `parseJson throws on missing required fields`() {
        val json = """
        {
            "timezone": "UTC"
        }
        """.trimIndent()

        WeatherDataParser.parseJson(json)
    }
}
