package com.torque.torque_obd2

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * "Keep the screen on" — SPEC §5.6.
 *
 *   MethodChannel "ktc.torque/screen"
 *     setKeepAwake(Boolean) -> null
 *
 * FLAG_KEEP_SCREEN_ON on the activity window: no wake lock, no permission,
 * and the flag dies with the window. Dart decides *when* — a live link and
 * the setting on — this only sets the flag. It holds the Activity because
 * the flag is the window's.
 */
class ScreenWakePlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "ktc.torque/screen"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)

    init {
        methodChannel.setMethodCallHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setKeepAwake" -> {
                val on = call.arguments as? Boolean ?: false
                val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                if (on) activity.window.addFlags(flag) else activity.window.clearFlags(flag)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
