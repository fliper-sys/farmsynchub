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
    final String base64Data = base64Encode(bytes);
    final html.AnchorElement anchor = html.AnchorElement(
      href: 'data:application/pdf;base64,$base64Data',
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
