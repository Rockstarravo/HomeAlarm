import 'package:permission_handler/permission_handler.dart';

/// PROJECT_SPEC.md section 9: the three permissions the app cannot function
/// reliably without. Re-checked on every app resume, not just at first
/// launch, since the OS (or the user) can revoke any of these silently
/// later.
class PermissionService {
  Future<bool> hasNotificationPermission() async {
    return Permission.notification.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> hasExactAlarmPermission() async {
    return Permission.scheduleExactAlarm.isGranted;
  }

  Future<bool> requestExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  Future<bool> hasBatteryOptimizationExemption() async {
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// All three, for the app-resume re-check (PROJECT_SPEC.md section 9).
  Future<bool> allGranted() async {
    final notifications = await hasNotificationPermission();
    final exactAlarm = await hasExactAlarmPermission();
    final battery = await hasBatteryOptimizationExemption();
    return notifications && exactAlarm && battery;
  }
}
