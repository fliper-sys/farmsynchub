import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ReportShareService {
  const ReportShareService();

  Future<void> sharePdf({
    required String filePath,
    required String fileName,
    required String message,
  }) =>
      _shareFile(filePath: filePath, fileName: fileName, message: message);

  /// Shares a receipt/card rendered to a PNG file - the format most apps
  /// (WhatsApp included) preview inline in a chat, unlike a PDF.
  Future<void> shareImage({
    required String filePath,
    required String fileName,
    required String message,
  }) =>
      _shareFile(filePath: filePath, fileName: fileName, message: message);

  /// Shares any saved file (attached farm documents, exports, etc.)
  /// regardless of its type.
  Future<void> shareFile({
    required String filePath,
    required String fileName,
    required String message,
  }) =>
      _shareFile(filePath: filePath, fileName: fileName, message: message);

  Future<void> _shareFile({
    required String filePath,
    required String fileName,
    required String message,
  }) async {
    if (kIsWeb) {
      await Share.share(message);
      return;
    }

    await Share.shareXFiles(
      <XFile>[XFile(filePath, name: fileName)],
      text: message,
    );
  }
}
