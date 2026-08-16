import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/ai_topic.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/livestock_provider.dart';
import '../../screens/ai_advisor/ai_advisor_screen.dart';
import 'app_card.dart';

/// Displays AI-powered recommendations for a crop or livestock,
/// using GeminiService with a fallback to local advice.
class AiRecommendationsWidget extends ConsumerStatefulWidget {
  const AiRecommendationsWidget({
    super.key,
    this.crop,
    this.livestock,
  });

  final Crop? crop;
  final Livestock? livestock;

  @override
  ConsumerState<AiRecommendationsWidget> createState() =>
      _AiRecommendationsWidgetState();
}

class _AiRecommendationsWidgetState
    extends ConsumerState<AiRecommendationsWidget> {
  String? _aiInsight;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_awesome_rounded,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'AI Recommendations',
              style: theme.textTheme.titleLarge,
            ),
            const Spacer(),
            if (_aiInsight == null && !_isLoading)
              TextButton.icon(
                onPressed: _generateInsight,
                icon: const Icon(Icons.touch_app_rounded, size: 18),
                label: const Text('Generate'),
              ),
            if (_aiInsight != null && !_isLoading)
              TextButton.icon(
                onPressed: _generateInsight,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.crop != null
              ? 'AI-powered recommendations for ${widget.crop!.name}'
              : 'AI-powered recommendations for ${_livestockLabel(widget.livestock!.species)}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        if (_isLoading) ...[
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Generating AI recommendations...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else if (_hasError) ...[
          AppCard(
            color: theme.colorScheme.errorContainer.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline_rounded,
                      size: 20, color: theme.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Could not load AI recommendations',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap refresh to try again, or open the AI Advisor for direct help.',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (_aiInsight != null) ...[
          AppCard(
            color: theme.colorScheme.primaryContainer.withOpacity(0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Insights',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _aiInsight!,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openAiAdvisor(context),
              icon: const Icon(Icons.chat_rounded, size: 16),
              label: const Text('Ask AI Advisor'),
            ),
          ),
        ] else ...[
          // Fallback to local suggestions when AI has not been generated yet
          _buildLocalSuggestions(theme),
        ],
      ],
    );
  }

  Widget _buildLocalSuggestions(ThemeData theme) {
    if (widget.crop != null) {
      return _buildCropSuggestions(theme, widget.crop!);
    } else if (widget.livestock != null) {
      return _buildLivestockSuggestions(theme, widget.livestock!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildCropSuggestions(ThemeData theme, Crop crop) {
    final List<_SuggestionItem> suggestions = <_SuggestionItem>[
      _SuggestionItem(
        title: crop.currentStage == CropStage.flowering ||
                crop.currentStage == CropStage.fruiting
            ? 'Protect yield-critical stage'
            : 'Push early stand quality',
        detail: crop.currentStage == CropStage.flowering ||
                crop.currentStage == CropStage.fruiting
            ? 'Keep moisture steady, reduce stress, and check pest pressure every 1-2 days so flowering and fruit fill are not interrupted.'
            : 'Inspect gaps, weed pressure, and leaf colour now. Early corrections usually protect the rest of the cycle.',
        color: const Color(0xFFE8F4D8),
      ),
      _SuggestionItem(
        title: crop.daysToHarvest <= 7 ? 'Prepare harvest logistics' : 'Keep cycle records current',
        detail: crop.daysToHarvest <= 7
            ? 'Line up labour, crates, buyers, and transport. Capture harvest dates and early sales so finance stays accurate.'
            : 'Update stage, tasks, and input records this week so the app can keep cycle timing and reminders useful.',
        color: const Color(0xFFDFF1FF),
      ),
    ];

    return Column(
      children: suggestions
          .map((_SuggestionItem item) => _SuggestionTile(
                title: item.title,
                detail: item.detail,
                tint: item.color,
                theme: theme,
              ))
          .toList(),
    );
  }

  Widget _buildLivestockSuggestions(ThemeData theme, Livestock livestock) {
    final List<_SuggestionItem> suggestions = <_SuggestionItem>[
      _SuggestionItem(
        title: livestock.healthScore < 70
            ? 'Health attention needed'
            : 'Maintain stable welfare',
        detail: livestock.healthScore < 70
            ? 'Separate weak animals, check water access, review feed quality, and record any treatment or symptoms today.'
            : 'Keep body condition, housing cleanliness, and vaccination records up to date while logging weight and feed use.',
        color: const Color(0xFFFFEBD0),
      ),
      _SuggestionItem(
        title: livestock.vaccinationStatus < 75
            ? 'Vaccination gap'
            : 'Plan production milestone',
        detail: livestock.vaccinationStatus < 75
            ? 'Vaccination coverage is below the safer range. Schedule the next round and mark it as a high-priority reminder.'
            : 'Track weight gains weekly, keep feed conversion efficient, and tighten hygiene to protect finishing performance.',
        color: const Color(0xFFDFF1FF),
      ),
    ];

    return Column(
      children: suggestions
          .map((_SuggestionItem item) => _SuggestionTile(
                title: item.title,
                detail: item.detail,
                tint: item.color,
                theme: theme,
              ))
          .toList(),
    );
  }

  Future<void> _generateInsight() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _aiInsight = null;
    });

    try {
      final List<Farm> farms =
          ref.read(farmsProvider).valueOrNull ?? <Farm>[];
      final List<Crop> crops =
          ref.read(cropsProvider).valueOrNull ?? <Crop>[];
      final List<Livestock> livestockList =
          ref.read(livestockProvider).valueOrNull ?? <Livestock>[];
      final List<Transaction> transactions =
          ref.read(transactionsProvider).valueOrNull ?? <Transaction>[];

      // Pick the relevant farm
      Farm? farm;
      if (widget.crop != null) {
        for (final Farm f in farms) {
          if (f.id == widget.crop!.farmId) {
            farm = f;
            break;
          }
        }
      } else if (widget.livestock != null) {
        for (final Farm f in farms) {
          if (f.id == widget.livestock!.farmId) {
            farm = f;
            break;
          }
        }
      }

      if (farm == null) {
        _setLocalFallback();
        return;
      }

      final String insight = await GeminiService.instance.generateFarmInsight(
        farm: farm,
        crops: crops,
        livestock: livestockList,
        transactions: transactions,
      );

      if (!mounted) return;

      if (insight.isNotEmpty) {
        setState(() {
          _aiInsight = insight;
          _isLoading = false;
        });
      } else {
        _setLocalFallback();
      }
    } catch (e) {
      if (!mounted) return;
      _setLocalFallback();
    }
  }

  void _setLocalFallback() {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _openAiAdvisor(BuildContext context) {
    final AiTopic topic =
        widget.crop != null ? AiTopic.cropManagement : AiTopic.animalHealth;
    final String prompt = widget.crop != null
        ? _cropContextPrompt(widget.crop!)
        : _livestockContextPrompt(widget.livestock!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AiAdvisorScreen(
          initialTopic: topic,
          contextPrompt: prompt,
        ),
      ),
    );
  }

  String _cropContextPrompt(Crop crop) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
        'Give me advice specific to this exact crop record, not general farming tips:');
    buffer.writeln(
        '- Crop: ${crop.name}${crop.variety.isEmpty ? '' : ' (${crop.variety})'}');
    buffer.writeln(
        '- Stage: ${_stageLabel(crop.currentStage)}, day ${crop.daysSincePlanting} of ${crop.cycleLengthDays}');
    buffer.writeln('- Area: ${crop.landSizeLabel}');
    buffer.writeln('- Days to harvest: ${crop.daysToHarvest}');
    buffer.writeln(
        '- Input spend so far: ${CurrencyUtils.formatCurrency(crop.totalInputCost)}');
    if (crop.targetYieldKg > 0) {
      buffer.writeln(
          '- Target yield: ${crop.targetYieldKg.toStringAsFixed(0)} kg');
    }
    if (crop.actualYieldKg > 0) {
      buffer.writeln(
          '- Actual harvested so far: ${crop.actualYieldKg.toStringAsFixed(0)} kg');
    }
    if (crop.intelligenceNotes.trim().isNotEmpty) {
      buffer.writeln(
          '- Recent notes: ${crop.intelligenceNotes.split('\n').take(3).join('; ')}');
    }
    buffer.write('What should I focus on this week for this specific crop?');
    return buffer.toString();
  }

  String _livestockContextPrompt(Livestock livestock) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
        'Give me advice specific to this exact livestock group record, not general tips:');
    buffer.writeln(
        '- Group: ${_livestockLabel(livestock.species)}${livestock.breed.isEmpty ? '' : ' (${livestock.breed})'}, ${livestock.count} head');
    buffer.writeln('- Purpose: ${livestock.purpose.name}');
    buffer.writeln(
        '- Growth stage: ${livestock.growthStage.name}, average age ${livestock.averageAgeMonths} months');
    buffer.writeln(
        '- Health score: ${livestock.healthScore}%, vaccination coverage: ${livestock.vaccinationStatus}%');
    if (livestock.averageWeightKg > 0) {
      buffer.writeln(
          '- Average weight: ${livestock.averageWeightKg.toStringAsFixed(1)} kg');
    }
    if (livestock.mortalityCount > 0) {
      buffer.writeln('- Mortality recorded: ${livestock.mortalityCount}');
    }
    if (livestock.intelligenceNotes.trim().isNotEmpty) {
      buffer.writeln(
          '- Recent notes: ${livestock.intelligenceNotes.split('\n').take(3).join('; ')}');
    }
    buffer.write(
        'What should I focus on this week for this specific group?');
    return buffer.toString();
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

  String _livestockLabel(LivestockSpecies species) {
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

class _SuggestionItem {
  const _SuggestionItem({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.title,
    required this.detail,
    required this.tint,
    required this.theme,
  });

  final String title;
  final String detail;
  final Color tint;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconBackground =
        isDark ? Color.alphaBlend(tint.withOpacity(0.22), theme.colorScheme.surface) : tint;
    final Color iconForeground =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF44624E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? tint.withOpacity(0.42) : Colors.transparent),
                ),
                child: Icon(Icons.lightbulb_outline_rounded, color: iconForeground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(detail,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

