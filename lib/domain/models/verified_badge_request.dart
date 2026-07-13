enum VerifiedBadgeRequestStatus {
  pending,
  approved,
  declined,
}

class VerifiedBadgeRequest {
  const VerifiedBadgeRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.phoneNumber,
    required this.ward,
    required this.primaryFocus,
    required this.status,
    required this.requestedAt,
    required this.updatedAt,
    this.bio = '',
    this.profileImageBase64 = '',
    this.note = '',
    this.reviewedBy = '',
    this.reviewedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String email;
  final String phoneNumber;
  final String ward;
  final String primaryFocus;
  final String bio;
  final String profileImageBase64;
  final String note;
  final VerifiedBadgeRequestStatus status;
  final DateTime requestedAt;
  final DateTime updatedAt;
  final String reviewedBy;
  final DateTime? reviewedAt;

  bool get isPending => status == VerifiedBadgeRequestStatus.pending;

  bool get isApproved => status == VerifiedBadgeRequestStatus.approved;

  bool get isDeclined => status == VerifiedBadgeRequestStatus.declined;

  VerifiedBadgeRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? email,
    String? phoneNumber,
    String? ward,
    String? primaryFocus,
    String? bio,
    String? profileImageBase64,
    String? note,
    VerifiedBadgeRequestStatus? status,
    DateTime? requestedAt,
    DateTime? updatedAt,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return VerifiedBadgeRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      ward: ward ?? this.ward,
      primaryFocus: primaryFocus ?? this.primaryFocus,
      bio: bio ?? this.bio,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      note: note ?? this.note,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'userName': userName,
        'email': email,
        'phoneNumber': phoneNumber,
        'ward': ward,
        'primaryFocus': primaryFocus,
        'bio': bio,
        'profileImageBase64': profileImageBase64,
        'note': note,
        'status': status.name,
        'requestedAt': requestedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory VerifiedBadgeRequest.fromJson(Map<String, dynamic> json) {
    return VerifiedBadgeRequest(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      ward: json['ward'] as String? ?? '',
      primaryFocus: json['primaryFocus'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profileImageBase64: json['profileImageBase64'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: VerifiedBadgeRequestStatus.values.firstWhere(
        (VerifiedBadgeRequestStatus value) => value.name == json['status'],
        orElse: () => VerifiedBadgeRequestStatus.pending,
      ),
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      reviewedBy: json['reviewedBy'] as String? ?? '',
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
    );
  }
}
