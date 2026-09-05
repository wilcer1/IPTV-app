package com.wille.iptv_app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceChannel = "iptv_app/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                // Android TV's native on-screen keyboard doesn't respond to
                // D-pad input on real hardware (unfixed Flutter engine bug:
                // flutter/flutter#125541, #177360), so the app uses its own
                // Flutter-rendered keyboard on TV instead. FEATURE_LEANBACK
                // is the standard system flag for "this is a TV device".
                "isTv" -> result.success(packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
                else -> result.notImplemented()
            }
        }
    }
}
