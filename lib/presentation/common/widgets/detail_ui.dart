import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'section_scroll_menu.dart';

/// Shared building blocks for the crop and livestock detail screens.
/// Design goals: the first screenful answers "is everything OK, and what do I
/// do next?", the main daily actions are one tap away, and the rest of the
/// page is easy to jump around. Built only from core Flutter widgets.

// ---------------------------------------------------------------------------
// Entrance animation
// ---------------------------------------------------------------------------

/// Fades and slides its child up. Use [index] to stagger a list.
class FadeInUp extends StatelessWidget {
  const FadeInUp({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Health / progress ring
// ---------------------------------------------------------------------------

/// Animated ring with a centred value. [value] is 0..1.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.centerText,
    this.caption,
    this.size = 84,
    this.onDark = true,
  });

  final double value;
  final Color color;
  final String centerText;
  final String? caption;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final double target = value.isNaN ? 0 : value.clamp(0.0, 1.0).toDouble();
    final Color text = onDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: v,
              color: color,
              track: (onDark ? Colors.white : Colors.black).withOpacity(0.14),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    centerText,
                    style: TextStyle(
                      color: text,
                      fontSize: size * 0.24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (caption != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        caption!,
                        style: TextStyle(
                          color: text.withOpacity(0.7),
                          fontSize: size * 0.12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.11;
    final Rect rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class HeroStat {
  const HeroStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;
}

/// Gradient summary card at the top of a detail screen.
class DetailHeroCard extends StatelessWidget {
  const DetailHeroCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.ringValue,
    required this.ringText,
    required this.ringCaption,
    required this.ringColor,
    required this.stats,
    this.statusLabel,
    this.statusColor,
    this.gradient = const <Color>[Color(0xFF062A1F), Color(0xFF0E4D38), Color(0xFF1B7A55)],
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final double ringValue;
  final String ringText;
  final String ringCaption;
  final Color ringColor;
  final List<HeroStat> stats;
  final String? statusLabel;
  final Color? statusColor;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: leading,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (statusLabel != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (statusColor ?? const Color(0xFFFFC800))
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: (statusColor ?? const Color(0xFFFFC800))
                                .withOpacity(0.6),
                          ),
                        ),
                        child: Text(
                          statusLabel!,
                          style: TextStyle(
                            color: statusColor ?? const Color(0xFFFFC800),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProgressRing(
                value: ringValue,
                color: ringColor,
                centerText: ringText,
                caption: ringCaption,
                size: 78,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              for (int i = 0; i < stats.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _HeroStatTile(stat: stats[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({required this.stat});

  final HeroStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(stat.icon, size: 13, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "What needs you" banner
// ---------------------------------------------------------------------------

class AttentionAction {
  const AttentionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

enum AttentionLevel { good, notice, urgent }

/// One clear sentence about the most important thing, with actions.
class AttentionBanner extends StatelessWidget {
  const AttentionBanner({
    super.key,
    required this.level,
    required this.title,
    required this.message,
    this.actions = const <AttentionAction>[],
  });

  final AttentionLevel level;
  final String title;
  final String message;
  final List<AttentionAction> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = switch (level) {
      AttentionLevel.good => const Color(0xFF2E9E5B),
      AttentionLevel.notice => const Color(0xFFD99A1E),
      AttentionLevel.urgent => const Color(0xFFE0524A),
    };
    final IconData icon = switch (level) {
      AttentionLevel.good => Icons.check_circle_rounded,
      AttentionLevel.notice => Icons.lightbulb_rounded,
      AttentionLevel.urgent => Icons.priority_high_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(theme.brightness == Brightness.dark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final AttentionAction a in actions)
                  ActionChip(
                    label: Text(a.label),
                    labelStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                    backgroundColor: color.withOpacity(0.12),
                    side: BorderSide(color: color.withOpacity(0.5)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      a.onTap();
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions
// ---------------------------------------------------------------------------

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.done = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Draws attention (e.g. "Mark fed" when not fed yet).
  final bool highlight;

  /// Shows a green tick instead of the icon.
  final bool done;
}

/// The handful of things the farmer does every day, one tap away.
class QuickActionRow extends StatelessWidget {
  const QuickActionRow({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int i) =>
            _QuickActionTile(action: actions[i]),
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action});

  final QuickAction action;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool should =
        widget.action.highlight && !MediaQuery.of(context).disableAnimations;
    if (should && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!should) {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _QuickActionTile old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuickAction a = widget.action;
    final Color accent = a.done
        ? const Color(0xFF2E9E5B)
        : a.highlight
            ? const Color(0xFFFF9600)
            : theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: a.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          a.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedBuilder(
            animation: _glow,
            builder: (BuildContext context, Widget? child) => Container(
              width: 92,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(a.highlight || a.done ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: accent.withOpacity(0.3 + 0.4 * _glow.value),
                ),
                boxShadow: a.highlight
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withOpacity(0.3 * _glow.value),
                          blurRadius: 14,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget c, Animation<double> anim) =>
                        ScaleTransition(scale: anim, child: c),
                    child: Icon(
                      a.done ? Icons.check_circle_rounded : a.icon,
                      key: ValueKey<bool>(a.done),
                      color: accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
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

// ---------------------------------------------------------------------------
// Jump bar
// ---------------------------------------------------------------------------

/// Horizontal chips that scroll the page to a section.
class SectionJumpBar extends StatelessWidget {
  const SectionJumpBar({super.key, required this.sections});

  final List<SectionEntry> sections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final SectionEntry s = sections[i];
          return ActionChip(
            avatar: s.icon == null
                ? null
                : Icon(s.icon, size: 16, color: theme.colorScheme.primary),
            label: Text(s.title),
            labelStyle:
                theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            onPressed: () {
              final BuildContext? target = s.sectionKey.currentContext;
              if (target == null) return;
              HapticFeedback.selectionClick();
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
                alignment: 0.06,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage stepper
// ---------------------------------------------------------------------------

class StageStep {
  const StageStep({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Horizontal life-cycle / growth-stage tracker. Steps up to and including
/// [currentIndex] are filled; [progress] (0..1) fills the line inside the
/// current stage.
class StageStepper extends StatelessWidget {
  const StageStepper({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.progressInStage = 0,
  });

  final List<StageStep> steps;
  final int currentIndex;
  final double progressInStage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color active = theme.colorScheme.primary;
    final Color idle = theme.colorScheme.outlineVariant;
    final int last = steps.length - 1;
    return Row(
      children: <Widget>[
              for (int i = 0; i < steps.length; i++)
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _Connector(
                              fill: i == 0
                                  ? -1
                                  : (i <= currentIndex
                                      ? 1
                                      : (i - 1 == currentIndex
                                          ? progressInStage
                                          : 0)),
                              active: active,
                              idle: idle,
                            ),
                          ),
                          _StepDot(
                            icon: steps[i].icon,
                            reached: i <= currentIndex,
                            current: i == currentIndex,
                            delay: i,
                          ),
                          Expanded(
                            child: _Connector(
                              fill: i == last
                                  ? -1
                                  : (i < currentIndex
                                      ? 1
                                      : (i == currentIndex
                                          ? progressInStage
                                          : 0)),
                              active: active,
                              idle: idle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: i == currentIndex
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: i == currentIndex
                              ? active
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.fill, required this.active, required this.idle});

  /// -1 = no line (first / last edge), otherwise 0..1 filled.
  final double fill;
  final Color active;
  final Color idle;

  @override
  Widget build(BuildContext context) {
    if (fill < 0) return const SizedBox(height: 4);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fill.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Container(
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: idle,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: active,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.icon,
    required this.reached,
    required this.current,
    required this.delay,
  });

  final IconData icon;
  final bool reached;
  final bool current;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color active = theme.colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay * 110),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) =>
          Transform.scale(scale: t.clamp(0.0, 1.15).toDouble(), child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: current ? 44 : 34,
        height: current ? 44 : 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reached ? active : theme.colorScheme.surface,
          border: Border.all(
            color: reached ? active : theme.colorScheme.outlineVariant,
            width: 2,
          ),
          boxShadow: current
              ? <BoxShadow>[
                  BoxShadow(color: active.withOpacity(0.4), blurRadius: 14),
                ]
              : const <BoxShadow>[],
        ),
        child: Icon(
          icon,
          size: current ? 22 : 17,
          color: reached
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
