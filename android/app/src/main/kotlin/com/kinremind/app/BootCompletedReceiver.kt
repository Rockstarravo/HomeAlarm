package com.kinremind.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * PROJECT_SPEC.md section 4 / edge case table: AlarmManager alarms don't
 * survive a reboot, so on BOOT_COMPLETED (and MY_PACKAGE_REPLACED, which
 * fires after the APK is updated) restart [SyncForegroundService], which
 * boots the headless Dart isolate that re-pulls active reminders from
 * Firestore and re-registers alarms for this member.
 *
 * Only runs if the member has already completed onboarding — that state
 * lives in Dart-side SharedPreferences and is checked by the headless
 * isolate itself before doing any work, so this receiver stays a thin,
 * unconditional trigger.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val serviceIntent = Intent(context, SyncForegroundService::class.java)
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
