import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import 'admin_locked_view.dart';

class AdminAdminsScreen extends ConsumerWidget {
  const AdminAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        message: 'Use the hidden admin login to register or manage app admins.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? GoRouterHelper(context).pop() : context.go('/admin-dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('App admins'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add admin'),
      ),
      body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                AppCard(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Register trusted admins here. The built-in login for the hidden admin area is also always available.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...state.admins.map(
                  (AdminAccount admin) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        title: Text(admin.name.isEmpty ? admin.email : admin.name),
                        subtitle: Text(
                          '${admin.email}\n${admin.role}${admin.lastLoginAt == null ? '' : ' | Last login ${admin.lastLoginAt}'}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (String value) async {
                            if (value == 'toggle') {
                              await ref.read(adminWorkspaceProvider.notifier).saveAdmin(
                                    admin.copyWith(isActive: !admin.isActive),
                                  );
                            } else if (value == 'delete') {
                              await ref.read(adminWorkspaceProvider.notifier).deleteAdmin(admin.id);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'toggle',
                              child: Text(admin.isActive ? 'Disable' : 'Enable'),
                            ),
                            if (admin.email != kDefaultAdminEmail)
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController roleController = TextEditingController(text: 'Admin');
    final TextEditingController notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Register admin', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 14),
                AppTextField(controller: nameController, label: 'Name', hint: 'Admin full name'),
                const SizedBox(height: 12),
                AppTextField(controller: emailController, label: 'Email', hint: 'admin@example.com'),
                const SizedBox(height: 12),
                AppTextField(controller: passwordController, label: 'Password', hint: 'Create admin password', obscureText: true),
                const SizedBox(height: 12),
                AppTextField(controller: roleController, label: 'Role', hint: 'Manager, support, editor'),
                const SizedBox(height: 12),
                AppTextField(controller: notesController, label: 'Notes', hint: 'Optional notes', maxLines: 3),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final String name = nameController.text.trim();
                      final String email = emailController.text.trim();
                      final String password = passwordController.text.trim();
                      final String? emailError = Validators.combine(
                        <String? Function(String?)>[
                          (String? value) => Validators.required(value, fieldName: 'Email'),
                          Validators.email,
                        ],
                        email,
                      );
                      if (name.isEmpty || emailError != null || password.length < 8) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(emailError ?? 'Password must be at least 8 characters.')),
                        );
                        return;
                      }
                      final String? error = await ref.read(adminWorkspaceProvider.notifier).registerAdmin(
                            name: name,
                            email: email,
                            password: password,
                            role: roleController.text.trim(),
                            notes: notesController.text.trim(),
                          );
                      if (sheetContext.mounted) {
                        if (error != null) {
                          sheetContext.showSnackBar(error, isError: true);
                        } else {
                          Navigator.of(sheetContext).pop();
                          context.showSnackBar('Admin created.');
                        }
                      }
                    },
                    child: const Text('Create admin'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    roleController.dispose();
    notesController.dispose();
  }
}
