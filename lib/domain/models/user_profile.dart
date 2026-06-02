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

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      ward.trim().isNotEmpty &&
      primaryFocus.trim().isNotEmpty &&
      profileImageBase64.trim().isNotEmpty;

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
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
