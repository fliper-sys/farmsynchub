import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/verified_badge_request.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import 'admin_locked_view.dart';

class AdminVerifiedBadgesScreen extends ConsumerWidget {
  const AdminVerifiedBadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? state = adminAsync.valueOrNull;
    final ThemeData theme = Theme.of(context);

    if (adminAsync.isLoading || state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.currentAdmin == null) {
      return const AdminLockedView(
        message: 'Use the hidden admin login to review verified badge applications.',
      );
    }

    final List<VerifiedBadgeRequest> pending = state.verifiedBadgeRequests.where((VerifiedBadgeRequest request) => request.isPending).toList(growable: false);
    final List<VerifiedBadgeRequest> reviewed = state.verifiedBadgeRequests.where((VerifiedBadgeRequest request) => !request.isPending).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? GoRouterHelper(context).pop() : context.go('/admin-dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Verified badges'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            AppCard(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Badge review queue', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Approve verified badges for trustworthy farmer profiles. Approved users will show a badge on their news posts and reposts.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _StatChip(label: 'Pending', value: '${pending.length}'),
                        _StatChip(label: 'Reviewed', value: '${reviewed.length}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Pending requests', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (pending.isEmpty)
              const Text('No pending verified badge requests right now.')
            else
              ...pending.map(
                (VerifiedBadgeRequest request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VerifiedRequestCard(
                    request: request,
                    onApprove: () => _approve(ref, context, request),
                    onDecline: () => _decline(ref, context, request),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Reviewed requests', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (reviewed.isEmpty)
              const Text('Reviewed requests will appear here after action is taken.')
            else
              ...reviewed.map(
                (VerifiedBadgeRequest request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReviewedRequestCard(request: request),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(WidgetRef ref, BuildContext context, VerifiedBadgeRequest request) async {
    try {
      await ref.read(adminWorkspaceProvider.notifier).approveVerifiedBadge(request);
      if (!context.mounted) return;
      context.showSnackBar('Verified badge approved for ${request.userName}.');
    } catch (_) {
      if (!context.mounted) return;
      context.showSnackBar('Could not approve the verified badge.', isError: true);
    }
  }

  Future<void> _decline(WidgetRef ref, BuildContext context, VerifiedBadgeRequest request) async {
    final TextEditingController noteController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Decline request?'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Decline note',
            hintText: 'Optional reason or next step',
          ),
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(adminWorkspaceProvider.notifier).declineVerifiedBadge(
            request,
            note: noteController.text.trim(),
          );
      if (!context.mounted) return;
      context.showSnackBar('Verified badge declined for ${request.userName}.');
    } catch (_) {
      if (!context.mounted) return;
      context.showSnackBar('Could not decline the verified badge.', isError: true);
    }
  }
}

class _VerifiedRequestCard extends StatelessWidget {
  const _VerifiedRequestCard({
    required this.request,
    required this.onApprove,
    required this.onDecline,
  });

  final VerifiedBadgeRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: request.profileImageBase64.isEmpty ? null : MemoryImage(base64Decode(request.profileImageBase64)),
                  child: request.profileImageBase64.isEmpty
                      ? Text(request.userName.isNotEmpty ? request.userName[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(request.userName.isEmpty ? request.email : request.userName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(request.email, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const _BadgeChip(),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(label: 'Ward', value: request.ward.isEmpty ? 'Not set' : request.ward),
                _InfoChip(label: 'Focus', value: request.primaryFocus.isEmpty ? 'Not set' : request.primaryFocus),
                _InfoChip(label: 'Phone', value: request.phoneNumber.isEmpty ? 'Not set' : request.phoneNumber),
              ],
            ),
            if (request.bio.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(request.bio, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
            ],
            if (request.note.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Applicant note: ${request.note}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton.secondary(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewedRequestCard extends StatelessWidget {
  const _ReviewedRequestCard({required this.request});

  final VerifiedBadgeRequest request;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool approved = request.isApproved;
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: approved ? const Color(0xFFE8F4D8) : const Color(0xFFFFEBD0),
          child: Icon(approved ? Icons.verified_rounded : Icons.remove_circle_outline_rounded),
        ),
        title: Text(request.userName.isEmpty ? request.email : request.userName),
        subtitle: Text(
          '${approved ? 'Approved' : 'Declined'}${request.reviewedAt == null ? '' : ' on ${request.reviewedAt}'}${request.reviewedBy.isNotEmpty ? ' by ${request.reviewedBy}' : ''}',
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text('$label: $value', style: theme.textTheme.labelLarge),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Pending',
        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
