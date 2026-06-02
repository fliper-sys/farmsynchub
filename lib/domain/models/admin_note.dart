class AdminNote {
  const AdminNote({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.message,
    required this.createdAt,
    this.targetAdminId = '',
    this.targetAdminEmail = '',
    this.isPinned = false,
    this.isRead = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String targetAdminId;
  final String targetAdminEmail;
  final String message;
  final DateTime createdAt;
  final bool isPinned;
  final bool isRead;

  AdminNote copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderEmail,
    String? targetAdminId,
    String? targetAdminEmail,
    String? message,
    DateTime? createdAt,
    bool? isPinned,
    bool? isRead,
  }) {
    return AdminNote(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      targetAdminId: targetAdminId ?? this.targetAdminId,
      targetAdminEmail: targetAdminEmail ?? this.targetAdminEmail,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderEmail': senderEmail,
        'targetAdminId': targetAdminId,
        'targetAdminEmail': targetAdminEmail,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'isPinned': isPinned,
        'isRead': isRead,
      };

  factory AdminNote.fromJson(Map<String, dynamic> json) {
    return AdminNote(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderEmail: json['senderEmail'] as String? ?? '',
      targetAdminId: json['targetAdminId'] as String? ?? '',
      targetAdminEmail: json['targetAdminEmail'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isPinned: json['isPinned'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
