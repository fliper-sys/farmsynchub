enum UserAccountRole {
  owner,
  worker,
  partner,
  viewer,
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.accountRole,
    required this.ward,
    required this.primaryFocus,
    required this.bio,
    required this.profileImageBase64,
    required this.createdAt,
    required this.updatedAt,
    this.isDisabled = false,
    this.isVerified = false,
    this.verificationStatus = 'none',
    this.verificationNote = '',
    this.verificationRequestedAt,
    this.verificationReviewedAt,
    this.restrictedFeatures = const <String>[],
    this.fcmTokens = const <String>[],
    this.dailyUpdatesEnabled = true,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final UserAccountRole accountRole;
  final String ward;
  final String primaryFocus;
  final String bio;
  final String profileImageBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDisabled;
  final bool isVerified;
  final String verificationStatus;
  final String verificationNote;
  final DateTime? verificationRequestedAt;
  final DateTime? verificationReviewedAt;
  final List<String> restrictedFeatures;
  final List<String> fcmTokens;
  final bool dailyUpdatesEnabled;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      ward.trim().isNotEmpty &&
      primaryFocus.trim().isNotEmpty;

  bool get hasPendingVerificationRequest => verificationStatus == 'pending';

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    UserAccountRole? accountRole,
    String? ward,
    String? primaryFocus,
    String? bio,
    String? profileImageBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDisabled,
    bool? isVerified,
    String? verificationStatus,
    String? verificationNote,
    DateTime? verificationRequestedAt,
    DateTime? verificationReviewedAt,
    List<String>? restrictedFeatures,
    List<String>? fcmTokens,
    bool? dailyUpdatesEnabled,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountRole: accountRole ?? this.accountRole,
      ward: ward ?? this.ward,
      primaryFocus: primaryFocus ?? this.primaryFocus,
      bio: bio ?? this.bio,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDisabled: isDisabled ?? this.isDisabled,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNote: verificationNote ?? this.verificationNote,
      verificationRequestedAt:
          verificationRequestedAt ?? this.verificationRequestedAt,
      verificationReviewedAt:
          verificationReviewedAt ?? this.verificationReviewedAt,
      restrictedFeatures: restrictedFeatures ?? this.restrictedFeatures,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      dailyUpdatesEnabled: dailyUpdatesEnabled ?? this.dailyUpdatesEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'accountRole': accountRole.name,
        'ward': ward,
        'primaryFocus': primaryFocus,
        'bio': bio,
        'profileImageBase64': profileImageBase64,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDisabled': isDisabled,
        'isVerified': isVerified,
        'verificationStatus': verificationStatus,
        'verificationNote': verificationNote,
        'verificationRequestedAt': verificationRequestedAt?.toIso8601String(),
        'verificationReviewedAt': verificationReviewedAt?.toIso8601String(),
        'restrictedFeatures': restrictedFeatures,
        'fcmTokens': fcmTokens,
        'dailyUpdatesEnabled': dailyUpdatesEnabled,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      accountRole: UserAccountRole.values.firstWhere(
        (UserAccountRole value) => value.name == json['accountRole'],
        orElse: () => UserAccountRole.owner,
      ),
      ward: json['ward'] as String? ?? '',
      primaryFocus: json['primaryFocus'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profileImageBase64: json['profileImageBase64'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      isDisabled: json['isDisabled'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String? ?? 'none',
      verificationNote: json['verificationNote'] as String? ?? '',
      verificationRequestedAt:
          DateTime.tryParse(json['verificationRequestedAt'] as String? ?? ''),
      verificationReviewedAt:
          DateTime.tryParse(json['verificationReviewedAt'] as String? ?? ''),
      restrictedFeatures: (json['restrictedFeatures'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          <String>[],
      fcmTokens: (json['fcmTokens'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          <String>[],
      dailyUpdatesEnabled: json['dailyUpdatesEnabled'] as bool? ?? true,
    );
  }
}
