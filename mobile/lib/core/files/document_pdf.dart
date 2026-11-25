import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a PDF from scanned document pages: one A4 page per image, scaled to
/// fit with a small margin so nothing is cropped at the edge.
///
/// The scanner plugin already straightens and crops each photo; this only has
/// to put the pages in one file worth sending.
Future<Uint8List> buildDocumentPdf(List<File> pages) async {
  final doc = pw.Document();

  for (final page in pages) {
    final image = pw.MemoryImage(await page.readAsBytes());
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  return doc.save();
}
