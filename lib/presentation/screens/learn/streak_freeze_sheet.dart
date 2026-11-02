import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';
import 'engagement_widgets.dart';

/// Status-aware streak banner: orange when learned today, ice-blue when the
/// fire is frozen and waiting to be restored, grey when the streak is lost.
class StreakHero extends ConsumerWidget {
  const StreakHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final EngagementState s = ref.watch(engagementProvider);
    final StreakInfo info = s.streakInfo(DateTime.now());

    final Color base;
    final String message;
    switch (info.status) {
      case StreakStatus.doneToday:
        base = EngagementColors.fire;
        message = language.tr(
            en: 'You learned today. Come back tomorrow!',
            ha: 'Ka yi karatu yau. Dawo gobe!',
            fr: 'Vous avez appris aujourd’hui. Revenez demain !');
        break;
      case StreakStatus.alive:
        base = EngagementColors.fire;
        message = language.tr(
            en: 'Finish a lesson today to extend your streak.',
            ha: 'Kammala darasi yau don ƙara jerin kwanakinka.',
            fr: 'Terminez une leçon aujourd’hui pour prolonger votre série.');
        break;
      case StreakStatus.frozen:
        base = EngagementColors.ice;
        message = language.tr(
            en: 'Your fire is frozen! Finish a lesson today to restore it. '
                '${info.restorationsLeft} of ${EngagementState.maxRestorations} restorations left.',
            ha: 'Wutar ka ta daskare! Kammala darasi yau don dawo da ita. '
                'Saura dawowa ${info.restorationsLeft} cikin ${EngagementState.maxRestorations}.',
            fr: 'Votre flamme est gelée ! Terminez une leçon aujourd’hui pour la rallumer. '
                'Il reste ${info.restorationsLeft} restauration(s) sur ${EngagementState.maxRestorations}.');
        break;
      case StreakStatus.broken:
        base = const Color(0xFF8E8E93);
        message = language.tr(
            en: 'Your streak ended. Start a new one today!',
            ha: 'Jerin kwanakinka ya ƙare. Fara sabo yau!',
            fr: 'Votre série est terminée. Recommencez aujourd’hui !');
        break;
      case StreakStatus.none:
        base = const Color(0xFF8E8E93);
        message = language.tr(
            en: 'Finish your first lesson to start a streak.',
            ha: 'Kammala darasinka na farko don fara jerin kwanaki.',
            fr: 'Terminez votre première leçon pour lancer une série.');
        break;
    }

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(color: base.withAlpha(90), offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${info.count}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 54,
                            height: 1,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      language.tr(
                          en: 'day streak',
                          ha: 'kwanaki a jere',
                          fr: 'jours de suite'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(message,
                        style: TextStyle(color: Colors.white.withAlpha(235))),
                  ],
                ),
              ),
              info.status == StreakStatus.frozen
                  ? const Icon(Icons.ac_unit_rounded,
                      color: Colors.white, size: 76)
                  : LottieOrIcon(
                      asset: LottieAssets.streakFire,
                      fallbackIcon: Icons.local_fire_department_rounded,
                      fallbackColor: Colors.white,
                      size: 96,
                    ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showStreakFreezeSheet(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: EngagementColors.gray, width: 2),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.ac_unit_rounded,
                    color: EngagementColors.ice, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    language.tr(
                        en: 'Streak freezes: ${s.freezeItems}/${EngagementState.maxFreezes}',
                        ha: 'Daskarewar jere: ${s.freezeItems}/${EngagementState.maxFreezes}',
                        fr: 'Gels de série : ${s.freezeItems}/${EngagementState.maxFreezes}'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.diamond_rounded,
                    color: EngagementColors.blue, size: 20),
                const SizedBox(width: 3),
                Text('${s.gems}',
                    style: const TextStyle(
                        color: EngagementColors.blue,
                        fontWeight: FontWeight.w900)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showStreakFreezeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _FreezeSheet(),
  );
}

class _FreezeSheet extends ConsumerWidget {
  const _FreezeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final EngagementState s = ref.watch(engagementProvider);
    final bool full = s.freezeItems >= EngagementState.maxFreezes;
    final bool canAfford = s.gems >= EngagementState.freezeCostGems;

    String? hint;
    if (full) {
      hint = language.tr(
          en: 'You already have the maximum.',
          ha: 'Ka riga ka kai matsakaicin adadi.',
          fr: 'Vous avez déjà le maximum.');
    } else if (!canAfford) {
      hint = language.tr(
          en: 'Earn gems by finishing lessons and unlocking achievements.',
          ha: 'Samu duwatsu ta hanyar kammala darussa da samun nasarori.',
          fr: 'Gagnez des gemmes en terminant des leçons et en débloquant des succès.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.ac_unit_rounded,
                  color: EngagementColors.ice, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  language.tr(
                      en: 'Streak freeze',
                      ha: 'Daskarewar jere',
                      fr: 'Gel de série'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 22),
                ),
              ),
              const Icon(Icons.diamond_rounded,
                  color: EngagementColors.blue, size: 22),
              const SizedBox(width: 3),
              Text('${s.gems}',
                  style: const TextStyle(
                      color: EngagementColors.blue,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            language.tr(
                en: 'A freeze automatically protects your streak if you miss a '
                    'day, and it does not use up one of your '
                    '${EngagementState.maxRestorations} restorations.',
                ha: 'Daskarewa tana kare jerin kwanakinka kai tsaye idan ka rasa '
                    'rana, kuma ba ta ɓata ɗaya daga cikin dawowar '
                    '${EngagementState.maxRestorations} ba.',
                fr: 'Un gel protège automatiquement votre série si vous manquez '
                    'un jour, sans utiliser l’une de vos '
                    '${EngagementState.maxRestorations} restaurations.'),
            style: const TextStyle(color: EngagementColors.grayText),
          ),
          const SizedBox(height: 12),
          Text(
            language.tr(
                en: 'Without a freeze, one missed day freezes your fire and '
                    'finishing a lesson restores it. You get '
                    '${EngagementState.maxRestorations} restorations '
                    '(${s.restorationsLeft} left). After that, the next miss '
                    'sends your streak back to the beginning.',
                ha: 'Ba tare da daskarewa ba, rasa rana ɗaya yana daskarar da '
                    'wutarka, kuma kammala darasi yana dawo da ita. Kana da '
                    'dawowa ${EngagementState.maxRestorations} '
                    '(saura ${s.restorationsLeft}). Bayan haka, rasa rana na '
                    'gaba zai mayar da jerinka daga farko.',
                fr: 'Sans gel, un jour manqué fige votre flamme et terminer une '
                    'leçon la rallume. Vous avez ${EngagementState.maxRestorations} '
                    'restaurations (${s.restorationsLeft} restantes). Ensuite, '
                    'le prochain oubli remet votre série à zéro.'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: EngagementColors.ice,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (full || !canAfford)
                  ? null
                  : () async {
                      final bool ok = await ref
                          .read(engagementProvider.notifier)
                          .buyFreeze();
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(language.tr(
                              en: 'Streak freeze equipped!',
                              ha: 'An sa daskarewar jere!',
                              fr: 'Gel de série activé !')),
                        ));
                      }
                    },
              icon: const Icon(Icons.diamond_rounded),
              label: Text(language.tr(
                  en: 'GET FOR ${EngagementState.freezeCostGems} GEMS',
                  ha: 'SAMU DA DUWATSU ${EngagementState.freezeCostGems}',
                  fr: 'OBTENIR POUR ${EngagementState.freezeCostGems} GEMMES')),
            ),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 8),
            Center(
              child: Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: EngagementColors.grayText, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
