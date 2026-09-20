package com.duanju.duanju_app

import io.flutter.embedding.android.FlutterActivity
import android.app.UiModeManager
import android.os.Build
import android.os.Bundle
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duanju/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceInfo") {
                    val mode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val television = mode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                    val version = packageManager.getPackageInfo(packageName, 0).versionName
                    result.success(mapOf("television" to television, "version" to version))
                } else {
                    result.notImplemented()
                }
            }
    }
}
