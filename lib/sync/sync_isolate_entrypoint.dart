import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../alarms/alarm_scheduler.dart';
import '../auth/auth_service.dart';
import '../core/feature_flags.dart';
import '../notifications/notification_service.dart';
import 'firestore_listener_service.dart';

/// How often the supervisor below re-checks which member it should be
/// listening for. Cheap (one SharedPreferences read) and only needs to be
/// fast enough that a login lands within a few seconds of completing.
const _supervisorInterval = Duration(seconds: 15);

/// Entry point for the headless FlutterEngine that
/// `SyncForegroundService.kt` boots on a background isolate. Everything
/// this needs (Firebase, the alarm callback dispatcher, notification
/// channel) has to be (re-)initialized here — it does not share state with
/// the main UI isolate.
@pragma('vm:entry-point')
Future<void> syncEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This isolate has no crash reporter and nobody awaits it — an uncaught
  // error here used to mean "the sync pipeline is dead until the process is
  // killed and restarted" with zero visible sign of it. Log instead of
  // losing it silently.
  runZonedGuarded(_runSync, (error, stackTrace) {
    debugPrint('[sync] FATAL uncaught error, sync isolate is degraded: '
        '$error\n$stackTrace');
  });
}

Future<void> _runSync() async {
  debugPrint('[sync] syncEntrypoint() started');

  if (!FeatureFlags.foregroundSyncEnabled) {
    // The native service (started from Kotlin on boot/app launch) doesn't
    // know about this Dart-side flag, so it still shows its persistent
    // notification — but bailing out here means it does no listener/alarm
    // work while the flag is off. Fully removing the native service too
    // is a manifest/Kotlin change; see docs/03-modules.md.
    debugPrint('[sync] foregroundSyncEnabled is false, bailing out');
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  await AlarmScheduler.initialize();
  await NotificationService.initialize();
  debugPrint('[sync] Firebase/AlarmScheduler/NotificationService ready');

  final listener = FirestoreListenerService();
  String? activeMemberId;

  Future<void> ensureListenerRunning() async {
    final memberId = await AuthService().getCachedMemberId();

    if (memberId == null) {
      if (activeMemberId != null) {
        debugPrint('[sync] no cached member (logged out?), stopping listener');
        await listener.dispose();
        activeMemberId = null;
      }
      return;
    }

    // (Re-)start whenever the logged-in member changed since we last
    // checked, or the previous listener's stream died. `SyncForegroundService`
    // only ever runs this isolate once per process (its native `onCreate`/
    // `onStartCommand` both no-op if the engine already exists) — without
    // this periodic self-check, a login that completes *after* this isolate's
    // first pass (the common case: onboarding starts the service, but a
    // fresh install logs in and finishes onboarding, both after that point)
    // would never get a listener at all for the lifetime of the process.
    if (memberId != activeMemberId || !listener.isActive) {
      debugPrint('[sync] starting Firestore listener for memberId=$memberId '
          '(was $activeMemberId)');
      listener.start(memberId);
      activeMemberId = memberId;
    }
  }

  await ensureListenerRunning();
  Timer.periodic(_supervisorInterval, (_) => ensureListenerRunning());
}
