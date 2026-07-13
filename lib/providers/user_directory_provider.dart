import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/firebase_service.dart';
import '../domain/models/user_profile.dart';
import 'auth_provider.dart';

final userDirectoryProvider =
    StateNotifierProvider<UserDirectoryController, AsyncValue<List<UserProfile>>>((ref) {
  return UserDirectoryController(ref.watch(firebaseServiceProvider));
});

class UserDirectoryController extends StateNotifier<AsyncValue<List<UserProfile>>> {
  UserDirectoryController(this._firebaseService) : super(const AsyncValue.loading()) {
    load();
  }

  final FirebaseService _firebaseService;

  Future<void> load() async {
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final List<UserProfile> users = await _firebaseService.getAllUserProfiles();
      if (!mounted) {
        return;
      }
      users.sort((UserProfile a, UserProfile b) => b.updatedAt.compareTo(a.updatedAt));
      state = AsyncValue.data(users);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => load();
}
