package com.mhflow.jobix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var saveResult: MethodChannel.Result? = null
    private var pdfBytes: ByteArray? = null
    private val saveRequest = 7341

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "jobix/pdf_save")
            .setMethodCallHandler { call, result ->
                if (call.method == "cancel") {
                    clearSave(false)
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "save") { result.notImplemented(); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                if (saveResult != null || bytes == null || bytes.size < 5 ||
                    String(bytes.copyOfRange(0, 5), Charsets.US_ASCII) != "%PDF-" ||
                    name == null || !name.matches(Regex("[a-fA-F0-9-]+\\.pdf"))) {
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
                } catch (_: Exception) {
                    clearSave(false)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest) return
        val uri = data?.data
        try {
            if (resultCode == Activity.RESULT_OK && uri != null && pdfBytes != null) {
                val stream = contentResolver.openOutputStream(uri)
                if (stream == null) clearSave(false)
                else { stream.use { it.write(pdfBytes!!) }; clearSave(true) }
            } else clearSave(false)
        } catch (_: Exception) { clearSave(false) }
    }

    private fun clearSave(saved: Boolean) {
        pdfBytes?.fill(0)
        pdfBytes = null
        saveResult?.success(saved)
        saveResult = null
    }

    override fun onDestroy() {
        clearSave(false)
        super.onDestroy()
    }
}