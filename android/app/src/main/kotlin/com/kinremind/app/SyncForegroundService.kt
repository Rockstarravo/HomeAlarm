package com.kinremind.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.view.FlutterCallbackInformation

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
        private const val TAG = "SyncForegroundService"
        private const val CHANNEL_ID = "kinremind_sync_service"
        private const val NOTIFICATION_ID = 1001

        // Written by MainActivity's "setSyncCallbackHandle" MethodChannel call
        // (lib/sync/foreground_service.dart) and read here — deliberately a
        // plain native SharedPreferences file, not the shared_preferences
        // plugin's own storage, since this has to be readable before any
        // Flutter/plugin code has run in this service's headless engine.
        const val NATIVE_PREFS_NAME = "com.kinremind.app.native_prefs"
        const val CALLBACK_HANDLE_KEY = "sync_callback_handle"
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

        val handle = applicationContext
            .getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(CALLBACK_HANDLE_KEY, 0L)
        if (handle == 0L) {
            // Nothing registered yet — happens only if this service is ever
            // triggered (e.g. BOOT_COMPLETED) before the app has been opened
            // once since install. Nothing to run yet; a later app launch
            // registers the handle and starts the service itself.
            Log.w(TAG, "No sync callback handle registered yet, skipping")
            return
        }

        // The shared, already-(re-)initializable loader — not `FlutterLoader()`,
        // which builds an independent instance out of step with the one the
        // main Activity's FlutterEngine uses. A previous version of this file
        // did that and had to be fixed once already (see git history); these
        // two calls are safely idempotent on the shared instance.
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val engine = FlutterEngine(applicationContext)
        GeneratedPluginRegistrant.registerWith(engine)

        // A named DartEntrypoint (library URI + function name) only resolves
        // lib/main.dart's own library in a compiled build — pointing it at
        // syncEntrypoint's actual file fails with "Dart_LookupLibrary: ...
        // not found" / "Could not create root isolate", so nothing in this
        // engine ever ran. The callback-handle mechanism is what every
        // headless Flutter plugin (android_alarm_manager_plus, workmanager,
        // firebase_messaging's background handler) actually uses instead,
        // and the only one that reliably launches a non-main entrypoint.
        // The FlutterEngine has to exist before this lookup — its callback
        // cache isn't populated until an engine is created.
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle)
        if (callbackInfo == null) {
            Log.e(TAG, "Could not resolve sync callback handle $handle")
            return
        }
        val callback = DartExecutor.DartCallback(
            applicationContext.assets,
            loader.findAppBundlePath(),
            callbackInfo,
        )
        engine.dartExecutor.executeDartCallback(callback)
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
