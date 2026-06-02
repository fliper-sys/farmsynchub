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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedCountryCode = '+234'; // Nigeria

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    final ThemeData theme = Theme.of(context);

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Open your FarmSync Hub account and start organizing farm operations with a clean setup.',
      footer: const AuthPageFooter(
        text: 'By creating an account, you prepare your dashboard, farm records, and notifications for secure sync.',
      ),
      child: Column(
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            label: 'Full name',
            hint: 'Amina James',
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'farmer@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          // Phone number field with country code
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  dropdownColor: theme.colorScheme.surface,
                  underline: const SizedBox(),
                  items: _countryCodeList.map((String code) {
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(code),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCountryCode = newValue);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  hint: '805 123 4567',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Choose a strong password',
            obscureText: _obscurePassword,
            suffix: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _confirmPasswordController,
            label: 'Confirm password',
            hint: 'Repeat your password',
            obscureText: _obscureConfirmPassword,
            suffix: IconButton(
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            ),
          ),
          const SizedBox(height: 18),
          const AuthInfoBanner(
            icon: Icons.mail_outline_rounded,
            message: 'After signup, we will send a verification email before full access is granted.',
            color: Color(0xFFE7F7DE),
          ),
          const SizedBox(height: 14),
          AppButton.secondary(
            onPressed: isLoading
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).signInWithGoogle();
                  },
            child: const _AuthActionLabel(
              label: 'Use Google instead',
              icon: _GoogleBadge(),
            ),
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            onPressed: () => context.go('/phone-auth'),
            child: const _AuthActionLabel(
              label: 'Register with phone',
              icon: Icon(Icons.phone_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: 'Create account',
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 18),
          const AuthSecondaryLinkRow(
            prompt: 'Already have an account?',
            actionLabel: 'Log in here',
            route: '/login',
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    final String? nameError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Full name'),
        (String? value) => Validators.minLength(value, 2, fieldName: 'Full name'),
      ],
      name,
    );
    final String? emailError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Email'),
        Validators.email,
      ],
      email,
    );
    final String? phoneError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Phone number'),
        (String? value) => Validators.minLength(value, 10, fieldName: 'Phone number'),
      ],
      phone,
    );
    final String? passwordError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Password'),
        (String? value) => Validators.minLength(value, 6, fieldName: 'Password'),
      ],
      password,
    );

    if (nameError != null) {
      context.showSnackBar(nameError, isError: true);
      return;
    }
    if (emailError != null) {
      context.showSnackBar(emailError, isError: true);
      return;
    }
    if (phoneError != null) {
      context.showSnackBar(phoneError, isError: true);
      return;
    }
    if (passwordError != null) {
      context.showSnackBar(passwordError, isError: true);
      return;
    }
    if (password != confirmPassword) {
      context.showSnackBar('Passwords do not match.', isError: true);
      return;
    }

    final String fullPhoneNumber = '$_selectedCountryCode$phone';
    await ref.read(authControllerProvider.notifier).register(
          name: name,
          email: email,
          password: password,
          phoneNumber: fullPhoneNumber,
        );
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      // Print the error code for debugging purposes
      debugPrint('Firebase Auth Error Code: ${error.code}');
      debugPrint('Firebase Auth Error Message: ${error.message}');

      switch (error.code) {
        case 'email-already-in-use':
          return 'An account with that email already exists.';
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'weak-password':
          return 'Choose a stronger password with at least 6 characters.';
        case 'operation-not-allowed':
          return 'Email/password registration is not enabled. Please contact support.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many registration attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'invalid-credential':
          return 'Invalid credentials. Please try again.';
        case 'configuration-not-found':
          return 'Firebase Auth email action settings are incomplete. In Firebase Console, enable Email/Password sign-in and check Authentication email templates/authorized domains.';
        case 'google-sign-in-failed':
          return error.message ?? 'Google sign-in failed. Please check Firebase configuration.';
      }
      // Fallback to the error message from Firebase if code is not handled
      return error.message ?? 'Registration failed. Please try again.';
    }

    // For non-Firebase errors, print for debugging
    debugPrint('Unexpected error during registration: $error');
    return 'Registration failed. Please try again.';
  }

  List<String> get _countryCodeList => <String>[
    '+234', // Nigeria
    '+1', // USA
    '+44', // UK
    '+91', // India
    '+27', // South Africa
    '+254', // Kenya
    '+256', // Uganda
    '+255', // Tanzania
    '+233', // Ghana
    '+237', // Cameroon
    '+212', // Morocco
    '+20', // Egypt
    '+880', // Bangladesh
    '+86', // China
    '+81', // Japan
    '+33', // France
    '+49', // Germany
    '+39', // Italy
    '+34', // Spain
    '+31', // Netherlands
  ];
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
