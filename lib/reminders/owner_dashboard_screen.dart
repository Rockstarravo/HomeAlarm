import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/reminder.dart';
import 'reminder_form_screen.dart';
import 'reminder_repository.dart';

/// Owner's CRUD view: every reminder in the family, regardless of who it's
/// assigned to, with per-member ack status.
class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({
    super.key,
    required this.repository,
    required this.members,
    required this.currentMemberId,
  });

  final ReminderRepository repository;
  final List<Member> members;
  final String currentMemberId;

  String _memberName(String id) {
    for (final member in members) {
      if (member.id == id) return member.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Reminder>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reminders = snapshot.data!;
          if (reminders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No reminders yet.\nTap + to create one for your family.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: reminders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return Card(
                child: ListTile(
                  leading: Icon(reminder.isActive ? Icons.alarm_on : Icons.alarm_off),
                  title: Text(reminder.title),
                  subtitle: Text(
                    [
                      reminder.scheduleTime,
                      reminder.isDaily ? 'Every day' : 'One time',
                      'For: ${reminder.targetMemberIds.map(_memberName).join(', ')}',
                    ].join(' · '),
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: reminder.isActive,
                    onChanged: (value) => repository.setActive(reminder.id, value),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReminderFormScreen(
                        repository: repository,
                        members: members,
                        currentMemberId: currentMemberId,
                        existing: reminder,
                      ),
                    ),
                  ),
                  onLongPress: () => _confirmDelete(context, reminder),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReminderFormScreen(
              repository: repository,
              members: members,
              currentMemberId: currentMemberId,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('"${reminder.title}" will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.delete(reminder.id);
    }
  }
}
