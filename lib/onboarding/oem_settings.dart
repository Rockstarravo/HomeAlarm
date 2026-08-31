import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';

class _OemTarget {
  const _OemTarget(this.package, this.activity);
  final String package;
  final String activity;
}

/// PROJECT_SPEC.md section 9: stock Android's battery-optimization
/// exemption is not enough on these OEM skins — they each ship their own,
/// undocumented "autostart" / "background permission" screen that also has
/// to be granted, or the app gets killed anyway. Component names are the
/// commonly cited ones for each ROM family; ROM updates can move them, so
/// several candidates are tried per manufacturer, falling back to the
/// app's own system settings page if none resolve.
class OemSettings {
  OemSettings._();

  static const _channel = MethodChannel(ChannelNames.oemSettings);

  static const Map<String, List<_OemTarget>> _targetsByManufacturer = {
    'xiaomi': [
      _OemTarget('com.miui.securitycenter',
          'com.miui.permcenter.autostart.AutoStartManagementActivity'),
    ],
    'oppo': [
      _OemTarget('com.coloros.safecenter',
          'com.coloros.safecenter.startupapp.StartupAppListActivity'),
      _OemTarget('com.coloros.safecenter',
          'com.coloros.safecenter.permission.startup.StartupAppListActivity'),
      _OemTarget('com.oppo.safe',
          'com.oppo.safe.permission.startup.StartupAppListActivity'),
    ],
    'vivo': [
      _OemTarget('com.vivo.permissionmanager',
          'com.vivo.permissionmanager.activity.BgStartUpManagerActivity'),
      _OemTarget('com.iqoo.secure',
          'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'),
    ],
    'huawei': [
      _OemTarget('com.huawei.systemmanager',
          'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity'),
      _OemTarget('com.huawei.systemmanager',
          'com.huawei.systemmanager.optimize.process.ProtectActivity'),
    ],
    'honor': [
      _OemTarget('com.huawei.systemmanager',
          'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity'),
    ],
    'oneplus': [
      _OemTarget('com.oneplus.security',
          'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity'),
    ],
    'samsung': [
      _OemTarget('com.samsung.android.lool',
          'com.samsung.android.sm.ui.battery.BatteryActivity'),
    ],
    'asus': [
      _OemTarget('com.asus.mobilemanager',
          'com.asus.mobilemanager.autostart.AutoStartActivity'),
    ],
    'letv': [
      _OemTarget('com.letv.android.letvsafe',
          'com.letv.android.letvsafe.AutobootManageActivity'),
    ],
  };

  /// True if this manufacturer is known to need an extra background/
  /// autostart screen beyond the standard battery-optimization dialog.
  static Future<bool> needsOemStep() async {
    final manufacturer = await _manufacturer();
    return _targetsByManufacturer.containsKey(manufacturer);
  }

  static Future<String?> manufacturerLabel() async {
    final manufacturer = await _manufacturer();
    if (manufacturer == null) return null;
    if (!_targetsByManufacturer.containsKey(manufacturer)) return null;
    return manufacturer[0].toUpperCase() + manufacturer.substring(1);
  }

  /// Tries each known component for this manufacturer in turn; falls back
  /// to the app's own detail settings page if none of them resolve.
  static Future<void> openAutostartSettings() async {
    final manufacturer = await _manufacturer();
    final targets = _targetsByManufacturer[manufacturer] ?? const [];

    for (final target in targets) {
      final launched = await _tryLaunch(target);
      if (launched) return;
    }

    await openAppSettings();
  }

  static Future<bool> _tryLaunch(_OemTarget target) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchComponent', {
        'package': target.package,
        'activity': target.activity,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> _manufacturer() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.manufacturer.toLowerCase();
    } catch (_) {
      return null;
    }
  }
}
