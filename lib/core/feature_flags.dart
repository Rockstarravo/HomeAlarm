/// One-line on/off switches for the genuinely *optional* layers of the
/// app — the reliability nets and extras wrapped around the core flow of
/// "log in, see reminders, get an alarm". If a module misbehaves on a
/// specific device (or you just want to isolate whether it's the cause of
/// a bug), flip its flag to `false`, hot-restart, and that layer is gone
/// without touching any other file.
///
/// The core spine is deliberately **not** flagged here: static login
/// (lib/auth), reminder CRUD (lib/reminders), AlarmManager scheduling
/// (lib/alarms), and the alarm notification itself (lib/notifications).
/// The app has no purpose without those, so making them "toggleable"
/// would just be a way to break the app, not to triage it. See
/// docs/03-modules.md for the full module map and what to do if one of
/// those core pieces is the thing that's broken.
class FeatureFlags {
  const FeatureFlags._();

  /// 15-minute WorkManager reconciliation safety net (lib/health,
  /// PROJECT_SPEC.md section 4). Turning this off only removes the safety
  /// net — the primary event-driven Firestore listener in lib/sync keeps
  /// scheduling alarms exactly as before.
  static const bool healthCheckEnabled = true;

  /// The manufacturer-specific "open autostart settings" step in
  /// onboarding (lib/onboarding/oem_settings.dart, PROJECT_SPEC.md
  /// section 9). Turning this off skips straight from the
  /// battery-optimization step to done — useful if a ROM update moves the
  /// OEM settings screen this app tries to deep-link to and it starts
  /// opening the wrong thing.
  static const bool oemAutostartStepEnabled = true;

  /// The native foreground service that holds the background Firestore
  /// listener alive (lib/sync/foreground_service.dart, PROJECT_SPEC.md
  /// section 4). Turning this off means reminders only sync while the app
  /// is open in the foreground — a useful triage step if the foreground
  /// service itself turns out to be what's crashing or draining battery
  /// on a given device.
  static const bool foregroundSyncEnabled = true;
}
