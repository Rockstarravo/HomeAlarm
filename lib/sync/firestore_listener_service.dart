import 'dart:async';

import 'package:flutter/foundation.dart';

import '../alarms/alarm_scheduler.dart';
import '../models/reminder.dart';
import '../reminders/reminder_repository.dart';

/// The realtime half of PROJECT_SPEC.md section 4: keeps this device's
/// scheduled AlarmManager alarms in sync with whatever reminders are
/// currently active and assigned to [memberId] in Firestore, driven by an
/// open snapshot listener (not polling).
class FirestoreListenerService {
  FirestoreListenerService({ReminderRepository? repository})
      : _repository = repository ?? ReminderRepository();

  final ReminderRepository _repository;
  StreamSubscription<List<Reminder>>? _subscription;

  void start(String memberId) {
    debugPrint('[sync] FirestoreListenerService.start(memberId=$memberId)');
    _subscription?.cancel();
    _subscription = _repository.watchForMember(memberId).listen(
      _reconcile,
      onError: (Object error) {
        // offline — alarms already scheduled stay armed
        debugPrint('[sync] listener error: $error');
      },
    );
  }

  Future<void> _reconcile(List<Reminder> reminders) async {
    debugPrint('[sync] snapshot: ${reminders.length} active reminder(s) '
        'for this member: ${reminders.map((r) => '${r.id}@${r.scheduleTime}').join(', ')}');

    final stillActiveIds = reminders.map((r) => r.id).toSet();

    final previouslyScheduled = await AlarmScheduler.scheduledReminderIds();
    for (final reminderId in previouslyScheduled) {
      if (!stillActiveIds.contains(reminderId)) {
        await AlarmScheduler.cancel(reminderId);
      }
    }

    for (final reminder in reminders) {
      // schedule() always cancels-and-reschedules first (PROJECT_SPEC.md
      // section 8), so this is safe to re-run on every snapshot, including
      // ones where nothing actually changed.
      await AlarmScheduler.schedule(reminder);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
