import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/firebase_service.dart';
import '../domain/models/user_profile.dart';
import 'auth_provider.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileController, AsyncValue<UserProfile?>>((ref) {
  // A new controller (starting from a clean, loading state) for every
  // account, so the previous person's name, photo and role never linger.
  ref.watch(sessionUidProvider);
  return UserProfileController(ref.watch(firebaseServiceProvider));
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

  /// Loads the profile. The copy already on this device is shown straight
  /// away (no spinner), then replaced by the server's copy when it arrives.
  Future<void> loadProfile() async {
    if (!mounted) {
      return;
    }

    if (!state.hasValue || state.valueOrNull == null) {
      final UserProfile? cached = await _firebaseService.getCachedUserProfile();
      if (!mounted) {
        return;
      }
      state = cached != null
          ? AsyncValue.data(cached)
          : const AsyncValue<UserProfile?>.loading();
    }

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
      // Keep showing what we already have rather than replacing a usable
      // profile with an error screen.
      if (!state.hasValue || state.valueOrNull == null) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  /// Saves the profile. The screen updates immediately and the saved copy is
  /// confirmed in the background; if saving fails the previous profile is put
  /// back and the error is rethrown so the caller can tell the person.
  Future<void> saveProfile(UserProfile profile) async {
    if (!mounted) {
      return;
    }

    final AsyncValue<UserProfile?> previous = state;
    state = AsyncValue.data(profile);

    try {
      await _firebaseService.saveUserProfile(profile);
    } catch (error) {
      if (mounted) {
        state = previous;
      }
      rethrow;
    }

    // Confirm what the server actually stored (it may add fields), without
    // making the person wait for the extra round trip.
    unawaited(_confirmSaved(profile));
  }

  Future<void> _confirmSaved(UserProfile fallback) async {
    try {
      final UserProfile? persisted = await _firebaseService.getUserProfile();
      if (mounted && persisted != null && persisted.uid == fallback.uid) {
        state = AsyncValue.data(persisted);
      }
    } catch (_) {
      // The optimistic copy is already showing; nothing to repair.
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
