package org.bortnik.meteogram

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import com.caverock.androidsvg.SVG
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayInputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Platform view for rendering SVG charts.
 * SVG rendering is performed on a background thread to avoid blocking the UI.
 */
class SvgChartPlatformView(
    context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    creationParams: Map<String, Any?>?
) : PlatformView {

    companion object {
        private const val TAG = "SvgChartView"
        // Shared executor for all instances to limit thread creation
        private val renderExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    }

    private var pendingSvg: String? = null
    private var lastRenderedSvg: String? = null
    private var currentBitmap: Bitmap? = null
    private val isRendering = AtomicBoolean(false)

    private val imageView = ImageView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        scaleType = ImageView.ScaleType.FIT_XY
    }

    private val methodChannel = MethodChannel(
        messenger,
        "org.bortnik.svg_chart_view_$viewId"
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

        // Skip if already rendering - will re-check after current render completes
        if (!isRendering.compareAndSet(false, true)) {
            Log.d(TAG, "Render in progress - will check for updates after completion")
            return
        }

        // Track what we're rendering to detect changes during render
        val svgToRender = svg
        Log.d(TAG, "Rendering at actual view size: ${width}x${height}px")

        // Render on background thread to avoid blocking UI
        renderExecutor.execute {
            var bitmap: Bitmap? = null
            try {
                val parsedSvg = SVG.getFromInputStream(ByteArrayInputStream(svgToRender.toByteArray()))
                parsedSvg.documentWidth = width.toFloat()
                parsedSvg.documentHeight = height.toFloat()

                bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                parsedSvg.renderToCanvas(canvas)

                // Post result to main thread
                val finalBitmap = bitmap
                imageView.post {
                    // Recycle old bitmap on main thread (safer)
                    currentBitmap?.recycle()
                    currentBitmap = finalBitmap
                    imageView.setImageBitmap(finalBitmap)
                    lastRenderedSvg = svgToRender
                    isRendering.set(false)

                    // Check if SVG changed while we were rendering - if so, re-render
                    if (pendingSvg != null && pendingSvg != lastRenderedSvg) {
                        Log.d(TAG, "SVG changed during render - re-rendering")
                        renderAtViewSize()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error rendering SVG", e)
                bitmap?.recycle()
                isRendering.set(false)
            }
        }
    }

    override fun getView(): View = imageView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        currentBitmap?.recycle()
        currentBitmap = null
    }
}
