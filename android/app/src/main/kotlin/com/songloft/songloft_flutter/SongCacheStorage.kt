package com.songloft.songloft_flutter

import android.app.Activity
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Local SAF volumes only: a cloud provider cannot promise offline playback. */
class SongCacheStorage(private val activity: Activity) {
    companion object {
        const val PICK_REQUEST = 5101
        private const val AUTHORITY = "com.android.externalstorage.documents"
        private const val GRANTS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }

    private val resolver = activity.contentResolver
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    private val active = ConcurrentHashMap.newKeySet<String>()
    private var picker: MethodChannel.Result? = null
    private val closed = AtomicBoolean(false)

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        val cmd = call.argument<String>("cmd") ?: return false
        if (!cmd.startsWith("cacheStorage")) return false
        if (closed.get()) {
            result.error("cache_storage_unavailable", "Activity closed", null)
            return true
        }
        if (cmd == "cacheStorageSupported") {
            result.success(true)
        } else if (cmd == "cacheStoragePick") {
            if (picker != null) {
                result.error("cache_busy", "Directory picker already open", null)
            } else {
                picker = result
                try {
                    activity.startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                GRANTS or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                            )
                            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                        },
                        PICK_REQUEST,
                    )
                } catch (e: Exception) {
                    picker = null
                    result.error("cache_storage_unavailable", e.message, null)
                }
            }
        } else if (cmd == "cacheStorageCancel") {
            call.argument<String>("operation")?.let {
                if (active.contains(it)) cancelled.add(it)
            }
            result.success(true)
        } else if (
            cmd == "cacheStorageValidate" ||
                cmd == "cacheStorageStatus" ||
                cmd == "cacheStorageCopy" ||
                cmd == "cacheStorageImport" ||
                cmd == "cacheStorageDelete"
        ) {
            val operation = call.argument<String>("operation")
            if (operation != null) active.add(operation)
            worker.execute {
                try {
                    val value: Any =
                        if (cmd == "cacheStorageValidate") {
                            val tree = tree(call.argument<String>("tree"))
                            validate(tree)
                            true
                        } else if (cmd == "cacheStorageStatus") {
                            status(
                                document(call.argument<String>("uri")),
                                tree(call.argument<String>("tree")),
                            )
                        } else if (cmd == "cacheStorageCopy") {
                            copy(call, operation.orEmpty())
                        } else if (cmd == "cacheStorageImport") {
                            val uri = document(call.argument<String>("uri"))
                            val target = privateFile(call.argument<String>("path"))
                            try {
                                resolver.openInputStream(uri).use { input ->
                                    target.outputStream().use { output ->
                                        transfer(
                                            input,
                                            output,
                                            operation.orEmpty(),
                                            expectedBytes(call),
                                        )
                                    }
                                }
                            } catch (e: Exception) {
                                target.delete()
                                throw e
                            }
                            true
                        } else {
                            val uri = document(call.argument<String>("uri"))
                            val state = status(uri, uri)
                            check(state != "unavailable") { "Cache directory unavailable" }
                            if (
                                state == "available" &&
                                    !DocumentsContract.deleteDocument(resolver, uri)
                            ) {
                                throw IllegalStateException("Cannot delete cached file")
                            }
                            true
                        }
                    main.post { result.success(value) }
                } catch (e: Exception) {
                    val code =
                        if (operation != null && cancelled.contains(operation)) "cancelled"
                        else "cache_storage_unavailable"
                    main.post { result.error(code, e.message, null) }
                } finally {
                    if (operation != null) {
                        active.remove(operation)
                        cancelled.remove(operation)
                    }
                }
            }
        } else {
            return false
        }
        return true
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != PICK_REQUEST) return false
        val result = picker ?: return true
        picker = null
        val raw = data?.data
        if (code != Activity.RESULT_OK || raw == null) {
            result.success(null)
            return true
        }
        worker.execute {
            try {
                val uri = tree(raw.toString())
                val flags = requireNotNull(data).flags and GRANTS
                if (flags != GRANTS) throw SecurityException("Read and write access required")
                resolver.takePersistableUriPermission(uri, flags)
                validate(uri)
                val label = DocumentsContract.getTreeDocumentId(uri)
                main.post { result.success(mapOf("uri" to uri.toString(), "label" to label)) }
            } catch (e: Exception) {
                main.post { result.error("cache_storage_unavailable", e.message, null) }
            }
        }
        return true
    }

    fun dispose() {
        closed.set(true)
        cancelled.addAll(active)
        picker?.error("cancelled", "Activity closed", null)
        picker = null
        worker.shutdown()
    }

    private fun tree(raw: String?): Uri {
        val uri = Uri.parse(requireNotNull(raw))
        require(
            uri.scheme == "content" &&
                uri.authority == AUTHORITY &&
                DocumentsContract.isTreeUri(uri)
        ) {
            "Choose a local device or SD card folder"
        }
        return uri
    }

    private fun document(raw: String?): Uri {
        val uri = tree(raw)
        require(DocumentsContract.isDocumentUri(activity, uri)) { "Invalid cache document" }
        return uri
    }

    private fun root(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun privateFile(raw: String?): File {
        val file = File(requireNotNull(raw)).canonicalFile
        val base = File(activity.applicationInfo.dataDir).canonicalPath + File.separator
        require(file.path.startsWith(base)) { "Expected app-private staging file" }
        return file
    }

    private fun exists(uri: Uri): Boolean {
        resolver
            .query(uri, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null)
            .use { cursor ->
                return cursor != null && cursor.moveToFirst()
            }
    }

    private fun validate(tree: Uri) {
        val uri = root(tree)
        resolver
            .query(uri, arrayOf(DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)
            .use { cursor ->
                require(
                    cursor != null &&
                        cursor.moveToFirst() &&
                        cursor.getString(0) == DocumentsContract.Document.MIME_TYPE_DIR
                ) {
                    "Cache directory unavailable"
                }
            }
        val probe =
            DocumentsContract.createDocument(
                resolver,
                uri,
                "application/octet-stream",
                ".songloft-probe-${System.nanoTime()}",
            ) ?: throw IllegalStateException("Directory is not writable")
        try {
            resolver.openOutputStream(probe, "w").use { output ->
                requireNotNull(output).write(0)
            }
        } finally {
            DocumentsContract.deleteDocument(resolver, probe)
        }
    }

    private fun status(uri: Uri, tree: Uri): String {
        return try {
            if (!exists(root(tree))) {
                "unavailable"
            } else {
                try {
                    if (!exists(uri)) "missing"
                    else {
                        resolver.openFileDescriptor(uri, "r").use { requireNotNull(it) }
                        "available"
                    }
                } catch (_: FileNotFoundException) {
                    "missing"
                }
            }
        } catch (_: Exception) {
            "unavailable"
        }
    }

    private fun copy(call: MethodCall, operation: String): String {
        val tree = tree(call.argument<String>("tree"))
        val name = requireNotNull(call.argument<String>("name"))
        require(name.isNotBlank() && !name.contains('/') && !name.contains('\\'))
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        val uri =
            DocumentsContract.createDocument(resolver, root(tree), mime, name)
                ?: throw IllegalStateException("Cannot create cached file")
        try {
            val source = requireNotNull(call.argument<String>("source"))
            val input =
                if (source.startsWith("content://")) resolver.openInputStream(document(source))
                else privateFile(source).inputStream()
            input.use {
                resolver.openOutputStream(uri, "w").use { output ->
                    transfer(it, output, operation, expectedBytes(call))
                }
            }
            scan(uri, mime)
            return uri.toString()
        } catch (e: Exception) {
            try {
                DocumentsContract.deleteDocument(resolver, uri)
            } catch (_: Exception) {}
            throw e
        }
    }

    private fun expectedBytes(call: MethodCall): Long =
        requireNotNull(call.argument<Number>("expected_bytes")).toLong().also { require(it >= 0) }

    private fun transfer(
        input: InputStream?,
        output: OutputStream?,
        operation: String,
        expected: Long,
    ) {
        requireNotNull(input) { "Cannot read cached file" }
        requireNotNull(output) { "Cannot write cached file" }
        val buffer = ByteArray(64 * 1024)
        var written = 0L
        while (true) {
            if (cancelled.contains(operation)) throw IllegalStateException("Cancelled")
            val size = input.read(buffer)
            if (size < 0) break
            output.write(buffer, 0, size)
            written += size
        }
        output.flush()
        check(written == expected) { "Cache copy size mismatch: $written/$expected" }
    }

    // Playback/writes always use SAF. A filesystem path is used only to ask the
    // system media scanner to expose completed local media to other players.
    private fun scan(uri: Uri, mime: String) {
        try {
            val id = DocumentsContract.getDocumentId(uri).split(':', limit = 2)
            if (id.size != 2) return
            val base =
                if (id[0] == "primary") Environment.getExternalStorageDirectory()
                else if (Build.VERSION.SDK_INT >= 30) {
                    activity
                        .getSystemService(StorageManager::class.java)
                        .storageVolumes
                        .firstOrNull {
                            it.uuid.equals(id[0], ignoreCase = true)
                        }
                        ?.directory
                } else {
                    activity
                        .getExternalFilesDirs(null)
                        .filterNotNull()
                        .map { File(it.absolutePath.substringBefore("/Android/")) }
                        .firstOrNull { it.name.equals(id[0], ignoreCase = true) }
                }
            if (base != null) {
                MediaScannerConnection.scanFile(
                    activity,
                    arrayOf(File(base, id[1]).path),
                    arrayOf(mime),
                    null,
                )
            }
        } catch (_: Exception) {
            /* SAF file is still accessible to file managers. */
        }
    }
}
