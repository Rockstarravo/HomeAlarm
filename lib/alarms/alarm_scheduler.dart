import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';
import '../notifications/notification_service.dart';

/// Exact-alarm scheduling on AlarmManager's STREAM_ALARM channel.
///
/// Design note: `android_alarm_manager_plus` fires one shared top-level
/// callback in a background isolate and does not hand that callback the id
/// of the alarm that triggered it. Rather than lean on undocumented plugin
/// internals, every scheduled alarm is mirrored into a small local
/// SharedPreferences-backed table (reminderId -> recurrence/time/fire
/// instant). The callback wakes up, reads that table, and acts on whatever
/// is actually due — which also means a delayed wakeup (Doze, OEM
/// throttling) still resolves correctly instead of silently doing nothing.
class AlarmScheduler {
  AlarmScheduler._();

  static const _pendingKey = 'kinremind.pendingAlarms';

  /// Alarms fire for anything due within this trailing window, to absorb
  /// scheduling jitter from Doze/OEM battery management.
  static const _dueTolerance = Duration(minutes: 2);

  /// Deterministic AlarmManager id. Collisions between two reminders are an
  /// accepted MVP trade-off (see PROJECT_SPEC.md section 10 for the class of
  /// edge cases this project already accepts).
  static int alarmIdFor(String reminderId) => reminderId.hashCode & 0x7fffffff;

  static Future<void> initialize() => AndroidAlarmManager.initialize();

  /// Cancels any existing alarm for this reminder and schedules the next
  /// occurrence. Safe to call on every create/edit — PROJECT_SPEC.md section
  /// 8 requires the old alarm to be explicitly cancelled first.
  static Future<void> schedule(Reminder reminder) async {
    await cancel(reminder.id);
    final fireTime = _nextFireTime(reminder.hour, reminder.minute, DateTime.now());
    await _upsertPending(
      reminderId: reminder.id,
      recurrence: reminder.recurrence,
      hour: reminder.hour,
      minute: reminder.minute,
      fireTime: fireTime,
    );
    await _arm(reminder.id, fireTime);
  }

  static Future<void> cancel(String reminderId) async {
    await AndroidAlarmManager.cancel(alarmIdFor(reminderId));
    await _removePending(reminderId);
  }

  /// Every reminder this device currently has an alarm armed for — used by
  /// the sync listener to cancel alarms for reminders that were deleted,
  /// deactivated, or unassigned from this member.
  static Future<Set<String>> scheduledReminderIds() async {
    final pending = await _readPending();
    return pending.keys.toSet();
  }

  /// PROJECT_SPEC.md section 8: snooze cancels the current notification and
  /// reschedules a new one-shot alarm `now + duration`, indefinitely, until
  /// Dismiss is tapped. No ack is written.
  static Future<void> snooze(
    String reminderId, {
    Duration duration = const Duration(minutes: 10),
  }) async {
    final pending = await _readPending();
    final entry = pending[reminderId];
    final recurrence = entry?['recurrence'] as String? ?? ReminderRecurrence.oneTime;
    final hour = entry?['hour'] as int? ?? 0;
    final minute = entry?['minute'] as int? ?? 0;

    final fireTime = DateTime.now().add(duration);
    await AndroidAlarmManager.cancel(alarmIdFor(reminderId));
    await _upsertPending(
      reminderId: reminderId,
      recurrence: recurrence,
      hour: hour,
      minute: minute,
      fireTime: fireTime,
    );
    await _arm(reminderId, fireTime);
  }

  static Future<void> _arm(String reminderId, DateTime fireTime) {
    return AndroidAlarmManager.oneShotAt(
      fireTime,
      alarmIdFor(reminderId),
      alarmCallbackDispatcher,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
  }

  static DateTime _nextFireTime(int hour, int minute, DateTime from) {
    var candidate = DateTime(from.year, from.month, from.day, hour, minute);
    if (!candidate.isAfter(from)) {
      // PROJECT_SPEC.md edge case table: a missed time schedules the *next*
      // occurrence rather than firing immediately as catch-up.
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static Future<Map<String, Map<String, dynamic>>> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
  }

  static Future<void> _writePending(Map<String, Map<String, dynamic>> pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(pending));
  }

  static Future<void> _upsertPending({
    required String reminderId,
    required String recurrence,
    required int hour,
    required int minute,
    required DateTime fireTime,
  }) async {
    final pending = await _readPending();
    pending[reminderId] = {
      'recurrence': recurrence,
      'hour': hour,
      'minute': minute,
      'fireEpochMs': fireTime.millisecondsSinceEpoch,
    };
    await _writePending(pending);
  }

  static Future<void> _removePending(String reminderId) async {
    final pending = await _readPending();
    if (pending.remove(reminderId) != null) {
      await _writePending(pending);
    }
  }
}

/// Runs in AlarmManager's background isolate. Must stay a top-level (or
/// static) function per android_alarm_manager_plus's requirements.
@pragma('vm:entry-point')
Future<void> alarmCallbackDispatcher() async {
  final now = DateTime.now();
  final pending = await AlarmScheduler._readPending();

  for (final entry in pending.entries.toList()) {
    final reminderId = entry.key;
    final data = entry.value;
    final fireEpochMs = data['fireEpochMs'] as int;
    final dueAt = DateTime.fromMillisecondsSinceEpoch(fireEpochMs);
    if (now.isBefore(dueAt.subtract(AlarmScheduler._dueTolerance))) {
      continue; // not due yet — leave scheduled
    }

    await NotificationService.showAlarmNotification(reminderId: reminderId);

    final recurrence = data['recurrence'] as String? ?? ReminderRecurrence.oneTime;
    if (recurrence == ReminderRecurrence.daily) {
      final hour = data['hour'] as int? ?? 0;
      final minute = data['minute'] as int? ?? 0;
      final next = AlarmScheduler._nextFireTime(hour, minute, now);
      await AlarmScheduler._upsertPending(
        reminderId: reminderId,
        recurrence: recurrence,
        hour: hour,
        minute: minute,
        fireTime: next,
      );
      await AlarmScheduler._arm(reminderId, next);
    } else {
      await AlarmScheduler._removePending(reminderId);
    }
  }
}
