package com.pipgarden.pip_garden

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by the alarm `QuietModeRule.begin` sets, so quiet mode still ends if
 * the system killed the app mid-session. Just switches the rule off; a session
 * that's still running means the app is alive and will re-silence on its next
 * sync.
 */
class QuietModeReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_END = "com.pipgarden.pip_garden.END_QUIET_MODE"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_END) return

        // Idempotent: the app may already have ended the session itself.
        QuietModeRule(context.applicationContext).end()
    }
}
