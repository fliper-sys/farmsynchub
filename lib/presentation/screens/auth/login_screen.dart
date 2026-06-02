import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_text_field.dart';
import 'auth_shared.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int _brandTapCount = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (previous is AsyncLoading && mounted) {
            final User? user = FirebaseAuth.instance.currentUser;
            if (user != null && user.email?.isNotEmpty == true && !user.emailVerified) {
              context.go('/verify-email');
            } else {
              context.go('/post-auth');
            }
          }
        },
        error: (Object error, StackTrace stackTrace) {
          context.showSnackBar(_errorMessage(error), isError: true);
        },
      );
    });

    final bool isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Log in',
      subtitle: 'Sign in to your farm workspace and pick up right where your last field update ended.',
      onBrandTap: _handleBrandTap,
      footer: const AuthPageFooter(
        text: 'Secure access for crop records, livestock tracking, finance, and advisory tools.',
      ),
      child: Column(
        children: <Widget>[
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'farmer@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your password',
            obscureText: _obscurePassword,
            suffix: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Expanded(child: SizedBox()),
              InkWell(
                onTap: () => context.go('/forgot-password'),
                child: Text(
                  'Forgot your password?',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: 'Log in',
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 14),
          AppButton.secondary(
            onPressed: isLoading
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).signInWithGoogle();
                  },
            child: const _AuthActionLabel(
              label: 'Continue with Google',
              icon: _GoogleBadge(),
            ),
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            onPressed: () => context.go('/phone-auth'),
            child: const _AuthActionLabel(
              label: 'Use phone number',
              icon: Icon(Icons.phone_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 18),
          const AuthSecondaryLinkRow(
            prompt: 'Don\'t have an account?',
            actionLabel: 'Register here',
            route: '/register',
          ),
        ],
      ),
    );
  }

  void _handleBrandTap() {
    _brandTapCount += 1;
    if (_brandTapCount >= 8) {
      _brandTapCount = 0;
      context.go('/admin-login');
    }
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    final String? emailError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Email'),
        Validators.email,
      ],
      email,
    );
    final String? passwordError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Password'),
        (String? value) => Validators.minLength(value, 6, fieldName: 'Password'),
      ],
      password,
    );

    if (emailError != null) {
      context.showSnackBar(emailError, isError: true);
      return;
    }
    if (passwordError != null) {
      context.showSnackBar(passwordError, isError: true);
      return;
    }

    await ref.read(authControllerProvider.notifier).signIn(
          email: email,
          password: password,
        );
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'too-many-requests':
          return 'Too many login attempts. Please wait and try again.';
        case 'google-sign-in-failed':
          return error.message ?? 'Google sign-in failed. Please check Firebase configuration.';
      }
      return error.message ?? 'Login failed. Please try again.';
    }
    return 'Login failed. Please try again.';
  }
}

class _AuthActionLabel extends StatelessWidget {
  const _AuthActionLabel({
    required this.label,
    required this.icon,
  });

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
