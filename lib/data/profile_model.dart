import '../core/permissions.dart';

class Profile {
  final String id;
  final String fullName;
  final AppRole? role; // null jika peran di database tidak dikenal
  final bool isActive;

  const Profile({required this.id, required this.fullName, required this.role, required this.isActive});

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      fullName: (map['full_name'] as String?) ?? '',
      role: AppRole.tryParse(map['role'] as String?),
      isActive: map['is_active'] == true,
    );
  }
}
