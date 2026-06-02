import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_text_field.dart';
import '../auth/auth_shared.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController(text: kDefaultAdminEmail);
  final TextEditingController _passwordController = TextEditingController(text: kDefaultAdminPassword);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final bool isLoading = adminAsync.isLoading;

    return AuthScaffold(
      title: 'Admin access',
      subtitle: 'Hidden workspace for app administration, user control, and broadcast tools.',
      badge: 'Admin Console',
      child: Column(
        children: <Widget>[
          const AuthInfoBanner(
            icon: Icons.admin_panel_settings_rounded,
            message: 'Use the built-in admin account or a registered app admin account.',
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
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter admin password',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/admin-recovery'),
              child: const Text('Recover admin password'),
            ),
          ),
          const SizedBox(height: 8),
          AuthPrimaryButton(
            label: 'Enter dashboard',
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to user login'),
          ),
          const SizedBox(height: 8),
          Text(
            'Default admin: $kDefaultAdminEmail',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String? emailError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Admin email'),
        Validators.email,
      ],
      email,
    );
    final String? passwordError = Validators.required(password, fieldName: 'Password');
    if (emailError != null) {
      context.showSnackBar(emailError, isError: true);
      return;
    }
    if (passwordError != null) {
      context.showSnackBar(passwordError, isError: true);
      return;
    }

    final bool success = await ref.read(adminWorkspaceProvider.notifier).login(
          email: email,
          password: password,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      context.go('/admin-dashboard');
    } else {
      context.showSnackBar('Admin credentials were not accepted.', isError: true);
    }
  }
}
