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
    required this.recipientName,
  });

  final CertificateRecord record;
  final String recipientName;

  @override
  ConsumerState<LessonCertificateScreen> createState() =>
      _LessonCertificateScreenState();
}

class _LessonCertificateScreenState
    extends ConsumerState<LessonCertificateScreen> {
  final GlobalKey _certificateKey = GlobalKey();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  bool _isExporting = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(
            en: 'Certificate', ha: 'Takardar shaida', fr: 'Certificat')),
        actions: <Widget>[
          IconButton(
            tooltip: language.tr(
                en: 'Export image',
                ha: 'Fitar da Hoto',
                fr: 'Exporter l\'image'),
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
            RepaintBoundary(
              key: _certificateKey,
              child: CertificateView(
                language: language,
                recipientName: widget.recipientName,
                lessonTitle: widget.record.lessonTitle,
                date: widget.record.completedAt,
              ),
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
                            fr: 'Details du certificat'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(language.tr(
                        en: 'Lesson: ${widget.record.lessonTitle}',
                        ha: 'Darasi: ${widget.record.lessonTitle}',
                        fr: 'Lecon : ${widget.record.lessonTitle}')),
                    const SizedBox(height: 4),
                    Text(language.tr(
                      en: 'Completed: ${app_date.DateUtils.formatDateTime(widget.record.completedAt)}',
                      ha: 'An Kammala: ${app_date.DateUtils.formatDateTime(widget.record.completedAt)}',
                      fr: 'Termine le : ${app_date.DateUtils.formatDateTime(widget.record.completedAt)}',
                    )),
                    const SizedBox(height: 4),
                    Text(language.tr(
                      en: 'This certificate is ready for sharing to WhatsApp, email, or cloud storage.',
                      ha: 'Wannan takardar shaida a shirye take don raba zuwa WhatsApp, imel, ko ajiyar girgije.',
                      fr: 'Ce certificat est pret a etre partage sur WhatsApp, par e-mail ou vers un stockage cloud.',
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportImage() async {
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
      if (!mounted) return;
      final AppLanguage language = ref.read(appLanguageProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(language.tr(
              en: 'Certificate saved to $path',
              ha: 'An adana takardar shaida a $path',
              fr: 'Certificat enregistre dans $path'))));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareImage() async {
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
        text: 'FarmSync certificate for ${widget.record.lessonTitle}',
      );
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
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to capture certificate image.');
    }
    return byteData.buffer.asUint8List();
  }
}
