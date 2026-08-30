import 'package:cloud_firestore/cloud_firestore.dart';

/// Recurrence is stored as a free-form string so the schema can grow into
/// full RRULE support later (see PROJECT_SPEC.md section 14 roadmap)
/// without a migration. MVP only ever writes/reads the two constants below.
class ReminderRecurrence {
  static const String daily = 'daily';
  static const String oneTime = 'one_time';
}

class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.notes,
    required this.scheduleTime,
    required this.recurrence,
    required this.targetMemberIds,
    required this.createdBy,
    required this.isActive,
  });

  final String id;
  final String title;
  final String notes;

  /// "HH:mm", 24-hour, interpreted in the *reading* device's local timezone
  /// (PROJECT_SPEC.md section 10 — locked decision, not the owner's).
  final String scheduleTime;

  final String recurrence;
  final List<String> targetMemberIds;
  final String createdBy;
  final bool isActive;

  bool get isDaily => recurrence == ReminderRecurrence.daily;

  int get hour => int.parse(scheduleTime.split(':')[0]);
  int get minute => int.parse(scheduleTime.split(':')[1]);

  factory Reminder.fromFirestore(String id, Map<String, dynamic> data) {
    return Reminder(
      id: id,
      title: data['title'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      scheduleTime: data['scheduleTime'] as String? ?? '00:00',
      recurrence: data['recurrence'] as String? ?? ReminderRecurrence.oneTime,
      targetMemberIds: List<String>.from(
        data['targetMemberIds'] as List<dynamic>? ?? const [],
      ),
      createdBy: data['createdBy'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  factory Reminder.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Reminder.fromFirestore(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'notes': notes,
      'scheduleTime': scheduleTime,
      'recurrence': recurrence,
      'targetMemberIds': targetMemberIds,
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  Reminder copyWith({
    String? title,
    String? notes,
    String? scheduleTime,
    String? recurrence,
    List<String>? targetMemberIds,
    bool? isActive,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      recurrence: recurrence ?? this.recurrence,
      targetMemberIds: targetMemberIds ?? this.targetMemberIds,
      createdBy: createdBy,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum AckStatus { pending, done }

AckStatus ackStatusFromString(String value) {
  return value == 'done' ? AckStatus.done : AckStatus.pending;
}

String ackStatusToString(AckStatus status) {
  return status == AckStatus.done ? 'done' : 'pending';
}

class ReminderAck {
  const ReminderAck({
    required this.memberId,
    required this.status,
    this.timestamp,
  });

  final String memberId;
  final AckStatus status;
  final DateTime? timestamp;

  factory ReminderAck.fromFirestore(String memberId, Map<String, dynamic> data) {
    final ts = data['timestamp'];
    return ReminderAck(
      memberId: memberId,
      status: ackStatusFromString(data['status'] as String? ?? 'pending'),
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': ackStatusToString(status),
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
