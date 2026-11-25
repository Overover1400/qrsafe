import 'dart:typed_data';
import 'dart:ui';

import 'package:qr_flutter/qr_flutter.dart';

/// Error-correction level used everywhere a QR is drawn (preview, PNG, SVG,
/// PDF) so the preview and the exported file are the same code. Level M keeps
/// ~15% redundancy, which survives printing and poor lighting far better than
/// the library default (L).
const int kQrErrorCorrection = QrErrorCorrectLevel.M;

/// White margin on each side, as a fraction of the image edge. The QR spec asks
/// for a four-module "quiet zone"; without it many scanners refuse to lock on.
const double kQuietZoneRatio = 0.08;

/// Builds the validated QR matrix for [data], or null when the data is empty,
/// too long, or otherwise unencodable.
QrCode? buildQrCode(String data) {
  if (data.isEmpty) return null;
  final result = QrValidator.validate(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: kQrErrorCorrection,
  );
  if (result.status != QrValidationStatus.valid) return null;
  return result.qrCode;
}

/// Renders [data] to PNG bytes off-screen (no widget tree needed), at [size]
/// pixels per edge, in foreground [color] on an opaque white background with a
/// quiet zone. Returns null when the data cannot be encoded.
///
/// The background matters: [QrPainter.toImageData] leaves it transparent, and
/// gallery apps and print shops show transparency as black — a dark QR on black
/// cannot be scanned. Painting onto our own canvas is what makes the exported
/// file readable.
Future<Uint8List?> renderQrPng(
  String data, {
  required Color color,
  double size = 1024,
}) async {
  final qrCode = buildQrCode(data);
  if (qrCode == null) return null;

  final painter = QrPainter.withQr(
    qr: qrCode,
    gapless: true,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
    dataModuleStyle: QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: color,
    ),
  );

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  final margin = size * kQuietZoneRatio;
  final inner = size - margin * 2;
  canvas.save();
  canvas.translate(margin, margin);
  painter.paint(canvas, Size(inner, inner));
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.round(), size.round());
  final data_ = await image.toByteData(format: ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data_?.buffer.asUint8List();
}
