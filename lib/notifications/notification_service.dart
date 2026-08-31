import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../alarms/alarm_scheduler.dart';
import '../auth/auth_service.dart';
import '../core/constants.dart';
import '../models/reminder.dart';

/// Full-screen, alarm-style notification with Dismiss / Snooze actions
/// (PROJECT_SPEC.md section 8). Action taps are handled entirely inside this
/// service so they work even if the app process has been fully killed — see
/// [notificationBackgroundDispatcher], which flutter_local_notifications
/// runs in its own background isolate.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) =>
          handleNotificationAction(response),
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundDispatcher,
    );

    const channel = AndroidNotificationChannel(
      NotificationConfig.alarmChannelId,
      NotificationConfig.alarmChannelName,
      description: NotificationConfig.alarmChannelDescription,
      importance: Importance.max,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Fires from [alarmCallbackDispatcher] when a reminder is due. Looks up
  /// the reminder's title/notes fresh from Firestore so an edit made after
  /// the alarm was scheduled is still reflected; falls back to a generic
  /// message if the device is offline at that moment.
  static Future<void> showAlarmNotification(
      {required String reminderId}) async {
    await initialize();

    var title = 'Reminder';
    var body = 'Tap to open KinRemind';
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.reminders)
          .doc(reminderId)
          .get();
      final data = doc.data();
      if (data != null) {
        final reminder = Reminder.fromFirestore(reminderId, data);
        title = reminder.title.isEmpty ? title : reminder.title;
        body = reminder.notes.isEmpty ? body : reminder.notes;
      }
    } catch (_) {
      // Offline — still ring with the generic text rather than staying silent.
    }

    await _plugin.show(
      _notificationIdFor(reminderId),
      title,
      body,
      _alarmNotificationDetails(includeSnooze: true),
      payload: reminderId,
    );
  }

  /// Rings the exact same full-screen alarm a real reminder would, right
  /// now, with no Firestore reminder involved. Lets a member confirm their
  /// phone actually rings through silent mode as soon as they finish
  /// onboarding, instead of waiting — and hoping — for the next real
  /// scheduled reminder. Its Dismiss action just clears the notification;
  /// see [handleNotificationAction].
  static Future<void> showTestAlarm() async {
    await initialize();
    await _plugin.show(
      _notificationIdFor(NotificationConfig.testReminderId),
      'Test alarm',
      'This is what a KinRemind reminder looks and sounds like. '
          'Tap Dismiss to clear it.',
      _alarmNotificationDetails(includeSnooze: false),
      payload: NotificationConfig.testReminderId,
    );
  }

  static NotificationDetails _alarmNotificationDetails({
    required bool includeSnooze,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationConfig.alarmChannelId,
        NotificationConfig.alarmChannelName,
        channelDescription: NotificationConfig.alarmChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        actions: [
          if (includeSnooze)
            const AndroidNotificationAction('snooze', 'Snooze 10m',
                showsUserInterface: false),
          const AndroidNotificationAction('dismiss', 'Dismiss',
              showsUserInterface: false, cancelNotification: true),
        ],
      ),
    );
  }

  /// Dismiss: cancel the pending alarm and write `ack.status = "done"`.
  static Future<void> dismiss({required String reminderId}) async {
    await _plugin.cancel(_notificationIdFor(reminderId));
    await AlarmScheduler.cancel(reminderId);
    await _writeAck(reminderId, AckStatus.done);
  }

  /// Snooze: cancel only the notification, reschedule +10 min. No ack is
  /// written — the reminder stays "pending" in the owner's view.
  static Future<void> requestSnooze({required String reminderId}) async {
    await _plugin.cancel(_notificationIdFor(reminderId));
    await AlarmScheduler.snooze(reminderId);
  }

  static int _notificationIdFor(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  static Future<void> _writeAck(String reminderId, AckStatus status) async {
    final memberId = await AuthService().getCachedMemberId();
    if (memberId == null) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.reminders)
        .doc(reminderId)
        .collection(FirestoreCollections.acks)
        .doc(memberId)
        .set(ReminderAck(memberId: memberId, status: status).toFirestore());
  }
}

Future<void> handleNotificationAction(NotificationResponse response) async {
  final reminderId = response.payload;
  if (reminderId == null || reminderId.isEmpty) return;

  if (reminderId == NotificationConfig.testReminderId) {
    // Never a real reminder — just clear it, no AlarmManager/Firestore.
    await NotificationService._plugin
        .cancel(NotificationService._notificationIdFor(reminderId));
    return;
  }

  switch (response.actionId) {
    case 'dismiss':
      await NotificationService.dismiss(reminderId: reminderId);
      break;
    case 'snooze':
      await NotificationService.requestSnooze(reminderId: reminderId);
      break;
    default:
      // Plain tap on the notification body — the plugin's own content
      // intent already brings MainActivity to the foreground.
      break;
  }
}

/// Runs the action handler in a background isolate when the app process has
/// been fully killed (PROJECT_SPEC.md section 8).
@pragma('vm:entry-point')
void notificationBackgroundDispatcher(NotificationResponse response) {
  handleNotificationAction(response);
}
