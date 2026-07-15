import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmsynchub/data/remote/firebase_service.dart';
import 'package:farmsynchub/domain/models/user_profile.dart';
import 'package:farmsynchub/providers/user_profile_provider.dart';

void main() {
  test('saveProfile reloads the persisted profile from the remote source', () async {
    final FakeFirebaseService fakeFirebaseService = FakeFirebaseService();
    final UserProfileController controller = UserProfileController(fakeFirebaseService);

    final UserProfile originalProfile = UserProfile(
      uid: 'user-1',
      fullName: 'Amina',
      email: 'amina@example.com',
      phoneNumber: '+2348000000000',
      accountRole: UserAccountRole.owner,
      ward: 'Jos South',
      primaryFocus: 'Vegetables',
      bio: 'Farmer',
      profileImageBase64: 'img',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    await controller.saveProfile(originalProfile);

    final String? savedName = controller.state.when(
      data: (UserProfile? profile) => profile?.fullName,
      loading: () => null,
      error: (_, __) => null,
    );

    expect(savedName, 'Persisted from storage');
  });
}

class FakeFirebaseService extends FirebaseService {
  UserProfile? _savedProfile;

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _savedProfile = profile.copyWith(
      fullName: 'Persisted from storage',
      updatedAt: DateTime(2025),
    );
  }

  @override
  Future<UserProfile?> getUserProfile() async {
    return _savedProfile;
  }
}
