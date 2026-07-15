import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/firebase_service.dart';
import '../../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_text_field.dart';

class InviteAcceptScreen extends ConsumerStatefulWidget {
  const InviteAcceptScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  bool _loading = true;
  String _inviteEmail = '';
  String _farmName = '';
  String _role = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      final Map<String, dynamic>? invite = await FirebaseService().getGlobalDocumentFromFirestore('invites', widget.token);
      if (invite == null) {
        setState(() {
          _error = 'Invitation not found or expired.';
          _loading = false;
        });
        return;
      }
      final String farmId = invite['farmId'] as String? ?? '';
      final Map<String, dynamic>? farm = await FirebaseService().getGlobalDocumentFromFirestore('farms', farmId);
      setState(() {
        _inviteEmail = invite['email'] as String? ?? '';
        final String inviteName = invite['name'] as String? ?? '';
        if (inviteName.isNotEmpty) {
          _nameController.text = inviteName;
        }
        _role = invite['role'] as String? ?? '';
        _farmName = farm != null ? (farm['name'] as String? ?? '') : '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load invitation.';
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() {
      _error = null;
    });
    final String name = _nameController.text.trim();
    final String password = _passwordController.text;
    final String confirm = _confirmController.text;
    if (name.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your name and a password.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    try {
      // Register user
      await ref.read(authControllerProvider.notifier).register(
            name: name,
            email: _inviteEmail,
            password: password,
            phoneNumber: '',
          );
      final String? uid = ref.read(firebaseServiceProvider).currentUser?.uid;
      if (uid == null) {
        setState(() => _error = 'Registration succeeded but user not available.');
        return;
      }
      // Claim invite
      try {
        await ref.read(firebaseServiceProvider).acceptInvite(inviteId: widget.token, newUid: uid, fullName: name);
      } catch (e) {
        // Friendly handling for already-accepted or expired invites
        setState(() => _error = 'This invitation has already been accepted or expired. You can sign in instead.');
        // Navigate to post-auth or login depending on state
        if (!mounted) return;
        context.go('/login');
        return;
      }
      if (!mounted) return;
      context.go('/post-auth');
    } catch (e) {
      setState(() => _error = 'Failed to accept invitation. ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation')),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  Text('You were invited to join', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(_farmName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('As: $_role', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Email: $_inviteEmail', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  AppTextField(controller: _nameController, label: 'Full name'),
                  const SizedBox(height: 8),
                  AppTextField(controller: _passwordController, label: 'Password', obscureText: true),
                  const SizedBox(height: 8),
                  AppTextField(controller: _confirmController, label: 'Confirm password', obscureText: true),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      onPressed: _accept,
                      child: const Text('Create account & join'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
