import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'report_file_saver_base.dart';

class _IoReportFileSaver implements ReportFileSaver {
  @override
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = path.join(directory.path, fileName);
    final File file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }
}

ReportFileSaver createReportFileSaverImpl() => _IoReportFileSaver();
