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
 * REQ-014's quiet mode on Android: one `AutomaticZenRule`, switched on while a
 * focus session runs and off the moment it does not.
 *
 * Five decisions are worth reading before changing anything in here.
 *
 * **A rule the app owns, never the global interruption filter.** From Android
 * 15 an app targeting 15 or later cannot change the device's own filter at all:
 * [NotificationManager.setInterruptionFilter] is silently redirected into an
 * implicit app-owned rule, which means an app that called it would appear to
 * work and would leave the user with a rule they never saw the app create. This
 * registers its rule explicitly instead, so it shows up in the user's Do Not
 * Disturb settings under a name they can recognise, alongside the schedules
 * they made themselves — and can be inspected, edited or deleted there like any
 * of them.
 *
 * **Priority rather than total silence, and that is not a softening.** A rule
 * with `INTERRUPTION_FILTER_NONE` silences everything with no policy to
 * negotiate — including this app's own notice that the session has finished,
 * which is the whole reason the phone was silenced for the next twenty-five
 * minutes. `INTERRUPTION_FILTER_PRIORITY` with a policy that allows exactly
 * alarms and reminders is what lets that one notification through: ticket 06's
 * completion notice is posted as `CATEGORY_REMINDER` — see
 * `local_session_notifications.dart` — which is what the platform matches the
 * policy against. Alarms are allowed for a plainer reason: an app that made
 * somebody sleep through an alarm clock has done far more damage than an
 * unsilenced phone ever could.
 *
 * **The rule is registered once and left alone.** It is looked up by its
 * condition id rather than by an id this app stores, so a reinstall, a cleared
 * cache or a lost preference cannot produce a second copy of it. An existing
 * rule is never rewritten either: the user is allowed to edit it in system
 * settings, and an app that reset their edit at the start of every session
 * would be taking that back.
 *
 * **Nothing here is possible below Android 10.** Adding a zen rule has been
 * possible since Android 7, but *activating* one from the app that owns it
 * needs [NotificationManager.setAutomaticZenRuleState], which arrived in
 * Android 10. Before that the only route was a bound `ConditionProviderService`
 * — a background service, on the platform versions least able to keep one alive,
 * for a feature about silence. Those devices are told the truth instead: the
 * app reports that it cannot do this, and the settings screen offers no switch.
 *
 * **The silence has a deadline the app does not have to be alive to keep.** See
 * [begin]. This is the failure the feature is not allowed to have.
 */
class QuietModeRule(private val context: Context) {

    companion object {
        /**
         * What the rule is called in the user's Do Not Disturb settings.
         *
         * They will meet this name without the app in front of them, in a list
         * of their own schedules, so it says what it is rather than what made
         * it.
         */
        const val RULE_NAME = "Pip Garden focus session"

        /**
         * The rule's condition id, and the app's handle on it.
         *
         * Fixed, and the only thing this class uses to find its own rule again:
         * an id returned by `addAutomaticZenRule` would have to be stored
         * somewhere, and anything stored can be lost while the rule it names
         * carries on existing. That is how an app ends up with four copies of
         * its own rule in somebody's settings.
         */
        val CONDITION_ID: Uri = Uri.parse("pipgarden://quiet-mode/focus-session")

        /**
         * How long after a session is due the failsafe lets the phone speak
         * again.
         *
         * Late rather than early, and deliberately: being late costs a minute
         * of quiet at the end of a session that is already over, and being
         * early would silence the completion notice this rule is at pains to
         * let through.
         */
        private const val GRACE_MILLIS = 60_000L

        private const val REQUEST_CODE = 11
    }

    private val notifications: NotificationManager
        get() = context.getSystemService(NotificationManager::class.java)

    private val alarms: AlarmManager
        get() = context.getSystemService(AlarmManager::class.java)

    /**
     * Whether this device can do any of this at all — Android 10 or later. The
     * version check is written out at every entry point below rather than
     * hidden behind a name, because it is also what the platform's own lint
     * reads to prove that an API this app's floor does not have is never
     * called on a device that does not have it.
     */
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /**
     * Whether the user has granted the notification policy access every call
     * below needs.
     *
     * Asked afresh every time rather than remembered. It is granted and revoked
     * on a system settings screen, with this app in the background, and a
     * remembered answer is exactly how a revoked permission becomes a feature
     * that silently does nothing.
     */
    fun isGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return notifications.isNotificationPolicyAccessGranted
    }

    /**
     * Opens the system screen where that access is granted.
     *
     * There is no runtime permission dialog for this one — the platform offers
     * a list of every app on the phone and nothing else — so the caller is
     * expected to have explained where the user is going before sending them.
     */
    fun openAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            // Started from the application context, which is not an activity
            // and so has no task of its own to open it in.
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /**
     * Silences the phone until the session ends, or until [untilMillis] at the
     * very latest.
     *
     * **The deadline is the whole of how quiet mode is kept from outliving its
     * session.** In the ordinary case [end] is what ends it, called by the app
     * when the session completes, is cancelled, or is voided by a force-quit.
     * But the app has to be running to call anything, and a process the system
     * kills to reclaim memory never gets to — so an alarm is set for the
     * instant the session is due, and the receiver behind it switches the rule
     * off with nothing of this app awake. A phone left permanently silent by an
     * app that is no longer running is the one outcome this feature must not
     * have.
     *
     * Re-arming on every call is what moves that deadline when a held session
     * is resumed: there is one alarm, and asking again replaces it.
     */
    fun begin(untilMillis: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val id = ruleId() ?: return

        // Armed before the silence starts, not after. There is no instant at
        // which this phone is quiet and nothing is due to make it loud again.
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
     * Lets the phone make noise again, and withdraws the failsafe.
     *
     * Safe to call when the rule is already off, when it was never registered,
     * and when policy access has since been revoked — all of which are ordinary:
     * this runs at every launch, so that a rule left switched on by a process
     * that died mid-session is switched off by the next one to open.
     */
    fun end() {
        // First, and outside the access check. An alarm this app set is this
        // app's to withdraw whatever the user has since revoked, and leaving
        // one armed would wake the device for a session that ended hours ago.
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

    /**
     * The id of the rule this app already owns, or null if it has none.
     *
     * Matched on the condition id, which is this app's, rather than on the name,
     * which is the user's to change.
     */
    private fun existingRuleId(): String? = notifications.automaticZenRules
        .entries
        .firstOrNull { it.value.conditionId == CONDITION_ID }
        ?.key

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun build(): AutomaticZenRule {
        val configuration = ComponentName(context, MainActivity::class.java)

        // The builder is Android 14 and later; the constructor it replaced is
        // how the same rule is described on 10 through 13. Both say exactly the
        // same thing, and the split is the platform's rather than a difference
        // in what the rule does.
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

    /** What is still allowed through. See the class comment. */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun policy(): ZenPolicy = ZenPolicy.Builder()
        .disallowAllSounds()
        .allowAlarms(true)
        .allowReminders(true)
        .build()

    /**
     * The pending intent behind the deadline, created or merely looked up
     * depending on [flags].
     *
     * `FLAG_NO_CREATE` is what makes cancelling honest: it hands back null when
     * there is no alarm set, rather than minting one in order to withdraw it.
     */
    private fun failsafe(flags: Int): PendingIntent? = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, QuietModeReceiver::class.java)
            .setAction(QuietModeReceiver.ACTION_END),
        flags or PendingIntent.FLAG_IMMUTABLE,
    )
}
