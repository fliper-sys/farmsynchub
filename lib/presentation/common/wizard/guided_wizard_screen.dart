import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../screens/learn/engagement_widgets.dart'
    show LottieOrIcon, fluidRoute;
import '../widgets/app_button.dart';
import 'wizard_models.dart';

/// Opens [wizard] full screen, above the bottom bar, and returns whatever the
/// wizard pops with (the finished draft, or null when the farmer leaves).
Future<T?> openWizard<T>(BuildContext context, Widget wizard) {
  return Navigator.of(context, rootNavigator: true)
      .push<T>(fluidRoute<T>(wizard));
}

/// A guided, one-question-at-a-time flow.
///
/// Each step shows a photo, a plain-language explanation of why the question
/// is asked, and the inputs. Steps slide in the direction of travel, progress
/// is always visible, and the farmer can switch language without leaving.
///
/// The owner keeps the answers (controllers and fields) in its own state and
/// rebuilds this widget with fresh [steps] whenever an answer changes. When
/// the last step is accepted, a short celebration plays and [onFinish] runs;
/// it should pop the route with the finished result.
class GuidedWizard extends ConsumerStatefulWidget {
  /// Creates the wizard.
  const GuidedWizard({
    super.key,
    required this.title,
    required this.steps,
    required this.finishLabel,
    required this.onFinish,
  });

  /// Name of the whole flow, e.g. "New farm".
  final LocalizedText title;

  /// The steps, in order. May change between rebuilds (for example a step
  /// that only applies to some answers).
  final List<WizardStep> steps;

  /// Label of the button on the last step, e.g. "Create farm".
  final LocalizedText finishLabel;

  /// Called after the celebration, once the last step is accepted.
  final VoidCallback onFinish;

  @override
  ConsumerState<GuidedWizard> createState() => _GuidedWizardState();
}

class _GuidedWizardState extends ConsumerState<GuidedWizard> {
  int _index = 0;
  bool _forward = true;
  bool _celebrating = false;
  LocalizedText? _error;

  bool get _isLast => _index >= widget.steps.length - 1;

  void _next() {
    final WizardStep step = widget.steps[_index];
    final LocalizedText? problem = step.validate?.call();
    if (problem != null) {
      HapticFeedback.mediumImpact();
      setState(() => _error = problem);
      return;
    }
    if (_isLast) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _forward = true;
      _index++;
    });
  }

  void _previous() {
    if (_index == 0) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _forward = false;
      _index--;
    });
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _celebrating = true;
    });
    final bool reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    }
    if (!mounted) {
      return;
    }
    widget.onFinish();
  }

  Future<void> _confirmLeave() async {
    final AppLanguage language = ref.read(appLanguageProvider);
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(WizardText.leaveTitle.resolve(language)),
        content: Text(WizardText.leaveBody.resolve(language)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(WizardText.stay.resolve(language)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(WizardText.leave.resolve(language)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final ThemeData theme = Theme.of(context);
    final bool reduce = MediaQuery.of(context).disableAnimations;
    if (_index >= widget.steps.length) {
      _index = widget.steps.length - 1;
    }
    final WizardStep step = widget.steps[_index];
    // The message disappears as soon as the answer becomes acceptable.
    final LocalizedText? problem =
        _error != null && step.validate?.call() != null ? _error : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || _celebrating) {
          return;
        }
        if (_index > 0) {
          _previous();
        } else {
          _confirmLeave();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _WizardHeader(
                  step: step,
                  wizardTitle: widget.title,
                  language: language,
                  index: _index,
                  total: widget.steps.length,
                  reduceMotion: reduce,
                  onClose: _confirmLeave,
                  onLanguage: (AppLanguage value) => ref
                      .read(appLanguageProvider.notifier)
                      .setLanguage(value),
                ),
                _ProgressBar(index: _index, total: widget.steps.length),
                Expanded(
                  child: AnimatedSwitcher(
                    duration:
                        reduce ? Duration.zero : const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: _expandLayout,
                    transitionBuilder: (Widget child, Animation<double> anim) {
                      final bool incoming =
                          child.key == ValueKey<String>(step.id);
                      final double dx = (_forward ? 1 : -1) * 0.18;
                      final Offset begin =
                          incoming ? Offset(dx, 0) : Offset(-dx, 0);
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: begin, end: Offset.zero)
                              .animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: _StepBody(
                      key: ValueKey<String>(step.id),
                      step: step,
                      language: language,
                    ),
                  ),
                ),
                _BottomBar(
                  language: language,
                  canGoBack: _index > 0,
                  isLast: _isLast,
                  finishLabel: widget.finishLabel,
                  problem: problem,
                  busy: _celebrating,
                  onBack: _previous,
                  onNext: _next,
                ),
              ],
            ),
            if (_celebrating)
              Positioned.fill(child: _Celebration(language: language)),
          ],
        ),
      ),
    );
  }
}

/// Stacks the outgoing and incoming step at full size so a slide does not
/// jump the layout.
Widget _expandLayout(Widget? current, List<Widget> previous) {
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[...previous, if (current != null) current],
  );
}

