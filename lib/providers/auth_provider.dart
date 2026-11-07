import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/services/farm_email_service.dart';
import '../core/services/session_cache.dart';
import '../data/remote/firebase_service.dart';
import 'email_notification_provider.dart';
import 'user_profile_provider.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

/// Auth state. Each sign-in is only announced after the on-device cache has
/// been claimed for that account, so no screen can read another account's
/// cached records.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref
      .watch(firebaseServiceProvider)
      .authStateChanges
      .asyncMap((User? user) async {
    await SessionCache.claim(user?.uid);
    return user;
  });
});

/// The uid of the signed-in account, or null. Account-scoped providers watch
/// this so they are rebuilt from scratch whenever a different person signs in
/// or out, instead of holding the previous account's data in memory.
final sessionUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((AsyncValue<User?> v) => v.valueOrNull?.uid));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    firebaseService: ref.watch(firebaseServiceProvider),
    emailService: ref.watch(farmEmailServiceProvider),
    refreshProfile: () => ref.read(userProfileProvider.notifier).loadProfile(),
  );
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController({
    required FirebaseService firebaseService,
    required FarmEmailService emailService,
    Future<void> Function()? refreshProfile,
  })  : _firebaseService = firebaseService,
        _emailService = emailService,
        _refreshProfile = refreshProfile,
        super(const AsyncValue.data(null));

  final FirebaseService _firebaseService;
  final FarmEmailService _emailService;
  final Future<void> Function()? _refreshProfile;

  /// Runs a notification email without making the person wait for it, and
  /// without turning a mail hiccup into a failed sign-in.
  void _sendInBackground(Future<void> Function() send) {
    unawaited(send().catchError((Object error) {
      debugPrint('Background email failed: $error');
    }));
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.signInWithEmail(
        email: email,
        password: password,
      );
      final String displayName =
          _firebaseService.currentUser?.displayName?.trim() ?? '';
      final String recipientName =
          displayName.isNotEmpty ? displayName : email.split('@').first;
      _sendInBackground(() => _emailService.sendLoginNotification(
            toEmail: email,
            recipientName: recipientName,
            signInMethod: 'email and password',
          ));
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.signInWithGoogle();
      unawaited(_refreshProfile?.call());
      final String email = _firebaseService.currentUser?.email ?? '';
      if (email.isNotEmpty) {
        final String displayName =
            _firebaseService.currentUser?.displayName?.trim() ?? '';
        _sendInBackground(() => _emailService.sendLoginNotification(
              toEmail: email,
              recipientName:
                  displayName.isNotEmpty ? displayName : email.split('@').first,
              signInMethod: 'Google sign-in',
            ));
      }
    });
  }

  /// Completes sign-in for a [GoogleSignInAccount] obtained from the web
  /// GIS button (`googleSignIn.onCurrentUserChanged`) rather than the
  /// deprecated imperative popup.
  Future<void> completeGoogleSignIn(GoogleSignInAccount account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.completeGoogleSignIn(account);
      unawaited(_refreshProfile?.call());
      final String email = _firebaseService.currentUser?.email ?? '';
      if (email.isNotEmpty) {
        final String displayName =
            _firebaseService.currentUser?.displayName?.trim() ?? '';
        _sendInBackground(() => _emailService.sendLoginNotification(
              toEmail: email,
              recipientName:
                  displayName.isNotEmpty ? displayName : email.split('@').first,
              signInMethod: 'Google sign-in',
            ));
      }
    });
  }

  Future<String> startPhoneSignIn(String phoneNumber) async {
    state = const AsyncValue.loading();
    try {
      final String verificationId =
          await _firebaseService.signInWithPhoneNumber(phoneNumber);
      state = const AsyncValue.data(null);
      return verificationId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.verifyOTP(verificationId, smsCode);
      unawaited(_refreshProfile?.call());
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.registerWithEmail(
        email: email,
        password: password,
        displayName: name,
        phoneNumber: phoneNumber,
      );
      // The account now exists and the profile document has just been
      // written; make sure the profile screen reads it rather than the empty
      // result it may have fetched while sign-up was still in progress.
      unawaited(_refreshProfile?.call());
      _sendInBackground(_firebaseService.sendEmailVerification);
      _sendInBackground(() => _emailService.sendWelcomeNotification(
            toEmail: email,
            recipientName: name,
          ));
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.sendPasswordResetEmail(email);
      await _emailService.sendPasswordResetNotification(
        toEmail: email,
        recipientName: email.split('@').first,
      );
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    });
  }

  Future<void> resendVerificationEmail() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.sendEmailVerification();
    });
  }

  Future<bool> reloadAndCheckVerification() async {
    state = const AsyncValue.loading();
    final AsyncValue<void> result = await AsyncValue.guard(() async {
      await _firebaseService.reloadCurrentUser();
    });
    state = result;
    return _firebaseService.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Wipe the previous account's cache before the auth change is
      // announced, and once more afterwards in case a screen wrote to it
      // while the sign-out was in flight.
      await SessionCache.clear();
      await _firebaseService.signOut();
      await SessionCache.clear();
    });
  }
}
