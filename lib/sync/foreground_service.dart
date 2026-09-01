import 'dart:ui';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import 'sync_isolate_entrypoint.dart';

/// Dart-side handle for the native `SyncForegroundService`
/// (android/app/src/main/kotlin/com/kinremind/app/SyncForegroundService.kt),
/// which hosts the headless Firestore listener described in
/// PROJECT_SPEC.md section 4. Started once onboarding completes, and again
/// on every app resume in case Android killed it.
class ForegroundSyncService {
  ForegroundSyncService._();

  static const _channel = MethodChannel(ChannelNames.syncService);

  static Future<void> start() async {
    // A plain named DartEntrypoint (library URI + function name) only
    // resolves lib/main.dart's own library in a compiled build — the native
    // side used to try that for syncEntrypoint() and it failed outright
    // ("Dart_LookupLibrary: ... not found", "Could not create root isolate"),
    // so the headless engine never ran anything. The callback-handle
    // mechanism below is what actually works for a non-main entrypoint
    // (it's what android_alarm_manager_plus/workmanager use themselves);
    // the handle has to be computed here, in a live Dart isolate, and handed
    // to the native side to persist — a fresh headless engine can't call
    // back into Dart to ask for it before it has run anything.
    final handle = PluginUtilities.getCallbackHandle(syncEntrypoint);
    if (handle == null) {
      throw StateError(
          'syncEntrypoint must be a top-level/static function to get a callback handle');
    }
    await _channel.invokeMethod('setSyncCallbackHandle', handle.toRawHandle());
    await _channel.invokeMethod('startSyncService');
  }

  static Future<void> stop() => _channel.invokeMethod('stopSyncService');

  static Future<bool> isBatteryOptimizationIgnored() async {
    final result =
        await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
    return result ?? false;
  }
}
