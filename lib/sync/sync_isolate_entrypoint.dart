import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../alarms/alarm_scheduler.dart';
import '../auth/auth_service.dart';
import '../notifications/notification_service.dart';
import 'firestore_listener_service.dart';

/// Entry point for the headless FlutterEngine that
/// `SyncForegroundService.kt` boots on a background isolate. Everything
/// this needs (Firebase, the alarm callback dispatcher, notification
/// channel) has to be (re-)initialized here — it does not share state with
/// the main UI isolate.
@pragma('vm:entry-point')
Future<void> syncEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  await AlarmScheduler.initialize();
  await NotificationService.initialize();

  final memberId = await AuthService().getCachedMemberId();
  if (memberId == null) {
    // Onboarding hasn't picked a member yet — nothing to sync.
    return;
  }

  // Kept alive by the foreground service's own lifecycle; the listener
  // subscription is what keeps this isolate doing useful work.
  FirestoreListenerService().start(memberId);
}
