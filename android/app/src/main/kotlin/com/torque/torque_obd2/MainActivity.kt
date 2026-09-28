package com.torque.torque_obd2

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var spp: SppPlugin? = null
    private var background: BackgroundPlugin? = null
    private var screenWake: ScreenWakePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Application context, not the activity: the socket must survive a
        // configuration change without holding the activity alive.
        spp = SppPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // This one holds the Activity on purpose — it needs it to raise the
        // POST_NOTIFICATIONS runtime prompt.
        background = BackgroundPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        // The keep-screen-on flag belongs to this Activity's window.
        screenWake = ScreenWakePlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The engine, and the trip recorder in it, dies with this Activity
        // (§3.4.1). A foreground service left up would hold a 'Recording
        // trip' notification over nothing; the next launch closes the trip.
        applicationContext.stopService(
            Intent(applicationContext, ObdForegroundService::class.java),
        )
        spp?.dispose()
        spp = null
        background?.dispose()
        background = null
        screenWake?.dispose()
        screenWake = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
