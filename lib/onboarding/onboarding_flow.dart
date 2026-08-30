import 'package:flutter/material.dart';

import 'oem_settings.dart';
import 'permission_service.dart';

/// First-launch permission wizard (PROJECT_SPEC.md section 9). The app is
/// not considered "ready" until every step here has been satisfied at
/// least once; main.dart re-runs the same checks (without this UI) on
/// every resume and routes back here if something was revoked.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.permissionService,
    required this.onComplete,
  });

  final PermissionService permissionService;
  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { notifications, exactAlarm, battery, oem, done }

class _OnboardingFlowState extends State<OnboardingFlow> with WidgetsBindingObserver {
  _Step _step = _Step.notifications;
  bool _needsOemStep = false;
  String? _oemLabel;
  bool _checkingOem = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OemSettings.needsOemStep().then((needed) async {
      final label = needed ? await OemSettings.manufacturerLabel() : null;
      if (!mounted) return;
      setState(() {
        _needsOemStep = needed;
        _oemLabel = label;
        _checkingOem = false;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check the current step's permission when returning from the
    // Settings app the step just deep-linked to.
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  void _advance() {
    setState(() {
      switch (_step) {
        case _Step.notifications:
          _step = _Step.exactAlarm;
          break;
        case _Step.exactAlarm:
          _step = _Step.battery;
          break;
        case _Step.battery:
          _step = _needsOemStep ? _Step.oem : _Step.done;
          break;
        case _Step.oem:
          _step = _Step.done;
          break;
        case _Step.done:
          break;
      }
    });
    if (_step == _Step.done) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOem) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_step) {
      case _Step.notifications:
        return _PermissionStep(
          icon: Icons.notifications_active,
          title: 'Allow notifications',
          body: 'KinRemind rings reminders as full-screen alarm-style notifications, '
              'even through silent mode. Without this permission it can\'t ring at all.',
          buttonLabel: 'Allow notifications',
          onPressed: () async {
            await widget.permissionService.requestNotificationPermission();
            _advance();
          },
        );
      case _Step.exactAlarm:
        return _PermissionStep(
          icon: Icons.alarm,
          title: 'Allow exact alarms',
          body: 'Reminders need to ring at the exact minute they\'re set for, '
              'not "sometime around then". Android calls this permission '
              '"Alarms & reminders".',
          buttonLabel: 'Allow exact alarms',
          onPressed: () async {
            await widget.permissionService.requestExactAlarmPermission();
            _advance();
          },
        );
      case _Step.battery:
        return _PermissionStep(
          icon: Icons.battery_charging_full,
          title: 'Disable battery optimization',
          body: 'This keeps KinRemind\'s background sync alive so reminders '
              'created by your family reach this phone in real time.',
          buttonLabel: 'Disable battery optimization',
          onPressed: () async {
            await widget.permissionService.requestBatteryOptimizationExemption();
            _advance();
          },
        );
      case _Step.oem:
        return _PermissionStep(
          icon: Icons.phone_android,
          title: '${_oemLabel ?? 'Your phone'} needs one more step',
          body: '${_oemLabel ?? 'This phone\'s'} manufacturer aggressively kills '
              'background apps unless you allow "autostart" for KinRemind. '
              'You\'ll be taken to that settings screen next — turn KinRemind on there.',
          buttonLabel: 'Open autostart settings',
          onPressed: () async {
            await OemSettings.openAutostartSettings();
            _advance();
          },
        );
      case _Step.done:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
