import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/remote/firebase_service.dart';
import '../domain/models/admin_note.dart';
import 'admin_provider.dart';
import 'auth_provider.dart';

final adminNotesProvider =
    StateNotifierProvider<AdminNotesController, AsyncValue<List<AdminNote>>>((ref) {
  return AdminNotesController(
    ref.read(firebaseServiceProvider),
    ref.read(adminWorkspaceProvider.notifier),
  );
});

class AdminNotesController extends StateNotifier<AsyncValue<List<AdminNote>>> {
  AdminNotesController(this._firebaseService, this._adminWorkspaceController)
      : super(const AsyncValue.loading()) {
    load();
  }

  final FirebaseService _firebaseService;
  final AdminWorkspaceController _adminWorkspaceController;
  static const String _collection = 'app_admin_notes';
  final Uuid _uuid = const Uuid();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final List<Map<String, dynamic>> records = await _firebaseService.getGlobalFromFirestore(_collection);
      final List<AdminNote> notes = records.map(AdminNote.fromJson).toList(growable: false)
        ..sort((AdminNote a, AdminNote b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncValue.data(notes);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => load();

  Future<void> sendNote({
    required String message,
    String targetAdminId = '',
    String targetAdminEmail = '',
    bool isPinned = false,
  }) async {
    final AdminWorkspaceState? workspace = _adminWorkspaceController.state.valueOrNull;
    final AdminAccount? sender = workspace?.currentAdmin;
    if (sender == null) {
      throw StateError('Admin session is not available.');
    }
    final AdminNote note = AdminNote(
      id: _uuid.v4(),
      senderId: sender.id,
      senderName: sender.name,
      senderEmail: sender.email,
      targetAdminId: targetAdminId,
      targetAdminEmail: targetAdminEmail,
      message: message.trim(),
      createdAt: DateTime.now(),
      isPinned: isPinned,
    );
    await _firebaseService.syncGlobalToFirestore(_collection, note.toJson());
    await load();
  }

  List<AdminNote> visibleNotesFor(AdminAccount? currentAdmin) {
    final List<AdminNote> notes = state.valueOrNull ?? <AdminNote>[];
    if (currentAdmin == null) {
      return notes;
    }
    return notes.where((AdminNote note) {
      if (note.targetAdminEmail.isEmpty && note.targetAdminId.isEmpty) {
        return true;
      }
      return note.targetAdminId == currentAdmin.id ||
          note.targetAdminEmail.toLowerCase() == currentAdmin.email.toLowerCase();
    }).toList(growable: false);
  }

  Future<void> markRead(String noteId) async {
    final List<AdminNote> current = state.valueOrNull ?? <AdminNote>[];
    final int index = current.indexWhere((AdminNote note) => note.id == noteId);
    if (index == -1) return;
    final AdminNote updated = current[index].copyWith(isRead: true);
    await _firebaseService.syncGlobalToFirestore(_collection, updated.toJson());
    await load();
  }
}
