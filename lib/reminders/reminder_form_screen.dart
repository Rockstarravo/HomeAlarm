import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/reminder.dart';
import 'reminder_repository.dart';

/// Owner-only create/edit form. Writes go straight to Firestore; each
/// target member's own device schedules (or cancels/reschedules) the
/// AlarmManager alarm from its own sync listener — this screen never talks
/// to AlarmManager directly.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({
    super.key,
    required this.repository,
    required this.members,
    required this.currentMemberId,
    this.existing,
  });

  final ReminderRepository repository;
  final List<Member> members;
  final String currentMemberId;
  final Reminder? existing;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TimeOfDay _time;
  late String _recurrence;
  late Set<String> _targetMemberIds;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _time = existing != null
        ? TimeOfDay(hour: existing.hour, minute: existing.minute)
        : TimeOfDay.now();
    _recurrence = existing?.recurrence ?? ReminderRecurrence.daily;
    _targetMemberIds = {...(existing?.targetMemberIds ?? const [])};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _scheduleTime =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one family member.')),
      );
      return;
    }

    setState(() => _saving = true);

    final reminder = Reminder(
      id: widget.existing?.id ?? '',
      title: _titleController.text.trim(),
      notes: _notesController.text.trim(),
      scheduleTime: _scheduleTime,
      recurrence: _recurrence,
      targetMemberIds: _targetMemberIds.toList(),
      createdBy: widget.existing?.createdBy ?? widget.currentMemberId,
      isActive: widget.existing?.isActive ?? true,
    );

    if (_isEditing) {
      await widget.repository.update(reminder);
    } else {
      await widget.repository.create(reminder);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit reminder' : 'New reminder')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const Divider(),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Every day'),
              value: ReminderRecurrence.daily,
              groupValue: _recurrence,
              onChanged: (value) => setState(() => _recurrence = value!),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('One time'),
              value: ReminderRecurrence.oneTime,
              groupValue: _recurrence,
              onChanged: (value) => setState(() => _recurrence = value!),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Remind', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...widget.members.map(
              (member) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(member.name),
                value: _targetMemberIds.contains(member.id),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _targetMemberIds.add(member.id);
                  } else {
                    _targetMemberIds.remove(member.id);
                  }
                }),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
