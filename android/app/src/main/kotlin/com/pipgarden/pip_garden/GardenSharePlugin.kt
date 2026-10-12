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
 * Share sheet on Android; same channel and method as `GardenSharePlugin.swift`.
 *
 * Shares a `content://` URI from the `FileProvider` (a `file://` URI throws
 * `FileUriExposedException` since Nougat). Saving to Photos/Gallery goes
 * through the chooser, so the app needs no storage permission.
 */
class GardenSharePlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "pip_garden/garden_share"

        /** Must match `res/xml/garden_share_paths.xml`. */
        const val SHARE_DIRECTORY = "garden-exports"

        /** Must match the manifest. Per-package so flavours don't collide. */
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
            result.error("share-failed", error.message, null)
        }
    }

    private fun write(image: ByteArray, filename: String): Uri {
        val directory = File(context.cacheDir, SHARE_DIRECTORY)
        directory.mkdirs()

        // One file, overwritten by the next export so the cache doesn't grow.
        // Basename only, so a `../` in the name can't escape the directory.
        val file = File(directory, File(filename).name)
        file.writeBytes(image)

        return FileProvider.getUriForFile(context, authorityFor(context), file)
    }

    private fun startChooser(image: Uri) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, image)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(send, null).apply {
            // Application context, so it needs its own task.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        context.startActivity(chooser)
    }
}
