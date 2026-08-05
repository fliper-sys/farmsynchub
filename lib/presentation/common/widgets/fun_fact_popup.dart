import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/data/fun_facts.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import 'farm_scene_artwork.dart';

/// A shareable "did you know" popup shown once a day, surfacing a fact
/// derived from a Learn-screen lesson (see [FunFact]) with a farm-art
/// background, the FarmSync logo, and a farm-themed Lottie animation.
class FunFactPopup extends StatefulWidget {
  const FunFactPopup({super.key, required this.fact});

  final FunFact fact;

  @override
  State<FunFactPopup> createState() => _FunFactPopupState();
}

class _FunFactPopupState extends State<FunFactPopup> {
  final GlobalKey _cardKey = GlobalKey();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  bool _isSharing = false;

  // Picked once per popup instance so it doesn't change on rebuild (e.g.
  // when _isSharing toggles).
  late final FarmArtworkVariant _artVariant = FarmArtworkVariant
      .values[Random().nextInt(FarmArtworkVariant.values.length)];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  RepaintBoundary(
                    key: _cardKey,
                    child: _FunFactCard(
                        fact: widget.fact, artVariant: _artVariant),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _RoundIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSharing ? null : _share,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.ios_share_rounded),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/learn/lesson/${widget.fact.lessonId}');
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Learn more'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
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

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final RenderRepaintBoundary? boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return;
      }
      final Uint8List bytes = byteData.buffer.asUint8List();
      final String path = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: 'farmsync_fun_fact.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        <XFile>[XFile(path, name: 'farmsync_fun_fact.png')],
        text: widget.fact.fact,
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

class _FunFactCard extends StatelessWidget {
  const _FunFactCard({required this.fact, required this.artVariant});

  final FunFact fact;
  final FarmArtworkVariant artVariant;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            FarmSceneArtwork(
              height: 460,
              variant: artVariant,
              borderRadius: BorderRadius.zero,
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(AppAssets.appIcon,
                              width: 26, height: 26),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'FarmSync Hub',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: SizedBox(
                        height: 140,
                        child: Lottie.asset(
                          AppAssets.onboardingWelcomeAnimation,
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'DID YOU KNOW?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fact.fact,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
