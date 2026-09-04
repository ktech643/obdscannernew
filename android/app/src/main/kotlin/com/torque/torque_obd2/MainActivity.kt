package com.torque.torque_obd2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var spp: SppPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Application context, not the activity: the socket must survive a
        // configuration change without holding the activity alive.
        spp = SppPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        spp?.dispose()
        spp = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
