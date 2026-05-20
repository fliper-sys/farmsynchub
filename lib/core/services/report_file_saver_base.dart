import 'dart:typed_data';

abstract class ReportFileSaver {
  Future<String> savePdf({
    required Uint8List bytes,
    required String fileName,
  });

  Future<String> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });
}
