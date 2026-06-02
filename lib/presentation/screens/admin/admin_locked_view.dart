import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets/app_card.dart';

class AdminLockedView extends StatelessWidget {
  const AdminLockedView({
    super.key,
    this.message =
        'Use the hidden admin login to access admin tools, manage users, publish news, and send notifications.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin console')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppCard(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded, size: 58, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('Admin workspace locked', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => context.go('/admin-login'),
                      child: const Text('Go to admin login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
