package org.bortnik.meteogram

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.text.format.DateFormat
import android.util.Log
import com.caverock.androidsvg.SVG
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.bortnik.meteogram/svg"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Extract Material You colors BEFORE Flutter engine starts
        // This ensures colors are in storage when Flutter's main() reads them
        MaterialYouColorExtractor.updateColorsIfChanged(this)

        super.configureFlutterEngine(flutterEngine)

        // Register PlatformView for native SVG chart rendering
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "svg_chart_view",
            SvgChartViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateSvg" -> {
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    val isLight = call.argument<Boolean>("isLight") ?: true
                    val usesFahrenheit = call.argument<Boolean>("usesFahrenheit") ?: false

                    if (width <= 0 || height <= 0) {
                        result.error("INVALID_ARGS", "Invalid dimensions: ${width}x${height}", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val svgString = generateSvgFromCache(width, height, isLight, usesFahrenheit)
                        if (svgString != null) {
                            result.success(svgString)
                        } else {
                            result.error("NO_DATA", "No weather data available", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error generating SVG", e)
                        result.error("GENERATE_ERROR", e.message, null)
                    }
                }
                "renderSvg" -> {
                    val svgString = call.argument<String>("svg")
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0

                    if (svgString == null || width <= 0 || height <= 0) {
                        result.error("INVALID_ARGS", "Invalid arguments", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val pngBytes = renderSvgToPng(svgString, width, height)
                        result.success(pngBytes)
                    } catch (e: Exception) {
                        result.error("RENDER_ERROR", e.message, null)
                    }
                }
                "fetchWeather" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")

                    if (latitude == null || longitude == null) {
                        result.error("INVALID_ARGS", "Missing latitude or longitude", null)
                        return@setMethodCallHandler
                    }

                    // Run on background thread
                    Thread {
                        try {
                            val success = WeatherFetcher.fetchWeatherSync(this, latitude, longitude)
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("FETCH_FAILED", "Failed to fetch weather data", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error fetching weather", e)
                            runOnUiThread {
                                result.error("FETCH_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Generate SVG string from cached weather data.
     */
    private fun generateSvgFromCache(
        width: Int,
        height: Int,
        isLight: Boolean,
        usesFahrenheit: Boolean
    ): String? {
        val weatherData = WeatherDataParser.parseFromPrefs(this)
        if (weatherData == null) {
            Log.d(TAG, "No cached weather data for SVG generation")
            return null
        }

        val displayData = weatherData.getDisplayRange()
        val nowIndex = weatherData.getNowIndex()

        // Get colors with Material You support
        val colors = getChartColors(isLight)

        val generator = SvgChartGenerator()
        return generator.generate(
            data = displayData,
            nowIndex = nowIndex,
            latitude = weatherData.latitude,
            longitude = weatherData.longitude,
            colors = colors,
            width = width.toDouble(),
            height = height.toDouble(),
            locale = Locale.getDefault(),
            usesFahrenheit = usesFahrenheit,
            use24HourFormat = DateFormat.is24HourFormat(this)
        )
    }

    /**
     * Get chart colors with Material You support.
     */
    private fun getChartColors(isLight: Boolean): SvgChartColors {
        val baseColors = if (isLight) SvgChartColors.light else SvgChartColors.dark

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return baseColors
        }

        val prefs = getSharedPreferences(WidgetUtils.PREFS_NAME, MODE_PRIVATE)

        val tempColorKey = if (isLight) "material_you_light_on_primary_container" else "material_you_dark_primary"
        val timeColorKey = if (isLight) "material_you_light_tertiary" else "material_you_dark_tertiary"

        val tempColor = prefs.getInt(tempColorKey, 0)
        val timeColor = prefs.getInt(timeColorKey, 0)

        if (tempColor == 0 || timeColor == 0) {
            return baseColors
        }

        return baseColors.withDynamicColors(
            temperatureLine = SvgColor.fromArgb(tempColor),
            timeLabel = SvgColor.fromArgb(timeColor)
        )
    }

    private fun renderSvgToPng(svgString: String, width: Int, height: Int): ByteArray {
        val svg = SVG.getFromInputStream(ByteArrayInputStream(svgString.toByteArray()))
        svg.documentWidth = width.toFloat()
        svg.documentHeight = height.toFloat()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        svg.renderToCanvas(canvas)

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        bitmap.recycle()

        return outputStream.toByteArray()
    }
}
