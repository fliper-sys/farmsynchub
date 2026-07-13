import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ReportShareService {
  const ReportShareService();

  Future<void> sharePdf({
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
