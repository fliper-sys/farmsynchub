import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';

/// The FarmSync Hub wordmark: app logo plus a serif title where "Hub" picks
/// up the brand gradient. Fades and slides in when first shown.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.large = false, this.showLogo = true});

  final bool large;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double size = large ? 34 : 22;
    final double logo = large ? 52 : 32;
    final Color base = theme.colorScheme.onSurface;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset((1 - t) * -16, 0), child: child),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showLogo) ...<Widget>[
            Container(
              width: logo,
              height: logo,
              padding: EdgeInsets.all(logo * 0.1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(logo * 0.3),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF2E9E5B).withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(logo * 0.22),
                child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
              ),
            ),
            SizedBox(width: large ? 14 : 10),
          ],
          Flexible(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'FarmSync ',
                    style: TextStyle(
                      fontFamily: 'DM Serif Display',
                      fontSize: size,
                      color: base,
                      letterSpacing: 0.2,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: ShaderMask(
                      shaderCallback: (Rect r) => const LinearGradient(
                        colors: <Color>[Color(0xFF2E9E5B), Color(0xFFFFB300)],
                      ).createShader(r),
                      child: Text(
                        'Hub',
                        style: TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: size,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
