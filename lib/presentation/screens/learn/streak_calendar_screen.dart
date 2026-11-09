import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';
import 'engagement_widgets.dart';
import 'learning_reminder_sheet.dart';
import 'streak_freeze_sheet.dart';

/// Streak + progress calendar. Every day shows whether it was passed
/// (learned), missed, or is still to come. Tapping a day shows the XP and
/// achievements earned on it.
class StreakCalendarScreen extends ConsumerStatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  ConsumerState<StreakCalendarScreen> createState() =>
      _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends ConsumerState<StreakCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final EngagementState s = ref.watch(engagementProvider);
    final DateTime now = DateTime.now();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime thisMonth = DateTime(now.year, now.month);
    final bool canGoForward = _month.isBefore(thisMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(
            en: 'Streak', ha: 'Jerin Kwanaki', fr: 'Série', pcm: 'Streak')),
        actions: <Widget>[
          IconButton(
            tooltip: language.tr(
                en: 'Reminders',
                ha: 'Tunatarwa',
                fr: 'Rappels',
                pcm: 'Reminders'),
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => showLearningReminderSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: <Widget>[
          const StreakHero(),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  icon: Icons.bolt_rounded,
                  color: EngagementColors.gold,
                  value: '${s.totalXp}',
                  label: language.tr(en: 'Total XP', ha: 'Jimillar XP', fr: 'XP total'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.emoji_events_rounded,
                  color: EngagementColors.fire,
                  value: '${s.longestStreak}',
                  label: language.tr(en: 'Longest', ha: 'Mafi tsawo', fr: 'Record'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.menu_book_rounded,
                  color: EngagementColors.green,
                  value: '${s.lessonsCompleted}',
                  label: language.tr(en: 'Lessons', ha: 'Darussa', fr: 'Leçons'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: EngagementColors.gray, width: 2),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${monthName(language, _month.month)} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                    ),
                    IconButton(
                      onPressed: canGoForward ? () => _shiftMonth(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: weekdayInitials(language)
                      .map((String d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: EngagementColors.grayText)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                _MonthGrid(
                  month: _month,
                  state: s,
                  now: now,
                  onDayTap: (DateTime d) => _showDay(context, d, s, now, language),
                ),
                const SizedBox(height: 12),
                _Legend(language: language),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            language.tr(en: 'Achievements', ha: 'Nasarori', fr: 'Succès'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ...Achievements.all.map((AchievementDef def) =>
              _AchievementRow(def: def, state: s, language: language)),
        ],
      ),
    );
  }

  void _showDay(BuildContext context, DateTime date, EngagementState s,
      DateTime now, AppLanguage language) {
    final DayStatus status = s.statusFor(date, now);
    if (status == DayStatus.future || status == DayStatus.beforeStart) return;
    final DayActivity activity = s.activityOn(date);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${date.day} ${monthName(language, date.month)} ${date.year}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              switch (status) {
                DayStatus.done => language.tr(
                    en: 'Passed - you learned this day',
                    ha: 'An ci - ka yi karatu a wannan rana',
                    fr: 'Réussi - vous avez appris ce jour-là'),
                DayStatus.frozen => language.tr(
                    en: 'Frozen - this missed day was covered, so your streak lived on',
                    ha: 'Daskararre - an rufe wannan ranar da aka rasa, jerinka ya ci gaba',
                    fr: 'Gelé - ce jour manqué a été couvert, votre série continue'),
                DayStatus.missed => language.tr(
                    en: 'Missed - no learning this day',
                    ha: 'An rasa - ba a yi karatu a wannan rana ba',
                    fr: 'Manqué - aucun apprentissage ce jour-là'),
                _ => language.tr(
                    en: 'Today - finish a lesson to keep your streak',
                    ha: 'Yau - kammala darasi don ci gaba da jerin',
                    fr: 'Aujourd’hui - terminez une leçon pour garder votre série'),
              },
              style: TextStyle(
                  color: status == DayStatus.missed
                      ? EngagementColors.red
                      : EngagementColors.grayText,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    icon: Icons.bolt_rounded,
                    color: EngagementColors.gold,
                    value: '${activity.xp}',
                    label: 'XP',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: Icons.menu_book_rounded,
                    color: EngagementColors.green,
                    value: '${activity.lessons}',
                    label: language.tr(
                        en: 'Lessons', ha: 'Darussa', fr: 'Leçons'),
                  ),
                ),
              ],
            ),
            if (activity.awards.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                language.tr(
                    en: 'Awards earned', ha: 'Lambobin yabo', fr: 'Récompenses'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...activity.awards.map((String id) {
                final AchievementDef? def = Achievements.byId(id);
                if (def == null) return const SizedBox.shrink();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: def.color.withAlpha(40),
                    child: Icon(def.icon, color: def.color),
                  ),
                  title: Text(def.title(language),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('+${def.bonusXp} XP'),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EngagementColors.gray, width: 2),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 2),
              Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: EngagementColors.grayText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.state,
    required this.now,
    required this.onDayTap,
  });

  final DateTime month;
  final EngagementState state;
  final DateTime now;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final int leading = DateTime(month.year, month.month, 1).weekday - 1;
    final int cells = leading + daysInMonth;
    final int rows = (cells / 7).ceil();

    return Column(
      children: List<Widget>.generate(rows, (int row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: List<Widget>.generate(7, (int col) {
              final int index = row * 7 + col;
              final int dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 48));
              }
              final DateTime date =
                  DateTime(month.year, month.month, dayNumber);
              return Expanded(
                child: _DayCell(
                  date: date,
                  status: state.statusFor(date, now),
                  activity: state.activityOn(date),
                  isToday: dateOnly(date) == dateOnly(now),
                  onTap: () => onDayTap(date),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.status,
    required this.activity,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final DayStatus status;
  final DayActivity activity;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Widget? badge;
    switch (status) {
      case DayStatus.done:
        bg = EngagementColors.fire;
        fg = Colors.white;
        break;
      case DayStatus.missed:
        bg = EngagementColors.red.withAlpha(30);
        fg = EngagementColors.red;
        break;
      case DayStatus.frozen:
        bg = EngagementColors.ice;
        fg = Colors.white;
        break;
      case DayStatus.todayPending:
        bg = Colors.transparent;
        fg = EngagementColors.fire;
        break;
      case DayStatus.future:
      case DayStatus.beforeStart:
        bg = Colors.transparent;
        fg = EngagementColors.grayText;
        break;
    }
    if (activity.awards.isNotEmpty) {
      badge = const Positioned(
        top: 0,
        right: 2,
        child: Icon(Icons.emoji_events_rounded,
            size: 14, color: EngagementColors.gold),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: EngagementColors.fire, width: 2.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: status == DayStatus.done
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('${date.day}',
                            style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                height: 1)),
                        Text('${activity.xp}',
                            style: TextStyle(
                                color: fg.withAlpha(220),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                height: 1.1)),
                      ],
                    )
                  : status == DayStatus.frozen
                      ? const Icon(Icons.ac_unit_rounded,
                          color: Colors.white, size: 20)
                      : Text('${date.day}',
                          style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
            ),
            if (badge != null) badge,
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.language});

  final AppLanguage language;

  Widget _item(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: EngagementColors.grayText)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _item(EngagementColors.fire,
            language.tr(en: 'Passed', ha: 'An ci', fr: 'Réussi')),
        _item(EngagementColors.ice,
            language.tr(en: 'Frozen', ha: 'Daskararre', fr: 'Gelé')),
        _item(EngagementColors.red.withAlpha(120),
            language.tr(en: 'Missed', ha: 'An rasa', fr: 'Manqué')),
        _item(EngagementColors.gold,
            language.tr(en: 'Award', ha: 'Lambar yabo', fr: 'Récompense')),
      ],
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow(
      {required this.def, required this.state, required this.language});

  final AchievementDef def;
  final EngagementState state;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = state.unlocked.contains(def.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EngagementColors.gray, width: 2),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  unlocked ? def.color.withAlpha(40) : EngagementColors.gray,
              child: Icon(def.icon,
                  color: unlocked ? def.color : EngagementColors.grayText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(def.title(language),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: unlocked ? null : EngagementColors.grayText)),
                  Text(def.description(language),
                      style: const TextStyle(
                          fontSize: 12, color: EngagementColors.grayText)),
                ],
              ),
            ),
            Text('+${def.bonusXp} XP',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: unlocked
                        ? EngagementColors.gold
                        : EngagementColors.grayText)),
          ],
        ),
      ),
    );
  }
}
