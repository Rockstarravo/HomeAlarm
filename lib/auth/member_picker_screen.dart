import 'package:flutter/material.dart';

import '../models/member.dart';
import 'auth_service.dart';
import 'pin_entry_screen.dart';

/// First screen on a fresh install: pick your name from the seeded family
/// roster, then enter your PIN on the next screen.
class MemberPickerScreen extends StatefulWidget {
  const MemberPickerScreen({
    super.key,
    required this.authService,
    required this.onLoggedIn,
  });

  final AuthService authService;
  final ValueChanged<Member> onLoggedIn;

  @override
  State<MemberPickerScreen> createState() => _MemberPickerScreenState();
}

class _MemberPickerScreenState extends State<MemberPickerScreen> {
  late Future<List<Member>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.authService.fetchMembers();
  }

  Future<void> _retry() async {
    setState(() {
      _membersFuture = widget.authService.fetchMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Who are you?')),
      body: FutureBuilder<List<Member>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString(), onRetry: _retry);
          }
          final members = snapshot.data ?? const [];
          if (members.isEmpty) {
            return _ErrorState(
              error: 'No family members are set up yet.\n'
                  'Ask whoever deployed this app to seed the "members" '
                  'collection (see firebase/seed_members.md).',
              onRetry: _retry,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(member.name),
                  subtitle: Text(member.isOwner ? 'Owner' : 'Family member'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PinEntryScreen(
                        authService: widget.authService,
                        member: member,
                        onLoggedIn: widget.onLoggedIn,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
