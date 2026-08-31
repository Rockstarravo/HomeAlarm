/// Every magic string/number that more than one module needs to agree on,
/// in one place. If you're hunting for "what's the Firestore collection
/// called" or "how long is a snooze", it's here — not buried inside
/// whichever module happened to need it first.
///
/// Native-side (Kotlin) constants that mirror these — the two
/// MethodChannel names in particular — live in
/// android/app/src/main/kotlin/com/kinremind/app/MainActivity.kt and have
/// to be kept in sync with [ChannelNames] by hand; Dart and Kotlin can't
/// share a source of truth here.
library;

/// Firestore collection/subcollection names (PROJECT_SPEC.md section 6).
class FirestoreCollections {
  const FirestoreCollections._();

  static const members = 'members';
  static const reminders = 'reminders';
  static const acks = 'ack';
}

/// SharedPreferences keys for locally cached state.
class PrefsKeys {
  const PrefsKeys._();

  static const memberId = 'kinremind.memberId';
  static const deviceId = 'kinremind.deviceId';
  static const pendingAlarms = 'kinremind.pendingAlarms';
}

/// Platform channel names bridging Dart and the native Kotlin side. Must
/// match the `SYNC_CHANNEL` / `OEM_CHANNEL` constants in MainActivity.kt.
class ChannelNames {
  const ChannelNames._();

  static const syncService = 'com.kinremind.app/sync_service';
  static const oemSettings = 'com.kinremind.app/oem_settings';
}

/// The full-screen alarm notification's channel identity
/// (PROJECT_SPEC.md section 8).
class NotificationConfig {
  const NotificationConfig._();

  static const alarmChannelId = 'kinremind_alarm';
  static const alarmChannelName = 'Alarm reminders';
  static const alarmChannelDescription =
      'Full-screen alarm-style reminders that ring through silent mode.';

  /// Payload id for the on-demand "send test alarm" self-check (see
  /// NotificationService.showTestAlarm) — never a real Firestore document,
  /// so it's excluded from the normal Dismiss/Snooze → AlarmManager/ack
  /// handling.
  static const testReminderId = 'kinremind-test-alarm';
}

/// Timing knobs for alarm scheduling (PROJECT_SPEC.md section 8).
class AlarmConfig {
  const AlarmConfig._();

  /// How long Snooze pushes a reminder out by.
  static const snoozeDuration = Duration(minutes: 10);

  /// Alarms fire for anything due within this trailing window, to absorb
  /// scheduling jitter from Doze/OEM battery management.
  static const dueTolerance = Duration(minutes: 2);
}

/// The WorkManager safety-net task (PROJECT_SPEC.md section 4).
class HealthCheckConfig {
  const HealthCheckConfig._();

  static const taskName = 'kinremind.healthCheck';

  /// Android's enforced floor for periodic WorkManager tasks.
  static const interval = Duration(minutes: 15);
}
