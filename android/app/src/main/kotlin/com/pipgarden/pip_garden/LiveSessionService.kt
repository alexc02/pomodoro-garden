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
 * Ongoing notification for a running focus session, held by a foreground
 * service so updates still arrive after the app is backgrounded and the
 * notification can't be swiped away. Also makes the process less likely to be
 * killed.
 *
 * No ticking: the countdown is [Notification.WHEN] plus
 * [NotificationCompat.Builder.setUsesChronometer], so no wake lock or thread.
 * The only scheduled thing is a stop at the due instant, so the notification
 * doesn't count past zero when the app isn't running.
 */
class LiveSessionService : Service() {

    companion object {
        const val NOTIFICATION_ID = 2

        /**
         * Separate from `session_completion` so users can mute one without
         * the other. LOW importance, never makes a sound.
         */
        const val CHANNEL_ID = "session_live"

        const val ACTION_SHOW = "com.pipgarden.pip_garden.SHOW_LIVE_SESSION"

        const val EXTRA_PAUSED = "paused"
        const val EXTRA_ENDS_AT = "endsAt"
        const val EXTRA_REMAINING_SECONDS = "remainingSeconds"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_STAGE_LABEL = "stageLabel"
        const val EXTRA_SPECIES_LABEL = "speciesLabel"

        private const val PROGRESS_MAX = 1000

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
            // System restart with no intent, or unknown action: nothing to show.
            stopSelf()
            return START_NOT_STICKY
        }

        scheduleTheStop(intent)

        val notification = build(intent)
        if (isForeground) {
            // Update in place under the same id.
            notificationManager.notify(NOTIFICATION_ID, notification)
        } else {
            startInForeground(notification)
            isForeground = true
        }

        // NOT_STICKY: after a kill the app recomputes the session from the
        // wall clock; a restarted service would only have a stale snapshot.
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
     * Stops the service when the session is due. Re-armed on every update
     * since pausing moves the end; paused sessions get no stop until resumed.
     * Normally `LiveSurfaceKeeper` hides it first; this covers a dead app.
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
        // Re-creating an existing channel is a no-op. Importance and sound are
        // fixed at creation, so changing either needs a new channel id.
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
            // e.g. "Sunflower · Sprout"
            .setContentText(getString(R.string.live_session_plant, species, stage))
            .setProgress(PROGRESS_MAX, (progress * PROGRESS_MAX).toInt(), false)
            // Android 14+ lets users dismiss it anyway; the service keeps
            // running and the next update reposts it.
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            // Show the countdown on the lock screen.
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openTheSession())

        if (!paused) {
            // The system counts down to `when` itself.
            builder
                .setWhen(endsAt)
                .setShowWhen(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
        }

        return builder.build()
    }

    /** `SINGLE_TOP` so a running app gets `onNewIntent` instead of a copy. */
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
