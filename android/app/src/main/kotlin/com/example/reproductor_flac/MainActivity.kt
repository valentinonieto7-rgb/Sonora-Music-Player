package com.example.reproductor_flac

import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setRefreshRate" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.error(
                                "UNSUPPORTED_ANDROID_VERSION",
                                "Refresh rate selection requires Android 6 or later.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val requestedRate = call.arguments as? Double
                        if (requestedRate == null) {
                            result.error(
                                "INVALID_REFRESH_RATE",
                                "A numeric refresh rate is required.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val attributes = window.attributes
                        if (requestedRate <= 0.0) {
                            attributes.preferredDisplayModeId = 0
                            attributes.preferredRefreshRate = 0f
                            window.attributes = attributes
                            result.success(0.0)
                            return@setMethodCallHandler
                        }

                        @Suppress("DEPRECATION")
                        val modes = windowManager.defaultDisplay.supportedModes
                        val mode = modes.minByOrNull {
                            abs(it.refreshRate - requestedRate.toFloat())
                        }
                        if (mode == null ||
                            abs(mode.refreshRate - requestedRate.toFloat()) > 1f
                        ) {
                            result.error(
                                "UNSUPPORTED_REFRESH_RATE",
                                "The display does not support ${requestedRate.toInt()} Hz.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        attributes.preferredDisplayModeId = mode.modeId
                        attributes.preferredRefreshRate = mode.refreshRate
                        window.attributes = attributes
                        result.success(mode.refreshRate.toDouble())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val DISPLAY_CHANNEL = "com.example.reproductor_flac/display"
    }
}
