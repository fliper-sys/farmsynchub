import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/farm_email_service.dart';
import '../data/remote/firebase_service.dart';
import 'email_notification_provider.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    firebaseService: ref.watch(firebaseServiceProvider),
    emailService: ref.watch(farmEmailServiceProvider),
  );
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController({
    required FirebaseService firebaseService,
    required FarmEmailService emailService,
  })  : _firebaseService = firebaseService,
        _emailService = emailService,
        super(const AsyncValue.data(null));

  final FirebaseService _firebaseService;
  final FarmEmailService _emailService;

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
      final String displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
      final String recipientName = displayName.isNotEmpty ? displayName : email.split('@').first;
      await _emailService.sendLoginNotification(
        toEmail: email,
        recipientName: recipientName,
        signInMethod: 'email and password',
      );
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.signInWithGoogle();
      final String email = _firebaseService.currentUser?.email ?? '';
      if (email.isNotEmpty) {
        final String displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
        await _emailService.sendLoginNotification(
          toEmail: email,
          recipientName: displayName.isNotEmpty ? displayName : email.split('@').first,
          signInMethod: 'Google sign-in',
        );
      }
    });
  }

  Future<String> startPhoneSignIn(String phoneNumber) async {
    state = const AsyncValue.loading();
    try {
      final String verificationId = await _firebaseService.signInWithPhoneNumber(phoneNumber);
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
      await _firebaseService.sendEmailVerification();
      await _emailService.sendWelcomeNotification(
        toEmail: email,
        recipientName: name,
      );
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
      await _firebaseService.signOut();
    });
  }
}
