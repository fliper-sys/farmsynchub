import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../common/widgets/app_text_field.dart';
import 'auth_shared.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (previous is AsyncLoading && mounted) {
            context.showSnackBar('Password reset email sent.');
          }
        },
        error: (Object error, StackTrace stackTrace) {
          context.showSnackBar(_errorMessage(error), isError: true);
        },
      );
    });

    final bool isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'Enter the email on your account and we will send a secure password reset link.',
      child: Column(
        children: <Widget>[
          const AuthInfoBanner(
            icon: Icons.lock_reset_rounded,
            message: 'The reset link should arrive within a few minutes if the email is registered.',
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'farmer@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: 'Send reset email',
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 18),
          const AuthSecondaryLinkRow(
            prompt: 'Remembered your password?',
            actionLabel: 'Back to login',
            route: '/login',
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String? emailError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Email'),
        Validators.email,
      ],
      email,
    );

    if (emailError != null) {
      context.showSnackBar(emailError, isError: true);
      return;
    }

    await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email);
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException && error.code == 'user-not-found') {
      return 'No account was found for that email address.';
    }
    return 'Could not send reset email. Please try again.';
  }
}
