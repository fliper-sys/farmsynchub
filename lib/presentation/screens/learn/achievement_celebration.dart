import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';
import '../../../providers/learning_provider.dart';
import 'engagement_widgets.dart';

/// Shows each newly unlocked achievement one after another.
Future<void> showAchievementCelebrations(
  BuildContext context,
  List<AchievementDef> achievements,
) async {
  for (final AchievementDef def in achievements) {
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'achievement',
      barrierColor: Colors.black.withAlpha(180),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => _AchievementDialog(def: def),
      transitionBuilder: (_, Animation<double> anim, __, Widget child) {
        final Animation<double> curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }
}

/// The picture that gets shared. Fixed light palette, so a shared image looks
/// the same whatever theme the sender uses.
class AchievementShareCard extends StatelessWidget {
  const AchievementShareCard({
    super.key,
    required this.def,
    required this.language,
    required this.learnerName,
    required this.streak,
    required this.totalXp,
  });

  final AchievementDef def;
  final AppLanguage language;
  final String learnerName;
  final int streak;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: def.color, width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            language.tr(
                en: 'ACHIEVEMENT UNLOCKED',
                ha: 'KA SAMI NASARA',
                fr: 'SUCCÈS DÉBLOQUÉ'),
            style: TextStyle(
                color: def.color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 12),
          ),
          const SizedBox(height: 8),
          LottieOrIcon(
            asset: def.lottie,
            fallbackIcon: def.icon,
            fallbackColor: def.color,
            size: 150,
            repeat: false,
          ),
          Text(def.title(language),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF3C3C3C),
                  fontWeight: FontWeight.w900,
                  fontSize: 24)),
          const SizedBox(height: 4),
          Text(def.description(language),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 14)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.local_fire_department_rounded,
                  color: EngagementColors.fire, size: 22),
              Text(' $streak   ',
                  style: const TextStyle(
                      color: EngagementColors.fire,
                      fontWeight: FontWeight.w900)),
              const Icon(Icons.bolt_rounded,
                  color: EngagementColors.gold, size: 22),
              Text(' $totalXp XP',
                  style: const TextStyle(
                      color: EngagementColors.gold,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            learnerName.isEmpty
                ? 'FarmSync Learn'
                : '$learnerName  •  FarmSync Learn',
            style: const TextStyle(
                color: Color(0xFF777777),
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AchievementDialog extends ConsumerStatefulWidget {
  const _AchievementDialog({required this.def});

  final AchievementDef def;

  @override
  ConsumerState<_AchievementDialog> createState() =>
      _AchievementDialogState();
}

class _AchievementDialogState extends ConsumerState<_AchievementDialog> {
  final GlobalKey _cardKey = GlobalKey();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    final AppLanguage language = ref.read(appLanguageProvider);
    setState(() => _isSharing = true);
    try {
      final RenderRepaintBoundary? boundary = _cardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Card is not ready.');
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not capture the card.');
      final Uint8List bytes = data.buffer.asUint8List();

      final String filename = 'farm_sync_${widget.def.id}.png';
      final String path = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: filename,
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        <XFile>[XFile(path, name: filename)],
        text: language.tr(
          en: 'I just unlocked "${widget.def.title(language)}" on FarmSync Learn!',
          ha: 'Na samu "${widget.def.title(language)}" a FarmSync Learn!',
          fr: 'Je viens de débloquer « ${widget.def.title(language)} » sur FarmSync Learn !',
          pcm: 'I just unlock "${widget.def.title(language)}" for FarmSync Learn!',
        ),
      );
      // Sharing counts towards the "community helper" award.
      await ref
          .read(learningProvider.notifier)
          .markShared('achievement_${widget.def.id}');
    } catch (error) {
      debugPrint('Achievement share failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(language.tr(
              en: 'Could not share. Please try again.',
              ha: 'Ba a iya rabawa ba. Sake gwadawa.',
              fr: 'Impossible de partager. Veuillez réessayer.')),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final EngagementState s = ref.watch(engagementProvider);
    final String name = ref.watch(learningProvider).learnerName;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Full-screen confetti behind the card.
          Positioned.fill(
            child: IgnorePointer(
              child: LottieOrIcon(
                asset: LottieAssets.confetti,
                fallbackIcon: Icons.celebration_rounded,
                fallbackColor: Colors.white24,
                size: 400,
                repeat: false,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RepaintBoundary(
                  key: _cardKey,
                  child: AchievementShareCard(
                    def: widget.def,
                    language: language,
                    learnerName: name,
                    streak: s.currentStreak(DateTime.now()),
                    totalXp: s.totalXp,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '+${widget.def.bonusXp} XP',
                  style: const TextStyle(
                      color: EngagementColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 320,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: EngagementColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(language
                        .tr(en: 'SHARE', ha: 'RABA', fr: 'PARTAGER')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 320,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: EngagementColors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(language.tr(
                        en: 'CONTINUE', ha: 'CI GABA', fr: 'CONTINUER')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
