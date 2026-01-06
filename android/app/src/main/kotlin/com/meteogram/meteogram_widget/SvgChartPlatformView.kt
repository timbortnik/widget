package com.meteogram.meteogram_widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import com.caverock.androidsvg.SVG
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayInputStream

class SvgChartPlatformView(
    context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    creationParams: Map<String, Any?>?
) : PlatformView {

    private var pendingSvg: String? = null
    private var currentBitmap: Bitmap? = null

    private val imageView = ImageView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        scaleType = ImageView.ScaleType.FIT_XY
    }

    private val methodChannel = MethodChannel(
        messenger,
        "com.meteogram.svg_chart_view_$viewId"
    )

    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "renderSvg" -> {
                    val svg = call.argument<String>("svg")
                    if (svg != null) {
                        pendingSvg = svg
                        renderAtViewSize()
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "SVG string required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Store SVG for rendering once view is laid out
        creationParams?.let {
            pendingSvg = it["svg"] as? String
        }

        // Render when view is laid out and we know actual size
        imageView.viewTreeObserver.addOnGlobalLayoutListener {
            renderAtViewSize()
        }
    }

    private fun renderAtViewSize() {
        val svg = pendingSvg ?: return
        val width = imageView.width
        val height = imageView.height

        if (width <= 0 || height <= 0) return

        android.util.Log.d("SvgChartView", "Rendering at actual view size: ${width}x${height}px")

        try {
            val parsedSvg = SVG.getFromInputStream(ByteArrayInputStream(svg.toByteArray()))
            parsedSvg.documentWidth = width.toFloat()
            parsedSvg.documentHeight = height.toFloat()

            currentBitmap?.recycle()

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            parsedSvg.renderToCanvas(canvas)

            currentBitmap = bitmap
            imageView.setImageBitmap(bitmap)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun getView(): View = imageView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        currentBitmap?.recycle()
        currentBitmap = null
    }
}
