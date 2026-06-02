import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/user_profile.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_card.dart';
import 'admin_locked_view.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? state = adminAsync.valueOrNull;
    final ThemeData theme = Theme.of(context);

    if (adminAsync.isLoading || state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.currentAdmin == null) {
      return const AdminLockedView(
        message: 'Use the hidden admin login to view, edit, and restrict user accounts.',
      );
    }
    final String query = _searchController.text.trim().toLowerCase();
    final List<UserProfile> filtered = state.users.where((UserProfile user) {
          if (query.isEmpty) return true;
          return user.fullName.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.ward.toLowerCase().contains(query) ||
              user.primaryFocus.toLowerCase().contains(query);
        }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All users'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
              onRefresh: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: <Widget>[
                  AppCard(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search users',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Showing ${filtered.length} users', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  ...filtered.map(
                    (UserProfile user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: ListTile(
                          onTap: () => context.go('/admin-users/${user.uid}'),
                          leading: CircleAvatar(
                            child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?'),
                          ),
                          title: Text(user.fullName.isEmpty ? user.email : user.fullName),
                          subtitle: Text(
                            user.isDisabled
                                ? 'Disabled'
                                : user.restrictedFeatures.isNotEmpty
                                    ? 'Restricted: ${user.restrictedFeatures.join(', ')}'
                                    : user.primaryFocus.isNotEmpty
                                        ? user.primaryFocus
                                        : user.ward,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
    );
  }
}
