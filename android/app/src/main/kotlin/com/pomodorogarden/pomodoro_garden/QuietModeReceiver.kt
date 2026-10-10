package com.pomodorogarden.pomodoro_garden

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The deadline on quiet mode, kept with none of this app running.
 *
 * **This is the whole answer to "what if the app never comes back".** The
 * ordinary way quiet mode ends is the app ending it: a session completes, is
 * cancelled, or is voided by a force-quit, and `QuietModeKeeper` switches the
 * rule off. Every one of those needs a live process. A process the system kills
 * to reclaim memory gets no warning and no last call — so `QuietModeRule.begin`
 * sets an alarm for the instant the session is due, and this is what that alarm
 * wakes.
 *
 * It is a receiver rather than anything larger because it has one thing to do
 * and a few milliseconds in which to do it: switch the rule off. There is no
 * session to consult — a session that is still running belongs to an app that is
 * still alive, and that app will silence the phone again at its next sync.
 */
class QuietModeReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_END = "com.pomodorogarden.pomodoro_garden.END_QUIET_MODE"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_END) return

        // Idempotent, and it has to be: this fires for a session the app may
        // well have ended itself a minute ago.
        QuietModeRule(context.applicationContext).end()
    }
}
