import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/validators.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/email_notification_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import '../crops/crop_detail_screen.dart';
import '../livestock/livestock_detail_screen.dart';

class FarmDetailScreen extends ConsumerWidget {
  const FarmDetailScreen({
    super.key,
    required this.farmId,
  });

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(firebaseServiceProvider).currentUser;
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
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

    ref.read(activeFarmProvider.notifier).setActiveFarm(farm.id);

    if (!_canAccessFarm(farm, currentUser?.uid, currentUser?.email, profile?.accountRole)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('You do not have access to this farm.')),
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
    final _GreenhousePlanSummary? greenhousePlan = farm.supportsGreenhouse ? _greenhousePlanSummary(farm) : null;

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
        heroSubtitle: '${farm.ward} ward - ${_farmTypeLabel(farm.farmType)} - ${farm.sizeHa.toStringAsFixed(1)} ha',
        heroIcon: Icons.agriculture_rounded,
        heroVariant: farm.coverImageBase64.isEmpty
            ? FarmArtworkVariant.field
            : FarmArtworkVariant.crops,
        heroBadge: '${farm.workspaceMembers.length} members - ${farm.openWorkspaceTaskCount} open tasks',
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
          const SoftSectionTitle(title: 'Operation profile'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _Tag(text: _farmTypeLabel(farm.farmType), color: const Color(0xFFE8F4D8)),
                  if (farm.supportsCrops) _Tag(text: '${farm.cropCapacityHa.toStringAsFixed(1)} ha crop capacity', color: const Color(0xFFDFF1FF)),
                  if (farm.supportsLivestock) _Tag(text: '${farm.livestockCapacity} livestock capacity', color: const Color(0xFFFFEBD0)),
                  if (farm.supportsGreenhouse)
                    _Tag(
                      text: '${farm.greenhouseCount} greenhouse units on ${farm.greenhouseAreaHa.toStringAsFixed(1)} ha',
                      color: const Color(0xFFEDE8FF),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Workspace board'),
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _Tag(
                    text: '${farm.workspaceMembers.length} members',
                    color: const Color(0xFFE5F5D8),
                  ),
                  _Tag(
                    text: '${farm.ownerCount} owners',
                    color: const Color(0xFFDFF1FF),
                  ),
                  _Tag(
                    text: '${farm.openWorkspaceTaskCount} open tasks',
                    color: const Color(0xFFFFEBD0),
                  ),
                  _Tag(
                    text: '${farm.financeEnabledMemberCount} finance users',
                    color: const Color(0xFFEDE8FF),
                  ),
                ],
              ),
            ),
          ),
          if (greenhousePlan != null) ...<Widget>[
            const SizedBox(height: 18),
            const SoftSectionTitle(title: 'Greenhouse planner'),
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Live greenhouse sizing is based on the farm area, current weather readings, and a conservative production layout. Farmers can keep these suggestions or override them if they already run a tighter system.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SoftInfoChip(
                            label: 'Plant slots',
                            value: '${greenhousePlan.estimatedPlantSlots}',
                            color: const Color(0xFFE5F5D8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SoftInfoChip(
                            label: 'Water/day',
                            value: '${greenhousePlan.dailyWaterLitres.toStringAsFixed(0)} L',
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
                            label: 'Substrate',
                            value: '${greenhousePlan.substrateVolumeLitres.toStringAsFixed(0)} L',
                            color: const Color(0xFFEDE8FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SoftInfoChip(
                            label: 'Seed trays',
                            value: '${greenhousePlan.seedlingTrayCount}',
                            color: const Color(0xFFFFEBD0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SoftInfoChip(
                            label: 'Usable area',
                            value: '${greenhousePlan.usableAreaM2.toStringAsFixed(0)} m²',
                            color: const Color(0xFFE5F5D8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _Tag(text: '${greenhousePlan.bedWidthM.toStringAsFixed(1)} m bed width', color: const Color(0xFFE8F4D8)),
                        _Tag(text: '${greenhousePlan.plantSpacingM.toStringAsFixed(2)} m plant spacing', color: const Color(0xFFDFF1FF)),
                        _Tag(text: '${greenhousePlan.interRowSpacingM.toStringAsFixed(2)} m inter-row space', color: const Color(0xFFFFEBD0)),
                        _Tag(text: '${greenhousePlan.irrigationRoundsPerDay} irrigation rounds/day', color: const Color(0xFFEDE8FF)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SuggestionCard(
                      icon: Icons.view_compact_alt_rounded,
                      title: 'Layout formula',
                      detail: greenhousePlan.layoutNote,
                      tint: const Color(0xFFE8F4D8),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionCard(
                      icon: Icons.water_drop_rounded,
                      title: 'Irrigation schedule',
                      detail: greenhousePlan.irrigationNote,
                      tint: const Color(0xFFDFF1FF),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionCard(
                      icon: Icons.grass_rounded,
                      title: 'Soilless mix example',
                      detail: greenhousePlan.mixNote,
                      tint: const Color(0xFFEDE8FF),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Inventory to record',
                      detail: 'Log seedlings, coco coir, mature compost, rice husk, drip line, emitters, grow bags, pH meter, trays, and nutrient salts. Start with about ${greenhousePlan.dripLineMeters.toStringAsFixed(0)} m of drip line and ${greenhousePlan.seedlingTrayCount} nursery trays for this setup.',
                      tint: const Color(0xFFFFEBD0),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        SizedBox(
                          width: 180,
                          child: AppButton.primary(
                            onPressed: () => _logGreenhousePlan(context, ref, farm!, override: false),
                            child: const Text('Save plan note'),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: AppButton.secondary(
                            onPressed: () => _logGreenhousePlan(context, ref, farm!, override: true),
                            child: const Text('I know my setup'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(
                width: 180,
                child: AppButton.primary(
                  onPressed: () => _openMemberSheet(context, ref, farm!),
                  child: const Text('Add member'),
                ),
              ),
              SizedBox(
                width: 180,
                child: AppButton.secondary(
                  onPressed: () => _openTaskSheet(context, ref, farm!),
                  child: const Text('Add task'),
                ),
              ),
              SizedBox(
                width: 180,
                child: AppButton.secondary(
                  onPressed: () => _openActivitySheet(context, ref, farm!),
                  child: const Text('Log update'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Workspace members'),
          if (farm.workspaceMembers.isEmpty)
            const _EmptyInfoCard(message: 'Invite workers, partners, or co-owners to share access to this farm.')
          else
            ...farm.workspaceMembers.take(6).map(
              (FarmWorkspaceMember member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkspaceMemberTile(member: member),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Task board'),
          if (farm.workspaceTasks.isEmpty)
            const _EmptyInfoCard(message: 'No shared tasks yet. Add a schedule, assign it, and let the team update progress here.')
          else
            ...farm.workspaceTasks.take(6).map(
              (FarmWorkspaceTask task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkspaceTaskTile(
                  task: task,
                  onToggle: () => _toggleWorkspaceTask(context, ref, farm!, task),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Activity log'),
          if (farm.activityLog.isEmpty)
            const _EmptyInfoCard(message: 'Activity updates from workers and partners will appear here for the farm owner or co-owners.')
          else
            ...farm.activityLog.take(6).map(
              (FarmActivityRecord activity) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityLogTile(activity: activity),
              ),
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
          const SoftSectionTitle(title: 'Cycle tracking'),
          Row(
            children: <Widget>[
              Expanded(
                child: _FarmMetricCard(
                  title: 'Crop progress',
                  value: crops.isEmpty ? 'No crops' : '${((crops.fold<double>(0, (double sum, Crop item) => sum + item.growthProgress) / crops.length) * 100).round()}%',
                  note: 'Average growth cycle',
                  icon: Icons.timeline_rounded,
                  tint: const Color(0xFFE8F4D8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FarmMetricCard(
                  title: 'Animal growth',
                  value: livestock.isEmpty ? 'No groups' : '${((livestock.fold<double>(0, (double sum, Livestock item) => sum + item.growthProgress) / livestock.length) * 100).round()}%',
                  note: 'Average maturity cycle',
                  icon: Icons.monitor_heart_rounded,
                  tint: const Color(0xFFDFF1FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Linked crops'),
          if (crops.isEmpty)
            const _EmptyInfoCard(message: 'No crops linked to this farm yet.')
          else
            ...crops.take(4).map(
              (Crop item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LinkedEntityTile(
                  icon: Icons.spa_rounded,
                  title: item.name,
                  subtitle: '${item.variety} - ${_cropStageLabel(item.currentStage)} - ${item.daysToHarvest >= 0 ? '${item.daysToHarvest} days to harvest' : 'Harvest due'}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CropDetailScreen(cropId: item.id),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Linked livestock'),
          if (livestock.isEmpty)
            const _EmptyInfoCard(message: 'No livestock groups linked to this farm yet.')
          else
            ...livestock.take(4).map(
              (Livestock item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LinkedEntityTile(
                  icon: Icons.pets_rounded,
                  title: _speciesLabel(item.species),
                  subtitle: '${item.breed} - ${_growthStageLabel(item.growthStage)} - ${item.count} animals',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LivestockDetailScreen(livestockId: item.id),
                    ),
                  ),
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
          if (farm.supportsGreenhouse) ...<Widget>[
            const SizedBox(height: 12),
            _SuggestionCard(
              icon: Icons.wb_sunny_outlined,
              title: 'Greenhouse management',
              detail: farm.temperatureCelsius > 30
                  ? 'Heat is rising for enclosed production. Vent early, inspect humidity, and avoid late heavy watering.'
                  : 'Keep venting, sanitation, and disease scouting consistent inside protected structures.',
              tint: const Color(0xFFEDE8FF),
            ),
          ],
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

  Future<void> _logGreenhousePlan(
    BuildContext context,
    WidgetRef ref,
    Farm farm, {
    required bool override,
  }) async {
    if (!farm.supportsGreenhouse) {
      return;
    }
    final _GreenhousePlanSummary summary = _greenhousePlanSummary(farm);
    final DateTime now = DateTime.now();
    final String action = override ? 'Overrode greenhouse plan' : 'Reviewed greenhouse plan';
    final String detail = override
        ? 'The farmer chose to continue with a custom greenhouse setup after reviewing the live spacing, irrigation, and substrate suggestions.'
        : 'Suggested spacing, irrigation, substrate mix, and inventory notes were saved for greenhouse planning.';
    final Farm updated = farm.copyWith(
      activityLog: <FarmActivityRecord>[
        FarmActivityRecord(
          id: const Uuid().v4(),
          actorName: farm.ownerName.isEmpty ? 'Farm owner' : farm.ownerName,
          actorRole: FarmWorkspaceRole.owner,
          action: action,
          detail: '$detail Layout: ${summary.estimatedPlantSlots} plant slots, ${summary.dailyWaterLitres.toStringAsFixed(0)} L/day, ${summary.substrateVolumeLitres.toStringAsFixed(0)} L substrate.',
          audience: farm.ownerCount > 1 ? FarmActivityAudience.owners : FarmActivityAudience.workspace,
          createdAt: now,
        ),
        ...farm.activityLog,
      ],
      updatedAt: now,
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(override ? 'Custom greenhouse plan kept.' : 'Greenhouse plan saved to activity log.')),
      );
    }
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

  Future<void> _openMemberSheet(BuildContext context, WidgetRef ref, Farm farm) async {
    final _WorkspaceMemberDraft? draft = await showModalBottomSheet<_WorkspaceMemberDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _WorkspaceMemberSheet(farm: farm),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final FarmWorkspaceMember member = FarmWorkspaceMember(
      id: const Uuid().v4(),
      name: draft.name,
      email: draft.email,
      phone: draft.phone,
      role: draft.role,
      allowedFarmIds: draft.allowedFarmIds.isEmpty ? <String>[farm.id] : draft.allowedFarmIds,
      financeAccess: draft.financeAccess,
      canManageTasks: draft.canManageTasks,
      canManageSchedule: draft.canManageSchedule,
      canPostUpdates: draft.canPostUpdates,
      canViewActivityLog: draft.canViewActivityLog,
      createdAt: now,
      updatedAt: now,
    );
    final Farm updated = farm.copyWith(
      workspaceMembers: <FarmWorkspaceMember>[member, ...farm.workspaceMembers],
      activityLog: <FarmActivityRecord>[
        FarmActivityRecord(
          id: const Uuid().v4(),
          actorName: 'System',
          actorRole: FarmWorkspaceRole.owner,
          action: 'Added member',
          detail: '${member.name} joined as ${member.roleLabel} with ${member.financeAccessLabel}.',
          audience: farm.ownerCount > 1 ? FarmActivityAudience.owners : FarmActivityAudience.workspace,
          createdAt: now,
        ),
        ...farm.activityLog,
      ],
      updatedAt: now,
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
    if (member.email.isNotEmpty) {
      await ref.read(farmEmailServiceProvider).sendWelcomeNotification(
            toEmail: member.email,
            recipientName: member.name,
          );
    }
  }

  Future<void> _openTaskSheet(BuildContext context, WidgetRef ref, Farm farm) async {
    final _WorkspaceTaskDraft? draft = await showModalBottomSheet<_WorkspaceTaskDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _WorkspaceTaskSheet(farm: farm),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final FarmWorkspaceTask task = FarmWorkspaceTask(
      id: const Uuid().v4(),
      title: draft.title,
      details: draft.details,
      assigneeName: draft.assigneeName,
      assigneeRole: draft.assigneeRole,
      dueAt: draft.dueAt,
      status: FarmTaskStatus.open,
      reminderEnabled: draft.reminderEnabled,
      reminderLeadMinutes: draft.reminderLeadMinutes,
      createdBy: draft.createdBy,
      updatedBy: draft.createdBy,
      createdAt: now,
      updatedAt: now,
    );
    final Farm updated = farm.copyWith(
      workspaceTasks: <FarmWorkspaceTask>[task, ...farm.workspaceTasks],
      activityLog: <FarmActivityRecord>[
        FarmActivityRecord(
          id: const Uuid().v4(),
          actorName: draft.createdBy,
          actorRole: FarmWorkspaceRole.owner,
          action: 'Added task',
          detail: '${task.title} is due ${app_date.DateUtils.formatDateTime(task.dueAt)}.',
          audience: FarmActivityAudience.owners,
          relatedTaskId: task.id,
          createdAt: now,
        ),
        ...farm.activityLog,
      ],
      updatedAt: now,
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
    if (farm.ownerEmail.isNotEmpty) {
      await ref.read(farmEmailServiceProvider).sendScheduleNotification(
            toEmail: farm.ownerEmail,
            recipientName: farm.ownerName.isNotEmpty ? farm.ownerName : 'Farm owner',
            farmName: farm.name,
            taskTitle: task.title,
            dueLabel: app_date.DateUtils.formatDateTime(task.dueAt),
            detail: task.details.isEmpty ? 'A new farm task has been scheduled for review.' : task.details,
          );
    }
  }

  Future<void> _openActivitySheet(BuildContext context, WidgetRef ref, Farm farm) async {
    final _WorkspaceActivityDraft? draft = await showModalBottomSheet<_WorkspaceActivityDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _WorkspaceActivitySheet(farm: farm),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final FarmActivityRecord activity = FarmActivityRecord(
      id: const Uuid().v4(),
      actorName: draft.actorName,
      actorRole: draft.actorRole,
      action: draft.action,
      detail: draft.detail,
      audience: draft.audience,
      sentToOwners: draft.sentToOwners || draft.audience == FarmActivityAudience.owners,
      createdAt: now,
    );
    final Farm updated = farm.copyWith(
      activityLog: <FarmActivityRecord>[activity, ...farm.activityLog],
      updatedAt: now,
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
    if (farm.ownerEmail.isNotEmpty && draft.sentToOwners) {
      await ref.read(farmEmailServiceProvider).sendWorkerLogNotification(
            toEmail: farm.ownerEmail,
            recipientName: farm.ownerName.isNotEmpty ? farm.ownerName : 'Farm owner',
            farmName: farm.name,
            action: draft.action,
            detail: draft.detail,
          );
    }
  }

  Future<void> _toggleWorkspaceTask(BuildContext context, WidgetRef ref, Farm farm, FarmWorkspaceTask task) async {
    final DateTime now = DateTime.now();
    final bool markDone = !task.isCompleted;
    final FarmWorkspaceTask updatedTask = task.copyWith(
      status: markDone ? FarmTaskStatus.done : FarmTaskStatus.open,
      completedAt: markDone ? now : null,
      clearCompletedAt: !markDone,
      updatedBy: 'Workspace',
      updatedAt: now,
    );
    final List<FarmWorkspaceTask> nextTasks = farm.workspaceTasks
        .map((FarmWorkspaceTask current) => current.id == task.id ? updatedTask : current)
        .toList(growable: false);
    final Farm updated = farm.copyWith(
      workspaceTasks: nextTasks,
      activityLog: <FarmActivityRecord>[
        FarmActivityRecord(
          id: const Uuid().v4(),
          actorName: updatedTask.assigneeName.isEmpty ? 'Workspace team' : updatedTask.assigneeName,
          actorRole: updatedTask.assigneeRole,
          action: markDone ? 'Completed task' : 'Reopened task',
          detail: '${updatedTask.title} was ${markDone ? 'marked done' : 'reopened'}.',
          audience: FarmActivityAudience.owners,
          relatedTaskId: updatedTask.id,
          createdAt: now,
        ),
        ...farm.activityLog,
      ],
      updatedAt: now,
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
    if (farm.ownerEmail.isNotEmpty) {
      await ref.read(farmEmailServiceProvider).sendWorkerLogNotification(
            toEmail: farm.ownerEmail,
            recipientName: farm.ownerName.isNotEmpty ? farm.ownerName : 'Farm owner',
            farmName: farm.name,
            action: markDone ? 'Completed task' : 'Reopened task',
            detail: '${updatedTask.title} was ${markDone ? 'marked done' : 'reopened'}.',
          );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(markDone ? 'Task completed.' : 'Task reopened.')),
      );
    }
  }
}

bool _canAccessFarm(
  Farm farm,
  String? currentUserId,
  String? currentUserEmail,
  UserAccountRole? accountRole,
) {
  if (currentUserId == null && currentUserEmail == null) {
    return true;
  }
  if (accountRole == null || accountRole == UserAccountRole.owner) {
    return true;
  }
  return farm.ownerUid == currentUserId ||
      farm.ownerEmail == currentUserEmail ||
      farm.workspaceMembers.any(
        (FarmWorkspaceMember member) =>
            member.email == currentUserEmail ||
            member.id == currentUserId ||
            member.allowedFarmIds.contains(farm.id),
      );
}

class _WorkspaceMemberDraft {
  const _WorkspaceMemberDraft({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.allowedFarmIds,
    required this.financeAccess,
    required this.canManageTasks,
    required this.canManageSchedule,
    required this.canPostUpdates,
    required this.canViewActivityLog,
  });

  final String name;
  final String email;
  final String phone;
  final FarmWorkspaceRole role;
  final List<String> allowedFarmIds;
  final FarmFinanceAccess financeAccess;
  final bool canManageTasks;
  final bool canManageSchedule;
  final bool canPostUpdates;
  final bool canViewActivityLog;
}

class _WorkspaceTaskDraft {
  const _WorkspaceTaskDraft({
    required this.title,
    required this.details,
    required this.assigneeName,
    required this.assigneeRole,
    required this.dueAt,
    required this.reminderEnabled,
    required this.reminderLeadMinutes,
    required this.createdBy,
  });

  final String title;
  final String details;
  final String assigneeName;
  final FarmWorkspaceRole assigneeRole;
  final DateTime dueAt;
  final bool reminderEnabled;
  final int reminderLeadMinutes;
  final String createdBy;
}

class _WorkspaceActivityDraft {
  const _WorkspaceActivityDraft({
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.detail,
    required this.audience,
    required this.sentToOwners,
  });

  final String actorName;
  final FarmWorkspaceRole actorRole;
  final String action;
  final String detail;
  final FarmActivityAudience audience;
  final bool sentToOwners;
}

class _WorkspaceMemberSheet extends StatefulWidget {
  const _WorkspaceMemberSheet({required this.farm});

  final Farm farm;

  @override
  State<_WorkspaceMemberSheet> createState() => _WorkspaceMemberSheetState();
}

class _WorkspaceMemberSheetState extends State<_WorkspaceMemberSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _farmsController = TextEditingController();
  FarmWorkspaceRole _role = FarmWorkspaceRole.worker;
  FarmFinanceAccess _financeAccess = FarmFinanceAccess.viewOnly;
  bool _canManageTasks = true;
  bool _canManageSchedule = true;
  bool _canPostUpdates = true;
  bool _canViewActivityLog = true;

  @override
  void initState() {
    super.initState();
    _farmsController.text = widget.farm.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _farmsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
              Text('Add workspace member', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              AppTextField(controller: _nameController, label: 'Full name', hint: 'Worker, partner, or co-owner'),
              const SizedBox(height: 12),
              AppTextField(controller: _emailController, label: 'Email', hint: 'member@farm.com'),
              const SizedBox(height: 12),
              AppTextField(controller: _phoneController, label: 'Phone', hint: '+234 or local number'),
              const SizedBox(height: 12),
              _EnumDropdownField<FarmWorkspaceRole>(
                label: 'Role',
                value: _role,
                items: FarmWorkspaceRole.values,
                itemLabel: _roleLabel,
                onChanged: (FarmWorkspaceRole? value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _EnumDropdownField<FarmFinanceAccess>(
                label: 'Finance access',
                value: _financeAccess,
                items: FarmFinanceAccess.values,
                itemLabel: _financeAccessLabel,
                onChanged: (FarmFinanceAccess? value) {
                  if (value != null) {
                    setState(() => _financeAccess = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _farmsController,
                label: 'Accessible farms',
                hint: 'Comma-separated farm IDs',
              ),
              const SizedBox(height: 12),
              AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  children: <Widget>[
                    CheckboxListTile(
                      value: _canManageTasks,
                      onChanged: (bool? value) => setState(() => _canManageTasks = value ?? false),
                      title: const Text('Can manage tasks'),
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: _canManageSchedule,
                      onChanged: (bool? value) => setState(() => _canManageSchedule = value ?? false),
                      title: const Text('Can manage schedules'),
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: _canPostUpdates,
                      onChanged: (bool? value) => setState(() => _canPostUpdates = value ?? false),
                      title: const Text('Can post updates'),
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: _canViewActivityLog,
                      onChanged: (bool? value) => setState(() => _canViewActivityLog = value ?? false),
                      title: const Text('Can view activity log'),
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: _submit,
                  child: const Text('Save member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final String? nameError = Validators.required(_nameController.text.trim(), fieldName: 'Full name');
    if (nameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(nameError)));
      return;
    }
    final String? emailError = Validators.required(_emailController.text.trim(), fieldName: 'Email') ?? Validators.email(_emailController.text.trim());
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emailError)));
      return;
    }

    final List<String> farmIds = _farmsController.text
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);

    Navigator.of(context).pop(
      _WorkspaceMemberDraft(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _role,
        allowedFarmIds: farmIds.isEmpty ? <String>[widget.farm.id] : farmIds,
        financeAccess: _financeAccess,
        canManageTasks: _canManageTasks,
        canManageSchedule: _canManageSchedule,
        canPostUpdates: _canPostUpdates,
        canViewActivityLog: _canViewActivityLog,
      ),
    );
  }
}

class _WorkspaceTaskSheet extends StatefulWidget {
  const _WorkspaceTaskSheet({required this.farm});

  final Farm farm;

  @override
  State<_WorkspaceTaskSheet> createState() => _WorkspaceTaskSheetState();
}

class _WorkspaceTaskSheetState extends State<_WorkspaceTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _assigneeController = TextEditingController();
  final TextEditingController _createdByController = TextEditingController(text: 'Farm owner');
  FarmWorkspaceRole _role = FarmWorkspaceRole.worker;
  DateTime _dueAt = DateTime.now().add(const Duration(days: 1));
  bool _reminderEnabled = true;
  int _reminderLeadMinutes = 60;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _assigneeController.dispose();
    _createdByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
              Text('Add workspace task', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              AppTextField(controller: _titleController, label: 'Task title', hint: 'Irrigation check, feed run, delivery'),
              const SizedBox(height: 12),
              AppTextField(controller: _detailsController, label: 'Details', maxLines: 3),
              const SizedBox(height: 12),
              AppTextField(controller: _assigneeController, label: 'Assignee', hint: 'Worker name or partner'),
              const SizedBox(height: 12),
              _EnumDropdownField<FarmWorkspaceRole>(
                label: 'Assignee role',
                value: _role,
                items: FarmWorkspaceRole.values,
                itemLabel: _roleLabel,
                onChanged: (FarmWorkspaceRole? value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Due date', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 10),
                      Text(app_date.DateUtils.formatDateTime(_dueAt)),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppButton.secondary(
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                                  initialDate: _dueAt,
                                );
                                if (picked == null) {
                                  return;
                                }
                                setState(() {
                                  _dueAt = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    _dueAt.hour,
                                    _dueAt.minute,
                                  );
                                });
                              },
                              child: const Text('Pick date'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton.secondary(
                              onPressed: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_dueAt),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setState(() {
                                  _dueAt = DateTime(
                                    _dueAt.year,
                                    _dueAt.month,
                                    _dueAt.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              },
                              child: const Text('Pick time'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: _reminderEnabled,
                      onChanged: (bool value) => setState(() => _reminderEnabled = value),
                      title: const Text('Enable reminder'),
                      subtitle: const Text('Sends a reminder before the due time'),
                    ),
                    _EnumDropdownField<int>(
                      label: 'Reminder lead',
                      value: _reminderLeadMinutes,
                      items: const <int>[30, 60, 180, 1440],
                      itemLabel: (int value) {
                        if (value == 1440) {
                          return '1 day before';
                        }
                        if (value == 180) {
                          return '3 hours before';
                        }
                        return '$value minutes before';
                      },
                      onChanged: (int? value) {
                        if (value != null) {
                          setState(() => _reminderLeadMinutes = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _createdByController,
                label: 'Created by',
                hint: 'Owner, manager, or worker',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: _submit,
                  child: const Text('Save task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final String? titleError = Validators.required(_titleController.text.trim(), fieldName: 'Task title');
    if (titleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(titleError)));
      return;
    }

    Navigator.of(context).pop(
      _WorkspaceTaskDraft(
        title: _titleController.text.trim(),
        details: _detailsController.text.trim(),
        assigneeName: _assigneeController.text.trim(),
        assigneeRole: _role,
        dueAt: _dueAt,
        reminderEnabled: _reminderEnabled,
        reminderLeadMinutes: _reminderLeadMinutes,
        createdBy: _createdByController.text.trim().isEmpty ? 'Farm owner' : _createdByController.text.trim(),
      ),
    );
  }
}

class _WorkspaceActivitySheet extends StatefulWidget {
  const _WorkspaceActivitySheet({required this.farm});

  final Farm farm;

  @override
  State<_WorkspaceActivitySheet> createState() => _WorkspaceActivitySheetState();
}

class _WorkspaceActivitySheetState extends State<_WorkspaceActivitySheet> {
  final TextEditingController _actorController = TextEditingController(text: 'Farm owner');
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  FarmWorkspaceRole _role = FarmWorkspaceRole.owner;
  FarmActivityAudience _audience = FarmActivityAudience.owners;
  bool _sentToOwners = true;

  @override
  void dispose() {
    _actorController.dispose();
    _actionController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
              Text('Log activity', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              AppTextField(controller: _actorController, label: 'Actor', hint: 'Worker, partner, or owner'),
              const SizedBox(height: 12),
              _EnumDropdownField<FarmWorkspaceRole>(
                label: 'Actor role',
                value: _role,
                items: FarmWorkspaceRole.values,
                itemLabel: _roleLabel,
                onChanged: (FarmWorkspaceRole? value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _actionController, label: 'Action', hint: 'Harvest update, payment, inspection'),
              const SizedBox(height: 12),
              AppTextField(controller: _detailController, label: 'Details', maxLines: 4),
              const SizedBox(height: 12),
              _EnumDropdownField<FarmActivityAudience>(
                label: 'Share with',
                value: _audience,
                items: FarmActivityAudience.values,
                itemLabel: _activityAudienceLabel,
                onChanged: (FarmActivityAudience? value) {
                  if (value != null) {
                    setState(() {
                      _audience = value;
                      _sentToOwners = value == FarmActivityAudience.owners;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _sentToOwners,
                onChanged: (bool value) => setState(() => _sentToOwners = value),
                title: const Text('Notify owners'),
                subtitle: const Text('Useful when the farm is co-owned'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: _submit,
                  child: const Text('Save update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final String? actorError = Validators.required(_actorController.text.trim(), fieldName: 'Actor');
    if (actorError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(actorError)));
      return;
    }
    final String? actionError = Validators.required(_actionController.text.trim(), fieldName: 'Action');
    if (actionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(actionError)));
      return;
    }
    final String? detailError = Validators.required(_detailController.text.trim(), fieldName: 'Details');
    if (detailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detailError)));
      return;
    }

    Navigator.of(context).pop(
      _WorkspaceActivityDraft(
        actorName: _actorController.text.trim(),
        actorRole: _role,
        action: _actionController.text.trim(),
        detail: _detailController.text.trim(),
        audience: _audience,
        sentToOwners: _sentToOwners,
      ),
    );
  }
}

class _EnumDropdownField<T> extends StatelessWidget {
  const _EnumDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _WorkspaceMemberTile extends StatelessWidget {
  const _WorkspaceMemberTile({required this.member});

  final FarmWorkspaceMember member;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: member.isActive ? const Color(0xFFE5F5D8) : const Color(0xFFFFEBD0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.groups_rounded),
        ),
        title: Text(member.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${member.roleLabel} - ${member.email}${member.phone.isEmpty ? '' : ' - ${member.phone}'}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _Tag(text: member.financeAccessLabel, color: const Color(0xFFDFF1FF)),
                  _Tag(text: '${member.allowedFarmIds.length} farm(s)', color: const Color(0xFFEDE8FF)),
                  _Tag(text: member.canManageTasks ? 'Tasks' : 'No task access', color: const Color(0xFFE5F5D8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTaskTile extends StatelessWidget {
  const _WorkspaceTaskTile({
    required this.task,
    required this.onToggle,
  });

  final FarmWorkspaceTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: CheckboxListTile(
        value: task.isCompleted,
        onChanged: (_) => onToggle(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        title: Text(task.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (task.details.isNotEmpty) ...<Widget>[
                Text(task.details, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _Tag(text: task.statusLabel, color: const Color(0xFFFFEBD0)),
                  _Tag(text: app_date.DateUtils.formatDateTime(task.dueAt), color: const Color(0xFFE5F5D8)),
                  if (task.reminderEnabled) _Tag(text: '${task.reminderLeadMinutes}m reminder', color: const Color(0xFFDFF1FF)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({required this.activity});

  final FarmActivityRecord activity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: activity.audience == FarmActivityAudience.owners
                ? const Color(0xFFDFF1FF)
                : const Color(0xFFEDE8FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.history_rounded),
        ),
        title: Text(activity.action),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${activity.actorLabel} - ${activity.detail}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _Tag(text: activity.audienceLabel, color: const Color(0xFFE5F5D8)),
                  _Tag(text: app_date.DateUtils.formatDateTime(activity.createdAt), color: const Color(0xFFFFEBD0)),
                  if (activity.sentToOwners) _Tag(text: 'Sent to owners', color: const Color(0xFFDFF1FF)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(FarmWorkspaceRole role) {
  switch (role) {
    case FarmWorkspaceRole.owner:
      return 'Owner';
    case FarmWorkspaceRole.coOwner:
      return 'Co-owner';
    case FarmWorkspaceRole.manager:
      return 'Manager';
    case FarmWorkspaceRole.supervisor:
      return 'Supervisor';
    case FarmWorkspaceRole.worker:
      return 'Worker';
    case FarmWorkspaceRole.partner:
      return 'Partner';
    case FarmWorkspaceRole.viewer:
      return 'Viewer';
  }
}

String _financeAccessLabel(FarmFinanceAccess access) {
  switch (access) {
    case FarmFinanceAccess.none:
      return 'No finance access';
    case FarmFinanceAccess.viewOnly:
      return 'View finance';
    case FarmFinanceAccess.recordOnly:
      return 'Record finance';
    case FarmFinanceAccess.manage:
      return 'Manage finance';
  }
}

String _activityAudienceLabel(FarmActivityAudience audience) {
  switch (audience) {
    case FarmActivityAudience.owners:
      return 'Owners';
    case FarmActivityAudience.workspace:
      return 'Workspace';
    case FarmActivityAudience.selectedMembers:
      return 'Selected members';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
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

class _LinkedEntityTile extends StatelessWidget {
  const _LinkedEntityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyInfoCard extends StatelessWidget {
  const _EmptyInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
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

class _GreenhousePlanSummary {
  const _GreenhousePlanSummary({
    required this.usableAreaM2,
    required this.plantSpacingM,
    required this.interRowSpacingM,
    required this.bedWidthM,
    required this.estimatedPlantSlots,
    required this.seedlingTrayCount,
    required this.irrigationRoundsPerDay,
    required this.dailyWaterLitres,
    required this.substrateVolumeLitres,
    required this.compostLitres,
    required this.cocoCoirLitres,
    required this.riceHuskLitres,
    required this.sandLitres,
    required this.dripLineMeters,
    required this.layoutNote,
    required this.irrigationNote,
    required this.mixNote,
  });

  final double usableAreaM2;
  final double plantSpacingM;
  final double interRowSpacingM;
  final double bedWidthM;
  final int estimatedPlantSlots;
  final int seedlingTrayCount;
  final int irrigationRoundsPerDay;
  final double dailyWaterLitres;
  final double substrateVolumeLitres;
  final double compostLitres;
  final double cocoCoirLitres;
  final double riceHuskLitres;
  final double sandLitres;
  final double dripLineMeters;
  final String layoutNote;
  final String irrigationNote;
  final String mixNote;
}

_GreenhousePlanSummary _greenhousePlanSummary(Farm farm) {
  final double greenhouseAreaHa = farm.greenhouseAreaHa > 0 ? farm.greenhouseAreaHa : math.max(farm.sizeHa * 0.12, 0.05);
  final double usableAreaM2 = greenhouseAreaHa * 10000 * 0.72;
  final double plantSpacingM = farm.temperatureCelsius >= 32 ? 0.40 : 0.35;
  final double interRowSpacingM = farm.temperatureCelsius >= 32 ? 0.70 : 0.60;
  final double bedWidthM = 1.20;
  final int estimatedPlantSlots = math.max(1, (usableAreaM2 / (plantSpacingM * interRowSpacingM)).floor());
  final int seedlingTrayCount = math.max(1, (estimatedPlantSlots / 98).ceil());
  final int irrigationRoundsPerDay = (farm.temperatureCelsius >= 32 || farm.soilMoisturePercent < 35) ? 3 : 2;
  double waterPerPlantLitres = 0.20;
  if (farm.temperatureCelsius >= 32) {
    waterPerPlantLitres += 0.05;
  }
  if (farm.humidityPercent <= 45) {
    waterPerPlantLitres += 0.03;
  }
  if (farm.soilMoisturePercent <= 35) {
    waterPerPlantLitres += 0.04;
  }
  final double dailyWaterLitres = estimatedPlantSlots * waterPerPlantLitres;
  final double substrateVolumeLitres = usableAreaM2 * 45;
  final double compostLitres = substrateVolumeLitres * 0.30;
  final double cocoCoirLitres = substrateVolumeLitres * 0.40;
  final double riceHuskLitres = substrateVolumeLitres * 0.20;
  final double sandLitres = substrateVolumeLitres * 0.10;
  final double dripLineMeters = usableAreaM2 / interRowSpacingM;
  return _GreenhousePlanSummary(
    usableAreaM2: usableAreaM2,
    plantSpacingM: plantSpacingM,
    interRowSpacingM: interRowSpacingM,
    bedWidthM: bedWidthM,
    estimatedPlantSlots: estimatedPlantSlots,
    seedlingTrayCount: seedlingTrayCount,
    irrigationRoundsPerDay: irrigationRoundsPerDay,
    dailyWaterLitres: dailyWaterLitres,
    substrateVolumeLitres: substrateVolumeLitres,
    compostLitres: compostLitres,
    cocoCoirLitres: cocoCoirLitres,
    riceHuskLitres: riceHuskLitres,
    sandLitres: sandLitres,
    dripLineMeters: dripLineMeters,
    layoutNote:
        'Use about ${plantSpacingM.toStringAsFixed(2)} m between plants and ${interRowSpacingM.toStringAsFixed(2)} m between rows. That gives roughly ${estimatedPlantSlots} plants across ${usableAreaM2.toStringAsFixed(0)} m² of usable greenhouse area. Growers can widen the spacing for fruiting crops or tighten it slightly for leafy greens.',
    irrigationNote:
        'Start with ${irrigationRoundsPerDay} short irrigation rounds per day. Each plant needs about ${waterPerPlantLitres.toStringAsFixed(2)} L daily from the current temperature, humidity, and moisture profile. In hotter weather, split watering into morning and afternoon cycles instead of one long run.',
    mixNote:
        'For a practical 100 L soilless batch, mix 40 L coco coir, 30 L well-rotted compost, 20 L rice husk or biochar, and 10 L sand or perlite. For this greenhouse, the starting substrate demand is ${substrateVolumeLitres.toStringAsFixed(0)} L in total, with ${compostLitres.toStringAsFixed(0)} L compost, ${cocoCoirLitres.toStringAsFixed(0)} L coco coir, ${riceHuskLitres.toStringAsFixed(0)} L rice husk, and ${sandLitres.toStringAsFixed(0)} L sand/perlite. Use only mature compost and pre-wet the mix before transplanting.',
  );
}

String _farmTypeLabel(FarmType type) {
  switch (type) {
    case FarmType.crop:
      return 'Crop farm';
    case FarmType.livestock:
      return 'Livestock farm';
    case FarmType.greenhouse:
      return 'Greenhouse farm';
    case FarmType.combined:
      return 'Combined farm';
  }
}

String _cropStageLabel(CropStage stage) {
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
  }
}

String _growthStageLabel(AnimalGrowthStage stage) {
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
