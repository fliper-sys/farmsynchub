import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../providers/app_preferences_provider.dart';

/// A reusable certificate visual widget. Keep it self-contained so it can
/// be embedded in a RepaintBoundary for image export.
///
/// The certificate is always drawn at [designWidth] x [designHeight] logical
/// pixels. On small screens, scale it with a FittedBox rather than letting
/// layout squeeze it. It also always uses a fixed light palette so a shared
/// image looks the same no matter which theme the sender uses.
class CertificateView extends StatelessWidget {
  const CertificateView({
    super.key,
    required this.language,
    required this.recipientName,
    required this.lessonTitle,
    required this.date,
    this.issuerName = 'FarmSync',
  });

  static const double designWidth = 1200;
  static const double designHeight = 800;

  final AppLanguage language;
  final String recipientName;
  final String lessonTitle;
  final DateTime date;
  final String issuerName;

  static const List<String> _monthsEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _monthsFr = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const List<String> _monthsHa = <String>[
    'Janairu',
    'Fabrairu',
    'Maris',
    'Afrilu',
    'Mayu',
    'Yuni',
    'Yuli',
    'Agusta',
    'Satumba',
    'Oktoba',
    'Nuwamba',
    'Disamba',
  ];

  String _formatDate() {
    final DateTime local = date.toLocal();
    final int index = local.month - 1;
    final String month = language.tr(
      en: _monthsEn[index],
      ha: _monthsHa[index],
      fr: _monthsFr[index],
    );
    return '${local.day} $month ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: Theme.of(context).colorScheme.primary,
      brightness: Brightness.light,
    );
    final TextTheme t = Theme.of(context).textTheme;
    const Color surface = Colors.white;
    final Color frameStart = scheme.primary;
    final Color frameEnd = scheme.primaryContainer;
    final Color titleColor = scheme.onSurface;
    final Color subtitleColor = scheme.onSurfaceVariant;
    final Color accent = scheme.primary;
    const Color chipBackground = Color(0xFFF2F7EC);
    const Color ringColor = Color(0xFFE3EADB);

    return Container(
      padding: const EdgeInsets.all(24),
      width: designWidth,
      height: designHeight,
      // Square outer frame and no shadow: the exported PNG has clean edges
      // instead of transparent corners and a clipped shadow.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[frameStart, frameEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ringColor, width: 1.2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Faint logo watermark behind the text.
            Opacity(
              opacity: 0.06,
              child: Image.asset(
                AppAssets.appIcon,
                width: 420,
                height: 420,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                children: <Widget>[
                  // The FarmSync logo. (This used to point at a file that does
                  // not exist, so every certificate showed a generic icon.)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: chipBackground,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: ringColor),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          AppAssets.appIcon,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.agriculture_rounded,
                              size: 52,
                              color: accent),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'FarmSyncHub',
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    language.tr(
                        en: 'Certificate of Completion',
                        ha: 'Takardar Shaidar Kammalawa',
                        fr: 'Certificat d’achèvement'),
                    textAlign: TextAlign.center,
                    style: t.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    language.tr(
                        en: 'This certificate is proudly presented to',
                        ha: 'Ana bayar da wannan takardar shaida cikin farin ciki ga',
                        fr: 'Ce certificat est fièrement remis à'),
                    style: t.bodyLarge?.copyWith(color: subtitleColor),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Text(
                      recipientName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Text(
                      language.tr(
                        en: 'For successfully completing the lesson:\n"$lessonTitle"',
                        ha: 'Saboda kammala darasin nan cikin nasara:\n"$lessonTitle"',
                        fr: 'Pour avoir terminé avec succès la leçon :\n« $lessonTitle »',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(
                        height: 1.5,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: chipBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ringColor),
                    ),
                    child: Text(
                      // Describes what the certificate is, without claiming an
                      // external verification that does not exist.
                      language.tr(
                          en: 'FarmSync Learn • Lesson completed in the app',
                          ha: 'FarmSync Koyo • An kammala darasi a manhaja',
                          fr: 'FarmSync Apprentissage • Leçon terminée dans l’application'),
                      style: t.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                            language.tr(
                                en: 'Issued by',
                                ha: 'An Bayar Daga',
                                fr: 'Délivré par'),
                            style:
                                t.labelLarge?.copyWith(color: subtitleColor)),
                        const SizedBox(height: 6),
                        Text(
                          issuerName,
                          style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700, color: titleColor),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                            language.tr(
                                en: 'Date', ha: 'Kwanan Wata', fr: 'Date'),
                            style:
                                t.labelLarge?.copyWith(color: subtitleColor)),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(),
                          style: t.titleMedium?.copyWith(color: titleColor),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
