import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_destinations.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/user_profile_provider.dart';

/// Side menu listing every part of the app, grouped by what the farmer is
/// trying to do. The bottom bar only has room for five tabs, so this is the
/// "map" of the whole app and the place to find anything else.
class AppMenuDrawer extends ConsumerWidget {
  /// Creates the menu. [currentPath] is used to highlight where the user is.
  const AppMenuDrawer({super.key, required this.currentPath});

  /// The route currently on screen.
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
    final String name = profile?.fullName.trim() ?? '';

    final List<Widget> sections = <Widget>[];
    for (final AppDestinationGroup group in AppDestinations.menuGroups) {
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Text(
            group.title(language),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
      for (final AppDestination destination in group.items) {
        sections.add(
          _MenuTile(
            destination: destination,
            language: language,
            selected: destination.route == currentPath,
            onTap: () => _open(context, destination, language, profile),
          ),
        );
      }
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MenuHeader(name: name),
            Divider(color: theme.colorScheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: sections,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    AppDestination destination,
    AppLanguage language,
    UserProfile? profile,
  ) {
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    if (profile?.restrictedFeatures.contains(destination.featureKey) == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            language.tr(
              en: 'This section is restricted for your account.',
              ha: 'An takaita wannan sashe a asusun ka.',
              fr: 'Cette section est restreinte pour votre compte.',
            ),
          ),
        ),
      );
      return;
    }
    if (destination.route != currentPath) {
      router.go(destination.route);
    }
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent =
        isDark ? theme.colorScheme.primary : const Color(0xFF0E5A41);
    final String initial = name.isEmpty ? 'F' : name.substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: theme.textTheme.titleLarge?.copyWith(color: accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.isEmpty ? 'FarmSync Hub' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'FarmSync Hub',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.destination,
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    // The brand green is too light to read as text on a white surface, so
    // light mode uses the same deep green as the bottom bar's selected pill.
    final Color accent =
        isDark ? theme.colorScheme.primary : const Color(0xFF0E5A41);
    final Color iconColor = selected ? accent : theme.colorScheme.onSurfaceVariant;
    final String hint = destination.hint(language);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label(language),
        child: Material(
          color: selected ? accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withOpacity(0.16)
                          : theme.colorScheme.onSurface.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          destination.label(language),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected ? accent : null,
                          ),
                        ),
                        if (hint.isNotEmpty)
                          Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
