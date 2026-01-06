package com.meteogram.meteogram_widget

import android.graphics.Bitmap
import android.graphics.Canvas
import com.caverock.androidsvg.SVG
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.meteogram.meteogram_widget/svg"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> result.notImplemented()
            }
        }
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
