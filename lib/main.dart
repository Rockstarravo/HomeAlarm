import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'alarms/alarm_scheduler.dart';
import 'auth/auth_service.dart';
import 'auth/member_picker_screen.dart';
import 'health/health_check_worker.dart';
import 'models/member.dart';
import 'notifications/notification_service.dart';
import 'onboarding/onboarding_flow.dart';
import 'onboarding/permission_service.dart';
import 'reminders/owner_dashboard_screen.dart';
import 'reminders/reminder_list_screen.dart';
import 'reminders/reminder_repository.dart';
import 'sync/foreground_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No `firebase_options.dart` import here on purpose: this is an
  // Android-only MVP (PROJECT_SPEC.md section 3), so the Android SDK's own
  // `google-services.json`-derived default options are enough. Run
  // `flutterfire configure` per README if you also want the generated
  // options file for future iOS support.
  await Firebase.initializeApp();

  await AlarmScheduler.initialize();
  await NotificationService.initialize();
  await HealthCheckWorker.register();

  runApp(const KinRemindApp());
}

class KinRemindApp extends StatelessWidget {
  const KinRemindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KinRemind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3F51B5), useMaterial3: true),
      home: const RootGate(),
    );
  }
}

/// Owns the top-level flow: static login -> permission onboarding -> home.
/// PROJECT_SPEC.md section 9 requires permissions to be re-verified on
/// every resume, not just at first launch, so this widget stays mounted for
/// the whole app lifetime and watches [WidgetsBindingObserver].
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  final _authService = AuthService();
  final _permissionService = PermissionService();

  bool _loading = true;
  Member? _member;
  bool _permissionsOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _member != null) {
      _recheckPermissions();
    }
  }

  Future<void> _bootstrap() async {
    final member = await _authService.getCachedMember();
    if (member != null) {
      final ok = await _permissionService.allGranted();
      if (ok) await ForegroundSyncService.start();
      if (!mounted) return;
      setState(() {
        _member = member;
        _permissionsOk = ok;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _recheckPermissions() async {
    final ok = await _permissionService.allGranted();
    if (ok) await ForegroundSyncService.start();
    if (!mounted) return;
    setState(() => _permissionsOk = ok);
  }

  void _onLoggedIn(Member member) {
    setState(() => _member = member);
    _recheckPermissions();
  }

  void _onOnboardingComplete() {
    setState(() => _permissionsOk = true);
    ForegroundSyncService.start();
  }

  void _onLogout() {
    _authService.logout();
    setState(() {
      _member = null;
      _permissionsOk = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_member == null) {
      return MemberPickerScreen(
          authService: _authService, onLoggedIn: _onLoggedIn);
    }

    if (!_permissionsOk) {
      return OnboardingFlow(
        permissionService: _permissionService,
        onComplete: _onOnboardingComplete,
      );
    }

    return HomeShell(
        member: _member!, authService: _authService, onLogout: _onLogout);
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.member,
    required this.authService,
    required this.onLogout,
  });

  final Member member;
  final AuthService authService;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _repository = ReminderRepository();
  late Future<List<Member>> _membersFuture;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.authService.fetchMembers();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.member.isOwner;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner && _tabIndex == 1
            ? 'Manage reminders'
            : 'Hi, ${widget.member.name}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: FutureBuilder<List<Member>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data!;
          if (!isOwner || _tabIndex == 0) {
            return ReminderListScreen(
                memberId: widget.member.id, repository: _repository);
          }
          return OwnerDashboardScreen(
            repository: _repository,
            members: members,
            currentMemberId: widget.member.id,
          );
        },
      ),
      bottomNavigationBar: isOwner
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (index) =>
                  setState(() => _tabIndex = index),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.list_alt), label: 'My reminders'),
                NavigationDestination(
                    icon: Icon(Icons.edit_calendar), label: 'Manage'),
              ],
            )
          : null,
    );
  }
}
