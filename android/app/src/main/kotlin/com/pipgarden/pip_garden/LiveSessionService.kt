package com.pipgarden.pip_garden

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * REQ-011's live session surface: an ongoing notification that shows a running
 * focus session, kept alive by a foreground service.
 *
 * **Why a service at all, when a notification would draw the same thing.**
 * Two reasons, and only the second is about pixels. A plain notification is
 * posted by a process the system is free to freeze the moment the user leaves
 * the app, so an update — the plant reaching its next stage — might never be
 * delivered. And an ongoing notification that is not a foreground service's is
 * dismissable, which is not what "the session you are in the middle of" should
 * be. The service is also the second guarantee under REQ-005's first: the
 * session is anchored to the wall clock and completes correctly whether or not
 * this runs, and this makes the process that owns it far less likely to be
 * killed in the meantime.
 *
 * **Nothing in here counts.** The countdown is [Notification.WHEN] plus
 * [NotificationCompat.Builder.setUsesChronometer], which the system renders
 * from an absolute instant — so this service holds no wake lock and no thread,
 * and a two-hour session costs the same as a five-minute one. That is what
 * makes surviving Doze a question about the platform's foreground service
 * contract rather than about this code.
 *
 * There is one scheduled thing, and it is a stop rather than a tick: a single
 * `postDelayed` at the instant the session is due, so the surface comes down
 * on its own when the session ends. Without it the notification would sit
 * there counting past zero next to the completion notice, because the app that
 * would otherwise take it down is not running — the user has put their phone
 * down, which is the whole scenario this ticket is about.
 */
class LiveSessionService : Service() {

    companion object {
        /** The one notification this service posts. There is one session. */
        const val NOTIFICATION_ID = 2

        /**
         * Its channel. Separate from ticket 06's `session_completion`, and
         * separate on purpose: a user who wants the ongoing timer but not the
         * chime — or the other way round — can have that from system settings
         * without turning the app off. Its importance is LOW, so it never makes
         * a sound; a notification that exists for the whole of a focus session
         * is furniture, not news.
         */
        const val CHANNEL_ID = "session_live"

        const val ACTION_SHOW = "com.pipgarden.pip_garden.SHOW_LIVE_SESSION"

        const val EXTRA_PAUSED = "paused"
        const val EXTRA_ENDS_AT = "endsAt"
        const val EXTRA_REMAINING_SECONDS = "remainingSeconds"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_STAGE_LABEL = "stageLabel"
        const val EXTRA_SPECIES_LABEL = "speciesLabel"

        /** The progress bar's resolution. Finer than a percent, and free. */
        private const val PROGRESS_MAX = 1000

        /** An [Intent] that shows [extras] on the surface. */
        fun showing(context: Context, extras: Intent.() -> Unit): Intent =
            Intent(context, LiveSessionService::class.java)
                .setAction(ACTION_SHOW)
                .apply(extras)

        fun stopping(context: Context): Intent =
            Intent(context, LiveSessionService::class.java)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action != ACTION_SHOW) {
            // Restarted by the system with no intent to work from, or started
            // with one this does not understand. There is nothing to show and
            // nothing to guess at: stop rather than sit in the foreground
            // holding a notification about a session nobody described.
            stopSelf()
            return START_NOT_STICKY
        }

        scheduleTheStop(intent)

        val notification = build(intent)
        if (isForeground) {
            // An update, not a start. Posting over the same id replaces the
            // notification in place — no animation, no re-sound, and no second
            // entry in the shade.
            notificationManager.notify(NOTIFICATION_ID, notification)
        } else {
            startInForeground(notification)
            isForeground = true
        }

