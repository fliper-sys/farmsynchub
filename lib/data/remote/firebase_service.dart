import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import '../../domain/models/user_profile.dart';
import '../../domain/models/verified_badge_request.dart';
import '../repositories/farm_repository.dart';
import 'operations_hub_remote_store.dart';

List<Map<String, dynamic>> mergeFirestoreRecords(
  List<Map<String, dynamic>> preferred,
  List<Map<String, dynamic>> fallback,
) {
  final Map<String, Map<String, dynamic>> merged = <String, Map<String, dynamic>>{};

  for (final Map<String, dynamic> record in preferred) {
    final String? id = record['id'] as String?;
    if (id == null || id.trim().isEmpty) {
      continue;
    }
    merged[id] = record;
  }

  for (final Map<String, dynamic> record in fallback) {
    final String? id = record['id'] as String?;
    if (id == null || id.trim().isEmpty || merged.containsKey(id)) {
      continue;
    }
    merged[id] = record;
  }

  return merged.values.toList(growable: false);
}

/// Firebase service for authentication and cloud operations.
class FirebaseService implements FarmRemoteStore, OperationsHubRemoteStore {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  ConfirmationResult? _webPhoneConfirmationResult;
  static const String _googleWebClientId =
      '190353139949-8vjnn71ku91tvp75kpl2q5ete9hcpnd1.apps.googleusercontent.com';

  /// Get current user
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get hasActiveUser => currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register a user with email and password.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (displayName != null && displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
    }

    await _createDefaultUserProfile(
      uid: credential.user?.uid,
      email: email,
      displayName: displayName,
      phoneNumber: phoneNumber,
    );

