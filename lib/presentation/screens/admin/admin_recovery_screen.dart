import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_text_field.dart';
import '../auth/auth_shared.dart';

class AdminRecoveryScreen extends ConsumerStatefulWidget {
  const AdminRecoveryScreen({super.key});

  @override
  ConsumerState<AdminRecoveryScreen> createState() => _AdminRecoveryScreenState();
}

class _AdminRecoveryScreenState extends ConsumerState<AdminRecoveryScreen> {
  final TextEditingController _emailController = TextEditingController(text: kDefaultAdminEmail);
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final bool isLoading = adminAsync.isLoading;

    return AuthScaffold(
      title: 'Recover admin password',
      subtitle: 'Only admins with the recovery code can reset a registered admin password.',
      badge: 'Admin Recovery',
      child: Column(
        children: <Widget>[
          const AuthInfoBanner(
            icon: Icons.key_rounded,
            message: 'Recovery code: Xanther839',
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _emailController,
            label: 'Admin email',
            hint: kDefaultAdminEmail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _codeController,
            label: 'Recovery code',
            hint: 'Enter code word',
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _newPasswordController,
            label: 'New password',
            hint: 'Create a new admin password',
            obscureText: true,
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: 'Reset password',
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/admin-login'),
            child: const Text('Back to admin login'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String recoveryCode = _codeController.text.trim();
    final String newPassword = _newPasswordController.text.trim();
    final String? emailError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Admin email'),
        Validators.email,
      ],
      email,
    );
    final String? passwordError = Validators.minLength(newPassword, 8, fieldName: 'New password');
    if (emailError != null) {
      context.showSnackBar(emailError, isError: true);
      return;
    }
    if (passwordError != null) {
      context.showSnackBar(passwordError, isError: true);
      return;
    }

    final String? error = await ref.read(adminWorkspaceProvider.notifier).recoverPassword(
          email: email,
          recoveryCode: recoveryCode,
          newPassword: newPassword,
        );
    if (!mounted) {
      return;
    }
    if (error != null) {
      context.showSnackBar(error, isError: true);
      return;
    }
    context.showSnackBar('Admin password updated.');
    context.go('/admin-login');
  }
}
