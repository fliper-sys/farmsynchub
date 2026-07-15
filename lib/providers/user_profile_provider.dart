import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/firebase_service.dart';
import '../domain/models/user_profile.dart';
import 'auth_provider.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileController, AsyncValue<UserProfile?>>((ref) {
  final UserProfileController controller = UserProfileController(ref.watch(firebaseServiceProvider));
  ref.listen(authStateProvider, (_, __) {
    controller.loadProfile();
  });
  return controller;
});

class UserProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileController(this._firebaseService) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  final FirebaseService _firebaseService;

  void setProfile(UserProfile? profile) {
    if (!mounted) {
      return;
    }
    state = AsyncValue.data(profile);
  }

  void clearProfile() {
    if (!mounted) {
      return;
    }
    state = const AsyncValue.data(null);
  }

  Future<void> loadProfile() async {
    if (!mounted) {
      return;
    }

    state = const AsyncValue.loading();
    try {
      final UserProfile? profile = await _firebaseService.getUserProfile();
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (!mounted) {
      return;
    }

    try {
      await _firebaseService.saveUserProfile(profile);
      if (!mounted) {
        return;
      }

      final UserProfile? persistedProfile = await _firebaseService.getUserProfile();
      if (!mounted) {
        return;
      }

      state = AsyncValue.data(persistedProfile ?? profile);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> requestVerifiedBadge({
    String note = '',
  }) async {
    final UserProfile? profile = state.valueOrNull;
    if (profile == null) {
      throw StateError('Profile is not loaded yet.');
    }
    if (profile.uid.isEmpty) {
      throw StateError('Cannot request a verified badge without a profile.');
    }
    state = const AsyncValue.loading();
    try {
      await _firebaseService.requestVerifiedBadge(profile: profile, note: note);
      if (!mounted) {
        return;
      }
      await loadProfile();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
