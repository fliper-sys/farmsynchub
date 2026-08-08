import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/farm_notification_service.dart';
import '../../../core/services/feed_calculator_service.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';

const List<String> _kMonthNames = <String>[
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// A daily feed log for one livestock group: mark today's feeding, browse
/// a year-round calendar of fed/missed days, and set an automatic daily
/// feeding-time reminder alongside computed feeding suggestions.
class FeedLogScreen extends ConsumerStatefulWidget {
  const FeedLogScreen({super.key, required this.livestockId});

  final String livestockId;

  @override
  ConsumerState<FeedLogScreen> createState() => _FeedLogScreenState();
}

class _FeedLogScreenState extends ConsumerState<FeedLogScreen> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final List<Livestock> all = ref.watch(livestockProvider).valueOrNull ?? <Livestock>[];
    Livestock? livestock;
    for (final Livestock item in all) {
      if (item.id == widget.livestockId) {
        livestock = item;
        break;
      }
    }

    if (livestock == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Feed log')),
        body: const Center(child: Text('This livestock group is no longer available.')),
      );
    }

    final Livestock l = livestock;
    final double feedPerAnimal = FeedCalculatorService.feedPerAnimalKg(
      l.species, l.growthStage, l.averageAgeMonths, l.purpose,
      actualWeightKg: l.averageWeightKg,
    );
    final double groupFeedKg = feedPerAnimal * l.count;
    final String advice = FeedCalculatorService.feedingAdvice(
      l.species, l.growthStage, l.purpose, l.count, feedPerAnimal,
    );

    return Scaffold(
      appBar: AppBar(title: Text('${_speciesLabel(l.species)} feed log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _TodayCard(
            livestock: l,
            groupFeedKg: groupFeedKg,
            onMarkFed: () => _toggleFed(l, DateTime.now()),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.lightbulb_outline_rounded, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(advice, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReminderCard(
            livestock: l,
            onChanged: (bool enabled, TimeOfDay time) => _setReminder(l, enabled, time),
          ),
          const SizedBox(height: 20),
          Text('Feeding calendar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Tap a day to mark or unmark feeding for that date.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          _FeedCalendar(
            livestock: l,
            focusedMonth: _focusedMonth,
            onMonthChanged: (DateTime month) => setState(() => _focusedMonth = month),
            onDayTap: (DateTime day) => _toggleFed(l, day),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFed(Livestock livestock, DateTime day) async {
    final DateTime target = DateTime(day.year, day.month, day.day);
    final bool alreadyFed = livestock.wasFedOn(target);
    final DateTime now = DateTime.now();

    List<LivestockProductionRecord> logs;
    if (alreadyFed) {
      logs = livestock.productionLogs
          .where((LivestockProductionRecord record) {
            final bool isDailyFeed =
                record.period == LivestockRecordPeriod.daily && record.feedKg > 0;
            if (!isDailyFeed) return true;
            final DateTime recordDay = DateTime(
                record.recordedAt.year, record.recordedAt.month, record.recordedAt.day);
            return recordDay != target;
          })
          .toList();
    } else {
      final double feedPerAnimal = FeedCalculatorService.feedPerAnimalKg(
        livestock.species, livestock.growthStage, livestock.averageAgeMonths, livestock.purpose,
        actualWeightKg: livestock.averageWeightKg,
      );
      final LivestockProductionRecord record = LivestockProductionRecord(
        id: const Uuid().v4(),
        period: LivestockRecordPeriod.daily,
        recordedAt: DateTime(target.year, target.month, target.day, 12),
        createdAt: now,
        updatedAt: now,
        feedKg: feedPerAnimal * livestock.count,
        notes: 'Marked fed via feed log',
      );
      logs = <LivestockProductionRecord>[...livestock.productionLogs, record];
    }

    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(productionLogs: logs, updatedAt: now, isSynced: false),
        );
  }

  Future<void> _setReminder(Livestock livestock, bool enabled, TimeOfDay time) async {
    final int notificationId = 'feed-reminder-${livestock.id}'.hashCode;
    if (enabled) {
      await FarmNotificationService.instance.scheduleDaily(
        id: notificationId,
        title: 'Feed your ${_speciesLabel(livestock.species)}',
        body: 'It\'s feeding time for your ${_speciesLabel(livestock.species)} group.',
        hour: time.hour,
        minute: time.minute,
        payload: '/livestock',
      );
    } else {
      await FarmNotificationService.instance.cancel(notificationId);
    }
    await ref.read(livestockProvider.notifier).updateLivestock(
          livestock.copyWith(
            feedReminderEnabled: enabled,
            feedReminderHour: time.hour,
            feedReminderMinute: time.minute,
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.livestock,
    required this.groupFeedKg,
    required this.onMarkFed,
  });

  final Livestock livestock;
  final double groupFeedKg;
  final VoidCallback onMarkFed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool fed = livestock.wasFedToday;
    return AppCard(
      color: fed
          ? theme.colorScheme.primaryContainer.withOpacity(0.4)
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: fed ? Colors.green.withOpacity(0.18) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                fed ? Icons.check_circle_rounded : Icons.restaurant_rounded,
                color: fed ? Colors.green : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fed ? 'Fed today' : 'Not fed yet today',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Suggested: ${groupFeedKg.toStringAsFixed(1)} kg for the group',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!fed)
              AppButton.primary(onPressed: onMarkFed, child: const Text('Mark fed')),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.livestock, required this.onChanged});

  final Livestock livestock;
  final void Function(bool enabled, TimeOfDay time) onChanged;

  @override
  Widget build(BuildContext context) {
    final TimeOfDay time =
        TimeOfDay(hour: livestock.feedReminderHour, minute: livestock.feedReminderMinute);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: <Widget>[
            const Icon(Icons.alarm_rounded, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Daily feed reminder', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    livestock.feedReminderEnabled
                        ? 'Reminds you every day at ${time.format(context)}'
                        : 'Off',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (livestock.feedReminderEnabled)
              TextButton(
                onPressed: () async {
                  final TimeOfDay? picked = await showTimePicker(context: context, initialTime: time);
                  if (picked != null) onChanged(true, picked);
                },
                child: Text(time.format(context)),
              ),
            Switch(
              value: livestock.feedReminderEnabled,
              onChanged: (bool value) async {
                if (value) {
                  final TimeOfDay? picked = await showTimePicker(context: context, initialTime: time);
                  onChanged(true, picked ?? time);
                } else {
                  onChanged(false, time);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCalendar extends StatelessWidget {
  const _FeedCalendar({
    required this.livestock,
    required this.focusedMonth,
    required this.onMonthChanged,
    required this.onDayTap,
  });

  final Livestock livestock;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTap;

  List<DateTime> _daysToDisplay() {
    final DateTime firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month);
    final DateTime lastOfMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final int leadingBlanks = firstOfMonth.weekday - DateTime.monday;
    final DateTime gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));
    final int totalCells = ((leadingBlanks + lastOfMonth.day) / 7).ceil() * 7;
    return List<DateTime>.generate(totalCells, (int i) => gridStart.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime today = DateTime.now();
    final DateTime todayKey = DateTime(today.year, today.month, today.day);
    final List<DateTime> days = _daysToDisplay();

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month - 1)),
            ),
            Expanded(
              child: Text(
                '${_kMonthNames[focusedMonth.month - 1]} ${focusedMonth.year}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month + 1)),
            ),
          ],
        ),
        Row(
          children: <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
              .map((String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 44,
          ),
          itemBuilder: (BuildContext context, int index) {
            final DateTime day = days[index];
            final bool inMonth = day.month == focusedMonth.month;
            final bool isToday = day == todayKey;
            final bool isFuture = day.isAfter(todayKey);
            final bool fed = livestock.wasFedOn(day);
            return Padding(
              padding: const EdgeInsets.all(2),
              child: InkWell(
                onTap: isFuture ? null : () => onDayTap(day),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: fed
                        ? Colors.green.withOpacity(0.75)
                        : isToday
                            ? theme.colorScheme.primary.withOpacity(0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: fed
                          ? Colors.white
                          : !inMonth || isFuture
                              ? theme.colorScheme.onSurfaceVariant.withOpacity(0.4)
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _speciesLabel(LivestockSpecies species) {
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
