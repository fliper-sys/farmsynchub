import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_button.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.badge = 'FarmSync Hub',
    this.onBrandTap,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final String badge;
  final VoidCallback? onBrandTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color inputSurface = isDark ? const Color(0xFF14241A) : const Color(0xFFE4EEE5);
    final ThemeData formTheme = theme.copyWith(
      colorScheme: scheme.copyWith(surface: inputSurface),
    );

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              AppAssets.uiLeafBackground,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? <Color>[
                          Colors.black.withOpacity(0.62),
                          const Color(0xFF051009).withOpacity(0.88),
                          Colors.black.withOpacity(0.96),
                        ]
                      : <Color>[
                          Colors.white.withOpacity(0.18),
                          const Color(0xFFE9F4EA).withOpacity(0.58),
                          Colors.white.withOpacity(0.94),
                        ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
              child: _PhoneAuthPanel(
                    title: title,
                    subtitle: subtitle,
                    badge: badge,
                    onBrandTap: onBrandTap,
                    footer: footer,
                    scheme: scheme,
                    isDark: isDark,
                    formTheme: formTheme,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneAuthPanel extends StatelessWidget {
  const _PhoneAuthPanel({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onBrandTap,
    required this.child,
    required this.footer,
    required this.scheme,
    required this.isDark,
    required this.formTheme,
  });

  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onBrandTap;
  final Widget child;
  final Widget? footer;
  final ColorScheme scheme;
  final bool isDark;
  final ThemeData formTheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1510).withOpacity(0.96) : Colors.white,
        borderRadius: BorderRadius.circular(38),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.42 : 0.18),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
        child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 238,
            child: _LeafHero(
              badge: badge,
              onBrandTap: onBrandTap,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 118,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1510) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 206, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: isDark ? Colors.white : AppColors.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: isDark ? Colors.white70 : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Theme(
                  data: formTheme,
                  child: child,
                ),
                if (footer != null) ...<Widget>[
                  const SizedBox(height: 18),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeafHero extends StatelessWidget {
  const _LeafHero({required this.badge, this.onBrandTap});

  final String badge;
  final VoidCallback? onBrandTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bottomColor = isDark ? const Color(0xFF0B1510) : Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          AppAssets.uiLeafBackground,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withOpacity(0.20),
                const Color(0xFF0D3723).withOpacity(0.62),
                bottomColor,
              ],
              stops: const <double>[0, 0.62, 1],
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 86,
          child: _HeroPhotoTile(
            assetPath: AppAssets.uiGallery02,
            size: 124,
          ),
        ),
        Positioned(
          right: 84,
          top: 170,
          child: _HeroPhotoTile(
            assetPath: AppAssets.uiGallery03,
            size: 70,
          ),
        ),
        Positioned(
          left: 24,
          top: 32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBrandTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(AppAssets.appIcon, width: 20, height: 20),
                  const SizedBox(width: 8),
                  Text(
                    badge,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 26,
          right: 26,
          bottom: 36,
          child: Text(
            'The best app for your farms',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPhotoTile extends StatelessWidget {
  const _HeroPhotoTile({
    required this.assetPath,
    required this.size,
  });

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton.primary(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class AuthSecondaryLinkRow extends StatelessWidget {
  const AuthSecondaryLinkRow({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.route,
  });

  final String prompt;
  final String actionLabel;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: <Widget>[
          Text(prompt),
          InkWell(
            onTap: () => context.go(route),
            child: Text(
              actionLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthInfoBanner extends StatelessWidget {
  const AuthInfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.color = const Color(0xFFFFF3D9),
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? color.withOpacity(0.16) : color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class AuthPageFooter extends StatelessWidget {
  const AuthPageFooter({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
    );
  }
}
