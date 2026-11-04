package com.dracondex.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// Port Link on Android (APP Plan.md Procress 32 part 9.1): a USB-OTG stick or
// an SD card is reachable only through the Storage Access Framework — a tree
// URI the user picks once, not a path. sqflite needs a path, so the Dart side
// (lib/core/platform/saf.dart) copies files in to its cache, works there, and
// copies results back out through here.
//
// No androidx.documentfile: DocumentsContract does all of it, and one less
// dependency is one less thing for the web/PWA build of this tree to step on.
//
// Every path below is relative to the picked tree ("novel-manager-data/app.ddx")
// and walked one display name at a time. All I/O runs off the main thread.
class SafChannel(private val activity: Activity, channel: MethodChannel) {
    companion object {
        const val NAME = "dracondex/saf"
        const val PICK_TREE = 0x5AF1
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pickResult: MethodChannel.Result? = null
    private val resolver get() = activity.contentResolver

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickTree" -> pickTree(result)
            // the folders this app may still open — survives restarts
            "trees" -> result.success(resolver.persistedUriPermissions.filter { it.isReadPermission && it.isWritePermission }.map { it.uri.toString() })
            "release" -> {
                val tree = Uri.parse(call.argument<String>("tree"))
                try { resolver.releasePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION) } catch (_: Exception) {}
                result.success(true)
            }
            else -> background(result) { run(call) }
        }
    }

    private fun run(call: MethodCall): Any? {
        val tree = Uri.parse(call.argument<String>("tree") ?: throw IllegalArgumentException("tree"))
        val rel = call.argument<String>("path") ?: ""
        return when (call.method) {
            // is the drive in, and is this folder still there?
            "available" -> try { find(tree, "") != null } catch (_: Exception) { false }
            "stat" -> find(tree, rel)?.let { stat(it) }
            "list" -> {
                val dir = find(tree, rel) ?: return null
                children(tree, DocumentsContract.getDocumentId(dir)).map { it.second }
            }
            "copyIn" -> {
                val doc = find(tree, rel) ?: return false
                val dest = File(call.argument<String>("dest") ?: throw IllegalArgumentException("dest"))
                dest.parentFile?.mkdirs()
                val tmp = File(dest.path + ".part")
                resolver.openInputStream(doc)?.use { input -> tmp.outputStream().use { input.copyTo(it) } } ?: return false
                if (dest.exists()) dest.delete()
                tmp.renameTo(dest)
            }
            "copyOut" -> copyOut(tree, rel, File(call.argument<String>("src") ?: throw IllegalArgumentException("src")))
            "mkdirs" -> mkdirs(tree, rel) != null
            "delete" -> find(tree, rel)?.let { DocumentsContract.deleteDocument(resolver, it) } ?: false
            else -> throw UnsupportedOperationException(call.method)
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val v = work()
                main.post { result.success(v) }
            } catch (e: Exception) {
                Log.w("DraconDex", "saf: ${e.message}", e)
                main.post { result.error("saf", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    // ── picking ───────────────────────────────────────────────────────────
    private fun pickTree(result: MethodChannel.Result) {
        if (pickResult != null) { result.error("busy", "a pick is already open", null); return }
        pickResult = result
        val i = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        activity.startActivityForResult(i, PICK_TREE)
    }

    // MainActivity forwards its onActivityResult here. → true when it was ours.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_TREE) return false
        val r = pickResult ?: return true
        pickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { r.success(null); return true }
        try {
            resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        } catch (e: Exception) {
            r.error("saf", "could not keep access: ${e.message}", null); return true
        }
        r.success(uri.toString())
        return true
    }

    // ── walking a tree by display names ───────────────────────────────────
    private fun segments(rel: String) = rel.split('/').filter { it.isNotEmpty() && it != "." && it != ".." }

    // (document URI, its row) of each child of one document
    private fun children(tree: Uri, docId: String): List<Pair<Uri, Map<String, Any?>>> {
        val kids = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
        val cols = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val out = mutableListOf<Pair<Uri, Map<String, Any?>>>()
        resolver.query(kids, cols, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0)
                out += DocumentsContract.buildDocumentUriUsingTree(tree, id) to mapOf(
                    "name" to c.getString(1),
                    "dir" to (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR),
                    "size" to (if (c.isNull(3)) 0L else c.getLong(3)),
                    "mtime" to (if (c.isNull(4)) 0L else c.getLong(4)),
                )
            }
        }
        return out
    }

    // The document at rel, or null. "" is the tree itself.
    private fun find(tree: Uri, rel: String): Uri? {
        var id = DocumentsContract.getTreeDocumentId(tree)
        var uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
        for (seg in segments(rel)) {
            val hit = children(tree, id).firstOrNull { it.second["name"] == seg } ?: return null
            uri = hit.first
            id = DocumentsContract.getDocumentId(uri)
        }
        return uri
    }

    private fun stat(doc: Uri): Map<String, Any?>? {
        val cols = arrayOf(DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED, DocumentsContract.Document.COLUMN_MIME_TYPE)
        return resolver.query(doc, cols, null, null, null)?.use { c ->
            if (!c.moveToFirst()) null
            else mapOf(
                "size" to (if (c.isNull(0)) 0L else c.getLong(0)),
                "mtime" to (if (c.isNull(1)) 0L else c.getLong(1)),
                "dir" to (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR),
            )
        }
    }

    private fun mkdirs(tree: Uri, rel: String): Uri? {
        var uri = find(tree, "") ?: return null
        for (seg in segments(rel)) {
            val id = DocumentsContract.getDocumentId(uri)
            uri = children(tree, id).firstOrNull { it.second["name"] == seg }?.first
                ?: DocumentsContract.createDocument(resolver, uri, DocumentsContract.Document.MIME_TYPE_DIR, seg)
                ?: return null
        }
        return uri
    }

    // Written as "<name>.tmp" beside the target, then the old file goes and the
    // temp takes its name — a drive pulled out mid-copy leaves the old file
    // whole (and a stray .tmp), never half a vault under the real name.
    // ponytail: providers rename best-effort; a provider that refuses leaves the
    // .tmp and reports false, and the caller keeps its own copy.
    private fun copyOut(tree: Uri, rel: String, src: File): Boolean {
        val segs = segments(rel)
        if (segs.isEmpty() || !src.isFile) return false
        val dir = mkdirs(tree, segs.dropLast(1).joinToString("/")) ?: return false
        val name = segs.last()
        val dirId = DocumentsContract.getDocumentId(dir)
        children(tree, dirId).firstOrNull { it.second["name"] == "$name.tmp" }?.let { DocumentsContract.deleteDocument(resolver, it.first) }
        val tmp = DocumentsContract.createDocument(resolver, dir, "application/octet-stream", "$name.tmp") ?: return false
        resolver.openOutputStream(tmp, "wt")?.use { out -> src.inputStream().use { it.copyTo(out) } } ?: return false
        children(tree, dirId).firstOrNull { it.second["name"] == name }?.let { DocumentsContract.deleteDocument(resolver, it.first) }
        return DocumentsContract.renameDocument(resolver, tmp, name) != null
    }
}
