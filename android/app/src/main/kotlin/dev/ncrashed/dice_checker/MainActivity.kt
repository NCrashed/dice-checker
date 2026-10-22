package dev.ncrashed.dice_checker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Exposes the app's private files directory so Dart can persist data
    // without pulling in plugins (which need a native jni/CMake build).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dice_checker/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "filesDir") result.success(filesDir.absolutePath) else result.notImplemented()
            }
    }
}
