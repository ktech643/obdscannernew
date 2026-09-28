package com.torque.torque_obd2

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service + OEM battery-optimisation control. SPEC §9.3 / §9.4.
 *
 *   MethodChannel "ktc.torque/fgs"
 *     startRecording()                -> null   (starts the connectedDevice FGS;
 *                                                error fgs_start if refused)
 *     stopRecording()                 -> null
 *     isForegroundServiceRunning()    -> Boolean
 *     hasNotificationPermission()     -> Boolean (API 33+ gate)
 *     requestNotificationPermission() -> Boolean (raises the system prompt)
 *     batteryOptimizationIntent()     -> Map{package,label,component,action} | null
 *     openBatterySettings()           -> Boolean (opened a vendor screen?)
 *
 * Everything here is dumb plumbing. The decision about *whether* to start a
 * foreground service lives in Dart, where the recording state actually is.
 * This plugin holds the Activity only to raise the POST_NOTIFICATIONS runtime
 * prompt, which Android requires to come from an Activity, not a Service.
 */
class BackgroundPlugin(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "ktc.torque/fgs"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4201
    }

    private val appContext = activity.applicationContext
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)

    init {
        methodChannel.setMethodCallHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> {
                val intent = Intent(appContext, ObdForegroundService::class.java)
                // ForegroundServiceStartNotAllowedException (a start from the
                // background, API 31+) and SecurityException reach Dart as
                // fgs_start, where startRecording() answers false.
                try {
                    appContext.startForegroundService(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("fgs_start", e.message, null)
                }
            }
            "stopRecording" -> {
                val intent = Intent(appContext, ObdForegroundService::class.java)
                appContext.stopService(intent)
                result.success(null)
            }
            "isForegroundServiceRunning" -> result.success(ObdForegroundService.isRunning)
            "hasNotificationPermission" -> result.success(hasNotificationPermission())
            "requestNotificationPermission" -> {
                requestNotificationPermission()
                result.success(true)
            }
            "batteryOptimizationIntent" ->
                result.success(BatteryOptimization.intentFor(appContext)?.toMap())
            "openBatterySettings" -> {
                val intent = BatteryOptimization.intentFor(appContext)?.toIntent()
                if (intent != null) {
                    appContext.startActivity(intent)
                }
                result.success(intent != null)
            }
            else -> result.notImplemented()
        }
    }

    /** API 33+ needs the runtime POST_NOTIFICATIONS grant to show a notification. */
    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        val nm = appContext.getSystemService(NotificationManager::class.java)
        return nm.areNotificationsEnabled()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }
}
