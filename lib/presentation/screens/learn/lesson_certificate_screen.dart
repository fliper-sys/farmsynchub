import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/learning_provider.dart';
import 'certificate_view.dart';
import '../../common/widgets/app_card.dart';

class LessonCertificateScreen extends ConsumerStatefulWidget {
  const LessonCertificateScreen({
    super.key,
    required this.record,
    this.recipientName,
  });

  final CertificateRecord record;

  /// Optional override. When null, the learner name saved in the app is used.
  final String? recipientName;

  @override
  ConsumerState<LessonCertificateScreen> createState() =>
      _LessonCertificateScreenState();
}

class _LessonCertificateScreenState
    extends ConsumerState<LessonCertificateScreen> {
  static const String _legacyPlaceholderName = 'FarmSync learner';

  final GlobalKey _certificateKey = GlobalKey();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  bool _isExporting = false;
  bool _isSharing = false;

  bool _hasCustomName(LearningState learning) {
    final String? override = widget.recipientName?.trim();
    if (override != null &&
        override.isNotEmpty &&
        override != _legacyPlaceholderName) {
      return true;
    }
    return learning.learnerName.isNotEmpty;
  }

  String _recipientName(LearningState learning, AppLanguage language) {
    final String? override = widget.recipientName?.trim();
    if (override != null &&
        override.isNotEmpty &&
        override != _legacyPlaceholderName) {
      return override;
    }
    if (learning.learnerName.isNotEmpty) {
      return learning.learnerName;
    }
    return language.tr(
      en: 'FarmSync learner',
      ha: 'Mai koyo a FarmSync',
      fr: 'Apprenant FarmSync',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final LearningState learning = ref.watch(learningProvider);
    final bool hasName = _hasCustomName(learning);

    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(
            en: 'Certificate', ha: 'Takardar shaida', fr: 'Certificat')),
        actions: <Widget>[
          IconButton(
            tooltip: language.tr(
                en: 'Edit name', ha: 'Gyara suna', fr: 'Modifier le nom'),
            onPressed: _editName,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: language.tr(
                en: 'Export image',
                ha: 'Fitar da Hoto',
                fr: 'Exporter l’image'),
            onPressed: _isExporting ? null : _exportImage,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: language.tr(
                en: 'Share certificate',
                ha: 'Raba Takardar Shaida',
                fr: 'Partager le certificat'),
            onPressed: _isSharing ? null : _shareImage,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            // The certificate is laid out at its fixed design size and scaled
            // down to fit the screen. The RepaintBoundary sits inside the
            // FittedBox, so the exported image is always the full-size,
            // landscape certificate regardless of screen width.
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double scale = math.min(
                  1.0,
                  constraints.maxWidth / CertificateView.designWidth,
                );
                return SizedBox(
                  width: CertificateView.designWidth * scale,
                  height: CertificateView.designHeight * scale,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: _certificateKey,
                      child: SizedBox(
                        width: CertificateView.designWidth,
                        height: CertificateView.designHeight,
                        child: CertificateView(
                          language: language,
                          recipientName: _recipientName(learning, language),
                          lessonTitle: widget.record.lessonTitle,
                          date: widget.record.completedAt,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                        language.tr(
                            en: 'Certificate details',
                            ha: 'Bayanin Takardar Shaida',
                            fr: 'Détails du certificat'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(language.tr(
                        en: 'Lesson: ${widget.record.lessonTitle}',
                        ha: 'Darasi: ${widget.record.lessonTitle}',
                        fr: 'Leçon : ${widget.record.lessonTitle}')),
                    const SizedBox(height: 4),
                    Text(language.tr(
                      en: 'Completed: ${app_date.DateUtils.formatDateTime(widget.record.completedAt)}',
                      ha: 'An Kammala: ${app_date.DateUtils.formatDateTime(widget.record.completedAt)}',
                      fr: 'Terminé le : ${app_date.DateUtils.formatDateTime(widget.record.completedAt)}',
                    )),
                    const SizedBox(height: 4),
                    Text(language.tr(
                      en: 'This certificate is ready for sharing to WhatsApp, email, or cloud storage.',
                      ha: 'Wannan takardar shaida a shirye take don raba zuwa WhatsApp, imel, ko ajiyar girgije.',
                      fr: 'Ce certificat est prêt à être partagé sur WhatsApp, par e-mail ou vers un stockage cloud.',
                    )),
                    if (!hasName) ...<Widget>[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _editName,
                        icon: const Icon(Icons.person_outline_rounded),
                        label: Text(language.tr(
                            en: 'Add your name to the certificate',
                            ha: 'Saka sunanka a takardar shaida',
                            fr: 'Ajouter votre nom au certificat')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _LearnerNameDialog(initialName: ref.read(learningProvider).learnerName),
    );
    if (name == null || !mounted) return;
    await ref.read(learningProvider.notifier).setLearnerName(name);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportImage() async {
    if (_isExporting) return;
    final AppLanguage language = ref.read(appLanguageProvider);
    setState(() => _isExporting = true);
    try {
      final Uint8List bytes = await _captureBytes();
      final String filename =
          'farm_sync_certificate_${widget.record.lessonId}.png';
      final String path = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: filename,
        mimeType: 'image/png',
      );
      _showMessage(language.tr(
          en: 'Certificate saved to $path',
          ha: 'An adana takardar shaida a $path',
          fr: 'Certificat enregistré dans $path'));
    } catch (error) {
      debugPrint('Certificate export failed: $error');
      _showMessage(language.tr(
          en: 'Could not save the certificate. Please try again.',
          ha: 'Ba a iya adana takardar shaida ba. Sake gwadawa.',
          fr: 'Impossible d’enregistrer le certificat. Veuillez réessayer.'));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;
    final AppLanguage language = ref.read(appLanguageProvider);
    setState(() => _isSharing = true);
    try {
      final Uint8List bytes = await _captureBytes();
      final String filename =
          'farm_sync_certificate_${widget.record.lessonId}.png';
      final String path = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: filename,
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        <XFile>[XFile(path, name: filename)],
        text: language.tr(
          en: 'FarmSync certificate for ${widget.record.lessonTitle}',
          ha: 'Takardar shaidar FarmSync ta ${widget.record.lessonTitle}',
          fr: 'Certificat FarmSync pour ${widget.record.lessonTitle}',
        ),
      );
    } catch (error) {
      debugPrint('Certificate share failed: $error');
      _showMessage(language.tr(
          en: 'Could not share the certificate. Please try again.',
          ha: 'Ba a iya raba takardar shaida ba. Sake gwadawa.',
          fr: 'Impossible de partager le certificat. Veuillez réessayer.'));
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<Uint8List> _captureBytes() async {
    final RenderRepaintBoundary? boundary = _certificateKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Certificate preview is not ready.');
    }
    // 2x of the 1200x800 design size (2400x1600) is sharp enough for sharing
    // and much lighter on memory than 3x for low-end phones.
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to capture certificate image.');
    }
    return byteData.buffer.asUint8List();
  }
}

class _LearnerNameDialog extends ConsumerStatefulWidget {
  const _LearnerNameDialog({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_LearnerNameDialog> createState() => _LearnerNameDialogState();
}

class _LearnerNameDialogState extends ConsumerState<_LearnerNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    return AlertDialog(
      title: Text(language.tr(
          en: 'Name on certificate',
          ha: 'Suna a takardar shaida',
          fr: 'Nom sur le certificat')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: language.tr(
              en: 'Your full name',
              ha: 'Cikakken sunanka',
              fr: 'Votre nom complet'),
        ),
        onSubmitted: (String value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
              language.tr(en: 'Cancel', ha: 'Soke', fr: 'Annuler')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(language.tr(en: 'Save', ha: 'Adana', fr: 'Enregistrer')),
        ),
      ],
    );
  }
}
