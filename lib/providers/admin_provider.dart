import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/farm_email_service.dart';
import '../data/remote/firebase_service.dart';
import '../domain/models/notification.dart';
import '../domain/models/user_profile.dart';
import '../domain/models/verified_badge_request.dart';
import 'auth_provider.dart';
import 'email_notification_provider.dart';
import 'notification_provider.dart';

const String kAdminRecoveryCode = 'Xanther839';
const String kDefaultAdminEmail = 'lovebari4@icloud.com';
const String kDefaultAdminPassword = 'Xanther839@';

final adminWorkspaceProvider =
    StateNotifierProvider<AdminWorkspaceController, AsyncValue<AdminWorkspaceState>>((ref) {
  return AdminWorkspaceController(ref);
});

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
    required this.isActive,
    this.notes = '',
    this.lastLoginAt,
  });

  final String id;
  final String name;
  final String email;
  final String password;
  final String role;
  final String notes;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  AdminAccount copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? role,
    String? notes,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return AdminAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    final String email = json['email'] as String? ?? '';
    return AdminAccount(
      id: json['id'] as String? ?? email,
      name: json['name'] as String? ?? '',
      email: email,
      password: json['password'] as String? ?? '',
      role: json['role'] as String? ?? 'Admin',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastLoginAt: DateTime.tryParse(json['lastLoginAt'] as String? ?? ''),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AdminWorkspaceState {
  const AdminWorkspaceState({
    required this.admins,
    required this.users,
    required this.verifiedBadgeRequests,
    required this.currentAdmin,
    required this.isLoading,
    required this.lastUpdatedAt,
  });

  final List<AdminAccount> admins;
  final List<UserProfile> users;
  final List<VerifiedBadgeRequest> verifiedBadgeRequests;
  final AdminAccount? currentAdmin;
  final bool isLoading;
  final DateTime? lastUpdatedAt;

  AdminWorkspaceState copyWith({
    List<AdminAccount>? admins,
    List<UserProfile>? users,
    List<VerifiedBadgeRequest>? verifiedBadgeRequests,
    AdminAccount? currentAdmin,
    bool? isLoading,
    DateTime? lastUpdatedAt,
  }) {
    return AdminWorkspaceState(
      admins: admins ?? this.admins,
      users: users ?? this.users,
      verifiedBadgeRequests: verifiedBadgeRequests ?? this.verifiedBadgeRequests,
      currentAdmin: currentAdmin ?? this.currentAdmin,
      isLoading: isLoading ?? this.isLoading,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class AdminWorkspaceController extends StateNotifier<AsyncValue<AdminWorkspaceState>> {
  AdminWorkspaceController(this._ref)
      : _firebaseService = _ref.read(firebaseServiceProvider),
        _emailService = _ref.read(farmEmailServiceProvider),
        _notifications = _ref.read(notificationsProvider.notifier),
        super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final FirebaseService _firebaseService;
  final FarmEmailService _emailService;
  final NotificationsNotifier _notifications;
  static const String _sessionKey = 'admin_session_email';
  static const String _collection = 'app_admins';

  AdminWorkspaceState? get _current => state.valueOrNull;

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? sessionEmail = prefs.getString(_sessionKey);
      final List<AdminAccount> admins = await _loadAdmins();
      final List<UserProfile> users = await _loadUsers();
      final List<VerifiedBadgeRequest> verifiedBadgeRequests = await _loadVerifiedBadgeRequests();
      final AdminAccount? currentAdmin =
          sessionEmail == null ? null : _findAdminByEmail(admins, sessionEmail);
      if (!mounted) return;
      state = AsyncValue.data(
        AdminWorkspaceState(
          admins: admins,
          users: users,
          verifiedBadgeRequests: verifiedBadgeRequests,
          currentAdmin: currentAdmin,
          isLoading: false,
          lastUpdatedAt: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<List<AdminAccount>> _loadAdmins() async {
    final List<Map<String, dynamic>> remote = await _safeLoadAdminRecords();
    final Map<String, AdminAccount> merged = <String, AdminAccount>{
      kDefaultAdminEmail: AdminAccount(
        id: kDefaultAdminEmail,
        name: 'FarmSync Super Admin',
        email: kDefaultAdminEmail,
        password: kDefaultAdminPassword,
        role: 'Super Admin',
        createdAt: DateTime.now(),
        isActive: true,
        notes: 'Default built-in admin account.',
      ),
      for (final Map<String, dynamic> record in remote)
        (record['email'] as String? ?? record['id'] as String? ?? ''): AdminAccount.fromJson(record),
    };
    final List<AdminAccount> admins = merged.values.toList(growable: false);
    admins.sort((AdminAccount a, AdminAccount b) => a.email.compareTo(b.email));
    return admins;
  }

  Future<List<UserProfile>> _loadUsers() async {
    try {
      return await _firebaseService.getAllUserProfiles();
    } catch (_) {
      return <UserProfile>[];
    }
  }

  Future<List<VerifiedBadgeRequest>> _loadVerifiedBadgeRequests() async {
    try {
      final List<VerifiedBadgeRequest> requests = await _firebaseService.getVerifiedBadgeRequests();
      requests.sort((VerifiedBadgeRequest a, VerifiedBadgeRequest b) => b.requestedAt.compareTo(a.requestedAt));
      return requests;
    } catch (_) {
      return <VerifiedBadgeRequest>[];
    }
  }

  Future<List<Map<String, dynamic>>> _safeLoadAdminRecords() async {
    try {
      return await _firebaseService.getAdminAccounts();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> refresh() => load();

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (_current == null) {
      await load();
    }
    final String normalizedEmail = email.trim().toLowerCase();
    final AdminAccount? admin = _findAdminByEmail(_current?.admins ?? <AdminAccount>[], normalizedEmail);
    if (admin == null || !admin.isActive || admin.password != password) {
      return false;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, admin.email);
    await _firebaseService.saveAdminAccount(
      admin.copyWith(lastLoginAt: DateTime.now()).toJson(),
    );
    await load();
    return true;
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await load();
  }

  Future<String?> recoverPassword({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (_current == null) {
      await load();
    }
    if (recoveryCode.trim() != kAdminRecoveryCode) {
      return 'Recovery code is incorrect.';
    }
    final AdminWorkspaceState? current = _current;
    if (current == null) {
      return 'Admin workspace is not ready yet.';
    }
    final String normalizedEmail = email.trim().toLowerCase();
    final int index = current.admins.indexWhere((AdminAccount item) => item.email.toLowerCase() == normalizedEmail);
    if (index == -1) {
      return 'No admin account found for that email.';
    }
    final AdminAccount updated = current.admins[index].copyWith(
      password: newPassword,
      lastLoginAt: DateTime.now(),
    );
    await _firebaseService.saveAdminAccount(updated.toJson());
    await load();
    return null;
  }

  Future<String?> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String role,
    String notes = '',
  }) async {
    if (_current == null) {
      await load();
    }
    final String normalizedEmail = email.trim().toLowerCase();
    final AdminWorkspaceState? current = _current;
    if (current == null) {
      return 'Admin workspace is not ready yet.';
    }
    if (current.admins.any((AdminAccount item) => item.email.toLowerCase() == normalizedEmail)) {
      return 'That admin already exists.';
    }
    final AdminAccount account = AdminAccount(
      id: normalizedEmail,
      name: name.trim(),
      email: normalizedEmail,
      password: password,
      role: role.trim().isEmpty ? 'Admin' : role.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
      isActive: true,
    );
    await _firebaseService.saveAdminAccount(account.toJson());
    await load();
    return null;
  }

  Future<void> setUserDisabled({
    required String userId,
    required bool disabled,
    required List<String> restrictedFeatures,
  }) async {
    await _firebaseService.updateUserRestrictions(
      uid: userId,
      isDisabled: disabled,
      restrictedFeatures: restrictedFeatures,
    );
    await load();
  }

  Future<void> deleteUser(String userId) async {
    await _firebaseService.deleteUserProfile(userId);
    await load();
  }

  Future<void> saveUser(UserProfile profile) async {
    await _firebaseService.saveUserProfile(profile);
    await load();
  }

  Future<void> approveVerifiedBadge(VerifiedBadgeRequest request) async {
    await _reviewVerifiedBadgeRequest(request, approved: true);
  }

  Future<void> declineVerifiedBadge(
    VerifiedBadgeRequest request, {
    String note = '',
  }) async {
    await _reviewVerifiedBadgeRequest(request, approved: false, note: note);
  }

  Future<void> saveAdmin(AdminAccount admin) async {
    final AdminAccount safeAdmin =
        admin.id == kDefaultAdminEmail || admin.email == kDefaultAdminEmail
            ? admin.copyWith(isActive: true)
            : admin;
    await _firebaseService.saveAdminAccount(safeAdmin.toJson());
    await load();
  }

  Future<void> _reviewVerifiedBadgeRequest(
    VerifiedBadgeRequest request, {
    required bool approved,
    String note = '',
  }) async {
    final AdminWorkspaceState? current = _current;
    final String reviewerName = current?.currentAdmin?.name.trim().isNotEmpty == true
        ? current!.currentAdmin!.name
        : 'FarmSync Admin';
    await _firebaseService.reviewVerifiedBadgeRequest(
      request: request,
      approved: approved,
      reviewerName: reviewerName,
      note: note,
    );

    UserProfile? user;
    for (final UserProfile candidate in current?.users ?? <UserProfile>[]) {
      if (candidate.uid == request.userId) {
        user = candidate;
        break;
      }
    }
    final String email = user?.email.trim().isNotEmpty == true ? user!.email : request.email;
    final String recipientName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : (request.userName.isNotEmpty ? request.userName : email.split('@').first);
    if (email.isNotEmpty) {
      await _emailService.sendVerifiedBadgeDecisionNotification(
        toEmail: email,
        recipientName: recipientName,
        approved: approved,
        reviewerName: reviewerName,
        note: note,
      );
    }
    await _notifications.publishNotification(
      title: approved ? 'Verified badge approved' : 'Verified badge declined',
      message: approved
          ? 'Your verified badge request was approved. The badge will now appear on your news posts and reposts.'
          : 'Your verified badge request was declined${note.isNotEmpty ? ': $note' : '.'}',
      type: approved ? NotificationType.success : NotificationType.warning,
      actionUrl: '/profile',
      audience: 'single',
      targetUserId: request.userId,
      metadata: <String, dynamic>{
        'source': 'verified_badge_review',
        'requestId': request.id,
        'approved': approved,
        if (note.isNotEmpty) 'note': note,
      },
    );
    await load();
  }

  Future<void> deleteAdmin(String id) async {
    if (id == kDefaultAdminEmail) {
      return;
    }
    await _firebaseService.deleteAdminAccount(id);
    await load();
  }

  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
    required String type,
    String audience = 'all',
    String? targetUserId,
  }) async {
    await _notifications.publishNotification(
      title: title,
      message: message,
      type: _notificationTypeFromAdminType(type),
      actionUrl: '/notifications',
      audience: audience,
      targetUserId: targetUserId,
      metadata: <String, dynamic>{
        'source': 'admin',
        'adminType': type,
      },
    );
    final List<UserProfile> recipients = audience == 'single' && targetUserId != null
        ? _current?.users.where((UserProfile user) => user.uid == targetUserId).toList(growable: false) ?? <UserProfile>[]
        : _current?.users ?? <UserProfile>[];
    for (final UserProfile user in recipients) {
      if (user.email.trim().isEmpty) {
        continue;
      }
      await _emailService.sendSystemNotification(
        toEmail: user.email,
        recipientName: user.fullName.isNotEmpty ? user.fullName : user.email.split('@').first,
        subject: title,
        headline: title,
        body: message,
        accents: <String>[type.toUpperCase(), audience.toUpperCase()],
      );
    }
  }

  Future<void> createAdminNews({
    required String title,
    required String body,
    required String category,
    required List<String> tags,
    String whatsappHandle = '',
  }) async {
    final AdminAccount? currentAdmin = _current?.currentAdmin;
    final String authorName =
        currentAdmin != null && currentAdmin.name.trim().isNotEmpty ? currentAdmin.name : 'FarmSync Admin';
    await _firebaseService.syncGlobalToFirestore(
      'news_posts',
      <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'authorId': 'admin',
        'authorName': authorName,
        'authorWhatsapp': whatsappHandle,
        'authorAvatar': '',
        'title': title,
        'body': body,
        'category': category,
        'coverImageBase64': '',
        'coverImageName': '',
        'sourcePostId': '',
        'repostedById': '',
        'comments': <dynamic>[],
        'tags': tags,
        'location': '',
        'linkUrl': '',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isAdminPost': true,
        'repostCount': 0,
        'commentCount': 0,
        'likeCount': 0,
        'isEdited': false,
        'visibility': 'public',
      },
    );
    await _notifications.publishNotification(
      title: 'Admin news update',
      message: title,
      type: NotificationType.info,
      actionUrl: '/news',
      audience: 'all',
      metadata: <String, dynamic>{
        'source': 'admin_news',
        'category': category,
      },
    );
    final String email = currentAdmin?.email ?? '';
    if (email.isNotEmpty) {
      final String adminName = currentAdmin?.name.trim() ?? '';
      await _emailService.sendNewsUpdateNotification(
        toEmail: email,
        recipientName: adminName.isNotEmpty ? adminName : 'Admin',
        title: title,
        category: category,
        summary: body.length > 160 ? '${body.substring(0, 160)}...' : body,
      );
    }
  }

  NotificationType _notificationTypeFromAdminType(String type) {
    switch (type.toLowerCase()) {
      case 'success':
      case 'update':
      case 'news':
        return NotificationType.success;
      case 'warning':
      case 'alert':
      case 'restriction':
        return NotificationType.warning;
      case 'error':
      case 'urgent':
        return NotificationType.error;
      default:
        return NotificationType.info;
    }
  }

  AdminAccount? _findAdminByEmail(List<AdminAccount> admins, String email) {
    final String normalizedEmail = email.trim().toLowerCase();
    for (final AdminAccount admin in admins) {
      if (admin.email.toLowerCase() == normalizedEmail) {
        return admin;
      }
    }
    return null;
  }
}
