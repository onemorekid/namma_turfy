import 'package:flutter_test/flutter_test.dart';
import 'package:namma_turfy/domain/entities/user.dart';

void main() {
  group('UserEntity', () {
    test('copyWith should update fields correctly', () {
      const user = UserEntity(
        id: '1',
        email: 'test@example.com',
        name: 'Test User',
        roles: [UserRole.player],
        activeRole: UserRole.player,
      );

      final updated = user.copyWith(
        name: 'Updated Name',
        phoneNumber: '1234567890',
      );

      expect(updated.name, 'Updated Name');
      expect(updated.phoneNumber, '1234567890');
      expect(updated.email, 'test@example.com');
      expect(updated.id, '1');
    });
  });
}
