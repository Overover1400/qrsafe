import 'dart:typed_data';
import 'dart:ui';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import 'qr_image.dart';

/// `#RRGGBB` for [color], the form SVG expects.
String hexColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Renders [data] as an SVG document: one `<path>` of 1x1 squares on a white
/// background, with a [quietZone] margin in modules. Vector output stays sharp
/// at any print size, which is the whole point of offering it next to the PNG.
///
/// Returns null when the data cannot be encoded.
String? renderQrSvg(
  String data, {
  required Color color,
  int quietZone = 4,
}) {
  final qrCode = buildQrCode(data);
  if (qrCode == null) return null;

  final image = QrImage(qrCode);
  final count = image.moduleCount;
  final total = count + quietZone * 2;

  final path = StringBuffer();
  for (var row = 0; row < count; row++) {
    for (var col = 0; col < count; col++) {
      if (!image.isDark(row, col)) continue;
      path.write('M${col + quietZone} ${row + quietZone}h1v1h-1z');
    }
  }

  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $total $total" '
      'width="1024" height="1024" shape-rendering="crispEdges">\n'
      '  <rect width="$total" height="$total" fill="#FFFFFF"/>\n'
      '  <path fill="${hexColor(color)}" d="$path"/>\n'
      '</svg>\n';
}

/// Renders [data] as a one-page A4 PDF with the QR centred and [label]
/// underneath. Built from the same PNG the image export uses, so the printed
/// code is identical to the saved one. Returns null when the data cannot be
/// encoded.
Future<Uint8List?> renderQrPdf(
  String data, {
  required Color color,
  String? label,
}) async {
  final png = await renderQrPng(data, color: color, size: 1024);
  if (png == null) return null;

  final doc = pw.Document();
  final image = pw.MemoryImage(png);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.SizedBox(
              width: 320,
              height: 320,
              child: pw.Image(image),
            ),
            if (label != null && label.trim().isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text(label.trim(), style: const pw.TextStyle(fontSize: 18)),
            ],
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