        // NOT_STICKY: if the system kills this process, the right thing on the
        // next launch is for the app to look at the wall clock and decide where
        // the session is — which is what it does anyway — rather than for a
        // service to come back holding a snapshot that is however many hours
        // stale. See ADR 0005.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopWhenDue)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        isForeground = false
        super.onDestroy()
    }

    private var isForeground = false

    private val handler = Handler(Looper.getMainLooper())

    private val stopWhenDue = Runnable { stopSelf() }

    /**
     * Arranges for the surface to come down when the session is due.
     *
     * Re-armed on every update, because an update can move the instant — a
     * session held for five minutes ends five minutes later.
     *
     * A held session gets no stop scheduled at all: it has no end to be due at
     * until the user resumes it, and the resume is an update that arms this
     * again with the instant the hold pushed it out to.
     *
     * If the app is alive it will have taken the surface down before this fires
     * — `LiveSurfaceKeeper` notices the completion within a frame of it. This
     * is for when it is not, and stopping a service twice costs nothing.
     */
    private fun scheduleTheStop(intent: Intent) {
        handler.removeCallbacks(stopWhenDue)
        if (intent.getBooleanExtra(EXTRA_PAUSED, false)) return

        val due = intent.getLongExtra(EXTRA_ENDS_AT, 0L) - System.currentTimeMillis()
        handler.postDelayed(stopWhenDue, due.coerceAtLeast(0L))
    }

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun startInForeground(notification: Notification) {
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                // Below Android 14 a type is neither required nor accepted.
                0
            },
        )
    }

    private fun createChannel() {
        // Created every start rather than once: creating a channel that exists
        // is a no-op, and there is no "have we done this" for a killed process
        // to get wrong. Note that a channel's importance and sound are fixed at
        // creation — a later ticket that wants to change either has to change
        // the id with it, or existing installs keep the old one.
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.live_session_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.live_session_channel_description)
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun build(intent: Intent): Notification {
        val paused = intent.getBooleanExtra(EXTRA_PAUSED, false)
        val endsAt = intent.getLongExtra(EXTRA_ENDS_AT, 0L)
        val remaining = intent.getIntExtra(EXTRA_REMAINING_SECONDS, 0)
        val progress = intent.getDoubleExtra(EXTRA_PROGRESS, 0.0)
        val stage = intent.getStringExtra(EXTRA_STAGE_LABEL).orEmpty()
        val species = intent.getStringExtra(EXTRA_SPECIES_LABEL).orEmpty()

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_session)
            .setContentTitle(
                if (paused) {
                    getString(R.string.live_session_paused, formatted(remaining))
                } else {
                    getString(R.string.live_session_focusing)
                },
            )
            // The plant, in the same words the app uses for it — "Sunflower ·
            // Sprout". The surface is about the garden, not about the timer.
            .setContentText(getString(R.string.live_session_plant, species, stage))
            .setProgress(PROGRESS_MAX, (progress * PROGRESS_MAX).toInt(), false)
            // Ongoing, so it cannot be swiped away while the session it
            // describes is still running. From Android 14 the user can dismiss
            // a foreground service's notification anyway once the app has been
            // in the background a while; the service keeps running when they
            // do, and the surface comes back on the next thing worth showing.
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            // The countdown is the point of this on a locked phone, so it has
            // to survive the lock screen's redaction.
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openTheSession())

        if (!paused) {
            // The whole of why the countdown does not need this app running:
            // `when` is the absolute instant the session ends and the system
            // counts down to it, second by second, with nothing of ours awake.
            builder
                .setWhen(endsAt)
                .setShowWhen(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
        }

        return builder.build()
    }

    /**
     * Tapping the notification comes back to the session it is about.
     *
     * `SINGLE_TOP` alongside the activity's launch mode, so a tap on a running
     * app brings the task forward and delivers the intent to `onNewIntent`
     * rather than building a second copy of the app over the first.
     */
    private fun openTheSession(): PendingIntent {
        val open = Intent(this, MainActivity::class.java)
            .setAction(MainActivity.ACTION_OPEN_SESSION)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        return PendingIntent.getActivity(
            this,
            0,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun formatted(seconds: Int): String {
        val whole = if (seconds < 0) 0 else seconds
        return "%d:%02d".format(whole / 60, whole % 60)
    }
}
