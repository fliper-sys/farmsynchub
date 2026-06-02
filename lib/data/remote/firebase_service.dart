import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/user_profile.dart';

/// Firebase service for authentication and cloud operations.
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

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

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(userId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return UserProfile.fromJson(data);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    debugPrint('[Firestore] saveUserProfile:start uid=${profile.uid} email=${profile.email} ward=${profile.ward} focus=${profile.primaryFocus}');
    debugPrint('[Firestore] saveUserProfile:authUser uid=${currentUser?.uid} email=${currentUser?.email} verified=${currentUser?.emailVerified}');
    await _firestore.collection('users').doc(profile.uid).set(profile.toJson(), SetOptions(merge: true));
    debugPrint('[Firestore] saveUserProfile:document write complete for users/${profile.uid}');

    if (currentUser != null && profile.fullName.trim().isNotEmpty) {
      await currentUser!.updateDisplayName(profile.fullName.trim());
      debugPrint('[Firestore] saveUserProfile:displayName updated to ${profile.fullName.trim()}');
    }
  }

  Future<String> runProfileWriteDebugCheck(UserProfile profile) async {
    final String? userId = currentUser?.uid;
    if (userId == null) {
      return 'Debug check failed: no authenticated user.';
    }

    final StringBuffer log = StringBuffer()
      ..writeln('Authenticated user: $userId')
      ..writeln('Profile target doc: users/${profile.uid}');

    try {
      final DocumentReference<Map<String, dynamic>> userDoc =
          _firestore.collection('users').doc(profile.uid);

      await userDoc.set(<String, dynamic>{
        'uid': profile.uid,
        'email': profile.email,
        'fullName': profile.fullName,
        'updatedAt': profile.updatedAt.toIso8601String(),
        'debugLastWriteCheckAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      log.writeln('User document write: success');

      final DocumentSnapshot<Map<String, dynamic>> userSnapshot = await userDoc.get();
      log.writeln('User document read: ${userSnapshot.exists ? 'success' : 'missing after write'}');

      final DocumentReference<Map<String, dynamic>> debugDoc =
          userDoc.collection('debug').doc('firestore_check');
      await debugDoc.set(<String, dynamic>{
        'checkedAt': DateTime.now().toIso8601String(),
        'authUid': userId,
        'profileUid': profile.uid,
      });
      log.writeln('Nested debug collection write: success');

      final DocumentSnapshot<Map<String, dynamic>> debugSnapshot = await debugDoc.get();
      log.writeln('Nested debug collection read: ${debugSnapshot.exists ? 'success' : 'missing after write'}');

      await debugDoc.delete();
      log.writeln('Nested debug collection cleanup: success');
    } on FirebaseException catch (error) {
      log.writeln('FirebaseException code=${error.code}');
      log.writeln('FirebaseException message=${error.message}');
      debugPrint('[Firestore] runProfileWriteDebugCheck:error ${log.toString()}');
      return log.toString();
    } catch (error) {
      log.writeln('Unexpected error=$error');
      debugPrint('[Firestore] runProfileWriteDebugCheck:error ${log.toString()}');
      return log.toString();
    }

    debugPrint('[Firestore] runProfileWriteDebugCheck:success ${log.toString()}');
    return log.toString();
  }

  /// Sign in with phone number
  Future<void> signInWithPhoneNumber(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        throw e;
      },
      codeSent: (String verificationId, int? resendToken) {
        // Handle code sent - this would be handled in the UI
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout
      },
    );
  }

  /// Verify OTP
  Future<UserCredential> verifyOTP(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sync data to Firestore
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
  }

  /// Get data from Firestore
  Future<List<Map<String, dynamic>>> getFromFirestore(String collection) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<Map<String, dynamic>?> getDocumentFromFirestore(String collection, String id) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .get();

    return snapshot.data();
  }

  /// Delete from Firestore
  Future<void> deleteFromFirestore(String collection, String id) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .doc(id)
        .delete();
  }

  Future<void> syncGlobalToFirestore(String collection, Map<String, dynamic> data) async {
    final String? documentId = data['id'] as String?;
    if (documentId == null || documentId.trim().isEmpty) {
      throw Exception('Cannot sync $collection record without a valid id');
    }
    await _firestore.collection(collection).doc(documentId).set(data, SetOptions(merge: true));
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
    );

    await _firestore.collection('users').doc(uid).set(profile.toJson(), SetOptions(merge: true));
  }
}
