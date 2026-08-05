import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _focusController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _didSeedControllers = false;
  bool _isSaving = false;
  String _selectedCountryCode = '+234';
  UserAccountRole _accountRole = UserAccountRole.owner;
  String _profileImageBase64 = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _wardController.dispose();
    _focusController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final profileAsync = ref.watch(userProfileProvider);

    profileAsync.whenOrNull(
      data: (UserProfile? profile) {
        if (_didSeedControllers) {
          return;
        }
        _didSeedControllers = true;
        _nameController.text = profile?.fullName.isNotEmpty == true
            ? profile!.fullName
            : (currentUser?.displayName ?? '');
        _emailController.text = currentUser?.email ?? profile?.email ?? '';
        if (profile?.phoneNumber.isNotEmpty == true) {
          final String phone = profile!.phoneNumber;
          for (final String code in _countryCodeList) {
            if (phone.startsWith(code)) {
              _selectedCountryCode = code;
              _phoneController.text = phone.substring(code.length).trim();
              break;
            }
          }
          if (_phoneController.text.isEmpty) {
            _phoneController.text = phone;
          }
        }
        _wardController.text = profile?.ward ?? '';
        _focusController.text = profile?.primaryFocus ?? '';
        _bioController.text = profile?.bio ?? '';
        _accountRole = profile?.accountRole ?? UserAccountRole.owner;
        _profileImageBase64 = profile?.profileImageBase64 ?? '';
      },
    );

    final ThemeData theme = Theme.of(context);
    final bool isEditingProfile = profileAsync.valueOrNull?.isComplete == true;

    return SoftScreenScaffold(
      heroTitle:
          isEditingProfile ? 'Edit your profile' : 'Complete your account',
      heroSubtitle: isEditingProfile
          ? 'Update your farmer identity, contact details, photo, and production focus.'
          : 'Set up the farmer identity, location, and main production focus that the rest of FarmSync will build around.',
      heroIcon: Icons.person_add_alt_1_rounded,
      heroVariant: FarmArtworkVariant.welcome,
      heroBadge: isEditingProfile ? 'Profile edit' : 'User creation',
      sections: <Widget>[
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Profile details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'These details improve your navigation, recommendations, and the way your workspace is labeled across the app.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                _ProfileImagePicker(
                  imageBase64: _profileImageBase64,
                  onTap: _pickProfileImage,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  hint: 'Amina James',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'farmer@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
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
                  controller: _wardController,
                  label: 'Ward or community',
                  hint: 'Jos South',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _focusController,
                  label: 'Primary focus',
                  hint: 'Vegetables and poultry',
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _bioController,
                  label: 'Short bio',
                  hint:
                      'Smallholder farmer focused on tomatoes, peppers, and broilers.',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Account role',
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserAccountRole>(
                      value: _accountRole,
                      isExpanded: true,
                      items: UserAccountRole.values
                          .map(
                            (UserAccountRole role) =>
                                DropdownMenuItem<UserAccountRole>(
                              value: role,
                              child: Text(_accountRoleLabel(role)),
                            ),
                          )
                          .toList(),
                      onChanged: (UserAccountRole? value) {
                        if (value != null) {
                          setState(() => _accountRole = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton.secondary(
                onPressed: _isSaving
                    ? null
                    : () => context
                        .go(isEditingProfile ? '/profile' : '/dashboard'),
                child: Text(isEditingProfile ? 'Cancel' : 'Skip for now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton.primary(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditingProfile
                        ? 'Save profile'
                        : 'Save and continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    final currentUser = ref.read(firebaseServiceProvider).currentUser;
    if (currentUser == null) {
      context.showSnackBar('Please sign in again to continue.', isError: true);
      context.go('/login');
      return;
    }

    final String? nameError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Full name'),
        (String? value) =>
            Validators.minLength(value, 2, fieldName: 'Full name'),
      ],
      _nameController.text.trim(),
    );
    final String? wardError = Validators.required(
      _wardController.text.trim(),
      fieldName: 'Ward or community',
    );
    final String emailValue = _emailController.text.trim();
    final String? emailError =
        emailValue.isEmpty ? null : Validators.email(emailValue);
    final String? focusError = Validators.required(
      _focusController.text.trim(),
      fieldName: 'Primary focus',
    );

    if (nameError != null) {
      context.showSnackBar(nameError, isError: true);
      return;
    }
    if (wardError != null) {
      context.showSnackBar(wardError, isError: true);
      return;
    }
    if (emailError != null) {
      context.showSnackBar(emailError, isError: true);
      return;
    }
    if (focusError != null) {
      context.showSnackBar(focusError, isError: true);
      return;
    }

    final DateTime now = DateTime.now();
    final UserProfile currentProfile =
        ref.read(userProfileProvider).valueOrNull ??
            UserProfile(
              uid: currentUser.uid,
              fullName: '',
              email: currentUser.email ?? '',
              phoneNumber: '',
              accountRole: UserAccountRole.owner,
              ward: '',
              primaryFocus: '',
              bio: '',
              profileImageBase64: '',
              createdAt: now,
              updatedAt: now,
            );
    final bool wasAlreadyComplete = currentProfile.isComplete;

    final UserProfile nextProfile = currentProfile.copyWith(
      uid: currentUser.uid,
      fullName: _nameController.text.trim(),
      email: emailValue.isNotEmpty
          ? emailValue
          : (currentUser.email ?? currentProfile.email),
      phoneNumber: '$_selectedCountryCode${_phoneController.text.trim()}',
      accountRole: _accountRole,
      ward: _wardController.text.trim(),
      primaryFocus: _focusController.text.trim(),
      bio: _bioController.text.trim(),
      profileImageBase64: _profileImageBase64,
      updatedAt: now,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(userProfileProvider.notifier).saveProfile(nextProfile);
      if (!mounted) {
        return;
      }
      context.showSnackBar('Account profile saved successfully.');
      context.go(wasAlreadyComplete ? '/profile' : '/app-tour');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = _saveErrorMessage(error);
      context.showSnackBar(message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 45,
      maxWidth: 480,
    );
    if (file == null || !mounted) {
      return;
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 500000) {
      if (mounted) {
        context.showSnackBar(
            'That image is too large. Please choose a smaller profile photo.',
            isError: true);
      }
      return;
    }
    setState(() {
      _profileImageBase64 = base64Encode(bytes);
    });
  }

  List<String> get _countryCodeList => <String>[
        '+234',
        '+1',
        '+44',
        '+91',
        '+27',
        '+254',
        '+256',
        '+255',
        '+233',
        '+237',
        '+212',
        '+20',
        '+880',
        '+86',
        '+81',
        '+33',
        '+49',
        '+39',
        '+34',
        '+31',
      ];

  String _saveErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return error.message ??
          'Authentication failed while saving your profile.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore denied this write. Check your Firestore rules for users/${ref.read(firebaseServiceProvider).currentUser?.uid}.';
        case 'unauthenticated':
          return 'You are no longer signed in. Please log in again and retry.';
        case 'unavailable':
          return 'Firestore is currently unavailable. Check your network and try again.';
      }
      return error.message ?? 'Could not save to Firestore right now.';
    }
    return 'Could not save profile right now. ${error.toString()}';
  }

  String _accountRoleLabel(UserAccountRole role) {
    switch (role) {
      case UserAccountRole.owner:
        return 'Owner';
      case UserAccountRole.worker:
        return 'Worker';
      case UserAccountRole.partner:
        return 'Partner';
      case UserAccountRole.viewer:
        return 'Viewer';
    }
  }
}

class _ProfileImagePicker extends StatelessWidget {
  const _ProfileImagePicker({
    required this.imageBase64,
    required this.onTap,
  });

  final String imageBase64;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    if (imageBase64.isNotEmpty) {
      imageBytes = base64Decode(imageBase64);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 34,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.10),
              backgroundImage:
                  imageBytes == null ? null : MemoryImage(imageBytes),
              child: imageBytes == null
                  ? Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Upload profile image',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    imageBytes == null
                        ? 'Choose a photo that will be beautifully displayed across your profile.'
                        : 'Tap to replace your current photo.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.add_a_photo_rounded),
          ],
        ),
      ),
    );
  }
}
