package org.bortnik.meteogram

import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.provider.Settings
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

    private val LOCATION_PERMISSION_REQUEST_CODE = 4001
    /** Held while a runtime location-permission request is in flight; resolved in onRequestPermissionsResult. */
    private var pendingPermissionResult: MethodChannel.Result? = null

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
                    val mode = call.argument<String>("mode") ?: "hourly"

                    if (width <= 0 || height <= 0) {
                        result.error("INVALID_ARGS", "Invalid dimensions: ${width}x${height}", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val svgString = generateSvgFromCache(width, height, isLight, usesFahrenheit, mode)
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
                            val fetchResult = WeatherFetcher.fetchWeatherSync(this, latitude, longitude)
                            runOnUiThread {
                                if (fetchResult.success) {
                                    result.success(true)
                                } else {
                                    result.error(
                                        "FETCH_FAILED",
                                        fetchResult.error ?: "Failed to fetch weather data",
                                        null,
                                    )
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
                "reverseGeocode" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")

                    if (latitude == null || longitude == null) {
                        result.error("INVALID_ARGS", "Missing latitude or longitude", null)
                        return@setMethodCallHandler
                    }

                    // Geocoder can block (network); resolve off the main thread and
                    // marshal the result back. callback runs at most once.
                    Thread {
                        ReverseGeocoder.cityFromCoordinates(this, latitude, longitude) { city ->
                            runOnUiThread { result.success(city) }
                        }
                    }.start()
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("INVALID_ARGS", "Missing url", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening URL", e)
                        result.error("OPEN_URL_ERROR", e.message, null)
                    }
                }
                "saveWidgetData" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGS", "saveWidgetData requires 'id'", null)
                        return@setMethodCallHandler
                    }
                    // Replicates the home_widget plugin's SharedPreferences codec so data
                    // written by earlier (home_widget-backed) installs stays readable: every
                    // key gets a companion "home_widget.double.<id>" flag, and doubles are
                    // stored as raw Long bits. See WidgetStore on the Dart side.
                    val editor = getSharedPreferences(WidgetUtils.PREFS_NAME, MODE_PRIVATE).edit()
                    val data = call.argument<Any>("data")
                    if (data != null) {
                        editor.putBoolean("home_widget.double.$id", data is Double)
                        when (data) {
                            is Boolean -> editor.putBoolean(id, data)
                            is Float -> editor.putFloat(id, data)
                            is String -> editor.putString(id, data)
                            is Double -> editor.putLong(id, java.lang.Double.doubleToRawLongBits(data))
                            is Int -> editor.putInt(id, data)
                            is Long -> editor.putLong(id, data)
                            else -> {
                                result.error("INVALID_TYPE", "Unsupported type ${data::class.java.simpleName}", null)
                                return@setMethodCallHandler
                            }
                        }
                    } else {
                        editor.remove(id)
                        editor.remove("home_widget.double.$id")
                    }
                    result.success(editor.commit())
                }
                "getWidgetData" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGS", "getWidgetData requires 'id'", null)
                        return@setMethodCallHandler
                    }
                    val prefs = getSharedPreferences(WidgetUtils.PREFS_NAME, MODE_PRIVATE)
                    val value = prefs.all[id]
                    if (value is Long && prefs.getBoolean("home_widget.double.$id", false)) {
                        result.success(java.lang.Double.longBitsToDouble(value))
                    } else {
                        result.success(value)
                    }
                }
                "updateWidget" -> {
                    val className = call.argument<String>("name") ?: call.argument<String>("android")
                    if (className == null) {
                        result.error("INVALID_ARGS", "updateWidget requires 'name'", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val javaClass = Class.forName("$packageName.$className")
                        val intent = Intent(this, javaClass).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        }
                        val ids = AppWidgetManager.getInstance(applicationContext)
                            .getAppWidgetIds(ComponentName(this, javaClass))
                        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        sendBroadcast(intent)
                        result.success(true)
                    } catch (e: ClassNotFoundException) {
                        result.error("NO_WIDGET", "No widget provider named $className", e)
                    }
                }
                "isLocationServiceEnabled" -> {
                    result.success(LocationProvider.isLocationServiceEnabled(this))
                }
                "checkLocationPermission" -> {
                    result.success(LocationProvider.checkPermissionStatus(this))
                }
                "requestLocationPermission" -> {
                    if (LocationProvider.checkPermissionStatus(this) == "granted") {
                        result.success("granted")
                        return@setMethodCallHandler
                    }
                    if (pendingPermissionResult != null) {
                        result.error("PERMISSION_IN_PROGRESS", "A location permission request is already in progress", null)
                        return@setMethodCallHandler
                    }
                    pendingPermissionResult = result
                    requestPermissions(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        ),
                        LOCATION_PERMISSION_REQUEST_CODE
                    )
                }
                "getCurrentPosition" -> {
                    val timeoutMs = (call.argument<Int>("timeoutMs") ?: 15000).toLong()
                    // LocationProvider always invokes its callback on the main thread.
                    LocationProvider.getCurrentPosition(this, timeoutMs) { coords ->
                        result.success(coords?.let { mapOf("latitude" to it[0], "longitude" to it[1]) })
                    }
                }
                "getLastKnownPosition" -> {
                    val coords = LocationProvider.getLastKnownPosition(this)
                    result.success(coords?.let { mapOf("latitude" to it[0], "longitude" to it[1]) })
                }
                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening location settings", e)
                        result.error("OPEN_SETTINGS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_PERMISSION_REQUEST_CODE) return

        val pending = pendingPermissionResult
        pendingPermissionResult = null
        if (pending == null) return

        val granted = grantResults.isNotEmpty() &&
            grantResults.any { it == PackageManager.PERMISSION_GRANTED }
        val status = when {
            granted -> "granted"
            // Not granted and no rationale allowed → user chose "don't ask again" (or it's policy-blocked).
            !shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION) -> "deniedForever"
            else -> "denied"
        }
        pending.success(status)
    }

    /**
     * Generate SVG string from cached weather data.
     * Also updates current_temperature_celsius in SharedPreferences to match nowIndex.
     */
    private fun generateSvgFromCache(
        width: Int,
        height: Int,
        isLight: Boolean,
        usesFahrenheit: Boolean,
        mode: String
    ): String? {
        val weatherData = WeatherDataParser.parseFromPrefs(this)
        if (weatherData == null) {
            Log.d(TAG, "No cached weather data for SVG generation")
            return null
        }

        val weekly = mode == "weekly"
        val view = if (weekly) weatherData.getWeeklyView() else weatherData.getHourlyView()

        // Only the hourly view drives "current temperature" — the weekly view
        // shares the same cache timestamp but shouldn't overwrite the reading.
        if (!weekly) {
            val currentTemp = weatherData.getCurrentTemperature()
            if (currentTemp != null) {
                getSharedPreferences(WidgetUtils.PREFS_NAME, MODE_PRIVATE)
                    .edit()
                    .putString("current_temperature_celsius", currentTemp.toString())
                    .apply()
            }
        }

        val colors = WidgetChartColors.get(this, isLight)

        val generator = SvgChartGenerator()
        return generator.generate(
            data = view.data,
            nowIndex = view.nowIndex,
            latitude = weatherData.latitude,
            longitude = weatherData.longitude,
            colors = colors,
            width = width.toDouble(),
            height = height.toDouble(),
            locale = Locale.getDefault(),
            usesFahrenheit = usesFahrenheit,
            use24HourFormat = DateFormat.is24HourFormat(this),
            labelStepHours = if (weekly) 24 else 12,
            labelFormat = if (weekly) TimeLabelFormat.WEEKDAY else TimeLabelFormat.HOUR
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
