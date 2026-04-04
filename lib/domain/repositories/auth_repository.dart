import 'package:namma_turfy/domain/entities/user.dart';

abstract class AuthRepository {
  Stream<UserEntity?> authStateChanges();
  UserEntity? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> switchRole(UserRole role);
  Future<void> addRole(UserRole role);
  Future<void> updateProfile({
    required String name,
    required String preferredCity,
  });
  Future<void> updatePhoneNumber(String phoneNumber);
  Future<void> updateUser(UserEntity user);
  Stream<List<UserEntity>> watchAllUsers();
  Future<void> signOut();
}
