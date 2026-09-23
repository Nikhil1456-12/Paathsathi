package com.pathsaathi.pathsaathi

import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth (biometric prompt).
class MainActivity : FlutterFragmentActivity() {

    private val secureChannel = "pathsaathi/secure_window"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // FLAG_SECURE blocks screenshots & screen recording — used
                    // while sensitive documents are on screen.
                    "enableSecure" -> {
                        runOnUiThread {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        }
                        result.success(true)
                    }
                    "disableSecure" -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
