enum UserRole { player, owner, admin }

class UserEntity {
  final String id;
  final String email;
  final String name;
  final List<UserRole> roles;
  final UserRole activeRole;
  final bool isSuspended;
  final String? preferredCity;
  final String? photoUrl;
  final String? phoneNumber;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.roles,
    required this.activeRole,
    this.isSuspended = false,
    this.preferredCity,
    this.photoUrl,
    this.phoneNumber,
  });

  UserEntity copyWith({
    String? email,
    String? name,
    List<UserRole>? roles,
    UserRole? activeRole,
    bool? isSuspended,
    String? preferredCity,
    String? photoUrl,
    String? phoneNumber,
  }) {
    return UserEntity(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      isSuspended: isSuspended ?? this.isSuspended,
      preferredCity: preferredCity ?? this.preferredCity,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
