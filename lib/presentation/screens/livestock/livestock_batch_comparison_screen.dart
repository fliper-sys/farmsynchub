import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/livestock_provider.dart';

/// Lets a farmer pick two or more livestock groups ("batches" - each
/// Livestock record already represents one distinct herd/flock) and
/// compare them side by side: size, weight, feed, cost, and health.
class LivestockBatchComparisonScreen extends ConsumerStatefulWidget {
  const LivestockBatchComparisonScreen({super.key});

  @override
  ConsumerState<LivestockBatchComparisonScreen> createState() =>
      _LivestockBatchComparisonScreenState();
}

class _LivestockBatchComparisonScreenState
    extends ConsumerState<LivestockBatchComparisonScreen> {
  final Set<String> _selectedIds = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<Livestock> livestock =
        ref.watch(livestockProvider).valueOrNull ?? <Livestock>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final Map<String, Farm> farmById = <String, Farm>{
      for (final Farm farm in farms) farm.id: farm,
    };
    final List<Livestock> sorted = List<Livestock>.of(livestock)
      ..sort((Livestock a, Livestock b) =>
          b.acquisitionDate.compareTo(a.acquisitionDate));
    final List<Livestock> filtered = _query.trim().isEmpty
        ? sorted
        : sorted
            .where((Livestock item) =>
                _speciesLabel(item.species)
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                item.breed.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    final List<Livestock> selected = livestock
        .where((Livestock item) => _selectedIds.contains(item.id))
        .toList()
      ..sort((Livestock a, Livestock b) =>
          a.acquisitionDate.compareTo(b.acquisitionDate));

    return Scaffold(
      appBar: AppBar(title: const Text('Compare livestock batches')),
      body: livestock.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add a few livestock groups first, then come back here to compare them.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: <Widget>[
                if (selected.length >= 2)
                  Expanded(
                    child: _ComparisonTable(livestock: selected, farmById: farmById),
                  )
                else ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search by species or breed',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        isDense: true,
                      ),
                      onChanged: (String value) => setState(() => _query = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select at least 2 groups to compare (${_selectedIds.length} selected)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Livestock item = filtered[index];
                        final Farm? farm = farmById[item.farmId];
                        final bool checked = _selectedIds.contains(item.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (bool? value) => setState(() {
                            if (value ?? false) {
                              _selectedIds.add(item.id);
                            } else {
                              _selectedIds.remove(item.id);
                            }
                          }),
                          title: Text(
                              '${_speciesLabel(item.species)}${item.breed.isEmpty ? '' : ' · ${item.breed}'}'),
                          subtitle: Text(
                            '${farm?.name ?? 'Unknown farm'} · ${item.count} animals · acquired ${_shortDate(item.acquisitionDate)}',
                          ),
                          secondary: Text(item.emoji, style: const TextStyle(fontSize: 20)),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _shortDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.livestock, required this.farmById});

  final List<Livestock> livestock;
  final Map<String, Farm> farmById;

  static const double _rowHeight = 56;
  static const double _labelWidth = 128;
  static const double _columnWidth = 168;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_MetricRow> rows = <_MetricRow>[
      _MetricRow('Farm', (Livestock l) => farmById[l.farmId]?.name ?? 'Unknown'),
      _MetricRow('Purpose', (Livestock l) => _purposeLabel(l.purpose)),
      _MetricRow('Count', (Livestock l) => '${l.count} (${l.maleCount}m / ${l.femaleCount}f)'),
      _MetricRow('Stage', (Livestock l) => _stageLabel(l.growthStage)),
      _MetricRow('Age', (Livestock l) => '${l.averageAgeMonths} mo'),
      _MetricRow('Target maturity', (Livestock l) => '${l.targetMaturityMonths} mo'),
      _MetricRow('Progress', (Livestock l) => '${(l.growthProgress * 100).round()}%'),
      _MetricRow(
        'Avg. weight',
        (Livestock l) => l.averageWeightKg > 0 ? '${l.averageWeightKg.toStringAsFixed(1)} kg' : '—',
      ),
      _MetricRow('Daily feed', (Livestock l) => '${(l.dailyFeedKg * l.count).toStringAsFixed(1)} kg'),
      _MetricRow('Daily water', (Livestock l) => '${(l.dailyWaterLitres * l.count).toStringAsFixed(1)} L'),
      _MetricRow('Health score', (Livestock l) => '${l.healthScore}%'),
      _MetricRow('Vaccinated', (Livestock l) => '${l.vaccinationStatus}%'),
      _MetricRow('Mortality', (Livestock l) => '${l.mortalityCount}'),
      _MetricRow('Estimated value', (Livestock l) => CurrencyUtils.formatCurrency(l.estimatedValue)),
      _MetricRow('Open tasks', (Livestock l) => '${l.openTaskCount}'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: _rowHeight + 12),
                for (final _MetricRow row in rows)
                  SizedBox(
                    height: _rowHeight,
                    child: Text(
                      row.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final Livestock item in livestock)
                    Container(
                      width: _columnWidth,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            height: _rowHeight + 12,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${_speciesLabel(item.species)}${item.breed.isEmpty ? '' : '\n${item.breed}'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          for (final _MetricRow row in rows)
                            SizedBox(
                              height: _rowHeight,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  row.valueFor(item),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stageLabel(AnimalGrowthStage stage) {
    switch (stage) {
      case AnimalGrowthStage.starter:
        return 'Starter';
      case AnimalGrowthStage.grower:
        return 'Grower';
      case AnimalGrowthStage.mature:
        return 'Mature';
      case AnimalGrowthStage.breeding:
        return 'Breeding';
      case AnimalGrowthStage.finishing:
        return 'Finishing';
    }
  }

  String _purposeLabel(LivestockPurpose purpose) {
    switch (purpose) {
      case LivestockPurpose.meat:
        return 'Meat';
      case LivestockPurpose.milk:
        return 'Milk';
      case LivestockPurpose.eggs:
        return 'Eggs';
      case LivestockPurpose.breeding:
        return 'Breeding';
    }
  }
}

class _MetricRow {
  const _MetricRow(this.label, this.valueFor);

  final String label;
  final String Function(Livestock item) valueFor;
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
