import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/reminder.dart';

/// Thin Firestore wrapper for the `reminders` collection and its per-member
/// `ack` subcollection (PROJECT_SPEC.md section 6).
class ReminderRepository {
  ReminderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reminders =>
      _firestore.collection(FirestoreCollections.reminders);

  /// Every reminder, for the owner's dashboard.
  Stream<List<Reminder>> watchAll() {
    return _reminders.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Reminder.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime)),
        );
  }

  /// Active reminders assigned to [memberId] — what a non-owner device's
  /// sync listener schedules alarms from, and what the member's own list
  /// screen shows.
  Stream<List<Reminder>> watchForMember(String memberId) {
    return _reminders
        .where('targetMemberIds', arrayContains: memberId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Reminder.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime)),
        );
  }

  Future<String> create(Reminder reminder) async {
    final doc = await _reminders.add(reminder.toFirestore());
    return doc.id;
  }

  Future<void> update(Reminder reminder) {
    return _reminders.doc(reminder.id).set(reminder.toFirestore());
  }

  Future<void> setActive(String reminderId, bool isActive) {
    return _reminders.doc(reminderId).update({'isActive': isActive});
  }

  Future<void> delete(String reminderId) {
    return _reminders.doc(reminderId).delete();
  }

  /// Live ack status per member, for the owner's dashboard.
  Stream<Map<String, ReminderAck>> watchAcks(String reminderId) {
    return _reminders
        .doc(reminderId)
        .collection(FirestoreCollections.acks)
        .snapshots()
        .map((snapshot) {
      final acks = <String, ReminderAck>{};
      for (final doc in snapshot.docs) {
        acks[doc.id] = ReminderAck.fromFirestore(doc.id, doc.data());
      }
      return acks;
    });
  }
}
