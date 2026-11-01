import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';
import 'streak_calendar_screen.dart';

/// Duolingo-style colours. Kept here so every engagement screen matches.
class EngagementColors {
  static const Color fire = Color(0xFFFF9600);
  static const Color fireDark = Color(0xFFE58700);
  static const Color green = Color(0xFF58CC02);
  static const Color greenDark = Color(0xFF58A700);
  static const Color gold = Color(0xFFFFC800);
  static const Color red = Color(0xFFFF4B4B);
  static const Color ice = Color(0xFF49C0F8);
  static const Color blue = Color(0xFF1CB0F6);
  static const Color gray = Color(0xFFE5E5E5);
  static const Color grayText = Color(0xFFAFAFAF);
}

/// Slide-up + fade transition used to move between lessons so the change
/// feels continuous instead of a hard cut.
Route<T> fluidRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
      final Animation<double> curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Plays a bundled Lottie file; shows [fallbackIcon] if the file is missing
/// so the app never crashes before the animations have been added.
class LottieOrIcon extends StatelessWidget {
  const LottieOrIcon({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 120,
    this.repeat = true,
  });

  final String asset;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        width: size,
        height: size,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallbackIcon, size: size * 0.7, color: fallbackColor),
      ),
    );
  }
}

/// Compact "fire + days" and "bolt + XP" chips for the top of the learn hub.
/// Tapping opens the streak calendar.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EngagementState s = ref.watch(engagementProvider);
    final DateTime now = DateTime.now();
    final StreakInfo info = s.streakInfo(now);
    final int streak = info.count;
    final bool frozen = info.status == StreakStatus.frozen;
    final Color streakColor = switch (info.status) {
      StreakStatus.doneToday => EngagementColors.fire,
      StreakStatus.alive => EngagementColors.fire,
      StreakStatus.frozen => EngagementColors.ice,
      _ => EngagementColors.grayText,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(fluidRoute<void>(const StreakCalendarScreen())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
                frozen
                    ? Icons.ac_unit_rounded
                    : Icons.local_fire_department_rounded,
                color: streakColor,
                size: 26),
            const SizedBox(width: 2),
            Text('$streak',
                style: TextStyle(
                    color: streakColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(width: 14),
            const Icon(Icons.bolt_rounded,
                color: EngagementColors.gold, size: 26),
            const SizedBox(width: 2),
            Text('${s.totalXp}',
                style: const TextStyle(
                    color: EngagementColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Monday-to-Sunday strip for the current week (the Duolingo "week" row).
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final EngagementState s = ref.watch(engagementProvider);
    final DateTime now = DateTime.now();
    final DateTime monday = addDays(dateOnly(now), -(now.weekday - 1));
    final List<String> labels = weekdayInitials(language);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(7, (int i) {
        final DateTime date = addDays(monday, i);
        final DayStatus status = s.statusFor(date, now);
        final bool isToday = dateOnly(date) == dateOnly(now);
        Color bg = Colors.transparent;
        Widget? child;
        switch (status) {
          case DayStatus.done:
            bg = EngagementColors.fire;
            child = const Icon(Icons.check_rounded,
                color: Colors.white, size: 20);
            break;
          case DayStatus.missed:
            bg = EngagementColors.red.withAlpha(36);
            child = const Icon(Icons.close_rounded,
                color: EngagementColors.red, size: 18);
            break;
          case DayStatus.frozen:
            bg = EngagementColors.ice;
            child = const Icon(Icons.ac_unit_rounded,
                color: Colors.white, size: 19);
            break;
          default:
            bg = EngagementColors.gray.withAlpha(120);
        }
        return Column(
          children: <Widget>[
            Text(labels[i],
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isToday
                        ? EngagementColors.fire
                        : EngagementColors.grayText)),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: EngagementColors.fire, width: 2)
                    : null,
              ),
              child: child == null ? null : Center(child: child),
            ),
          ],
        );
      }),
    );
  }
}

List<String> weekdayInitials(AppLanguage l) => <String>[
      l.tr(en: 'M', ha: 'L', fr: 'L'),
      l.tr(en: 'T', ha: 'T', fr: 'M'),
      l.tr(en: 'W', ha: 'L', fr: 'M'),
      l.tr(en: 'T', ha: 'A', fr: 'J'),
      l.tr(en: 'F', ha: 'J', fr: 'V'),
      l.tr(en: 'S', ha: 'A', fr: 'S'),
      l.tr(en: 'S', ha: 'L', fr: 'D'),
    ];

String monthName(AppLanguage l, int month) {
  const List<String> en = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  const List<String> ha = <String>[
    'Janairu', 'Fabrairu', 'Maris', 'Afrilu', 'Mayu', 'Yuni', 'Yuli',
    'Agusta', 'Satumba', 'Oktoba', 'Nuwamba', 'Disamba',
  ];
  const List<String> fr = <String>[
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  return l.tr(en: en[month - 1], ha: ha[month - 1], fr: fr[month - 1]);
}
