import 'package:flutter/material.dart';

import '../models/reminder.dart';
import 'reminder_repository.dart';

/// Read-only view for a non-owner member: what's coming, assigned to them.
/// Actual alarm scheduling happens out-of-band in lib/sync — this screen
/// only reflects Firestore state, it never schedules anything itself.
class ReminderListScreen extends StatelessWidget {
  const ReminderListScreen({
    super.key,
    required this.memberId,
    required this.repository,
  });

  final String memberId;
  final ReminderRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reminder>>(
      stream: repository.watchForMember(memberId),
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
                'No reminders yet.\nAnything set for you by your family will show up here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reminders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(reminder.title),
                subtitle: Text(
                  [
                    reminder.scheduleTime,
                    reminder.isDaily ? 'Every day' : 'One time',
                    if (reminder.notes.isNotEmpty) reminder.notes,
                  ].join(' · '),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
