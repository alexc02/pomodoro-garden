package com.pipgarden.pip_garden

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Android's half of REQ-035's share sheet.
 *
 * Answers the same channel `GardenSharePlugin.swift` answers, with the same one
 * method, so nothing in Dart knows which phone it is on.
 *
 * **The image goes out as a content URI, not as a file path.** Android has not
 * allowed a `file://` URI to cross an app boundary since Nougat — it throws
 * `FileUriExposedException` — so the PNG is written into the cache directory the
 * `FileProvider` in `AndroidManifest.xml` is configured for and shared as the
 * `content://` URI that provider hands back. The receiving app reads it through
 * a grant that lasts as long as the chooser does.
 *
 * **Which is also the whole of "saves correctly to the photo library" on this
 * platform.** The Photos and Gallery apps appear in the chooser like any other
 * target and save the image under their own permissions; this app asks the user
 * for nothing, holds no storage permission, and has none to hold — writing to
 * the media store on the user's behalf would need `WRITE_EXTERNAL_STORAGE` on
 * old versions and would put this app in the business of managing somebody's
 * photo library, to do a thing the chooser already does.
 */
class GardenSharePlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "pip_garden/garden_share"

        /**
         * The subdirectory of the cache the provider exposes, and the only path
         * anything here writes to. Named in `res/xml/garden_share_paths.xml`;
         * the two have to agree or the provider refuses the file.
         */
        const val SHARE_DIRECTORY = "garden-exports"

        /**
         * The provider's authority, which must match the one in the manifest.
         * Derived from the package name so a flavour cannot collide with the
         * installed build of another.
         */
        fun authorityFor(context: Context): String =
            "${context.packageName}.gardenshare"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME).apply {
        setMethodCallHandler(this@GardenSharePlugin)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "share") {
            result.notImplemented()
            return
        }

        val image = call.argument<ByteArray>("image")
        val filename = call.argument<String>("filename") ?: "garden.png"
        if (image == null) {
            result.error("no-image", "share was called with no image", null)
            return
        }

        try {
            startChooser(write(image, filename))
            result.success(null)
        } catch (error: Exception) {
            // Reported as an error so Dart can say the sheet did not open. The
            // Dart side turns every failure into one sentence for the user —
            // see `ChannelGardenShare`.
            result.error("share-failed", error.message, null)
        }
    }

    /** Writes [image] into the shared cache and hands back its content URI. */
    private fun write(image: ByteArray, filename: String): Uri {
        val directory = File(context.cacheDir, SHARE_DIRECTORY)
        directory.mkdirs()

        // One file, overwritten. An export the user has finished with is of no
        // further interest, and a directory that accumulated one PNG per tap
        // would be this app quietly filling somebody's storage with pictures
        // they already sent. The chooser's read grant outlives this call and
        // the file is not deleted underneath it; the next export replaces it.
        //
        // The basename only. Dart sends a constant today, but a name is a
        // string crossing a channel into a path join, and `../` in one would
        // write outside the directory the provider is configured for — which
        // is either a throw at `getUriForFile` or something worse.
        val file = File(directory, File(filename).name)
        file.writeBytes(image)

        return FileProvider.getUriForFile(context, authorityFor(context), file)
    }

    private fun startChooser(image: Uri) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, image)
            // The grant the receiving app reads through. Without it the chooser
            // opens and every target fails to load the image.
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(send, null).apply {
            // Started from the application context rather than an activity, so
            // it needs its own task. The plugin holds the application context
            // for the reason `MainActivity` gives: an activity held by
            // something that outlives a rotation is an activity leaked.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        context.startActivity(chooser)
    }
}
