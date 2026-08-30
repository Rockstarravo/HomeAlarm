import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/member.dart';

/// Static, config-based auth per PROJECT_SPEC.md section 7: no Firebase
/// Auth, no sign-up. The `members` collection is seeded out-of-band (see
/// firebase/seed_members.md); this service only matches a picked name
/// against its PIN and caches the result locally.
class AuthService {
  AuthService({FirebaseFirestore? firestore, SharedPreferences? prefs})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _prefsOverride = prefs;

  static const _memberIdKey = 'kinremind.memberId';
  static const _deviceIdKey = 'kinremind.deviceId';

  final FirebaseFirestore _firestore;
  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      _firestore.collection('members');

  /// The full seeded roster, for the name-picker screen.
  Future<List<Member>> fetchMembers() async {
    final snapshot = await _membersCollection.get();
    final members = snapshot.docs
        .map((doc) => Member.fromFirestore(doc.id, doc.data()))
        .toList();
    members.sort((a, b) => a.name.compareTo(b.name));
    return members;
  }

  /// Returns the matched [Member] and caches the session locally, or null
  /// if the PIN doesn't match.
  Future<Member?> login({required String memberId, required String pin}) async {
    final doc = await _membersCollection.doc(memberId).get();
    if (!doc.exists) return null;

    final member = Member.fromFirestore(doc.id, doc.data()!);
    if (member.pin != pin) return null;

    final prefs = await _prefs;
    await prefs.setString(_memberIdKey, member.id);
    await _ensureDeviceId(prefs);
    return member;
  }

  Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove(_memberIdKey);
  }

  Future<String?> getCachedMemberId() async {
    final prefs = await _prefs;
    return prefs.getString(_memberIdKey);
  }

  Future<Member?> getCachedMember() async {
    final memberId = await getCachedMemberId();
    if (memberId == null) return null;
    final doc = await _membersCollection.doc(memberId).get();
    if (!doc.exists) return null;
    return Member.fromFirestore(doc.id, doc.data()!);
  }

  /// A stable per-install id (PROJECT_SPEC.md edge case table: the same
  /// member logged in on 2 devices both keep independent alarms; this id
  /// is what would let a future version tell those installs apart).
  Future<String> getOrCreateDeviceId() async {
    final prefs = await _prefs;
    return _ensureDeviceId(prefs);
  }

  Future<String> _ensureDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}
