import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/admin_note.dart';
import '../../../providers/admin_notes_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import 'admin_locked_view.dart';

class AdminNotesScreen extends ConsumerStatefulWidget {
  const AdminNotesScreen({super.key});

  @override
  ConsumerState<AdminNotesScreen> createState() => _AdminNotesScreenState();
}

class _AdminNotesScreenState extends ConsumerState<AdminNotesScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _targetAdminId = '';
  String _targetAdminEmail = '';
  bool _isPinned = false;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? adminState = adminAsync.valueOrNull;
    if (adminAsync.isLoading || adminState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (adminState.currentAdmin == null) {
      return const AdminLockedView(
        message: 'Use the hidden admin login to exchange live work notes with other admins.',
      );
    }

    final AsyncValue<List<AdminNote>> notesAsync = ref.watch(adminNotesProvider);
    final bool isLoadingNotes = notesAsync.isLoading;
    final List<AdminNote> notes = notesAsync.valueOrNull ?? <AdminNote>[];
    final List<AdminAccount> admins = adminState.admins.where((AdminAccount admin) => admin.isActive).toList(growable: false);
    final List<AdminNote> visibleNotes = ref.read(adminNotesProvider.notifier).visibleNotesFor(adminState.currentAdmin);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin notes'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(adminNotesProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminNotesProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            AppCard(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Work notes', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Drop live notes here so admins can coordinate tasks, handoffs, support requests, and urgent follow-ups.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _targetAdminId.isEmpty ? null : _targetAdminId,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All admins'),
                        ),
                        ...admins.map(
                          (AdminAccount admin) => DropdownMenuItem<String>(
                            value: admin.id,
                            child: Text(admin.name.isEmpty ? admin.email : '${admin.name} (${admin.email})'),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        final AdminAccount? selected = admins.where((AdminAccount admin) => admin.id == value).cast<AdminAccount?>().firstWhere(
                              (AdminAccount? item) => item != null,
                              orElse: () => null,
                            );
                        setState(() {
                          _targetAdminId = value;
                          _targetAdminEmail = selected?.email ?? '';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Send to'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _messageController,
                      label: 'Message',
                      hint: 'Example: please review the crop report before noon',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pin this note'),
                      subtitle: const Text('Keep urgent notes at the top.'),
                      value: _isPinned,
                      onChanged: (bool value) => setState(() => _isPinned = value),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _sending ? null : () => _send(context),
                      child: Text(_sending ? 'Sending...' : 'Send note'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Live feed', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (isLoadingNotes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibleNotes.isEmpty)
              const Text('No admin notes yet.')
            else
              ...visibleNotes.map(
                (AdminNote note) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: ListTile(
                      onTap: note.isRead
                          ? null
                          : () => ref.read(adminNotesProvider.notifier).markRead(note.id),
                      title: Text(note.message),
                      subtitle: Text(
                        '${note.senderName} • ${_formatTarget(note)} • ${note.createdAt}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: CircleAvatar(
                        child: Text(note.senderName.isNotEmpty ? note.senderName[0].toUpperCase() : 'A'),
                      ),
                      trailing: note.isPinned
                          ? const Icon(Icons.push_pin_rounded)
                          : note.isRead
                              ? const Icon(Icons.done_rounded)
                              : const Icon(Icons.mark_chat_unread_rounded),
                    ),
                  ),
                ),
              ),
            if (notes.isNotEmpty) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final String message = _messageController.text.trim();
    if (message.isEmpty) {
      context.showSnackBar('Write a note first.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(adminNotesProvider.notifier).sendNote(
            message: message,
            targetAdminId: _targetAdminId,
            targetAdminEmail: _targetAdminEmail,
            isPinned: _isPinned,
          );
      if (!mounted) return;
      context.showSnackBar('Admin note sent.');
      _messageController.clear();
      setState(() {
        _targetAdminId = '';
        _targetAdminEmail = '';
        _isPinned = false;
      });
    } catch (_) {
      if (!mounted) return;
      context.showSnackBar('Could not send admin note.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _formatTarget(AdminNote note) {
    if (note.targetAdminEmail.isEmpty && note.targetAdminId.isEmpty) {
      return 'All admins';
    }
    return note.targetAdminEmail.isNotEmpty ? 'To ${note.targetAdminEmail}' : 'Private note';
  }
}
