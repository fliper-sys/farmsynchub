import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../providers/auth_provider.dart';
import '../../common/widgets/app_button.dart';
import 'auth_shared.dart';

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (Object error, StackTrace stackTrace) {
          context.showSnackBar('Action failed. Please try again.', isError: true);
        },
      );
    });

    final bool isLoading = ref.watch(authControllerProvider).isLoading;
    final String email = ref.watch(firebaseServiceProvider).currentUser?.email ?? 'your email';

    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a verification email to $email. Confirm it to unlock the full dashboard.',
      child: Column(
        children: <Widget>[
          const AuthInfoBanner(
            icon: Icons.mark_email_unread_outlined,
            message: 'Check your inbox and spam folder, then come back here after opening the verification link.',
            color: Color(0xFFE7F7DE),
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: 'I have verified my email',
            isLoading: isLoading,
            onPressed: () async {
              final bool verified =
                  await ref.read(authControllerProvider.notifier).reloadAndCheckVerification();
              if (!context.mounted) {
                return;
              }
              if (verified) {
                context.go('/post-auth');
              } else {
                context.showSnackBar('Email not verified yet. Please check your inbox.', isError: true);
              }
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton.secondary(
              onPressed: isLoading
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).resendVerificationEmail();
                      if (context.mounted) {
                        context.showSnackBar('Verification email sent again.');
                      }
                    },
              child: const Text('Resend verification email'),
            ),
          ),
          const SizedBox(height: 18),
          const AuthSecondaryLinkRow(
            prompt: 'Need a different account?',
            actionLabel: 'Back to login',
            route: '/login',
          ),
        ],
      ),
    );
  }
}
