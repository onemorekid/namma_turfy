import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:namma_turfy/main.dart' as app;
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:namma_turfy/domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _userController = StreamController<UserEntity?>.broadcast();
  UserEntity? _currentUser = const UserEntity(
    id: 'mock_mrpatilpralhad_id',
    email: 'mrpatilpralhad@gmail.com',
    name: 'Pralhad Patil',
    roles: [UserRole.player, UserRole.owner, UserRole.admin],
    activeRole: UserRole.player,
    phoneNumber: '9876543210',
  );

  @override
  Stream<UserEntity?> authStateChanges() => _userController.stream;

  @override
  UserEntity? get currentUser => _currentUser;

  @override
  Future<void> signInWithGoogle() async {
    _userController.add(_currentUser);
  }

  @override
  Future<void> switchRole(UserRole role) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(activeRole: role);
      _userController.add(_currentUser);
    }
  }

  @override
  Future<void> addRole(UserRole role) async {}

  @override
  Future<void> updateProfile({
    required String name,
    required String preferredCity,
  }) async {}

  @override
  Future<void> updatePhoneNumber(String phoneNumber) async {}

  @override
  Future<void> updateUser(UserEntity user) async {}

  @override
  Stream<List<UserEntity>> watchAllUsers() {
    return Stream.value([_currentUser!]);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _userController.add(null);
  }

  @override
  void dispose() {
    _userController.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Workflows for mrpatilpralhad@gmail.com', () {
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
    });

    testWidgets('Full Journey: Login -> Admin -> Owner -> Player', (
      WidgetTester tester,
    ) async {
      app.main();

      // Wait for app to settle on the LoginScreen
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);

      // 1. LOGIN WORKFLOW
      // We tap the Google Sign-in button, which uses our mock repository
      await tester.tap(find.text('Continue with Google'));
      await mockAuthRepo.signInWithGoogle();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert we are on the Home Screen (Player mode by default)
      expect(find.text('Search venues or areas...'), findsOneWidget);

      // 2. ADMIN WORKFLOW
      // Open the drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Ensure Admin Mode is visible and tap it
      expect(find.text('Admin Mode'), findsOneWidget);
      await tester.tap(find.text('Admin Mode'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert we are on Admin Dashboard
      expect(find.text('Super-Admin Dashboard'), findsOneWidget);

      // Tap Users tab
      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pralhad Patil'),
        findsWidgets,
      ); // Checking for our mock user

      // 3. OWNER WORKFLOW
      // Open the drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Ensure Owner Mode is visible and tap it
      expect(find.text('Owner Mode'), findsOneWidget);
      await tester.tap(find.text('Owner Mode'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert we are on Owner Dashboard
      expect(find.text('Owner Dashboard'), findsOneWidget);

      // If the "Create Venue" button is visible (no existing venue), create one
      if (find.text('Create Venue').evaluate().isNotEmpty) {
        await tester.tap(find.text('Create Venue'));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'Namma Turf Premium');
        await tester.enterText(textFields.at(1), 'Bangalore');
        await tester.enterText(textFields.at(2), 'Best turf in town');
        await tester.enterText(textFields.at(3), '1200');

        // Tap the Create button in the dialog
        await tester.tap(find.text('Create').last);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Add a Zone
      expect(find.byTooltip('Add Zone'), findsWidgets);
      await tester.tap(find.byTooltip('Add Zone').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Pitch A');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Add a Slot via manual Add Alarm button
      expect(find.byIcon(Icons.add_alarm), findsWidgets);
      await tester.tap(find.byIcon(Icons.add_alarm).first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 4. PLAYER BOOKING WORKFLOW
      // Open the drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Switch to Player
      await tester.tap(find.text('Home / Player Mode'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Search for the newly created venue
      await tester.enterText(
        find.byType(TextField).first,
        'Namma Turf Premium',
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap on the venue to open its details
      final venueCard = find.text('Namma Turf Premium').first;
      expect(venueCard, findsWidgets);
      await tester.tap(venueCard);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find the available slot (represented by an un-crossed text or container)
      // and tap it to add to cart
      final availableSlot = find.byType(GestureDetector).last;
      await tester.tap(availableSlot);
      await tester.pumpAndSettle();

      // Verify the Book Now button appears and tap it
      expect(find.text('Book Now'), findsWidgets);
      await tester.tap(find.text('Book Now').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // We should now be on the Checkout screen
      expect(find.text('Confirm Booking'), findsWidgets);
    });
  });
}
