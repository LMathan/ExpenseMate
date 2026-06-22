import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/storage/hive_helper.dart';
import '../../../../core/services/firestore_sync_service.dart';
import '../../../../core/services/notification_service.dart';

enum AuthStatus { initial, authenticating, syncing, authenticated, guest, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? displayName;
  final String? profilePicPath;
  final String? profilePicUrl;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.email,
    this.displayName,
    this.profilePicPath,
    this.profilePicUrl,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? displayName,
    String? profilePicPath,
    String? profilePicUrl,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profilePicPath: profilePicPath ?? this.profilePicPath,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirestoreSyncService _syncService = FirestoreSyncService();

  AuthNotifier() : super(AuthState.initial()) {
    checkAutoLogin();
  }

  void checkAutoLogin() {
    try {
      final box = Hive.box(HiveHelper.settingsBox);
      final isLoggedIn = box.get('is_logged_in', defaultValue: false) as bool;
      final isGuest = box.get('is_guest_mode', defaultValue: false) as bool;
      final userName = box.get('user_name', defaultValue: 'Mathan') as String;
      final profilePicPath = box.get('profile_picture_path') as String?;
      final profilePicUrl = box.get('profile_picture_url') as String?;

      String? actualProfilePicPath = profilePicPath;
      if (profilePicPath != null && !profilePicPath.startsWith('http')) {
        final file = File(profilePicPath);
        if (!file.existsSync()) {
          actualProfilePicPath = null;
          // Recreate persistent cache file in application documents directory if we have base64 url
          if (profilePicUrl != null && profilePicUrl.startsWith('data:image')) {
            _recreateProfilePicCache(profilePicUrl);
          }
        }
      }

      final firebaseUser = _firebaseAuth.currentUser;

      if (isLoggedIn && firebaseUser != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          email: firebaseUser.email,
          displayName: firebaseUser.displayName ?? userName,
          profilePicPath: actualProfilePicPath,
          profilePicUrl: profilePicUrl,
        );
        // Sync cloud database to local Hive in the background
        _syncService.syncCloudToLocal();
        NotificationService().updateFcmTokenInFirestore();
      } else if (isGuest) {
        state = AuthState(
          status: AuthStatus.guest,
          displayName: userName,
          profilePicPath: actualProfilePicPath,
          profilePicUrl: profilePicUrl,
        );
      } else {
        state = AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  void _recreateProfilePicCache(String base64Url) async {
    try {
      final base64String = base64Url.split('base64,').last;
      final bytes = base64Decode(base64String);
      final docDir = await getApplicationDocumentsDirectory();
      final cachedFile = File('${docDir.path}/profile_persistent.jpg');
      await cachedFile.writeAsBytes(bytes);
      
      final box = Hive.box(HiveHelper.settingsBox);
      await box.put('profile_picture_path', cachedFile.path);
      
      // Update state with the newly created path reactively
      state = state.copyWith(profilePicPath: cachedFile.path);
      debugPrint('Recreated profile picture cache successfully.');
    } catch (e) {
      debugPrint('Error recreating profile picture cache: $e');
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
      final user = userCredential.user;
      if (user != null) {
        final box = Hive.box(HiveHelper.settingsBox);
        await box.put('is_logged_in', true);
        await box.put('is_guest_mode', false);
        await box.put('user_email', user.email ?? email);
        
        final displayName = user.displayName ?? (user.email != null ? user.email!.split('@').first : 'User');
        await box.put('user_name', displayName);

        final profilePicPath = box.get('profile_picture_path') as String?;
        final profilePicUrl = box.get('profile_picture_url') as String?;

        // Await data sync before marking as authenticated
        state = AuthState(
          status: AuthStatus.syncing,
          email: user.email,
          displayName: displayName,
          profilePicPath: profilePicPath,
          profilePicUrl: profilePicUrl,
        );
        try {
          await _syncService.syncCloudToLocal()
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          // sync failure is non-fatal — carry on with local data
        }

        final updatedPath = box.get('profile_picture_path') as String?;
        final updatedUrl = box.get('profile_picture_url') as String?;

        state = AuthState(
          status: AuthStatus.authenticated,
          email: user.email,
          displayName: box.get('user_name', defaultValue: displayName) as String?,
          profilePicPath: updatedPath,
          profilePicUrl: updatedUrl,
        );
        NotificationService().updateFcmTokenInFirestore();
        return true;
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Login failed',
        );
        return false;
      }
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message ?? 'Login failed',
      );
      return false;
    } on TimeoutException {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Connection timed out. Please check your internet connection.',
      );
      return false;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  Future<bool> signupWithEmail(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(name);

        final box = Hive.box(HiveHelper.settingsBox);
        await box.put('is_logged_in', true);
        await box.put('is_guest_mode', false);
        await box.put('user_email', email);
        await box.put('user_name', name);

        final profilePicPath = box.get('profile_picture_path') as String?;
        final profilePicUrl = box.get('profile_picture_url') as String?;

        state = AuthState(
          status: AuthStatus.authenticated,
          email: email,
          displayName: name,
          profilePicPath: profilePicPath,
          profilePicUrl: profilePicUrl,
        );

        // Upload initial local/offline configuration to new Cloud profile in background
        _syncService.syncLocalToCloud();
        NotificationService().updateFcmTokenInFirestore();
        return true;
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Registration failed',
        );
        return false;
      }
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message ?? 'Registration failed',
      );
      return false;
    } on TimeoutException {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Connection timed out. Please check your internet connection.',
      );
      return false;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      debugPrint('Google Sign-In: Initializing GoogleSignIn SDK...');
      final GoogleSignIn googleSignIn = GoogleSignIn();
      debugPrint('Google Sign-In: Triggering account selector dialog...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google Sign-In: User cancelled account selection.');
        state = AuthState(status: AuthStatus.unauthenticated);
        return false;
      }

      debugPrint('Google Sign-In: Fetching authentication tokens for ${googleUser.email}...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      debugPrint('Google Sign-In: Creating credential...');
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Google Sign-In: Attempting Firebase Auth sign-in with credential...');
      final userCredential = await _firebaseAuth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));
      final user = userCredential.user;
      if (user != null) {
        debugPrint('Google Sign-In: Firebase login successful! Saving user settings to Hive...');
        final box = Hive.box(HiveHelper.settingsBox);
        await box.put('is_logged_in', true);
        await box.put('is_guest_mode', false);
        await box.put('user_email', user.email ?? '');
        
        final displayName = user.displayName ?? (user.email != null ? user.email!.split('@').first : 'User');
        await box.put('user_name', displayName);

        final profilePicPath = box.get('profile_picture_path') as String?;
        final profilePicUrl = box.get('profile_picture_url') as String?;

        debugPrint('Google Sign-In: Starting Firestore sync...');
        state = AuthState(
          status: AuthStatus.syncing,
          email: user.email,
          displayName: displayName,
          profilePicPath: profilePicPath,
          profilePicUrl: profilePicUrl,
        );
        try {
          await _syncService.syncCloudToLocal()
              .timeout(const Duration(seconds: 20));
        } catch (_) {}

        final updatedPath = box.get('profile_picture_path') as String?;
        final updatedUrl = box.get('profile_picture_url') as String?;

        state = AuthState(
          status: AuthStatus.authenticated,
          email: user.email,
          displayName: box.get('user_name', defaultValue: displayName) as String?,
          profilePicPath: updatedPath,
          profilePicUrl: updatedUrl,
        );
        NotificationService().updateFcmTokenInFirestore();
        return true;
      } else {
        debugPrint('Google Sign-In: Firebase returned null user.');
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google login failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error caught: $e');
      final errText = e.toString();
      String msg = errText;
      if (e is TimeoutException) {
        msg = 'Connection timed out. Please check your internet connection.';
      } else if (errText.contains('10')) {
        msg = 'Google Sign-In Error (SHA-1 fingerprint not registered in Firebase console)';
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<void> loginAsGuest() async {
    state = state.copyWith(status: AuthStatus.authenticating);
    await Future.delayed(const Duration(milliseconds: 600));

    final box = Hive.box(HiveHelper.settingsBox);
    await box.put('is_logged_in', false);
    await box.put('is_guest_mode', true);
    await box.put('user_name', 'Guest User');

    state = AuthState(
      status: AuthStatus.guest,
      displayName: 'Guest User',
      profilePicPath: null,
      profilePicUrl: null,
    );
  }

  Future<void> logout() async {
    try {
      await NotificationService().removeFcmTokenFromFirestore();
    } catch (_) {}

    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    try {
      await Hive.box(HiveHelper.transactionsBox).clear();
      await Hive.box(HiveHelper.budgetsBox).clear();
      await Hive.box(HiveHelper.goalsBox).clear();
      await Hive.box(HiveHelper.subscriptionsBox).clear();
      await Hive.box(HiveHelper.billsBox).clear();
      await Hive.box(HiveHelper.challengesBox).clear();
      await Hive.box(HiveHelper.groupsBox).clear();
    } catch (e) {
      debugPrint('Error clearing Hive boxes on logout: $e');
    }

    final box = Hive.box(HiveHelper.settingsBox);
    await box.put('is_logged_in', false);
    await box.put('is_guest_mode', false);
    await box.delete('user_name');
    await box.delete('user_upi_id');
    await box.delete('user_gender');
    await box.delete('profile_picture_url');
    await box.delete('profile_picture_path');
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    try {
      await NotificationService().removeFcmTokenFromFirestore();
    } catch (_) {}

    try {
      await _firebaseAuth.currentUser?.delete();
      await _firebaseAuth.signOut();
    } catch (_) {}

    try {
      await Hive.box(HiveHelper.transactionsBox).clear();
      await Hive.box(HiveHelper.budgetsBox).clear();
      await Hive.box(HiveHelper.goalsBox).clear();
      await Hive.box(HiveHelper.subscriptionsBox).clear();
      await Hive.box(HiveHelper.billsBox).clear();
      await Hive.box(HiveHelper.challengesBox).clear();
      await Hive.box(HiveHelper.groupsBox).clear();
    } catch (e) {
      debugPrint('Error clearing Hive boxes on deleteAccount: $e');
    }

    final box = Hive.box(HiveHelper.settingsBox);
    await box.clear();
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void updateProfileDetails({
    String? displayName,
    String? profilePicPath,
    String? profilePicUrl,
    bool clearPhoto = false,
  }) {
    state = AuthState(
      status: state.status,
      email: state.email,
      displayName: displayName ?? state.displayName,
      profilePicPath: clearPhoto ? null : (profilePicPath ?? state.profilePicPath),
      profilePicUrl: clearPhoto ? null : (profilePicUrl ?? state.profilePicUrl),
      errorMessage: state.errorMessage,
    );
  }
}
