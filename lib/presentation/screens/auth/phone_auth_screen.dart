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

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  String _verificationId = '';
  String _countryCode = '+234';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AuthScaffold(
      title: 'Phone sign in',
      subtitle: 'Use your phone number to create or access your FarmSync account without email.',
      badge: 'FarmSync Hub',
      footer: const AuthPageFooter(
        text: 'If you are testing, add a Firebase test phone number in the console. Firebase will not send an SMS to test numbers.',
      ),
      child: Column(
        children: <Widget>[
          const AuthInfoBanner(
            icon: Icons.info_outline_rounded,
            color: Color(0xFFEFF6E7),
            message: 'Real SMS delivery depends on Firebase Phone Auth setup. For development, use test phone numbers and their saved codes in the Firebase console.',
          ),
          const SizedBox(height: 14),
          if (!_codeSent) ...<Widget>[
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
                    value: _countryCode,
                    dropdownColor: theme.colorScheme.surface,
                    underline: const SizedBox(),
                    items: _countryCodes.map((String code) {
                      return DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _countryCode = value);
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
            const SizedBox(height: 18),
            AppButton.primary(
              onPressed: _isSending ? null : _sendCode,
              child: Text(_isSending ? 'Sending code...' : 'Send code'),
            ),
          ] else ...<Widget>[
            const AuthInfoBanner(
              icon: Icons.sms_rounded,
              color: Color(0xFFE7F7DE),
              message: 'Code sent to the phone number you entered.',
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _codeController,
              label: 'Verification code',
              hint: '123456',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            AppButton.primary(
              onPressed: _isVerifying ? null : _verifyCode,
              child: Text(_isVerifying ? 'Checking code...' : 'Verify and continue'),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              onPressed: _isSending ? null : _sendCode,
              child: const Text('Resend code'),
            ),
          ],
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    final String phone = _phoneController.text.trim();
    final String? phoneError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Phone number'),
        (String? value) => Validators.minLength(value, 10, fieldName: 'Phone number'),
      ],
      phone,
    );
    if (phoneError != null) {
      context.showSnackBar(phoneError, isError: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      final String verificationId = await ref.read(authControllerProvider.notifier).startPhoneSignIn('$_countryCode$phone');
      if (!mounted) {
        return;
      }
      if (verificationId.isEmpty) {
        context.go('/post-auth');
        return;
      }
      setState(() {
        _verificationId = verificationId;
        _codeSent = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showSnackBar(_errorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final String code = _codeController.text.trim();
    final String? codeError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Verification code'),
        (String? value) => Validators.minLength(value, 4, fieldName: 'Verification code'),
      ],
      code,
    );
    if (codeError != null) {
      context.showSnackBar(codeError, isError: true);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyPhoneCode(
            verificationId: _verificationId,
            smsCode: code,
          );
      if (mounted) {
        context.go('/post-auth');
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar(_errorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  String _errorMessage(Object error) {
      if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'That code is incorrect. Please try again.';
        case 'session-expired':
          return 'That code has expired. Request a new one.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'invalid-phone-number':
          return 'That phone number is not valid.';
        case 'quota-exceeded':
          return 'Firebase SMS quota has been reached. Try again later or use a Firebase test phone number.';
        case 'captcha-check-failed':
          return 'Phone verification could not complete the security check. Check Firebase setup and try again.';
        case 'operation-not-allowed':
          return 'Phone sign-in is not enabled in Firebase Authentication yet.';
        case 'missing-client-identifier':
          return 'Phone sign-in needs the correct Firebase setup for this device.';
        case 'network-request-failed':
          return 'Your device is offline or Firebase could not be reached.';
      }
    }
    return 'Phone verification failed. Please try again.';
  }

  List<String> get _countryCodes => <String>[
        '+234',
        '+1',
        '+44',
        '+91',
        '+27',
        '+254',
        '+256',
        '+255',
        '+233',
      ];
}
