import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final authState = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final AppLanguage language = ref.watch(appLanguageProvider);
    final String displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!
        : 'Farmer';
    final bool isProfileComplete = profile?.isComplete == true;
    final Uint8List? avatarBytes = _avatarBytesFrom(profile?.profileImageBase64);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SoftScreenScaffold(
      heroTitle: language.tr(en: 'Farmer profile', ha: 'Bayanan manomi', fr: 'Profil du fermier'),
      heroSubtitle: language.tr(
        en: 'Keep account details, language choices, and farm identity in one softer settings space.',
        ha: 'Rike bayanan asusu, zabin harshe, da sunan gona wuri guda mai sauki.',
        fr: 'Gardez les details du compte, la langue et l identite de la ferme au meme endroit.',
      ),
      heroIcon: Icons.person_rounded,
      heroVariant: FarmArtworkVariant.welcome,
      heroBadge: isProfileComplete
          ? language.tr(en: 'Account ready', ha: 'Asusu a shirye', fr: 'Compte pret')
          : language.tr(en: 'Complete setup', ha: 'Cika saitin', fr: 'Terminer la configuration'),
      trailing: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primary.withOpacity(0.14),
            backgroundImage: avatarBytes == null ? null : MemoryImage(avatarBytes),
            child: avatarBytes == null
                ? Text(
                    _initialsFor(displayName),
                    style: theme.textTheme.labelLarge,
                  )
                : null,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => context.push('/account-setup'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.edit_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Edit'),
                ],
              ),
            ),
          ),
        ],
      ),
      sections: <Widget>[
        if (!isProfileComplete) ...<Widget>[
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            onTap: () => context.push('/account-setup'),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBD0),
                child: Icon(Icons.person_add_alt_1_rounded),
              ),
              title: Text(
                language.tr(en: 'Complete your account setup', ha: 'Kammala saitin asusunka', fr: 'Completer la configuration du compte'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.primary,
                ),
              ),
              subtitle: Text(
                language.tr(
                  en: 'Add your ward, production focus, and contact details for a fuller workspace.',
                  ha: 'Saka unguwa, fannin aiki, da bayanan tuntuɓa domin cike filin aiki.',
                  fr: 'Ajoutez quartier, domaine de production et contacts pour un espace complet.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 18),
        ],
        SoftSectionTitle(
          title: language.tr(en: 'Account hub', ha: 'Cibiyar asusu', fr: 'Centre du compte'),
          titleStyle: theme.textTheme.titleMedium?.copyWith(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
          ),
          action: TextButton(
            onPressed: () => context.push('/settings'),
            child: Text(language.tr(en: 'Open settings', ha: 'Bude saituna', fr: 'Ouvrir les parametres')),
          ),
        ),
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest,
          onTap: () => context.push('/settings'),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDFF1FF),
              child: Icon(Icons.settings_suggest_rounded),
            ),
            title: Text(
              language.tr(en: 'App settings', ha: 'Saitunan app', fr: 'Parametres de l app'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.primary,
              ),
            ),
            subtitle: Text(
              language.tr(
                en: 'Theme, language, sync status, alerts, and exports',
                ha: 'Jigo, harshe, matsayin sync, sanarwa, da fitar da rahoto',
                fr: 'Theme, langue, synchro, alertes et exports',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: language.tr(en: 'Personal details', ha: 'Bayanan kanka', fr: 'Informations personnelles'),
          titleStyle: theme.textTheme.titleMedium?.copyWith(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
          ),
        ),
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  label: language.tr(en: 'Farmer name', ha: 'Sunan manomi', fr: 'Nom du fermier'),
                  value: profile?.fullName.isNotEmpty == true ? profile!.fullName : displayName,
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  label: language.tr(en: 'Email', ha: 'Imel', fr: 'E-mail'),
                  value: profile?.email.isNotEmpty == true
                      ? profile!.email
                      : (currentUser?.email ?? 'farmer@example.com'),
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  label: language.tr(en: 'Ward', ha: 'Unguwa', fr: 'Quartier'),
                  value: profile?.ward.isNotEmpty == true ? profile!.ward : language.tr(en: 'Not set', ha: 'Babu shi', fr: 'Non defini'),
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  label: language.tr(en: 'Primary focus', ha: 'Babban fanni', fr: 'Domaine principal'),
                  value: profile?.primaryFocus.isNotEmpty == true ? profile!.primaryFocus : language.tr(en: 'Not set', ha: 'Babu shi', fr: 'Non defini'),
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  label: language.tr(en: 'Phone', ha: 'Waya', fr: 'Telephone'),
                  value: profile?.phoneNumber.isNotEmpty == true ? profile!.phoneNumber : language.tr(en: 'Not set', ha: 'Babu shi', fr: 'Non defini'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(title: language.tr(en: 'Preferences', ha: 'Zabuka', fr: 'Preferences')),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: 'Language',
                value: language.label,
                color: const Color(0xFFDFF1FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Theme',
                value: Theme.of(context).brightness == Brightness.dark ? 'Dark' : 'Light',
                color: const Color(0xFFE9F4DB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: 'Setup',
                value: isProfileComplete ? 'Complete' : 'Pending',
                color: const Color(0xFFFFEBD0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(title: language.tr(en: 'Access', ha: 'Shiga', fr: 'Acces')),
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile?.email.isNotEmpty == true
                      ? profile!.email
                      : (currentUser?.email ?? language.tr(en: 'No signed-in account', ha: 'Babu asusun da aka shiga', fr: 'Aucun compte connecte')),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  currentUser?.emailVerified == true
                    ? language.tr(
                        en: 'Email verified and ready for full account access.',
                        ha: 'An tabbatar da imel kuma asusun a shirye yake.',
                        fr: 'E-mail verifie et acces complet pret.',
                      )
                    : language.tr(
                        en: 'Email verification is still pending for this account.',
                        ha: 'Har yanzu ana jiran tabbatar da imel.',
                        fr: 'La verification de l e-mail est toujours en attente.',
                      ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                if (profile?.bio.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    profile!.bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.primary(
                    onPressed: () => context.push('/account-setup'),
                    child: Text(isProfileComplete ? 'Edit profile details' : 'Finish account setup'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.secondary(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            await ref.read(authControllerProvider.notifier).signOut();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                    child: Text(language.tr(en: 'Sign out', ha: 'Fita', fr: 'Deconnexion')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _initialsFor(String value) {
    final List<String> parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return value.length >= 2 ? value.substring(0, 2).toUpperCase() : value.toUpperCase();
  }

  Uint8List? _avatarBytesFrom(String? base64Value) {
    if (base64Value == null || base64Value.isEmpty) {
      return null;
    }
    return base64Decode(base64Value);
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
