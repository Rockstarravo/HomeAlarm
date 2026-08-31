import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';

import '../alarms/alarm_scheduler.dart';
import '../auth/auth_service.dart';
import '../core/constants.dart';
import '../reminders/reminder_repository.dart';

/// PROJECT_SPEC.md section 4: the *only* true polling in this system, and
/// explicitly a safety net rather than the primary sync path. Every 15
/// minutes (Android's enforced floor for periodic WorkManager tasks) this
/// re-derives "what should be scheduled" from Firestore and reconciles it
/// against what's actually armed, catching anything the event-driven
/// listener missed — a snapshot that arrived while the process was dying, a
/// silently-killed foreground service, etc.
class HealthCheckWorker {
  HealthCheckWorker._();

  static Future<void> register() async {
    await Workmanager().initialize(healthCheckCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      HealthCheckConfig.taskName,
      HealthCheckConfig.taskName,
      frequency: HealthCheckConfig.interval,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

@pragma('vm:entry-point')
void healthCheckCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await AlarmScheduler.initialize();

    final memberId = await AuthService().getCachedMemberId();
    if (memberId == null) return true;

    final reminders = await ReminderRepository().watchForMember(memberId).first;
    final activeIds = reminders.map((r) => r.id).toSet();
    final scheduledIds = await AlarmScheduler.scheduledReminderIds();

    for (final reminderId in scheduledIds) {
      if (!activeIds.contains(reminderId)) {
        await AlarmScheduler.cancel(reminderId);
      }
    }
    for (final reminder in reminders) {
      if (!scheduledIds.contains(reminder.id)) {
        await AlarmScheduler.schedule(reminder);
      }
    }

    return true;
  });
}
