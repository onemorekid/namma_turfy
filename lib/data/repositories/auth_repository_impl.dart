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
    if (kIsWeb) {
      // Process any pending redirect sign-in (e.g. mobile web returning from
      // Google OAuth redirect). authStateChanges() fires automatically once
      // processed, so we only need to catch errors here.
      () async {
        try {
          await _firebaseAuth.getRedirectResult();
        } catch (e) {
          debugPrint('[AuthRepository] getRedirectResult error: $e');
        }
      }();
    }
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
      if (kIsWeb) {
        // Use Firebase Auth directly on web — avoids dependency on
        // google_sign_in_web and works on both desktop and mobile browsers.
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        try {
          // Desktop web: signInWithPopup opens a Google popup.
          debugPrint('[AuthRepository] Web: signInWithPopup...');
          await _firebaseAuth.signInWithPopup(provider);
          debugPrint('[AuthRepository] signInWithPopup success');
        } on FirebaseAuthException catch (e) {
          // Mobile web: browsers block popups triggered by async code.
          // Fall back to redirect — user leaves app and returns after auth.
          if (e.code == 'popup-blocked' ||
              e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request') {
            debugPrint('[AuthRepository] Popup blocked, falling back to redirect...');
            await _firebaseAuth.signInWithRedirect(provider);
            // App will restart; getRedirectResult() in constructor handles it.
          } else {
            rethrow;
          }
        }
      } else {
        // Native Android / iOS: use Google Sign In SDK.
        debugPrint('[AuthRepository] Native: GoogleSignIn.signIn()...');
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('[AuthRepository] Sign-in cancelled by user');
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
        debugPrint('[AuthRepository] Native signInWithCredential success');
      }
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