String _languageCode(AppLanguage language) {
  switch (language) {
    case AppLanguage.english:
      return 'EN';
    case AppLanguage.hausa:
      return 'HA';
    case AppLanguage.french:
      return 'FR';
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.wizardTitle,
    required this.language,
    required this.index,
    required this.total,
    required this.reduceMotion,
    required this.onClose,
    required this.onLanguage,
  });

  final WizardStep step;
  final LocalizedText wizardTitle;
  final AppLanguage language;
  final int index;
  final int total;
  final bool reduceMotion;
  final VoidCallback onClose;
  final ValueChanged<AppLanguage> onLanguage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double top = MediaQuery.of(context).padding.top;
    // With the keyboard open there is little room, so the photo shrinks to a
    // slim title bar instead of pushing the question off screen.
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double height = (keyboardOpen ? 112.0 : 232.0) + top;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedSwitcher(
              duration:
                  reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
              layoutBuilder: _expandLayout,
              child: _HeroImage(
                key: ValueKey<String>(step.id),
                asset: step.image,
                animate: !reduceMotion,
              ),
            ),
            // Keeps white text readable on any photo.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withOpacity(0.38),
                    Colors.black.withOpacity(0.18),
                    Colors.black.withOpacity(0.78),
                  ],
                  stops: const <double>[0, 0.4, 1],
                ),
              ),
            ),
            Positioned(
              top: top + 6,
              left: 8,
              right: 12,
              child: Row(
                children: <Widget>[
                  Material(
                    color: Colors.black.withOpacity(0.35),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: onClose,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wizardTitle.resolve(language).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  _LanguageChip(language: language, onSelected: onLanguage),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!keyboardOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        WizardText.stepOf(language, index + 1, total),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(step.icon,
                            color: AppColors.onPrimaryBrand, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step.title.resolve(language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
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

/// The step photo, slowly zooming so the screen feels alive.
class _HeroImage extends StatelessWidget {
  const _HeroImage({super.key, required this.asset, required this.animate});

  final String asset;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      asset,
      fit: BoxFit.cover,
      cacheWidth: 1100,
      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
          const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF0E5A41), Color(0xFF0B3D2D)],
          ),
        ),
      ),
    );
    if (!animate) {
      return image;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.12),
      duration: const Duration(seconds: 10),
      curve: Curves.easeOut,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: image,
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.language, required this.onSelected});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      tooltip: 'Language',
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => AppLanguage.values
          .map(
            (AppLanguage value) => PopupMenuItem<AppLanguage>(
              value: value,
              child: Row(
                children: <Widget>[
                  Icon(
                    value == language
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(value.label),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.translate_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              _languageCode(language),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One segment per step; filled up to and including the current one.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color on = AppColors.primaryForeground(theme.brightness);
    final Color off = theme.colorScheme.outlineVariant;
    final bool reduce = MediaQuery.of(context).disableAnimations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Row(
        children: List<Widget>.generate(total, (int i) {
          return Expanded(
            child: AnimatedContainer(
              duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i <= index ? on : off,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Fades and lifts its child into place; [delayMs] staggers siblings.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }
    const int base = 380;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: base + delayMs),
      curve: Interval(delayMs / (base + delayMs), 1.0,
          curve: Curves.easeOutCubic),
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({super.key, required this.step, required this.language});

  final WizardStep step;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppColors.primaryForeground(theme.brightness);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _FadeUp(
                delayMs: 0,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lightbulb_outline_rounded,
                            color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              WizardText.whyWeAsk.resolve(language),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.why.resolve(language),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _FadeUp(delayMs: 90, child: Builder(builder: step.builder)),
              if (step.tip != null) ...<Widget>[
                const SizedBox(height: 16),
                _FadeUp(
                  delayMs: 180,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.premiumWarning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.tips_and_updates_outlined,
                            color: AppColors.premiumWarning, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${WizardText.tip.resolve(language)}: ${step.tip!.resolve(language)}',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.language,
    required this.canGoBack,
    required this.isLast,
    required this.finishLabel,
    required this.problem,
    required this.busy,
    required this.onBack,
    required this.onNext,
  });

  final AppLanguage language;
  final bool canGoBack;
  final bool isLast;
  final LocalizedText finishLabel;
  final LocalizedText? problem;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: problem == null
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.40),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.info_outline_rounded,
                                color: theme.colorScheme.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                problem!.resolve(language),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Row(
                children: <Widget>[
                  if (canGoBack) ...<Widget>[
                    Expanded(
                      flex: 2,
                      child: AppButton.secondary(
                        onPressed: busy ? null : onBack,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.arrow_back_rounded, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                WizardText.back.resolve(language),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: AppButton.primary(
                      onPressed: busy ? null : onNext,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              (isLast ? finishLabel : WizardText.next)
                                  .resolve(language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
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

/// Full-screen "All set!" moment after the last step.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withOpacity(0.97),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IgnorePointer(
            child: Lottie.asset(
              AppAssets.confettiAnimation,
              repeat: false,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                  const SizedBox.shrink(),
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double t, Widget? child) =>
                  Opacity(
                opacity: t.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const LottieOrIcon(
                    asset: AppAssets.onboardingSuccessAnimation,
                    fallbackIcon: Icons.check_circle_rounded,
                    fallbackColor: AppColors.primary,
                    size: 160,
                    repeat: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    WizardText.allSet.resolve(language),
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
