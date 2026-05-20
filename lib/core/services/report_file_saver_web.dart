import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'report_file_saver_base.dart';

class _WebReportFileSaver implements ReportFileSaver {
  @override
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return saveBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  @override
  Future<String> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final String base64Data = base64Encode(bytes);
    final html.AnchorElement anchor = html.AnchorElement(
      href: 'data:$mimeType;base64,$base64Data',
    )
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return fileName;
  }
}

ReportFileSaver createReportFileSaverImpl() => _WebReportFileSaver();
