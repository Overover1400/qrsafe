import 'dart:typed_data';
import 'dart:ui';

import 'package:qr_flutter/qr_flutter.dart';

/// Renders [data] to PNG bytes off-screen (no widget tree needed), at [size]
/// pixels per edge in foreground [color] on white. Used by the download/share
/// flow. Returns null for empty data.
Future<Uint8List?> renderQrPng(
  String data, {
  required Color color,
  double size = 1024,
}) async {
  if (data.isEmpty) return null;
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
    dataModuleStyle: QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: color,
    ),
  );
  final image = await painter.toImageData(size, format: ImageByteFormat.png);
  return image?.buffer.asUint8List();
}
