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
                        val contentValues = ContentValues().apply {
                            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                            put(
                                MediaStore.Downloads.MIME_TYPE,
                                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                            )
                            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        }

                        val uri: Uri? = resolver.insert(
                            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                            contentValues
                        )
                        if (uri != null) {
                            val outputStream: OutputStream? = resolver.openOutputStream(uri)
                            outputStream?.use {
                                it.write(bytes)
                                it.flush()
                            }
                            result.success("Download/$fileName")
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
