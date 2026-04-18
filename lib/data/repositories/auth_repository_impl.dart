import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:namma_turfy/data/models/user_model.dart';
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:namma_turfy/domain/repositories/auth_repository.dart';

// Web/server OAuth client ID from google-services.json (client_type: 3)
const _serverClientId =
    '685968369147-m46gv5a01fchlsoo8i8262818e8tm2qh.apps.googleusercontent.com';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _serverClientId : null,
    scopes: ['email', 'profile'],
  );

  final _userController = StreamController<UserEntity?>.broadcast();
  StreamSubscription? _userDocSubscription;
  UserEntity? _currentUser;

  AuthRepositoryImpl() {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) {
    _userDocSubscription?.cancel();

    if (firebaseUser == null) {
      _currentUser = null;
      _userController.add(null);
      return;
    }

    // Real-time listener on user's Firestore document
    _userDocSubscription = _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) {
            final newUser = _mapInitialUser(firebaseUser);
            await updateUser(newUser);
            return;
          }
          final data = snapshot.data()!;
          data['id'] = snapshot.id;
          _currentUser = UserModel.fromJson(data);
          _userController.add(_currentUser);
        });
  }

  UserEntity _mapInitialUser(User user) {
    final email = user.email ?? '';
    final roles = [UserRole.player];
    return UserModel(
      id: user.uid,
      email: email,
      name: user.displayName ?? email.split('@')[0],
      roles: roles,
      activeRole: UserRole.player,
      photoUrl: user.photoURL,
    );
  }

  @override
  Stream<UserEntity?> authStateChanges() => _userController.stream;

  @override
  UserEntity? get currentUser => _currentUser;

  @override
  Future<void> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        // Attempt silent sign-in first as recommended for web.
        debugPrint('[AuthRepository] Attempting silent sign-in for web...');
        googleUser = await _googleSignIn.signInSilently();
      }

      if (googleUser == null) {
        debugPrint('[AuthRepository] Prompting user for sign-in...');
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        debugPrint('[AuthRepository] Sign-in cancelled by user');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      debugPrint('[AuthRepository] Fetched googleAuth tokens');

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
      debugPrint('[AuthRepository] Firebase signInWithCredential success');
    } catch (e) {
      debugPrint('[AuthRepository] signInWithGoogle failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchRole(UserRole role) async {
    if (_currentUser != null) {
      await updateUser(_currentUser!.copyWith(activeRole: role));
    }
  }

  @override
  Future<void> addRole(UserRole role) async {
    if (_currentUser != null && !_currentUser!.roles.contains(role)) {
      final updatedRoles = [..._currentUser!.roles, role];
      await updateUser(
        _currentUser!.copyWith(roles: updatedRoles, activeRole: role),
      );
    }
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String preferredCity,
  }) async {
    if (_currentUser != null) {
      await updateUser(
        _currentUser!.copyWith(name: name, preferredCity: preferredCity),
      );
    }
  }

  @override
  Future<void> updatePhoneNumber(String phoneNumber) async {
    if (_currentUser != null) {
      await updateUser(_currentUser!.copyWith(phoneNumber: phoneNumber));
    }
  }

  @override
  Future<void> updateUser(UserEntity user) async {
    final model = UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      roles: user.roles,
      activeRole: user.activeRole,
      isSuspended: user.isSuspended,
      preferredCity: user.preferredCity,
      photoUrl: user.photoUrl,
      phoneNumber: user.phoneNumber,
    );
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Stream<List<UserEntity>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return UserModel.fromJson(data);
      }).toList();
    });
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    _userController.close();
  }

  @override
  Future<void> signOut() async {
    _userDocSubscription?.cancel();
    _currentUser = null;
    _userController.add(null);
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
