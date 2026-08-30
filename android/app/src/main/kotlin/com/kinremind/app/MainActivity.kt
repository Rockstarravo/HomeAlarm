package com.kinremind.app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

/**
 * Single Flutter activity. The only native-side responsibility beyond the
 * default FlutterActivity behaviour is starting/stopping [SyncForegroundService]
 * on request from Dart (lib/sync/foreground_service.dart) — the service hosts
 * the long-lived Firestore listener that survives the main UI being closed.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val SYNC_CHANNEL = "com.kinremind.app/sync_service"
        const val OEM_CHANNEL = "com.kinremind.app/oem_settings"
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSyncService" -> {
                        val intent = Intent(this, SyncForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopSyncService" -> {
                        stopService(Intent(this, SyncForegroundService::class.java))
                        result.success(null)
                    }
                    "isBatteryOptimizationIgnored" -> {
                        val pm = getSystemService(android.os.PowerManager::class.java)
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    else -> result.notImplemented()
                }
            }

        // OEM autostart/background-permission screens (PROJECT_SPEC.md
        // section 9) live at manufacturer-specific, undocumented component
        // names. lib/onboarding/oem_settings.dart supplies a candidate list
        // per manufacturer; this just tries each until one resolves.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchComponent" -> {
                        val packageName = call.argument<String>("package")
                        val className = call.argument<String>("activity")
                        if (packageName == null || className == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent().apply {
                                component = android.content.ComponentName(packageName, className)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
