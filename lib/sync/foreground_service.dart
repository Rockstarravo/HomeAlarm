import 'package:flutter/services.dart';

/// Dart-side handle for the native `SyncForegroundService`
/// (android/app/src/main/kotlin/com/kinremind/app/SyncForegroundService.kt),
/// which hosts the headless Firestore listener described in
/// PROJECT_SPEC.md section 4. Started once onboarding completes, and again
/// on every app resume in case Android killed it.
class ForegroundSyncService {
  ForegroundSyncService._();

  static const _channel = MethodChannel('com.kinremind.app/sync_service');

  static Future<void> start() => _channel.invokeMethod('startSyncService');

  static Future<void> stop() => _channel.invokeMethod('stopSyncService');

  static Future<bool> isBatteryOptimizationIgnored() async {
    final result =
        await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
    return result ?? false;
  }
}
