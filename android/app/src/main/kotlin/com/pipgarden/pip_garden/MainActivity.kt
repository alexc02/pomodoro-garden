package com.pipgarden.pip_garden

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    companion object {
        /** Carried by the live session notification's tap. */
        const val ACTION_OPEN_SESSION =
            "com.pipgarden.pip_garden.OPEN_SESSION"
    }

    private var liveSession: LiveSessionSurfacePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val plugin = LiveSessionSurfacePlugin(
            // Application context: the service outlives the activity and
            // holding the activity would leak it across a rotation.
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        liveSession = plugin

        QuietModePlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        GardenSharePlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        // A cold start from a surface tap: held until Dart asks for it.
        plugin.handle(intent, alreadyRunning = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Tap while already running (singleTop in the manifest).
        liveSession?.handle(intent, alreadyRunning = true)
    }
}
