import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/app_preferences_provider.dart';
import 'wizard_models.dart';

/// One option in a [WizardChoiceGrid].
@immutable
class WizardChoice<T> {
  /// Creates a choice. Give it one visual: [image], [emoji] or [icon].
  const WizardChoice({
    required this.value,
    required this.label,
    this.hint,
    this.icon,
    this.emoji,
    this.image,
  });

  /// The value picked when this card is tapped.
  final T value;

  /// Short name.
  final LocalizedText label;

  /// One short line explaining the option in everyday words.
  final LocalizedText? hint;

  /// Icon used when there is no image or emoji.
  final IconData? icon;

  /// Emoji used when there is no image.
  final String? emoji;

  /// Asset photo shown at the top of the card.
  final String? image;
}

/// Picture cards for picking one option. Selecting animates the border, tint
/// and a check badge, so the answer is obvious at a glance.
class WizardChoiceGrid<T> extends StatelessWidget {
  /// Creates the grid.
  const WizardChoiceGrid({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    required this.language,
    this.columns = 2,
  });

  /// Options to show.
  final List<WizardChoice<T>> choices;

  /// Currently selected value, if any.
  final T? selected;

  /// Called when a card is tapped.
  final ValueChanged<T> onSelected;

  /// Language for labels and hints.
  final AppLanguage language;

  /// Cards per row.
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 12;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final WizardChoice<T> choice in choices)
              SizedBox(
                width: width,
                child: _ChoiceCard<T>(
                  choice: choice,
                  selected: choice.value == selected,
                  language: language,
                  onTap: () => onSelected(choice.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.selected,
    required this.language,
    required this.onTap,
  });

  final WizardChoice<T> choice;
  final bool selected;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppColors.primaryForeground(theme.brightness);
    final bool reduce = MediaQuery.of(context).disableAnimations;
    final Duration duration =
        reduce ? Duration.zero : const Duration(milliseconds: 220);
    final String? hint = choice.hint?.resolve(language);

    return Semantics(
      button: true,
      selected: selected,
      label: choice.label.resolve(language),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.10)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? accent : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _ChoiceVisual(choice: choice, accent: accent),
                      const SizedBox(height: 10),
                      Text(
                        choice.label.resolve(language),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (hint != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          hint,
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: duration,
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.surface, width: 2),
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 16, color: AppColors.onPrimaryBrand),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceVisual extends StatelessWidget {
  const _ChoiceVisual({required this.choice, required this.accent});

  final WizardChoice<dynamic> choice;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = _badge(
      child: choice.emoji != null
          ? Text(choice.emoji!, style: const TextStyle(fontSize: 28))
          : Icon(choice.icon ?? Icons.eco_rounded, color: accent, size: 28),
    );

    if (choice.image == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 76,
        width: double.infinity,
        child: Image.asset(
          choice.image!,
          fit: BoxFit.cover,
          cacheWidth: 500,
          errorBuilder: (BuildContext c, Object e, StackTrace? s) => fallback,
        ),
      ),
    );
  }

  Widget _badge({required Widget child}) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Big plus/minus control for whole numbers (animal counts and the like),
/// with quick-add chips so large numbers do not need hundreds of taps.
class WizardCounter extends StatelessWidget {
  /// Creates a counter.
  const WizardCounter({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.language,
    this.min = 0,
    this.max = 1000000,
    this.quickAdds = const <int>[5, 10],
    this.icon,
  });

  /// What is being counted, e.g. "Number of animals".
  final LocalizedText label;

  /// Current value.
  final int value;

  /// Called with the new value.
  final ValueChanged<int> onChanged;

  /// Language for labels.
  final AppLanguage language;

  /// Smallest allowed value.
  final int min;

  /// Largest allowed value.
  final int max;

  /// Amounts offered as "+N" chips.
  final List<int> quickAdds;

  /// Optional leading icon.
  final IconData? icon;

  void _set(int next) {
    final int clamped = next < min ? min : (next > max ? max : next);
    if (clamped != value) {
      HapticFeedback.selectionClick();
      onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppColors.primaryForeground(theme.brightness);
    final bool reduce = MediaQuery.of(context).disableAnimations;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label.resolve(language),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _RoundButton(
                icon: Icons.remove_rounded,
                onPressed: value > min ? () => _set(value - 1) : null,
              ),
              SizedBox(
                width: 120,
                child: AnimatedSwitcher(
                  duration:
                      reduce ? Duration.zero : const Duration(milliseconds: 180),
                  transitionBuilder: (Widget child, Animation<double> anim) =>
                      ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    '$value',
                    key: ValueKey<int>(value),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                onPressed: value < max ? () => _set(value + 1) : null,
              ),
            ],
          ),
          if (quickAdds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final int amount in quickAdds)
                  ActionChip(
                    label: Text('+$amount'),
                    onPressed: () => _set(value + amount),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled
          ? AppColors.primary
          : Theme.of(context).colorScheme.outlineVariant,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            icon,
            size: 28,
            color: enabled
                ? AppColors.onPrimaryBrand
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A tappable card that opens the date picker and shows the chosen date.
class WizardDateField extends StatelessWidget {
  /// Creates a date field.
  const WizardDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.language,
    this.firstDate,
    this.lastDate,
    this.icon = Icons.event_rounded,
  });

  /// What the date is, e.g. "Planting date".
  final LocalizedText label;

  /// Currently chosen date.
  final DateTime value;

  /// Called with the picked date.
  final ValueChanged<DateTime> onChanged;

  /// Language for labels.
  final AppLanguage language;

  /// Earliest pickable date (default year 2000).
  final DateTime? firstDate;

  /// Latest pickable date (default year 2100).
  final DateTime? lastDate;

  /// Leading icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppColors.primaryForeground(theme.brightness);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final DateTime first = firstDate ?? DateTime(2000);
          final DateTime last = lastDate ?? DateTime(2100);
          DateTime initial = value;
          if (initial.isBefore(first)) {
            initial = first;
          }
          if (initial.isAfter(last)) {
            initial = last;
          }
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label.resolve(language), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yyyy').format(value),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the final "check your answers" card.
@immutable
class WizardReviewItem {
  /// Creates a review line.
  const WizardReviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  /// Leading icon.
  final IconData icon;

  /// What the answer is for.
  final LocalizedText label;

  /// The farmer's answer, already formatted.
  final String value;
}

/// A tidy summary of the answers, shown on the last step.
class WizardReviewCard extends StatelessWidget {
  /// Creates the card.
  const WizardReviewCard({
    super.key,
    required this.items,
    required this.language,
  });

  /// Lines to show.
  final List<WizardReviewItem> items;

  /// Language for labels.
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppColors.primaryForeground(theme.brightness);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(items[i].icon, color: accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Text(
                      items[i].label.resolve(language),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text(
                      items[i].value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
