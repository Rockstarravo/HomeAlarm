import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/reminder.dart';
import '../notifications/notification_service.dart';

/// Thrown by [AlarmScheduler] when the OS would silently refuse to register
/// an exact alarm because `SCHEDULE_EXACT_ALARM` is not effectively held.
///
/// This matters because `android_alarm_manager_plus` does **not** surface
/// that case: its native `AlarmService.scheduleAlarm` logs an error, skips
/// the `AlarmManager` call, and still returns success — so `oneShotAt`
/// resolves to `true` while nothing is scheduled. We check the same
/// condition ourselves and raise this instead of arming into the void.
class ExactAlarmPermissionException implements Exception {
  const ExactAlarmPermissionException();

  @override
  String toString() => 'ExactAlarmPermissionException: the "Alarms & '
      'reminders" permission is off, so AlarmManager would drop this alarm.';
}

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
    final fireTime = _nextFireTime(
      reminder.hour,
      reminder.minute,
      DateTime.now(),
      grace: AlarmConfig.dueTolerance,
      oneTime: reminder.recurrence == ReminderRecurrence.oneTime,
    );
    debugPrint('[alarms] scheduling "${reminder.title}" (${reminder.id}) '
        'next fire: $fireTime');
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
    Duration duration = AlarmConfig.snoozeDuration,
  }) async {
    final pending = await _readPending();
    final entry = pending[reminderId];
    final recurrence =
        entry?['recurrence'] as String? ?? ReminderRecurrence.oneTime;
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

  static Future<void> _arm(String reminderId, DateTime fireTime) async {
    if (!await canScheduleExactAlarms()) {
      // Fail loudly: android_alarm_manager_plus would return success here
      // while silently registering nothing (see [ExactAlarmPermissionException]).
      throw const ExactAlarmPermissionException();
    }
    final armed = await AndroidAlarmManager.oneShotAt(
      fireTime,
      alarmIdFor(reminderId),
      alarmCallbackDispatcher,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
    debugPrint('[alarms] armed reminderId=$reminderId for $fireTime -> $armed');
    if (!armed) {
      throw StateError(
          'AndroidAlarmManager.oneShotAt returned false for $reminderId');
    }
  }

  /// Mirrors the exact check `android_alarm_manager_plus` runs natively
  /// before deciding whether to register an exact alarm. On Android 12+
  /// `permission_handler` maps this to `AlarmManager.canScheduleExactAlarms()`;
  /// on older versions no permission is required and it reports granted.
  static Future<bool> canScheduleExactAlarms() async {
    final status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  /// Resolves "HH:mm" to the next concrete instant to fire at.
  ///
  /// [grace] widens "now" backwards: a candidate up to [grace] in the past
  /// still counts as due-now rather than rolling forward. This absorbs the
  /// clock skew between the owner's phone and this one, plus Firestore
  /// snapshot latency — without it, a reminder created "2 minutes from now"
  /// that lands a few seconds late is silently pushed a full day out.
  ///
  /// [oneTime] reminders have no "next occurrence", so a genuinely-late one
  /// fires almost immediately instead of vanishing until tomorrow. Recurring
  /// reminders keep the PROJECT_SPEC.md edge-case behaviour of scheduling
  /// the next occurrence rather than firing catch-up.
  static DateTime _nextFireTime(
    int hour,
    int minute,
    DateTime from, {
    Duration grace = Duration.zero,
    bool oneTime = false,
  }) {
    final candidate = DateTime(from.year, from.month, from.day, hour, minute);
    if (candidate.isAfter(from.subtract(grace))) {
      return candidate;
    }
    if (oneTime) {
      return from.add(const Duration(seconds: 5));
    }
    return candidate.add(const Duration(days: 1));
  }

  static Future<Map<String, Map<String, dynamic>>> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    // The pending table is written from the sync isolate and the health-check
    // isolate but read here from android_alarm_manager_plus's own long-lived
    // background isolate, whose SharedPreferences copy is cached at first use
    // and never re-read from disk. Without this, an alarm scheduled after that
    // isolate started firing looks absent and the callback shows nothing.
    await prefs.reload();
    final raw = prefs.getString(PrefsKeys.pendingAlarms);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
  }

  static Future<void> _writePending(
      Map<String, Map<String, dynamic>> pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.pendingAlarms, jsonEncode(pending));
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
  // AlarmManager fires this in a fresh isolate — nothing is initialized yet.
  await AlarmScheduler.initialize();

  final now = DateTime.now();
  final pending = await AlarmScheduler._readPending();
  debugPrint('[alarms] alarmCallbackDispatcher fired at $now, '
      '${pending.length} pending entr${pending.length == 1 ? 'y' : 'ies'}');

  for (final entry in pending.entries.toList()) {
    final reminderId = entry.key;
    final data = entry.value;
    try {
      final fireEpochMs = data['fireEpochMs'] as int;
      final dueAt = DateTime.fromMillisecondsSinceEpoch(fireEpochMs);
      if (now.isBefore(dueAt.subtract(AlarmConfig.dueTolerance))) {
        debugPrint('[alarms] $reminderId not due until $dueAt, skipping');
        continue; // not due yet — leave scheduled
      }

      debugPrint('[alarms] $reminderId is due, showing notification');
      await NotificationService.showAlarmNotification(reminderId: reminderId);

      final recurrence =
          data['recurrence'] as String? ?? ReminderRecurrence.oneTime;
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
    } catch (e) {
      debugPrint('[alarms] error processing $reminderId: $e');
    }
  }
}
