package com.torque.torque_obd2

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * The typed foreground service that holds the adapter connection while a trip
 * recording runs with the screen off. SPEC §9.3.
 *
 * Declared with `foregroundServiceType="connectedDevice"`, the type Android
 * requires for a Bluetooth connection held in background. Without it the
 * service crashes with MissingForegroundServiceTypeException on API 34+.
 *
 * The service does no protocol work: the SPP/BLE link lives in the plugin
 * objects and the polling lives in Dart. Its only job is to keep the process
 * alive and to make Android — and the OEM battery killers — believe the app is
 * legitimately busy, so the connection isn't torn down while recording.
 *
 * minSdk is 26, so the framework Notification.Builder (channel-aware) is used
 * directly; no androidx.core dependency is needed.
 */
class ObdForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "torque.trip_recording"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.torque.torque_obd2.action.STOP_RECORDING"

        /** Whether the service is currently up, read by the Dart side. */
        @Volatile
        var isRunning = false
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // The notification's Stop action drives this; it must be able to end
        // the service without going back through Dart.
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        isRunning = true
        startForeground(NOTIFICATION_ID, buildNotification())
        // START_NOT_STICKY: if the OS kills us we do not want to be relaunched
        // into a recording the user has already stopped.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.fgs_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.fgs_channel_desc)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stop = PendingIntent.getService(
            this,
            0,
            Intent(this, ObdForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val open = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_obd)
            .setContentTitle(getString(R.string.fgs_title))
            .setContentText(getString(R.string.fgs_text))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(R.drawable.ic_stat_obd, getString(R.string.fgs_stop), stop)
            .build()
    }
}
