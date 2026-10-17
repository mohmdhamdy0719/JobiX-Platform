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
                    name == null || !name.matches(Regex("[\\p{L}\\p{N}_-]{1,64}\\.pdf"))) {
                    result.error("INVALID_STATE", "PDF cannot be saved.", null)
                    return@setMethodCallHandler
                }
                saveResult = result
                pdfBytes = bytes
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
        try {
            if (resultCode == Activity.RESULT_OK && uri != null && pdfBytes != null) {
                val bytes = pdfBytes!!
                val stream = contentResolver.openOutputStream(uri)
                if (stream == null) {
                    completeSave(
                        saved = false,
                        stage = "output_unavailable",
                        submittedBytes = bytes.size
                    )
                } else {
                    stream.use { it.write(bytes) }
                    val finalSize = readDocumentSize(uri)
                    val sizeMatches = finalSize == null || finalSize == bytes.size.toLong()
                    completeSave(
                        saved = sizeMatches,
                        stage = if (sizeMatches) "saved" else "size_mismatch",
                        submittedBytes = bytes.size,
                        finalSizeBytes = finalSize
                    )
                }
            } else {
                completeSave(saved = false, stage = "cancelled")
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
            if (cursor.moveToFirst()) {
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
            "stage" to stage
        )
        if (submittedBytes != null) result["submitted_bytes"] = submittedBytes
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