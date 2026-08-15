import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Renders whatever is wrapped in a [RepaintBoundary] at [boundaryKey] into
/// PNG bytes - used to let farmers share a receipt (or any card) as an
/// image, which reads far better than a PDF attachment in a WhatsApp chat.
Future<Uint8List?> captureBoundaryImage(
  GlobalKey boundaryKey, {
  double pixelRatio = 3,
}) async {
  final RenderObject? renderObject =
      boundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    return null;
  }
  final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
