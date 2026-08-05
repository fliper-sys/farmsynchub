import 'package:flutter/material.dart';

import '../../../providers/app_preferences_provider.dart';

/// A reusable certificate visual widget. Keep it self-contained so it can
/// be embedded in a RepaintBoundary for image export.
class CertificateView extends StatelessWidget {
  const CertificateView({
    super.key,
    required this.language,
    required this.recipientName,
    required this.lessonTitle,
    required this.date,
    this.issuerName = 'FarmSync',
  });

  final AppLanguage language;
  final String recipientName;
  final String lessonTitle;
  final DateTime date;
  final String issuerName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? const Color(0xFF10261C) : Colors.white;
    final Color frameStart =
        isDark ? const Color(0xFF143E2C) : theme.colorScheme.primary;
    final Color frameEnd =
        isDark ? const Color(0xFF1E6A4A) : theme.colorScheme.primaryContainer;
    final Color titleColor =
        isDark ? const Color(0xFFF2F7EC) : theme.colorScheme.onSurface;
    final Color subtitleColor =
        isDark ? const Color(0xFFD4E6DA) : theme.colorScheme.onSurfaceVariant;
    final Color accent =
        isDark ? const Color(0xFF7FC8A1) : theme.colorScheme.primary;
    final Color chipBackground =
        isDark ? const Color(0xFF183728) : const Color(0xFFF2F7EC);
    final Color ringColor =
        isDark ? const Color(0xFF315E48) : const Color(0xFFE3EADB);
    final TextTheme t = theme.textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      width: 1200,
      height: 800,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [frameStart, frameEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            color: isDark ? Colors.black54 : Colors.black26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ringColor, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: chipBackground,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: ringColor),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Image.asset('assets/app/appicon.png',
                        fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    language.tr(
                        en: 'Certificate of Completion',
                        ha: 'Takardar Shaidar Kammalawa',
                        fr: 'Certificat d\'achevement'),
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
                        fr: 'Ce certificat est fierement remis a'),
                    style: t.bodyLarge?.copyWith(color: subtitleColor),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    recipientName,
                    textAlign: TextAlign.center,
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Text(
                      language.tr(
                        en: 'For successfully completing the lesson:\n"$lessonTitle"',
                        ha: 'Saboda kammala darasin nan cikin nasara:\n"$lessonTitle"',
                        fr: 'Pour avoir termine avec succes la lecon :\n« $lessonTitle »',
                      ),
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(
                        height: 1.5,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: chipBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ringColor),
                    ),
                    child: Text(
                      language.tr(
                          en: 'FarmSync Learn • Verified by progress tracking',
                          ha: 'FarmSync Koyo • An Tabbatar da Ci Gaba',
                          fr: 'FarmSync Apprentissage • Verifie par le suivi de progression'),
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
                                fr: 'Delivre par'),
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
                          date.toLocal().toIso8601String().split('T').first,
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
      ),
    );
  }
}
