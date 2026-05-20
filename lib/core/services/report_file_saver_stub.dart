import 'dart:typed_data';

import 'report_file_saver_base.dart';

class _UnsupportedReportFileSaver implements ReportFileSaver {
  @override
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    throw UnsupportedError('PDF export is not supported on this platform.');
  }

  @override
  Future<String> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    throw UnsupportedError('File export is not supported on this platform.');
  }
}

ReportFileSaver createReportFileSaverImpl() => _UnsupportedReportFileSaver();
