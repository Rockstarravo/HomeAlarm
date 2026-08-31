package com.kinremind.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader

/**
 * Foreground service required by PROJECT_SPEC.md section 4: keeps a
 * Firestore listener alive on the member's device even when the main
 * Activity UI is not visible, so a reminder created/edited by the owner
 * gets an AlarmManager alarm scheduled on this device without the member
 * having to open the app.
 *
 * It hosts a second, headless FlutterEngine running the
 * `syncEntrypoint()` Dart entry point (lib/sync/sync_isolate_entrypoint.dart),
 * which owns the actual Firestore + AlarmManager wiring. This service's own
 * job is only: show the mandatory persistent notification, and keep the
 * process alive (START_STICKY) so Android doesn't reclaim it eagerly.
 */
class SyncForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "kinremind_sync_service"
        private const val NOTIFICATION_ID = 1001
    }

    private var flutterEngine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        startHeadlessEngineIfNeeded()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startHeadlessEngineIfNeeded()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        flutterEngine?.destroy()
        flutterEngine = null
        super.onDestroy()
    }

    private fun startHeadlessEngineIfNeeded() {
        if (flutterEngine != null) return

        val loader = FlutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val engine = FlutterEngine(applicationContext)
        val entrypoint = DartExecutor.DartEntrypoint(
            loader.findAppBundlePath(),
            "syncEntrypoint",
        )
        engine.dartExecutor.executeDartEntrypoint(entrypoint)
        flutterEngine = engine
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KinRemind background sync",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Keeps family reminders in sync in real time."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KinRemind is running")
            .setContentText("Listening for reminders from your family.")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }
}
