package com.pipgarden.pip_garden

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android's half of the one live-session port.
 *
 * Answers the same three methods iOS's `LiveSessionSurfacePlugin` answers, on
 * the same channel, against the same map — and turns them into a foreground
 * service where iOS turns them into an ActivityKit activity. Nothing above this
 * line knows which of those two it is talking to; that is the whole of what
 * "Dart code talks to one port" buys.
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
     * Whether the app was launched by a tap on the surface, and Dart has not
     * been told yet.
     *
     * The tap happens before there is any Dart alive to hear it, so it waits
     * here until the first thing that listens asks for it. Consumed on reading:
     * a launch tap opens the timer once, not on every later resume.
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
            // A long, because it is milliseconds since the epoch: the same
            // units `Notification.when` is in, which is what lets the system
            // count down to it without anything of ours running. Read as a
            // `Number` because the standard codec hands an integer across as
            // whichever of Integer and Long it fits in, and which one that is
            // is not something this should depend on.
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

        // From Android 12 a foreground service may not be *started* from the
        // background, and this app can reach here from it: Dart timers go on
        // running behind a backgrounded Android app, so the push that says the
        // plant has reached its next stage can arrive with nobody looking. That
        // push is almost always an update to a service that is already running,
        // which is allowed — but if the service was killed in between, it is a
        // start, and the platform throws.
        //
        // Reported rather than swallowed, and rather than crashed on: the port
        // is best-effort by contract, and what has been lost is a picture. The
        // session is anchored to the wall clock and is completed and announced
        // by things that never look at any of this.
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
     * An [Intent] the activity was launched or resumed with. Returns whether it
     * was a tap on the surface.
     *
     * Called from both directions the platform delivers one: `onCreate`, where
     * the app is starting because of the tap, and `onNewIntent`, where it is
     * already running.
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
