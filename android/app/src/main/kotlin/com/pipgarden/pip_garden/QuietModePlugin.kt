package com.pipgarden.pip_garden

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Quiet mode channel on Android; same channel as `QuietModePlugin.swift`, but
 * Android can actually silence itself. The work lives in [QuietModeRule] so
 * `QuietModeReceiver` can use it without a Flutter engine.
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

        /** Always false here; only iOS launches via an App Intent. */
        private const val METHOD_TAKE_LAUNCH_REQUEST = "takeLaunchRequest"

        private const val ARGUMENT_UNTIL = "until"

        /** [QuietModeAccess] in Dart, by name. */
        private const val ACCESS_UNAVAILABLE = "unavailable"
        private const val ACCESS_DENIED = "denied"
        private const val ACCESS_GRANTED = "granted"
    }

    private val rule = QuietModeRule(context)

    init {
        // Not kept: nothing on Android calls into Dart on this channel.
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_ACCESS -> result.success(
                when {
                    // Not "denied": there's nothing the user could grant.
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
                // `Number`: the codec sends Integer or Long depending on size.
                // Missing means already due, so the silence lifts in a minute.
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
