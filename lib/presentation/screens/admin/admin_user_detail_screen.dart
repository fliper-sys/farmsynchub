import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_card.dart';
import 'admin_locked_view.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _focusController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _restrictionController = TextEditingController();
  bool _isDisabled = false;
  bool _initialised = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _wardController.dispose();
    _focusController.dispose();
    _bioController.dispose();
    _restrictionController.dispose();
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
        message: 'Use the hidden admin login to edit user profiles and restrictions.',
      );
    }
    final UserProfile? user = adminState.users.firstWhere(
      (UserProfile item) => item.uid == widget.userId,
      orElse: () => UserProfile(
        uid: '',
        fullName: '',
        email: '',
        phoneNumber: '',
        accountRole: UserAccountRole.viewer,
        ward: '',
        primaryFocus: '',
        bio: '',
        profileImageBase64: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (user == null || user.uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('User details')),
        body: const Center(child: Text('User not found.')),
      );
    }

    if (!_initialised) {
      _initialised = true;
      _nameController.text = user.fullName;
      _phoneController.text = user.phoneNumber;
      _wardController.text = user.ward;
      _focusController.text = user.primaryFocus;
      _bioController.text = user.bio;
      _isDisabled = user.isDisabled;
      _restrictionController.text = user.restrictedFeatures.join(', ');
    }

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(user.fullName.isEmpty ? user.email : user.fullName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _deleteUser(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Edit profile', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone number')),
                  const SizedBox(height: 12),
                  TextField(controller: _wardController, decoration: const InputDecoration(labelText: 'Ward')),
                  const SizedBox(height: 12),
                  TextField(controller: _focusController, decoration: const InputDecoration(labelText: 'Primary focus')),
                  const SizedBox(height: 12),
                  TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disable account'),
                    subtitle: const Text('Stop the user from entering the workspace until restored.'),
                    value: _isDisabled,
                    onChanged: (bool value) => setState(() => _isDisabled = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _restrictionController,
                    decoration: const InputDecoration(
                      labelText: 'Restricted features',
                      hintText: 'finance, news, crops',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _saveUser(user),
                    child: const Text('Save changes'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUser(UserProfile current) async {
    final List<String> restrictedFeatures = _restrictionController.text
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final UserProfile updated = current.copyWith(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      ward: _wardController.text.trim(),
      primaryFocus: _focusController.text.trim(),
      bio: _bioController.text.trim(),
      isDisabled: _isDisabled,
      restrictedFeatures: restrictedFeatures,
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(adminWorkspaceProvider.notifier).saveUser(updated);
      if (!mounted) return;
      context.showSnackBar('User profile updated.');
    } catch (_) {
      if (!mounted) return;
      context.showSnackBar('Could not update the user profile.', isError: true);
    }
  }

  Future<void> _deleteUser(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this user?'),
        content: const Text('This removes the Firestore profile record.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminWorkspaceProvider.notifier).deleteUser(widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }
}
