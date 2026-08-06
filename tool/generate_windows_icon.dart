// Regenerates windows/runner/resources/app_icon.ico from assets/appicon.png
// as a real multi-resolution Windows ICO. The file previously checked in
// there was a raw PNG saved with a .ico extension, which the Windows RC
// compiler rejects ("resource file ... is not in 3.00 format").
//
// Run with: dart run tool/generate_windows_icon.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

void main() {
  final File sourceFile = File('assets/appicon.png');
  final Uint8List bytes = sourceFile.readAsBytesSync();
  final img.Image? source = img.decodePng(bytes);
  if (source == null) {
    stderr.writeln('Could not decode assets/appicon.png');
    exit(1);
  }

  const List<int> sizes = <int>[16, 24, 32, 48, 64, 128, 256];
  final img.Image container = img.Image(width: 1, height: 1);
  container.frames.clear();
  for (final int size in sizes) {
    container.frames.add(img.copyResize(
      source,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    ));
  }

  final List<int> icoBytes = img.encodeIco(container);

  final File outFile = File('windows/runner/resources/app_icon.ico');
  outFile.writeAsBytesSync(icoBytes);
  stdout.writeln(
      'Wrote ${outFile.path} (${icoBytes.length} bytes, ${sizes.length} sizes: $sizes)');
}
