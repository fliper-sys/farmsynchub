import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/ai_chat_provider.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final Uri _supportEmailUri = Uri(
    scheme: 'mailto',
    path: 'support@farmsync.lbtech.site',
    query: 'subject=FarmSync Support',
  );

  static final Uri _whatsAppUri = Uri.parse(
    'https://chat.whatsapp.com/CVde2VexwGhARro63xSaVn?mode=gi_t',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeProvider);
    final ai = ref.watch(aiChatProvider);
    final AppLanguage appLanguage = ref.watch(appLanguageProvider);
    final AppSettings appSettings = ref.watch(appSettingsProvider);
    final SyncOverview syncOverview = ref.watch(syncOverviewProvider);
    final User? currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _launchUri(context, _whatsAppUri),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_rounded),
        label: const Text(''),
      ),
      body: SoftScreenScaffold(
        heroTitle: 'Settings that feel calm',
        heroSubtitle: 'Adjust appearance, language, sync, and notifications in one polished control room.',
        heroIcon: Icons.tune_rounded,
        heroVariant: FarmArtworkVariant.dashboard,
        heroBadge: 'Preferences',
        trailing: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: const Icon(Icons.settings_suggest_rounded),
        ),
        sections: <Widget>[
          SoftSectionTitle(
            title: 'Appearance',
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
                  _ModeTile(
                    label: 'System theme',
                    subtitle: 'Follow your device preference automatically.',
                    icon: Icons.brightness_auto_rounded,
                    selected: themeMode == ThemeMode.system,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system),
                  ),
                  const SizedBox(height: 12),
                  _ModeTile(
                    label: 'Light mode',
                    subtitle: 'Keep the soft cream and green daytime look.',
                    icon: Icons.light_mode_rounded,
                    selected: themeMode == ThemeMode.light,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(height: 12),
                  _ModeTile(
                    label: 'Dark mode',
                    subtitle: 'Switch to a darker field-ready interface.',
                    icon: Icons.dark_mode_rounded,
                    selected: themeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'AI preferences'),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _SettingsRow(
                    icon: Icons.translate_rounded,
                    title: 'AI language',
                    value: ai.language,
                    tint: const Color(0xFFDFF1FF),
                    onTap: () => _showLanguageSheet(context, ref),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI model',
                    value: ai.modelName,
                    tint: const Color(0xFFE9F4DB),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: Icons.delete_sweep_rounded,
                    title: 'Reset AI chats',
                    value: 'Clear all',
                    tint: const Color(0xFFFFEBD0),
                    onTap: () => ref.read(aiChatProvider).clearAll(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Farm preferences'),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _SettingsRow(
                    icon: Icons.translate_rounded,
                    title: 'Language',
                    value: appLanguage.label,
                    tint: const Color(0xFFDFF1FF),
                    onTap: () => _showAppLanguageSheet(context, ref),
                  ),
                  const SizedBox(height: 12),
                  _ToggleSettingsRow(
                    icon: Icons.notifications_active_rounded,
                    title: 'Push notifications',
                    subtitle: 'Receive app alerts and farm updates.',
                    value: appSettings.notificationsEnabled,
                    tint: const Color(0xFFE9F4DB),
                    onChanged: (bool value) => ref.read(appSettingsProvider.notifier).setNotificationsEnabled(value),
                  ),
                  const SizedBox(height: 12),
                  _ToggleSettingsRow(
                    icon: Icons.alarm_on_rounded,
                    title: 'Reminder notifications',
                    subtitle: 'Crop and livestock reminders can notify you on time.',
                    value: appSettings.reminderNotificationsEnabled,
                    tint: const Color(0xFFDFF1FF),
                    onChanged: (bool value) =>
                        ref.read(appSettingsProvider.notifier).setReminderNotificationsEnabled(value),
                  ),
                  const SizedBox(height: 12),
                  _ToggleSettingsRow(
                    icon: Icons.sync_rounded,
                    title: 'Auto sync when online',
                    subtitle: 'Sync offline records as soon as internet is available.',
                    value: appSettings.autoSyncEnabled,
                    tint: const Color(0xFFFFEBD0),
                    onChanged: (bool value) => ref.read(appSettingsProvider.notifier).setAutoSyncEnabled(value),
                  ),
                  const SizedBox(height: 12),
                  _ToggleSettingsRow(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric lock',
                    subtitle: 'Require device biometric unlock on supported phones.',
                    value: appSettings.biometricLockEnabled,
                    tint: const Color(0xFFEAD9FF),
                    onChanged: (bool value) =>
                        ref.read(appSettingsProvider.notifier).setBiometricLockEnabled(value),
                  ),
                  const SizedBox(height: 12),
                  const _SettingsRow(
                    icon: Icons.download_rounded,
                    title: 'Export reports',
                    value: 'Weekly PDF',
                    tint: Color(0xFFFFEBD0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Security'),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _SettingsRow(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change password',
                    value: currentUser?.email ?? 'Update account password',
                    tint: const Color(0xFFEAD9FF),
                    onTap: () => _showChangePasswordSheet(context, ref),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: Icons.email_rounded,
                    title: 'Send password reset',
                    value: currentUser?.email ?? 'Reset via email',
                    tint: const Color(0xFFDFF1FF),
                    onTap: currentUser?.email == null
                        ? null
                        : () => _sendPasswordReset(context, ref, currentUser!.email!),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: Icons.verified_user_rounded,
                    title: 'Email verification status',
                    value: currentUser?.emailVerified == true ? 'Verified' : 'Pending',
                    tint: const Color(0xFFE9F4DB),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Support'),
          AppCard(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _SettingsRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Email support',
                    value: 'support@farmsync.lbtech.site',
                    tint: const Color(0xFFFFEBD0),
                    onTap: () => _launchUri(context, _supportEmailUri),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: Icons.chat_rounded,
                    title: 'Join WhatsApp support',
                    value: 'Open community',
                    tint: const Color(0xFFDDF7E4),
                    onTap: () => _launchUri(context, _whatsAppUri),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Connection and alerts'),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: 'Sync status',
                  value: syncOverview.isSyncing
                      ? 'Syncing'
                      : syncOverview.pendingCount == 0
                          ? 'Synced'
                          : '${syncOverview.pendingCount} pending',
                  color: const Color(0xFFE9F4DB),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: SoftInfoChip(
                  label: 'Alerts',
                  value: 'Live',
                  color: Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: SoftInfoChip(
                  label: 'Version',
                  value: '1.0.0',
                  color: Color(0xFFFFEBD0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAppLanguageSheet(BuildContext context, WidgetRef ref) async {
    final AppLanguage current = ref.read(appLanguageProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values
                .map(
                  (AppLanguage language) => ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: const Icon(Icons.language_rounded),
                    title: Text(language.label),
                    trailing: current == language
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: () async {
                      await ref.read(appLanguageProvider.notifier).setLanguage(language);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link right now.')),
      );
    }
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
    final ai = ref.read(aiChatProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ai.supportedLanguages
                .map(
                  (String language) => ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: const Icon(Icons.language_rounded),
                    title: Text(language),
                    trailing: ai.language == language
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: () async {
                      await ai.setLanguage(language);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _showChangePasswordSheet(BuildContext context, WidgetRef ref) async {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            Future<void> submit() async {
              final String currentPassword = currentPasswordController.text.trim();
              final String newPassword = newPasswordController.text.trim();
              final String confirmPassword = confirmPasswordController.text.trim();

              if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill all password fields first.')),
                );
                return;
              }
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Choose a stronger password with at least 6 characters.')),
                );
                return;
              }
              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match.')),
                );
                return;
              }

              setState(() => isSaving = true);
              try {
                await ref.read(authControllerProvider.notifier).changePassword(
                      currentPassword: currentPassword,
                      newPassword: newPassword,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully.')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not change password: $error')),
                  );
                }
              } finally {
                if (context.mounted) {
                  setState(() => isSaving = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Change password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your current password, then choose a new one.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.verified_user_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving ? null : submit,
                        child: Text(isSaving ? 'Saving...' : 'Update password'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendPasswordReset(BuildContext context, WidgetRef ref, String email) async {
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reset email: $error')),
        );
      }
    }
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.10)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary.withOpacity(0.18)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.tint,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              onTap == null ? Icons.info_outline_rounded : Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSettingsRow extends StatelessWidget {
  const _ToggleSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tint,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color tint;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
