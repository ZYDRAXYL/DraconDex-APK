package com.dracondex.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// "Share → DraconDex" (APP Procress 16 part 2): the files another app hands
// over wait here until the Dart side (features/tools/share_inbox.dart) takes
// them and files them into a Nest folder. No plugin: a share is one intent.
class MainActivity : FlutterActivity() {
    private var pending: Intent? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = intent // a cold start from the share sheet
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dracondex/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    val i = pending
                    pending = null
                    result.success(if (i == null) emptyList() else read(i))
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    // already running (singleTop): tell Dart there is something to take
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        pending = intent
        channel?.invokeMethod("shared", null)
    }

    // ponytail: whole files in memory — AssetStore.addFile caps the size anyway
    private fun read(i: Intent): List<Map<String, Any>> {
        val uris = when (i.action) {
            Intent.ACTION_SEND -> listOfNotNull(stream(i))
            Intent.ACTION_SEND_MULTIPLE -> streams(i)
            else -> emptyList()
        }
        return uris.mapNotNull { u ->
            try {
                val bytes = contentResolver.openInputStream(u)?.use { it.readBytes() } ?: return@mapNotNull null
                mapOf("name" to nameOf(u), "bytes" to bytes)
            } catch (e: Exception) {
                Log.w("DraconDex", "share: could not read $u", e)
                null
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun stream(i: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java) else i.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streams(i: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) i.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) else i.getParcelableArrayListExtra(Intent.EXTRA_STREAM))
            ?: emptyList()

    private fun nameOf(u: Uri): String =
        contentResolver.query(u, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
            ?: u.lastPathSegment ?: "shared"
}
