package com.pipgarden.pip_garden

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Live session channel on Android. Same methods and map as the iOS plugin, but
 * backed by [LiveSessionService] instead of ActivityKit.
 */
class LiveSessionSurfacePlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "pip_garden/live_session"

        private const val METHOD_SHOW = "show"
        private const val METHOD_HIDE = "hide"
        private const val METHOD_TAKE_LAUNCH_TAP = "takeLaunchTap"
        private const val METHOD_OPENED = "opened"
    }

    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler(this)
    }

    /**
     * Set when a surface tap launched the app before Dart was running. Cleared
     * once read.
     */
    private var launchTapPending = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_SHOW -> show(call, result)

            METHOD_HIDE -> {
                context.stopService(LiveSessionService.stopping(context))
                result.success(null)
            }

            METHOD_TAKE_LAUNCH_TAP -> {
                result.success(launchTapPending)
                launchTapPending = false
            }

            else -> result.notImplemented()
        }
    }

    private fun show(call: MethodCall, result: MethodChannel.Result) {
        val intent = LiveSessionService.showing(context) {
            putExtra(LiveSessionService.EXTRA_PAUSED, call.argument<Boolean>("paused") ?: false)
            // Epoch millis, same units as `Notification.when`. `Number`
            // because the codec sends Integer or Long depending on size.
            putExtra(
                LiveSessionService.EXTRA_ENDS_AT,
                call.argument<Number>("endsAt")?.toLong() ?: 0L,
            )
            putExtra(
                LiveSessionService.EXTRA_REMAINING_SECONDS,
                call.argument<Number>("remainingSeconds")?.toInt() ?: 0,
            )
            putExtra(
                LiveSessionService.EXTRA_PROGRESS,
                call.argument<Number>("progress")?.toDouble() ?: 0.0,
            )
            putExtra(
                LiveSessionService.EXTRA_STAGE_LABEL,
                call.argument<String>("stageLabel").orEmpty(),
            )
            putExtra(
                LiveSessionService.EXTRA_SPECIES_LABEL,
                call.argument<String>("speciesLabel").orEmpty(),
            )
        }

        // Android 12+ throws if a foreground service is started from the
        // background, which happens if the service was killed and a Dart timer
        // pushes an update. Reported, not crashed on: the surface is
        // best-effort and the session itself doesn't depend on it.
        try {
            ContextCompat.startForegroundService(context, intent)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "live_surface_unavailable",
                "The live session surface could not be started: ${error.message}",
                null,
            )
        }
    }

    /**
     * Called from `configureFlutterEngine` and `onNewIntent`. Returns whether
     * [intent] was a surface tap.
     */
    fun handle(intent: Intent?, alreadyRunning: Boolean): Boolean {
        if (intent?.action != MainActivity.ACTION_OPEN_SESSION) return false

        if (alreadyRunning) {
            channel.invokeMethod(METHOD_OPENED, null)
        } else {
            launchTapPending = true
        }
        return true
    }
}
