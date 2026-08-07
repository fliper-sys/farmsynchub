import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/crop.dart';
import '../../../../domain/models/farm.dart';
import '../../../../domain/models/livestock.dart';
import '../../../../domain/models/transaction.dart';
import '../../../../providers/crop_provider.dart';
import '../../../../providers/farm_provider.dart';
import '../../../../providers/finance_provider.dart';
import '../../../../providers/livestock_provider.dart';
import '../../crops/crop_detail_screen.dart';
import '../../farms/farm_detail_screen.dart';
import '../../livestock/livestock_detail_screen.dart';


class ActivityFeed extends ConsumerWidget {
  const ActivityFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_ActivityData> activities = <_ActivityData>[
      ...ref.watch(farmsProvider).maybeWhen(
            data: (List<Farm> items) => items
                .take(2)
                .map(
                  (Farm farm) => _ActivityData(
                    title: 'Farm updated',
                    subtitle: '${farm.name} in ${farm.ward} was updated in your records.',
                    time: _timeLabel(farm.updatedAt),
                    icon: Icons.agriculture_rounded,
                    tint: const Color(0xFFE4F5D6),
                    sortDate: farm.updatedAt,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FarmDetailScreen(farmId: farm.id),
                      ),
                    ),
                  ),
                )
                .toList(),
            orElse: () => <_ActivityData>[],
          ),
      ...ref.watch(cropsProvider).maybeWhen(
            data: (List<Crop> items) => items
                .take(2)
                .map(
                  (Crop crop) => _ActivityData(
                    title: 'Crop record changed',
                    subtitle: '${crop.name} is now in ${_stageLabel(crop.currentStage).toLowerCase()} stage.',
                    time: _timeLabel(crop.updatedAt),
                    icon: Icons.spa_rounded,
                    tint: const Color(0xFFD9EEFF),
                    sortDate: crop.updatedAt,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CropDetailScreen(cropId: crop.id),
                      ),
                    ),
                  ),
                )
                .toList(),
            orElse: () => <_ActivityData>[],
          ),
      ...ref.watch(livestockProvider).maybeWhen(
            data: (List<Livestock> items) => items
                .take(2)
                .map(
                  (Livestock item) => _ActivityData(
                    title: 'Livestock group updated',
                    subtitle: '${item.count} ${_speciesLabel(item.species).toLowerCase()} recorded for farm operations.',
                    time: _timeLabel(item.updatedAt),
                    icon: Icons.pets_rounded,
                    tint: const Color(0xFFFFE0D3),
                    sortDate: item.updatedAt,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LivestockDetailScreen(livestockId: item.id),
                      ),
                    ),
                  ),
                )
                .toList(),
            orElse: () => <_ActivityData>[],
          ),
      ...ref.watch(transactionsProvider).maybeWhen(
            data: (List<Transaction> items) => items
                .take(2)
                .map(
                  (Transaction transaction) => _ActivityData(
                    title: transaction.type == TransactionType.income
                        ? 'Income recorded'
                        : 'Expense recorded',
                    subtitle: transaction.description,
                    time: _timeLabel(transaction.updatedAt),
                    icon: transaction.type == TransactionType.income
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    tint: transaction.type == TransactionType.income
                        ? const Color(0xFFE4F5D6)
                        : const Color(0xFFFFE0D3),
                    sortDate: transaction.updatedAt,
                    onTap: () => context.go('/finance'),
                  ),
                )
                .toList(),
            orElse: () => <_ActivityData>[],
          ),
    ]..sort((_ActivityData a, _ActivityData b) => b.sortDate.compareTo(a.sortDate));

    final List<_ActivityData> visible = activities.take(5).toList();

    if (visible.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Text(
          'Your recent farm, crop, livestock, and finance actions will appear here as you start using the app.',
        ),
      );
    }

    return Column(
      children: visible
          .map(
            (_ActivityData activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityItem(activity: activity),
            ),
          )
          .toList(),
    );
  }

  static String _timeLabel(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  static String _stageLabel(CropStage stage) {
    switch (stage) {
      case CropStage.seeding:
        return 'Seeding';
      case CropStage.germination:
        return 'Germination';
      case CropStage.vegetative:
        return 'Vegetative';
      case CropStage.flowering:
        return 'Flowering';
      case CropStage.fruiting:
        return 'Fruiting';
    }
  }

  static String _speciesLabel(LivestockSpecies species) {
    switch (species) {
      case LivestockSpecies.goat:
        return 'Goats';
      case LivestockSpecies.chicken:
        return 'Chickens';
      case LivestockSpecies.pig:
        return 'Pigs';
      case LivestockSpecies.cattle:
        return 'Cattle';
      case LivestockSpecies.sheep:
        return 'Sheep';
      case LivestockSpecies.rabbit:
        return 'Rabbits';
      case LivestockSpecies.duck:
        return 'Ducks';
      case LivestockSpecies.fish:
        return 'Fish';
      case LivestockSpecies.snail:
        return 'Snails';
    }
  }
}

class _ActivityData {
  const _ActivityData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.tint,
    required this.sortDate,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color tint;
  final DateTime sortDate;
  final VoidCallback onTap;
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});

  final _ActivityData activity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: activity.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: activity.tint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(activity.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      activity.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    activity.time,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryMid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
