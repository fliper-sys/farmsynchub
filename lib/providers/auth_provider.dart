import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/firebase_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(firebaseServiceProvider));
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._firebaseService) : super(const AsyncValue.data(null));

  final FirebaseService _firebaseService;

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
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _firebaseService.sendPasswordResetEmail(email);
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
