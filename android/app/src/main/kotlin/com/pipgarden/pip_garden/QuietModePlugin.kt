package com.pipgarden.pip_garden

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android's half of the one quiet-mode port.
 *
 * Answers the same channel iOS's `QuietModePlugin.swift` answers, and gives a
 * different answer to the first question on it — this platform *can* silence
 * itself, so it says so, and then does. Everything that follows from that
 * difference is decided in one place: the settings screen offers a switch where
 * the capability is real and the Shortcuts recipe where it is not. No Dart
 * anywhere asks which phone it is running on.
 *
 * The work itself is [QuietModeRule]'s. What is left here is turning four
 * method calls into it, and the reason that split exists is
 * `QuietModeReceiver`: the deadline that keeps quiet mode from outliving its
 * session has to run with no Flutter engine anywhere near it.
 */
class QuietModePlugin(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "pip_garden/quiet_mode"

        private const val METHOD_ACCESS = "access"
        private const val METHOD_REQUEST_ACCESS = "requestAccess"
        private const val METHOD_BEGIN = "begin"
        private const val METHOD_END = "end"

        /**
         * Answered but never true here: the App Intent behind it is iOS's
         * answer to REQ-014, and this platform has no need of one because it
         * can silence itself. Answered anyway, so that the one port has one
         * shape on both sides and Dart has nothing to special-case.
         */
        private const val METHOD_TAKE_LAUNCH_REQUEST = "takeLaunchRequest"

        private const val ARGUMENT_UNTIL = "until"

        /** [QuietModeAccess] in Dart, by name. */
        private const val ACCESS_UNAVAILABLE = "unavailable"
        private const val ACCESS_DENIED = "denied"
        private const val ACCESS_GRANTED = "granted"
    }

    private val rule = QuietModeRule(context)

    init {
        // Not held onto, unlike `LiveSessionSurfacePlugin`'s: nothing on this
        // platform ever calls *into* Dart on this channel. What would — the App
        // Intent — is iOS's answer to a question Android answers by silencing
        // itself.
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_ACCESS -> result.success(
                when {
                    // Not "denied": there is nothing here for the user to
                    // grant, and a settings screen that sent them looking for a
                    // permission that would change nothing would be worse than
                    // one that says this phone cannot do it.
                    !rule.isSupported() -> ACCESS_UNAVAILABLE
                    rule.isGranted() -> ACCESS_GRANTED
                    else -> ACCESS_DENIED
                }
            )

            METHOD_REQUEST_ACCESS -> {
                rule.openAccessSettings()
                result.success(null)
            }

            METHOD_BEGIN -> {
                // Read as a `Number` because the standard codec hands an
                // integer across as whichever of Integer and Long it fits in,
                // and milliseconds since the epoch is not something to let that
                // decide. Missing is treated as already due, which the rule
                // turns into a silence that lifts a minute from now — the safe
                // way for this to be wrong.
                rule.begin(call.argument<Number>(ARGUMENT_UNTIL)?.toLong() ?: 0L)
                result.success(null)
            }

            METHOD_END -> {
                rule.end()
                result.success(null)
            }

            METHOD_TAKE_LAUNCH_REQUEST -> result.success(false)

            else -> result.notImplemented()
        }
    }
}
