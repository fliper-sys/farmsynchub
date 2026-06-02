import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../common/widgets/farm_scene_artwork.dart';

class AccountRestrictedScreen extends ConsumerWidget {
  const AccountRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              scheme.errorContainer.withOpacity(0.28),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 0,
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const FarmSceneArtwork(
                          height: 200,
                          variant: FarmArtworkVariant.dashboard,
                          borderRadius: BorderRadius.all(Radius.circular(28)),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Your account is restricted',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'An app admin has limited this account. Contact support or an owner for help restoring access.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Back to login'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                          child: const Text('Sign out now'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
