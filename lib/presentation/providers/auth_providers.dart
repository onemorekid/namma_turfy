import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/data/repositories/auth_repository_impl.dart';
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:namma_turfy/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authStateChangesProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authStateChangesProvider).value;
});

final allUsersProvider = StreamProvider<List<UserEntity>>((ref) {
  return ref.watch(authRepositoryProvider).watchAllUsers();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    return;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> updatePhoneNumber(String phoneNumber) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).updatePhoneNumber(phoneNumber),
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}
