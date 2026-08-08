import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';

/// Lets a farmer pick two or more crop plantings ("batches" - each Crop
/// record already represents one distinct planting) and compare them
/// side by side: cost, land size, timeline, stage, and target yield.
class CropBatchComparisonScreen extends ConsumerStatefulWidget {
  const CropBatchComparisonScreen({super.key});

  @override
  ConsumerState<CropBatchComparisonScreen> createState() =>
      _CropBatchComparisonScreenState();
}

class _CropBatchComparisonScreenState
    extends ConsumerState<CropBatchComparisonScreen> {
  final Set<String> _selectedIds = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final Map<String, Farm> farmById = <String, Farm>{
      for (final Farm farm in farms) farm.id: farm,
    };
    final List<Crop> sorted = List<Crop>.of(crops)
      ..sort((Crop a, Crop b) => b.plantingDate.compareTo(a.plantingDate));
    final List<Crop> filtered = _query.trim().isEmpty
        ? sorted
        : sorted
            .where((Crop crop) =>
                crop.name.toLowerCase().contains(_query.toLowerCase()) ||
                crop.variety.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    final List<Crop> selected = crops
        .where((Crop crop) => _selectedIds.contains(crop.id))
        .toList()
      ..sort((Crop a, Crop b) => a.plantingDate.compareTo(b.plantingDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare crop batches'),
      ),
      body: crops.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add a few crop plantings first, then come back here to compare them.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: <Widget>[
                if (selected.length >= 2)
                  Expanded(
                    child: _ComparisonTable(crops: selected, farmById: farmById),
                  )
                else ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search by crop name or variety',
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
                        'Select at least 2 batches to compare (${_selectedIds.length} selected)',
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
                        final Crop crop = filtered[index];
                        final Farm? farm = farmById[crop.farmId];
                        final bool checked = _selectedIds.contains(crop.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (bool? value) => setState(() {
                            if (value ?? false) {
                              _selectedIds.add(crop.id);
                            } else {
                              _selectedIds.remove(crop.id);
                            }
                          }),
                          title: Text('${crop.name}${crop.variety.isEmpty ? '' : ' · ${crop.variety}'}'),
                          subtitle: Text(
                            '${farm?.name ?? 'Unknown farm'} · ${crop.landSizeLabel} · planted ${_shortDate(crop.plantingDate)}',
                          ),
                          secondary: Text(_stageEmoji(crop.currentStage), style: const TextStyle(fontSize: 20)),
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

  String _stageEmoji(CropStage stage) {
    switch (stage) {
      case CropStage.seeding:
        return '🌱';
      case CropStage.germination:
        return '🌾';
      case CropStage.vegetative:
        return '🍃';
      case CropStage.flowering:
        return '🌼';
      case CropStage.fruiting:
        return '🌽';
    }
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.crops, required this.farmById});

  final List<Crop> crops;
  final Map<String, Farm> farmById;

  static const double _rowHeight = 56;
  static const double _labelWidth = 128;
  static const double _columnWidth = 168;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_MetricRow> rows = <_MetricRow>[
      _MetricRow('Farm', (Crop c) => farmById[c.farmId]?.name ?? 'Unknown'),
      _MetricRow('Land size', (Crop c) => c.landSizeLabel),
      _MetricRow('Planted', (Crop c) => _shortDate(c.plantingDate)),
      _MetricRow('Days since planting', (Crop c) => '${c.daysSincePlanting} days'),
      _MetricRow(
        'Days to harvest',
        (Crop c) => c.status == CropStatus.harvested
            ? 'Harvested'
            : c.daysToHarvest < 0
                ? '${-c.daysToHarvest} days overdue'
                : '${c.daysToHarvest} days',
      ),
      _MetricRow('Stage', (Crop c) => _stageLabel(c.currentStage)),
      _MetricRow('Status', (Crop c) => _statusLabel(c.status)),
      _MetricRow('Progress', (Crop c) => '${(c.growthProgress * 100).round()}%'),
      _MetricRow('Input cost', (Crop c) => CurrencyUtils.formatCurrency(c.totalInputCost)),
      _MetricRow(
        'Cost / ha',
        (Crop c) => c.areaHa > 0
            ? CurrencyUtils.formatCurrency(c.totalInputCost / c.areaHa)
            : '—',
      ),
      _MetricRow(
        'Target yield',
        (Crop c) => c.targetYieldKg > 0 ? '${c.targetYieldKg.toStringAsFixed(0)} kg' : '—',
      ),
      _MetricRow('Open tasks', (Crop c) => '${c.openTaskCount}'),
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
                  for (final Crop crop in crops)
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
                                '${crop.name}${crop.variety.isEmpty ? '' : '\n${crop.variety}'}',
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
                                  row.valueFor(crop),
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

  String _shortDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _stageLabel(CropStage stage) {
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

  String _statusLabel(CropStatus status) {
    switch (status) {
      case CropStatus.planted:
        return 'Planted';
      case CropStatus.growing:
        return 'Growing';
      case CropStatus.ready:
        return 'Ready';
      case CropStatus.harvested:
        return 'Harvested';
    }
  }
}

class _MetricRow {
  const _MetricRow(this.label, this.valueFor);

  final String label;
  final String Function(Crop crop) valueFor;
}
