package com.pomodorogarden.pomodoro_garden

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    companion object {
        /**
         * What the live session notification's tap carries, and the whole of
         * how "open the app on the active session screen" is told apart from an
         * ordinary launch from the home screen.
         */
        const val ACTION_OPEN_SESSION =
            "com.pomodorogarden.pomodoro_garden.OPEN_SESSION"
    }

    private var liveSession: LiveSessionSurfacePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val plugin = LiveSessionSurfacePlugin(
            // The application context, not this activity: the plugin starts a
            // service that outlives any one activity, and holding an activity
            // in something that does would leak it across a rotation.
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        liveSession = plugin

        // Ticket 11's quiet mode. The application context for the same reason:
        // the zen rule it owns and the alarm behind it outlive any one
        // activity, and this one is torn down and rebuilt by a rotation.
        QuietModePlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        // REQ-035's share sheet. The application context again: the chooser is
        // started with FLAG_ACTIVITY_NEW_TASK and outlives this activity, and
        // an export begun before a rotation should still open its sheet after
        // one.
        GardenSharePlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        // The intent this activity was created with. If the app is starting
        // *because* the user tapped the surface, the tap arrived before there
        // was any Dart to tell — so it is held until Dart asks for it.
        plugin.handle(intent, alreadyRunning = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A tap on the surface of an app that is already running. `singleTop`
        // in the manifest is what makes this the delivery route rather than a
        // second copy of the activity.
        liveSession?.handle(intent, alreadyRunning = true)
    }
}
