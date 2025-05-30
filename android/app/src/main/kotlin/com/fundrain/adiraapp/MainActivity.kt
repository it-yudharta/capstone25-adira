package com.fundrain.adiraapp

import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.content.ContentValues
import android.net.Uri
import java.io.OutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.fundrain.adiraapp/download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveFileToDownloads") {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")

                    try {
                        val resolver = applicationContext.contentResolver

                        val mimeType = when {
                            fileName!!.endsWith(".png", ignoreCase = true) -> "image/png"
                            fileName.endsWith(".xlsx", ignoreCase = true) -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                            fileName.endsWith(".pdf", ignoreCase = true) -> "application/pdf"
                            else -> "application/octet-stream"
                        }

                        val contentValues = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                put(MediaStore.MediaColumns.IS_PENDING, 1)

                                // Simpan ke Pictures/QR_Pendaftaran jika PNG, selain itu ke Downloads
                                put(
                                    MediaStore.MediaColumns.RELATIVE_PATH,
                                    if (fileName.endsWith(".png", ignoreCase = true))
                                        Environment.DIRECTORY_PICTURES + "/QR_Pendaftaran"
                                    else
                                        Environment.DIRECTORY_DOWNLOADS
                                )
                            }
                        }

                        val uri: Uri? = if (fileName.endsWith(".png", ignoreCase = true)) {
                            resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                        } else {
                            resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                        }

                        if (uri != null) {
                            resolver.openOutputStream(uri)?.use { outputStream ->
                                outputStream.write(bytes)
                                outputStream.flush()
                            }

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                contentValues.clear()
                                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                resolver.update(uri, contentValues, null, null)
                            }

                            result.success("File berhasil disimpan: $fileName")
                        } else {
                            result.error("SAVE_FAILED", "Gagal membuat URI", null)
                        }

                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", "Gagal simpan file: ${e.message}", null)
                    }

                } else {
                    result.notImplemented()
                }
            }
    }
}
