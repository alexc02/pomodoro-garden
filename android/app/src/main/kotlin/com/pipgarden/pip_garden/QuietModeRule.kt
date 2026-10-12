package com.pipgarden.pip_garden

import android.app.AlarmManager
import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.service.notification.Condition
import android.service.notification.ZenPolicy
import androidx.annotation.RequiresApi

/**
 * Quiet mode on Android: one app-owned `AutomaticZenRule`, on while a focus
 * session runs.
 *
 * - Never the global filter. From Android 15,
 *   [NotificationManager.setInterruptionFilter] gets silently redirected into
 *   an implicit rule the user never saw created. An explicit rule shows up in
 *   DND settings where the user can edit or delete it.
 * - Priority, not `INTERRUPTION_FILTER_NONE`: alarms and reminders get
 *   through, so the completion notice (posted as `CATEGORY_REMINDER` in
 *   `local_session_notifications.dart`) still arrives.
 * - Looked up by condition id, never a stored id, so it can't be duplicated.
 *   An existing rule is never rewritten since the user may have edited it.
 * - Android 10+ only: [NotificationManager.setAutomaticZenRuleState] arrived
 *   in 10. Older devices report unsupported.
 * - An alarm ends the rule even if the process dies. See [begin].
 */
class QuietModeRule(private val context: Context) {

    companion object {
        /** Shown in the user's Do Not Disturb settings. */
        const val RULE_NAME = "Pip Garden focus session"

        /**
         * Fixed, and the only way the rule is found again. A stored rule id
         * can get lost while the rule lives on, which leads to duplicates.
         */
        val CONDITION_ID: Uri = Uri.parse("pipgarden://quiet-mode/focus-session")

        /**
         * Failsafe fires this long after the session is due. Late on purpose:
         * early would swallow the completion notice.
         */
        private const val GRACE_MILLIS = 60_000L

        private const val REQUEST_CODE = 11
    }

    private val notifications: NotificationManager
        get() = context.getSystemService(NotificationManager::class.java)

    private val alarms: AlarmManager
        get() = context.getSystemService(AlarmManager::class.java)

    /**
     * Android 10+. The SDK check is repeated inline at each entry point below
     * because lint only recognises it written out.
     */
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /**
     * Notification policy access. Checked every time, never cached: the user
     * can revoke it in system settings while the app is backgrounded.
     */
    fun isGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return notifications.isNotificationPolicyAccessGranted
    }

    /**
     * Opens the system access screen. No runtime dialog exists for this, so
     * the caller should explain first.
     */
    fun openAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            // Application context has no task of its own.
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /**
     * Silences the phone until [end] is called or [untilMillis] at the latest.
     *
     * The app normally calls [end], but a process killed for memory can't, so
     * an alarm wakes [QuietModeReceiver] to switch the rule off. There's one
     * alarm; calling again (e.g. on resume) replaces it.
     */
    fun begin(untilMillis: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val id = ruleId() ?: return

        // Arm before silencing so there's never a window with no deadline.
        failsafe(PendingIntent.FLAG_UPDATE_CURRENT)?.let { deadline ->
            alarms.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                untilMillis + GRACE_MILLIS,
                deadline,
            )
        }
        notifications.setAutomaticZenRuleState(
            id,
            Condition(CONDITION_ID, "A focus session is running", Condition.STATE_TRUE),
        )
    }

    /**
     * Turns the rule off and cancels the failsafe. Safe if it's already off,
     * never registered, or access was revoked; runs at every launch to clean
     * up after a process that died mid-session.
     */
    fun end() {
        // Before the access check: cancel the alarm even if access was revoked.
        failsafe(PendingIntent.FLAG_NO_CREATE)?.let(alarms::cancel)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        if (!isGranted()) return
        val id = existingRuleId() ?: return

        notifications.setAutomaticZenRuleState(
            id,
            Condition(CONDITION_ID, "No focus session is running", Condition.STATE_FALSE),
        )
    }

    /** The rule's id, registering it if this is the first time. */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun ruleId(): String? {
        if (!isGranted()) return null

        return existingRuleId() ?: notifications.addAutomaticZenRule(build())
    }

    /** Matched on condition id, not name (the user can rename it). */
    private fun existingRuleId(): String? = notifications.automaticZenRules
        .entries
        .firstOrNull { it.value.conditionId == CONDITION_ID }
        ?.key

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun build(): AutomaticZenRule {
        val configuration = ComponentName(context, MainActivity::class.java)

        // Builder is 14+; same rule via the old constructor on 10-13.
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            AutomaticZenRule.Builder(RULE_NAME, CONDITION_ID)
                .setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                .setZenPolicy(policy())
                .setConfigurationActivity(configuration)
                .build()
        } else {
            @Suppress("DEPRECATION")
            AutomaticZenRule(
                RULE_NAME,
                // No owner: this app switches its rule on and off directly
                // rather than through a bound ConditionProviderService.
                null,
                configuration,
                CONDITION_ID,
                policy(),
                NotificationManager.INTERRUPTION_FILTER_PRIORITY,
                true,
            )
        }
    }

    /** Alarms and reminders only. */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun policy(): ZenPolicy = ZenPolicy.Builder()
        .disallowAllSounds()
        .allowAlarms(true)
        .allowReminders(true)
        .build()

    /**
     * The failsafe's pending intent. With `FLAG_NO_CREATE` it's null when no
     * alarm is set instead of creating one just to cancel it.
     */
    private fun failsafe(flags: Int): PendingIntent? = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, QuietModeReceiver::class.java)
            .setAction(QuietModeReceiver.ACTION_END),
        flags or PendingIntent.FLAG_IMMUTABLE,
    )
}
