package com.torque.torque_obd2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var spp: SppPlugin? = null
    private var background: BackgroundPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Application context, not the activity: the socket must survive a
        // configuration change without holding the activity alive.
        spp = SppPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // This one holds the Activity on purpose — it needs it to raise the
        // POST_NOTIFICATIONS runtime prompt.
        background = BackgroundPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        spp?.dispose()
        spp = null
        background?.dispose()
        background = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