    return credential;
  }

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google.
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: <String>['email'],
      clientId: kIsWeb ? _googleWebClientId : null,
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _createDefaultUserProfile(
        uid: userCredential.user?.uid,
        email: userCredential.user?.email ?? '',
        displayName: userCredential.user?.displayName,
        phoneNumber: userCredential.user?.phoneNumber,
      );
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (error) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: _googleSignInErrorMessage(error),
      );
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = currentUser;
    final String email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You need to be signed in to change your password.',
      );
    }

    final AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Sends a verification email to the current user.
  Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
  }

  /// Reloads current user from Firebase.
  Future<void> reloadCurrentUser() async {
    await currentUser?.reload();
  }

  Future<UserProfile?> getUserProfile() async {
    final String? userId = currentUser?.uid;
    if (userId == null) {
      return null;
    }

    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection('users').doc(userId);

    // Prefer the on-device cache first so a previously-signed-in user isn't
    // stuck waiting on a network round trip that may never resolve offline.
    try {
      final DocumentSnapshot<Map<String, dynamic>> cached =
          await docRef.get(const GetOptions(source: Source.cache));
      final Map<String, dynamic>? cachedData = cached.data();
      if (cachedData != null) {
        return UserProfile.fromJson(cachedData);
      }
    } catch (_) {
      // No cached document yet; fall through to a server fetch.
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await docRef.get().timeout(const Duration(seconds: 8));
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return UserProfile.fromJson(data);
  }

  Future<UserProfile?> getUserProfileById(String userId) async {
    if (userId.trim().isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(userId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return UserProfile.fromJson(data);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.uid).set(profile.toJson(), SetOptions(merge: true));

    if (currentUser != null && profile.fullName.trim().isNotEmpty) {
      await currentUser!.updateDisplayName(profile.fullName.trim());
    }
  }

  Future<void> saveDeviceToken(String token) async {
    final User? user = currentUser;
    if (user == null || token.isEmpty) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set(
      <String, dynamic>{
        'fcmTokens': FieldValue.arrayUnion(<String>[token]),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<UserProfile>> getAllUserProfiles() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore.collection('users').get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => UserProfile.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<List<VerifiedBadgeRequest>> getVerifiedBadgeRequests() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore.collection('verified_badge_requests').get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => VerifiedBadgeRequest.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<void> saveVerifiedBadgeRequest(VerifiedBadgeRequest request) async {
    await _firestore.collection('verified_badge_requests').doc(request.id).set(request.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteVerifiedBadgeRequest(String id) async {
    await _firestore.collection('verified_badge_requests').doc(id).delete();
  }

  Future<void> updateUserVerificationStatus({
    required String uid,
    required bool isVerified,
    required String verificationStatus,
    String verificationNote = '',
    DateTime? verificationRequestedAt,
    DateTime? verificationReviewedAt,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      <String, dynamic>{
        'isVerified': isVerified,
        'verificationStatus': verificationStatus,
        'verificationNote': verificationNote,
        'verificationRequestedAt': verificationRequestedAt?.toIso8601String(),
        'verificationReviewedAt': verificationReviewedAt?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<VerifiedBadgeRequest?> getVerifiedBadgeRequestByUserId(String userId) async {
    if (userId.trim().isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('verified_badge_requests').doc(userId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return VerifiedBadgeRequest.fromJson(data);
  }

  Future<void> requestVerifiedBadge({
    required UserProfile profile,
    String note = '',
  }) async {
    final DateTime now = DateTime.now();
    final VerifiedBadgeRequest request = VerifiedBadgeRequest(
      id: profile.uid,
      userId: profile.uid,
      userName: profile.fullName.isNotEmpty ? profile.fullName : profile.email.split('@').first,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      ward: profile.ward,
      primaryFocus: profile.primaryFocus,
      bio: profile.bio,
      profileImageBase64: profile.profileImageBase64,
      note: note.trim(),
      status: VerifiedBadgeRequestStatus.pending,
      requestedAt: now,
      updatedAt: now,
    );
    await saveVerifiedBadgeRequest(request);
    await updateUserVerificationStatus(
      uid: profile.uid,
      isVerified: false,
      verificationStatus: 'pending',
      verificationNote: note.trim(),
      verificationRequestedAt: now,
      verificationReviewedAt: null,
    );
  }

  Future<void> reviewVerifiedBadgeRequest({
    required VerifiedBadgeRequest request,
    required bool approved,
    required String reviewerName,
    String note = '',
  }) async {
    final DateTime now = DateTime.now();
    final VerifiedBadgeRequest updated = request.copyWith(
      status: approved ? VerifiedBadgeRequestStatus.approved : VerifiedBadgeRequestStatus.declined,
      updatedAt: now,
      reviewedBy: reviewerName,
      reviewedAt: now,
      note: note.trim().isEmpty ? request.note : note.trim(),
    );
    await saveVerifiedBadgeRequest(updated);
    await updateUserVerificationStatus(
      uid: request.userId,
      isVerified: approved,
      verificationStatus: approved ? 'approved' : 'declined',
      verificationNote: updated.note,
      verificationRequestedAt: request.requestedAt,
      verificationReviewedAt: now,
    );
  }

  Future<void> deleteUserProfile(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<void> updateUserRestrictions({
    required String uid,
    required bool isDisabled,
    required List<String> restrictedFeatures,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      <String, dynamic>{
        'isDisabled': isDisabled,
        'restrictedFeatures': restrictedFeatures,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Start a phone-number verification flow and return the verification ID.
  Future<String> signInWithPhoneNumber(String phoneNumber) async {
    if (kIsWeb) {
      final ConfirmationResult confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
      _webPhoneConfirmationResult = confirmationResult;
      return 'web-phone-confirmation';
    }

    final Completer<String> verificationIdCompleter = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.complete('');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.completeError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!verificationIdCompleter.isCompleted) {
          verificationIdCompleter.complete(verificationId);
        }
      },
    );
    return verificationIdCompleter.future;
  }

  /// Verify OTP
  Future<UserCredential> verifyOTP(String verificationId, String smsCode) async {
    if (kIsWeb) {
      final ConfirmationResult? confirmationResult = _webPhoneConfirmationResult;
      if (confirmationResult == null) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'Phone verification session has expired. Please request a new code.',
        );
      }

      final UserCredential userCredential = await confirmationResult.confirm(smsCode);
      _webPhoneConfirmationResult = null;
      await _createDefaultUserProfile(
        uid: userCredential.user?.uid,
        email: userCredential.user?.email ?? '',
        displayName: userCredential.user?.displayName,
        phoneNumber: userCredential.user?.phoneNumber,
      );
      return userCredential;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    await _createDefaultUserProfile(
      uid: userCredential.user?.uid,
      email: userCredential.user?.email ?? '',
      displayName: userCredential.user?.displayName,
      phoneNumber: userCredential.user?.phoneNumber,
    );
    return userCredential;
  }

  /// Sign out
  Future<void> signOut() async {
    _webPhoneConfirmationResult = null;
    await _auth.signOut();
  }

  /// Sync data to Firestore
  @override
  Future<void> syncToFirestore(String collection, Map<String, dynamic> data) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    final String? documentId = data['id'] as String?;
    if (documentId == null || documentId.trim().isEmpty) {
      throw Exception('Cannot sync $collection record without a valid id');
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(documentId)
        .set(data, SetOptions(merge: true));

    try {
      await _firestore.collection(collection).doc(documentId).set(data, SetOptions(merge: true));
    } catch (_) {
      // Ignore shared write failures so the user-scoped copy still persists.
    }
  }

  /// Get data from Firestore
  @override
  Future<List<Map<String, dynamic>>> getFromFirestore(String collection) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final List<Map<String, dynamic>> userScoped = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> globalScoped = <Map<String, dynamic>>[];

    try {
      final userSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(collection)
          .get();
      userScoped.addAll(userSnapshot.docs.map((doc) => doc.data()).toList(growable: false));
    } catch (_) {
      // Ignore user-scoped read failures and continue to fall back to shared records.
    }

    try {
      final globalSnapshot = await _firestore.collection(collection).get();
      globalScoped.addAll(globalSnapshot.docs.map((doc) => doc.data()).toList(growable: false));
    } catch (_) {
      // Ignore global read failures if the collection is unavailable.
    }

    return mergeFirestoreRecords(userScoped, globalScoped);
  }

  Future<Map<String, dynamic>?> getDocumentFromFirestore(String collection, String id) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final userSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .get();

    if (userSnapshot.exists) {
      return userSnapshot.data();
    }

    final globalSnapshot = await _firestore.collection(collection).doc(id).get();
    return globalSnapshot.data();
  }

  /// Delete from Firestore
  @override
  Future<void> deleteFromFirestore(String collection, String id) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .delete();

    try {
      await _firestore.collection(collection).doc(id).delete();
    } catch (_) {
      // Ignore shared delete failures so the user-scoped delete still succeeds.
    }
  }

  Future<void> syncGlobalToFirestore(String collection, Map<String, dynamic> data) async {
    final String? documentId = data['id'] as String?;
    if (documentId == null || documentId.trim().isEmpty) {
      throw Exception('Cannot sync $collection record without a valid id');
    }
    await _firestore.collection(collection).doc(documentId).set(data, SetOptions(merge: true));
  }

  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
    required String type,
    String audience = 'all',
    String? targetUserId,
    Map<String, dynamic>? metadata,
  }) async {
    final String id = _uuid.v4();
    await syncGlobalToFirestore('app_notifications', <String, dynamic>{
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
      'actionUrl': '/notifications',
      'metadata': <String, dynamic>{
        'audience': audience,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (metadata != null) ...metadata,
      },
    });
  }

  Future<List<Map<String, dynamic>>> getAdminAccounts() async {
    return getGlobalFromFirestore('app_admins');
  }

  Future<void> saveAdminAccount(Map<String, dynamic> data) async {
    await syncGlobalToFirestore('app_admins', data);
  }

  Future<void> deleteAdminAccount(String id) async {
    await deleteGlobalFromFirestore('app_admins', id);
  }

  Future<List<Map<String, dynamic>>> getGlobalFromFirestore(String collection) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore.collection(collection).get();
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data()).toList(growable: false);
  }

  Future<Map<String, dynamic>?> getGlobalDocumentFromFirestore(String collection, String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore.collection(collection).doc(id).get();
    return snapshot.data();
  }

  Future<void> deleteGlobalFromFirestore(String collection, String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }

  /// Create an invitation record for a user to join a farm workspace.
  Future<void> createInvite({
    required String id,
    required String email,
    String? name,
    required String farmId,
    required String role,
    required List<String> allowedFarmIds,
    required String createdBy,
    required DateTime createdAt,
  }) async {
    await _firestore.collection('invites').doc(id).set(
      <String, dynamic>{
        'id': id,
        'email': email,
        'name': name ?? '',
        'farmId': farmId,
        'role': role,
        'allowedFarmIds': allowedFarmIds,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Accept an invite by token and claim the workspace member entry for the new user.
  Future<void> acceptInvite({
    required String inviteId,
    required String newUid,
    String? fullName,
  }) async {
    final Map<String, dynamic>? invite = await getGlobalDocumentFromFirestore('invites', inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }
    final String farmId = invite['farmId'] as String? ?? '';
    final String email = invite['email'] as String? ?? '';

    if (farmId.isEmpty) {
      throw Exception('Invalid invite: missing farm id');
    }

    final Map<String, dynamic>? farmDoc = await getGlobalDocumentFromFirestore('farms', farmId);
    if (farmDoc == null) {
      throw Exception('Farm not found');
    }

    // Update workspaceMembers matching the invited email to use the new uid and activate.
    final List<dynamic> membersRaw = farmDoc['workspaceMembers'] as List<dynamic>? ?? <dynamic>[];
    final DateTime now = DateTime.now();
    bool updated = false;
    final List<Map<String, dynamic>> updatedMembers = <Map<String, dynamic>>[];
    for (final dynamic raw in membersRaw) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(raw as Map);
      if ((m['email'] as String? ?? '').toLowerCase() == email.toLowerCase()) {
        m['id'] = newUid;
        m['name'] = (fullName != null && fullName.trim().isNotEmpty) ? fullName.trim() : (m['name'] as String? ?? '');
        m['isActive'] = true;
        m['updatedAt'] = now.toIso8601String();
        updated = true;
      }
      updatedMembers.add(m);
    }

    if (!updated) {
      // If no placeholder member existed, add a new member record.
      final Map<String, dynamic> newMember = <String, dynamic>{
        'id': newUid,
        'name': fullName ?? '',
        'email': email,
        'phone': '',
        'role': invite['role'] as String? ?? 'worker',
        'allowedFarmIds': invite['allowedFarmIds'] as List<dynamic>? ?? <String>[farmId],
        'financeAccess': 'none',
        'canManageTasks': false,
        'canManageSchedule': false,
        'canPostUpdates': true,
        'canViewActivityLog': true,
        'isActive': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      updatedMembers.insert(0, newMember);
    }

    // write back farm document with updated members
    farmDoc['workspaceMembers'] = updatedMembers;
    farmDoc['updatedAt'] = now.toIso8601String();
    await syncGlobalToFirestore('farms', farmDoc);

    // remove or mark invite accepted
    await _firestore.collection('invites').doc(inviteId).delete();
  }

  Future<void> _createDefaultUserProfile({
    required String? uid,
    required String email,
    required String? displayName,
    String? phoneNumber,
  }) async {
    if (uid == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final UserProfile profile = UserProfile(
      uid: uid,
      fullName: displayName?.trim() ?? '',
      email: email,
      phoneNumber: phoneNumber?.trim() ?? '',
      accountRole: UserAccountRole.owner,
      ward: '',
      primaryFocus: '',
      bio: '',
      profileImageBase64: '',
      createdAt: now,
      updatedAt: now,
      fcmTokens: const <String>[],
    );

    await _firestore.collection('users').doc(uid).set(profile.toJson(), SetOptions(merge: true));
  }

  String _googleSignInErrorMessage(Object error) {
    if (kIsWeb) {
      return 'Google sign-in is not fully configured for web yet. Make sure the web OAuth client ID is added in web/index.html and the domain is authorized in Firebase.';
    }
    return 'Google sign-in failed. Check Firebase Google provider settings and your Android SHA-1/SHA-256 fingerprints.';
  }
}
