import 'dart:async';

import 'package:flutter/foundation.dart';

import '../alarms/alarm_scheduler.dart';
import '../models/reminder.dart';
import '../notifications/notification_service.dart';
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
  bool _active = false;

  /// Whether the snapshot stream is currently subscribed. `false` after the
  /// stream closes on its own (it shouldn't, but see [sync_isolate_entrypoint])
  /// — the caller's supervisor loop uses this to notice and restart it.
  bool get isActive => _active;

  void start(String memberId) {
    debugPrint('[sync] FirestoreListenerService.start(memberId=$memberId)');
    _subscription?.cancel();
    _active = true;
    _subscription = _repository.watchForMember(memberId).listen(
      (reminders) {
        // `onData` exceptions are not delivered to `onError` below (that's
        // for stream errors only) and this isolate has no top-level crash
        // handler of its own — an unhandled throw here used to silently
        // kill scheduling for the rest of the process's life.
        unawaited(_reconcile(reminders).catchError((Object error, StackTrace stackTrace) {
          debugPrint('[sync] reconcile failed: $error\n$stackTrace');
        }));
      },
      onError: (Object error) {
        // Offline or a transient Firestore error — alarms already scheduled
        // stay armed, and the stream itself keeps trying to recover.
        debugPrint('[sync] listener error: $error');
      },
      onDone: () {
        debugPrint('[sync] listener stream closed unexpectedly');
        _active = false;
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

    var blockedByPermission = false;
    for (final reminder in reminders) {
      try {
        // schedule() always cancels-and-reschedules first (PROJECT_SPEC.md
        // section 8), so this is safe to re-run on every snapshot, including
        // ones where nothing actually changed.
        await AlarmScheduler.schedule(reminder);
      } on ExactAlarmPermissionException catch (e) {
        blockedByPermission = true;
        debugPrint('[sync] ${reminder.id}: $e');
      } catch (e, stackTrace) {
        // One bad reminder must not take the rest of the batch down with it.
        debugPrint('[sync] failed to schedule ${reminder.id}: $e\n$stackTrace');
      }
    }

    if (blockedByPermission) {
      await NotificationService.showSchedulingBlockedNotification();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _active = false;
  }
}
