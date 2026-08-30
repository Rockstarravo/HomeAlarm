/// A seeded family member. See firebase/seed_members.md — this collection
/// is never written by the app itself, only read at login time.
enum MemberRole { owner, member }

MemberRole memberRoleFromString(String value) {
  switch (value) {
    case 'owner':
      return MemberRole.owner;
    case 'member':
    default:
      return MemberRole.member;
  }
}

String memberRoleToString(MemberRole role) {
  return role == MemberRole.owner ? 'owner' : 'member';
}

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
  });

  final String id;
  final String name;
  final String pin;
  final MemberRole role;

  bool get isOwner => role == MemberRole.owner;

  factory Member.fromFirestore(String id, Map<String, dynamic> data) {
    return Member(
      id: id,
      name: data['name'] as String? ?? '',
      pin: data['pin'] as String? ?? '',
      role: memberRoleFromString(data['role'] as String? ?? 'member'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'pin': pin,
      'role': memberRoleToString(role),
    };
  }
}
