import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class FarmDetailScreen extends ConsumerWidget {
  const FarmDetailScreen({
    super.key,
    required this.farmId,
  });

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    Farm? farm;
    for (final Farm item in farms) {
      if (item.id == farmId) {
        farm = item;
        break;
      }
    }
    if (farm == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Farm not found.')),
      );
    }

    final List<Crop> crops = (ref.watch(cropsProvider).valueOrNull ?? <Crop>[])
        .where((Crop item) => item.farmId == farmId)
        .toList(growable: false);
    final List<Livestock> livestock = (ref.watch(livestockProvider).valueOrNull ?? <Livestock>[])
        .where((Livestock item) => item.farmId == farmId)
        .toList(growable: false);
    final List<Transaction> transactions = (ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[])
        .where((Transaction item) => item.farmId == farmId)
        .toList(growable: false);

    final double income = transactions
        .where((Transaction item) => item.type == TransactionType.income)
        .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
    final double expenses = transactions
        .where((Transaction item) => item.type == TransactionType.expense)
        .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
    final int animalCount = livestock.fold<int>(0, (int sum, Livestock item) => sum + item.count);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(farm.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.thermostat_rounded),
            onPressed: () => _openMetricsSheet(context, ref, farm!),
          ),
        ],
      ),
      body: SoftScreenScaffold(
        heroTitle: farm.name,
        heroSubtitle: '${farm.ward} ward - ${farm.sizeHa.toStringAsFixed(1)} ha - ${farm.documents.length} documents',
        heroIcon: Icons.agriculture_rounded,
        heroVariant: farm.coverImageBase64.isEmpty
            ? FarmArtworkVariant.field
            : FarmArtworkVariant.crops,
        heroBadge: farm.isSynced ? 'Synced profile' : 'Pending sync',
        trailing: Column(
          children: <Widget>[
            SizedBox(
              width: 52,
              height: 52,
              child: AppButton.primary(
                onPressed: () => _pickFarmImage(context, ref, farm!),
                child: const Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 52,
              height: 52,
              child: AppButton.secondary(
                onPressed: () => _openDocumentSheet(context, ref, farm!),
                child: const Icon(Icons.note_add_rounded),
              ),
            ),
          ],
        ),
        sections: <Widget>[
          if (farm.coverImageBase64.isNotEmpty) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.memory(
                base64Decode(farm.coverImageBase64),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: 'Temperature',
                  value: '${farm.temperatureCelsius.toStringAsFixed(1)} C',
                  color: const Color(0xFFFFEBD0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: 'Humidity',
                  value: '${farm.humidityPercent.toStringAsFixed(0)}%',
                  color: const Color(0xFFDFF1FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: 'Soil moisture',
                  value: '${farm.soilMoisturePercent.toStringAsFixed(0)}%',
                  color: const Color(0xFFE5F5D8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: 'Precipitation',
                  value: '${farm.precipitationMm.toStringAsFixed(0)} mm',
                  color: const Color(0xFFEDE8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Quick stats'),
          Row(
            children: <Widget>[
              Expanded(
                child: _FarmMetricCard(
                  title: 'Crops',
                  value: '${crops.length}',
                  note: 'Linked records',
                  icon: Icons.spa_rounded,
                  tint: const Color(0xFFE5F5D8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FarmMetricCard(
                  title: 'Animals',
                  value: '$animalCount',
                  note: '${livestock.length} groups',
                  icon: Icons.pets_rounded,
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FarmMetricCard(
                  title: 'Balance',
                  value: CurrencyUtils.formatCompactCurrency(income - expenses),
                  note: 'Income vs spend',
                  icon: Icons.account_balance_wallet_rounded,
                  tint: const Color(0xFFFFEBD0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Farm notes'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    farm.notes.trim().isEmpty
                        ? 'No farm notes added yet.'
                        : farm.notes,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.secondary(
                      onPressed: () => _openNotesSheet(context, ref, farm!),
                      child: const Text('Update notes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Document storage'),
          if (farm.documents.isEmpty)
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No farm documents added yet. Add permits, contracts, inspection notes, or storage references.',
                ),
              ),
            )
          else
            ...farm.documents.map(
              (FarmDocumentRecord document) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFF1FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.description_outlined),
                    ),
                    title: Text(document.title),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${document.type} - ${document.reference}\n${document.notes}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Linked performance'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _LinkedRow(label: 'Farm income', value: CurrencyUtils.formatCurrency(income)),
                  const SizedBox(height: 12),
                  _LinkedRow(label: 'Farm expenses', value: CurrencyUtils.formatCurrency(expenses)),
                  const SizedBox(height: 12),
                  _LinkedRow(label: 'Transactions', value: '${transactions.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Farm suggestions'),
          _SuggestionCard(
            icon: Icons.water_drop_rounded,
            title: farm.soilMoisturePercent < 40 ? 'Irrigation priority' : 'Moisture stable',
            detail: farm.soilMoisturePercent < 40
                ? 'Soil moisture is below the comfortable range. Schedule watering, mulch exposed beds, and inspect young crops first.'
                : 'Current soil moisture is workable. Keep monitoring after hot afternoons or rainfall changes.',
            tint: const Color(0xFFDFF1FF),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: Icons.cloud_queue_rounded,
            title: farm.precipitationMm > 12 ? 'Rainfall watch' : 'Weather window open',
            detail: farm.precipitationMm > 12
                ? 'Rainfall is high enough to check drainage, storage cover, and livestock housing before evening.'
                : 'Precipitation risk is low. This is a good window for harvesting, spraying, transport, or field inspection.',
            tint: const Color(0xFFFFEBD0),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: Icons.inventory_2_rounded,
            title: 'Sales readiness',
            detail: transactions.any((Transaction item) => item.recordKind == TransactionRecordKind.sale)
                ? 'This farm already has sales records. Review receipts and inventory before the next market trip.'
                : 'No sale has been registered for this farm yet. Add produce inventory from Finance when harvest starts.',
            tint: const Color(0xFFE5F5D8),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFarmImage(BuildContext context, WidgetRef ref, Farm farm) async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (file == null) {
      return;
    }
    final String encoded = base64Encode(await file.readAsBytes());
    final Farm updated = farm.copyWith(
      coverImageBase64: encoded,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farm image updated.')),
      );
    }
  }

  Future<void> _openMetricsSheet(BuildContext context, WidgetRef ref, Farm farm) async {
    final _FarmMetricsDraft? draft = await showModalBottomSheet<_FarmMetricsDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _FarmMetricsSheet(farm: farm),
    );
    if (draft == null) {
      return;
    }
    await ref.read(farmsProvider.notifier).updateFarm(
          farm.copyWith(
            temperatureCelsius: draft.temperatureCelsius,
            humidityPercent: draft.humidityPercent,
            soilMoisturePercent: draft.soilMoisturePercent,
            precipitationMm: draft.precipitationMm,
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
  }

  Future<void> _openNotesSheet(BuildContext context, WidgetRef ref, Farm farm) async {
    final TextEditingController controller = TextEditingController(text: farm.notes);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Farm notes', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                AppTextField(
                  controller: controller,
                  label: 'Notes',
                  hint: 'Add field observations, storage plans, or seasonal reminders',
                  maxLines: 5,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.primary(
                    onPressed: () async {
                      await ref.read(farmsProvider.notifier).updateFarm(
                            farm.copyWith(
                              notes: controller.text.trim(),
                              updatedAt: DateTime.now(),
                              isSynced: false,
                            ),
                          );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Save notes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _openDocumentSheet(BuildContext context, WidgetRef ref, Farm farm) async {
    final _FarmDocumentDraft? draft = await showModalBottomSheet<_FarmDocumentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const _FarmDocumentSheet(),
    );
    if (draft == null) {
      return;
    }
    final List<FarmDocumentRecord> nextDocuments = <FarmDocumentRecord>[
      FarmDocumentRecord(
        id: const Uuid().v4(),
        title: draft.title,
        type: draft.type,
        reference: draft.reference,
        notes: draft.notes,
        createdAt: DateTime.now(),
      ),
      ...farm.documents,
    ];
    await ref.read(farmsProvider.notifier).updateFarm(
          farm.copyWith(
            documents: nextDocuments,
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
  }
}

class _FarmMetricCard extends StatelessWidget {
  const _FarmMetricCard({
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LinkedRow extends StatelessWidget {
  const _LinkedRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmMetricsSheet extends StatefulWidget {
  const _FarmMetricsSheet({required this.farm});

  final Farm farm;

  @override
  State<_FarmMetricsSheet> createState() => _FarmMetricsSheetState();
}

class _FarmMetricsSheetState extends State<_FarmMetricsSheet> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _humidityController;
  late final TextEditingController _soilController;
  late final TextEditingController _rainController;

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController(
      text: widget.farm.temperatureCelsius.toStringAsFixed(1),
    );
    _humidityController = TextEditingController(
      text: widget.farm.humidityPercent.toStringAsFixed(0),
    );
    _soilController = TextEditingController(
      text: widget.farm.soilMoisturePercent.toStringAsFixed(0),
    );
    _rainController = TextEditingController(
      text: widget.farm.precipitationMm.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _soilController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Update environmental metrics', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            AppTextField(
              controller: _temperatureController,
              label: 'Temperature (C)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _humidityController,
              label: 'Humidity (%)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _soilController,
              label: 'Soil moisture (%)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _rainController,
              label: 'Precipitation (mm)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: _submit,
                child: const Text('Save metrics'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _FarmMetricsDraft(
        temperatureCelsius: double.tryParse(_temperatureController.text.trim()) ?? 0,
        humidityPercent: double.tryParse(_humidityController.text.trim()) ?? 0,
        soilMoisturePercent: double.tryParse(_soilController.text.trim()) ?? 0,
        precipitationMm: double.tryParse(_rainController.text.trim()) ?? 0,
      ),
    );
  }
}

class _FarmDocumentSheet extends StatefulWidget {
  const _FarmDocumentSheet();

  @override
  State<_FarmDocumentSheet> createState() => _FarmDocumentSheetState();
}

class _FarmDocumentSheetState extends State<_FarmDocumentSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Add farm document', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            AppTextField(controller: _titleController, label: 'Title', hint: 'Input invoice'),
            const SizedBox(height: 12),
            AppTextField(controller: _typeController, label: 'Type', hint: 'Invoice, permit, contract'),
            const SizedBox(height: 12),
            AppTextField(controller: _referenceController, label: 'Storage reference', hint: 'Shelf A / Google Drive / Box 2'),
            const SizedBox(height: 12),
            AppTextField(controller: _notesController, label: 'Notes', maxLines: 3),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: _submit,
                child: const Text('Save document'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final String? titleError = Validators.required(_titleController.text.trim(), fieldName: 'Title');
    if (titleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(titleError)));
      return;
    }
    Navigator.of(context).pop(
      _FarmDocumentDraft(
        title: _titleController.text.trim(),
        type: _typeController.text.trim().isEmpty ? 'Document' : _typeController.text.trim(),
        reference: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
      ),
    );
  }
}

class _FarmMetricsDraft {
  const _FarmMetricsDraft({
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.soilMoisturePercent,
    required this.precipitationMm,
  });

  final double temperatureCelsius;
  final double humidityPercent;
  final double soilMoisturePercent;
  final double precipitationMm;
}

class _FarmDocumentDraft {
  const _FarmDocumentDraft({
    required this.title,
    required this.type,
    required this.reference,
    required this.notes,
  });

  final String title;
  final String type;
  final String reference;
  final String notes;
}
