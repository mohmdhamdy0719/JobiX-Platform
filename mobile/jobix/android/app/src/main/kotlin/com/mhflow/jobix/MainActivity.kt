package com.mhflow.jobix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns

class MainActivity : FlutterActivity() {
    private var saveResult: MethodChannel.Result? = null
    private var pdfBytes: ByteArray? = null
    private val saveRequest = 7341
    private var destinationSelected = false
    private var uriReturned = false
    private var streamOpened = false
    private var writeCompleted = false
    private var streamClosed = false
    private var bytesWritten: Int? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "jobix/pdf_save")
            .setMethodCallHandler { call, result ->
                if (call.method == "cancel") {
                    completeSave(saved = false, stage = "cancelled")
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "save") { result.notImplemented(); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                if (saveResult != null || bytes == null || bytes.size < 5 ||
                    String(bytes.copyOfRange(0, 5), Charsets.US_ASCII) != "%PDF-" ||
                    name == null ||
                    !name.matches(Regex("[^\\p{Cntrl}<>:\"/\\\\|?*]{1,71}\\.pdf"))) {
                    result.error("INVALID_STATE", "PDF cannot be saved.", null)
                    return@setMethodCallHandler
                }
                saveResult = result
                pdfBytes = bytes
                destinationSelected = false
                uriReturned = false
                streamOpened = false
                writeCompleted = false
                streamClosed = false
                bytesWritten = null
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("application/pdf")
                        .putExtra(Intent.EXTRA_TITLE, name)
                    startActivityForResult(intent, saveRequest)
                } catch (error: Exception) {
                    completeSave(
                        saved = false,
                        stage = "picker_start_failed",
                        exceptionType = error.javaClass.simpleName
                    )
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest) return
        val uri = data?.data
        uriReturned = uri != null
        destinationSelected = resultCode == Activity.RESULT_OK && uri != null
        try {
            if (resultCode == Activity.RESULT_CANCELED) {
                completeSave(saved = false, stage = "cancelled")
            } else if (resultCode == Activity.RESULT_OK && uri == null) {
                completeSave(saved = false, stage = "uri_missing")
            } else if (resultCode == Activity.RESULT_OK && pdfBytes != null) {
                val bytes = pdfBytes!!
                val selectedUri = uri!!
                val stream = contentResolver.openOutputStream(selectedUri)
                if (stream == null) {
                    completeSave(
                        saved = false,
                        stage = "output_unavailable",
                        submittedBytes = bytes.size
                    )
                } else {
                    streamOpened = true
                    stream.use { output ->
                        output.write(bytes)
                        output.flush()
                        writeCompleted = true
                        bytesWritten = bytes.size
                    }
                    streamClosed = true
                    // SAF providers may return stale/zero SIZE immediately
                    // after close. Read back suspicious metadata when allowed;
                    // never interpret zero metadata as an actual empty file.
                    val finalSize = PdfSaveVerification.verifiedSize(
                        readDocumentSize(selectedUri), bytes
                    ) { contentResolver.openInputStream(selectedUri) }
                    val sizeMatches = PdfSaveVerification.completeWrite(
                        bytes.size.toLong(), bytesWritten?.toLong(),
                        streamOpened, writeCompleted, streamClosed, finalSize
                    )
                    completeSave(
                        saved = sizeMatches,
                        stage = if (sizeMatches) "saved" else "size_mismatch",
                        submittedBytes = bytes.size,
                        finalSizeBytes = finalSize
                    )
                }
            } else {
                completeSave(saved = false, stage = "picker_result_failed")
            }
        } catch (error: Exception) {
            completeSave(
                saved = false,
                stage = "write_failed",
                submittedBytes = pdfBytes?.size,
                exceptionType = error.javaClass.simpleName
            )
        }
    }

    private fun readDocumentSize(uri: Uri): Long? = try {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) {
                cursor.getLong(0).takeIf { it >= 0L }
            } else null
        }
    } catch (_: Exception) {
        null
    }

    private fun completeSave(
        saved: Boolean,
        stage: String,
        submittedBytes: Int? = null,
        finalSizeBytes: Long? = null,
        exceptionType: String? = null
    ) {
        pdfBytes?.fill(0)
        pdfBytes = null
        val result = mutableMapOf<String, Any?>(
            "saved" to saved,
            "stage" to stage,
            "destination_selected" to destinationSelected,
            "uri_returned" to uriReturned,
            "stream_opened" to streamOpened,
            "write_completed" to writeCompleted,
            "stream_closed" to streamClosed
        )
        if (bytesWritten != null) result["bytes_written"] = bytesWritten
        if (submittedBytes != null) result["submitted_bytes"] = submittedBytes
        result["final_size_available"] = finalSizeBytes != null
        if (finalSizeBytes != null) result["final_size_bytes"] = finalSizeBytes
        if (exceptionType != null) result["exception_type"] = exceptionType
        saveResult?.success(result)
        saveResult = null
    }

    override fun onDestroy() {
        completeSave(saved = false, stage = "activity_destroyed")
        super.onDestroy()
    }
}