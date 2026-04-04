import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/user.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.roles,
    required super.activeRole,
    super.isSuspended = false,
    super.preferredCity,
    super.photoUrl,
    super.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      roles: ((json['roles'] as List?)?.cast<String>() ?? ['player'])
          .map(_roleFromString)
          .toList(),
      activeRole: _roleFromString(json['activeRole'] as String? ?? 'player'),
      isSuspended: json['isSuspended'] as bool? ?? false,
      preferredCity: json['preferredCity'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    return UserModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'roles': roles.map(_roleToString).toList(),
    'activeRole': _roleToString(activeRole),
    'isSuspended': isSuspended,
    if (preferredCity != null) 'preferredCity': preferredCity,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
  };

  static UserRole _roleFromString(String s) {
    switch (s) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.player;
    }
  }

  static String _roleToString(UserRole r) {
    switch (r) {
      case UserRole.owner:
        return 'owner';
      case UserRole.admin:
        return 'admin';
      case UserRole.player:
        return 'player';
    }
  }
}
