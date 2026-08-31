import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../core/widgets/error_state_view.dart';
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
            return ErrorStateView(
                message: snapshot.error.toString(), onRetry: _retry);
          }
          final members = snapshot.data ?? const [];
          if (members.isEmpty) {
            return ErrorStateView(
              message: 'No family members are set up yet.\n'
                  'Ask whoever deployed this app to seed the "members" '
                  'collection (see firebase/seed_members.md).',
              onRetry: _retry,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(member.name),
                  subtitle: Text(member.isOwner ? 'Owner' : 'Family member'),
                  trailing: const Icon(AppIcons.chevronForward),
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
