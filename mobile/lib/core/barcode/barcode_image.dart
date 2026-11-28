import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The 1D barcode symbologies the generator can produce.
///
/// Deliberately short. Each one here is a format a shop, a warehouse or a
/// courier actually reads, and each is one the scanner side also decodes (see
/// `scannerFormats` in the scanner screen) — offering a code we cannot read
/// back ourselves would be a trap.
///
/// [wire] is stored in the saved payload, so these strings must not change.
enum BarcodeSymbology {
  code128('code128', 'Code 128', 'Letters and numbers, any length'),
  ean13('ean13', 'EAN-13', 'Retail products. 12 or 13 digits'),
  ean8('ean8', 'EAN-8', 'Small packages. 7 or 8 digits'),
  upcA('upca', 'UPC-A', 'North American retail. 11 or 12 digits'),
  code39('code39', 'Code 39', 'Capitals, numbers and - . / + % space'),
  itf14('itf14', 'ITF-14', 'Shipping cartons. 13 or 14 digits');

  const BarcodeSymbology(this.wire, this.label, this.hint);

  final String wire;
  final String label;

  /// Shown under the picker so the rules are visible before an error is.
  final String hint;

  static BarcodeSymbology parse(String? s) {
    for (final v in BarcodeSymbology.values) {
      if (v.wire == s) return v;
    }
    return BarcodeSymbology.code128;
  }

  /// Digit-only formats get the number pad.
  bool get digitsOnly =>
      this == ean13 || this == ean8 || this == upcA || this == itf14;

  Barcode get barcode => switch (this) {
    code128 => Barcode.code128(),
    ean13 => Barcode.ean13(),
    ean8 => Barcode.ean8(),
    upcA => Barcode.upcA(),
    code39 => Barcode.code39(),
    itf14 => Barcode.itf14(),
  };

  /// Whether [value] can actually be encoded. EAN and UPC carry a check digit
  /// and a fixed length, so a typo is a hard failure, not a blurry code.
  bool accepts(String value) {
    final v = normalizeDigits(value).trim();
    if (v.isEmpty) return false;
    try {
      return barcode.isValid(v);
    } catch (_) {
      return false;
    }
  }

  /// A value this symbology WOULD accept, built from what was typed, or null
  /// when there is no near miss worth offering.
  ///
  /// EAN, UPC and ITF end in a check digit. Type it wrong and the code is
  /// refused, which is right - a wrong check digit scans as a different
  /// product - but it leaves the person stuck with a dead Save button and no
  /// way forward. Dropping the last digit lets the library compute the
  /// correct one, so the form can offer the fix instead of only complaining.
  /// Never applied silently: the digits printed would not be the digits typed.
  String? suggestionFor(String value) {
    final v = normalizeDigits(value).trim();
    if (v.isEmpty || accepts(v)) return null;
    if (!digitsOnly) return null;
    if (v.length > 1 && accepts(v.substring(0, v.length - 1))) {
      return v.substring(0, v.length - 1);
    }
    return null;
  }

  /// Why [value] was refused, in words the person typing can act on.
  String? errorFor(String value) {
    final v = normalizeDigits(value).trim();
    if (v.isEmpty || accepts(v)) return null;
    return switch (this) {
      // The last digit is a check digit. Leave it off and it is computed;
      // type it wrong and the code would scan as a different product, so it
      // is refused rather than silently corrected.
      ean13 => 'EAN-13 needs 12 or 13 digits, and the 13th must be the '
          'correct check digit.',
      ean8 => 'EAN-8 needs 7 or 8 digits, and the 8th must be the correct '
          'check digit.',
      upcA => 'UPC-A needs 11 or 12 digits, and the 12th must be the correct '
          'check digit.',
      itf14 => 'ITF-14 needs 13 or 14 digits.',
      code39 => 'Code 39 takes capitals, digits and - . / + % and space.',
      code128 => 'Code 128 cannot encode one of these characters.',
    };
  }
}

/// Rewrites Persian (۰-۹) and Arabic-Indic (٠-٩) digits as ASCII 0-9.
///
/// A Persian keyboard types ۱۲۳ where the person means 123, and no barcode
/// symbology can encode those code points - Code 128 is ASCII, EAN and UPC
/// are digits only. Without this the Save button stays grey for every type,
/// with an error about characters that look, on screen, exactly like the
/// digits that would have worked.
String normalizeDigits(String input) {
  const persianZero = 0x06F0;
  const arabicZero = 0x0660;
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= persianZero && rune <= persianZero + 9) {
      out.writeCharCode(0x30 + rune - persianZero);
    } else if (rune >= arabicZero && rune <= arabicZero + 9) {
      out.writeCharCode(0x30 + rune - arabicZero);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Aspect of the drawn barcode (width : height), printed text included.
const double kBarcodeAspect = 2.6;

/// Paints a barcode onto a canvas. One painter serves the live preview and the
/// PNG export, so what she sees on screen is the file she gets.
class BarcodePainter extends CustomPainter {
  const BarcodePainter({
    required this.symbology,
    required this.value,
    required this.color,
    this.drawText = true,
  });

  final BarcodeSymbology symbology;
  final String value;
  final Color color;
  final bool drawText;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final v = normalizeDigits(value).trim();
    if (v.isEmpty || !symbology.accepts(v)) return;

    // A quiet zone left and right: without it many scanners never lock on,
    // exactly as with a QR.
    final margin = size.width * 0.06;
    final w = size.width - margin * 2;
    final h = size.height - margin * 2;
    final fontHeight = drawText ? h * 0.22 : 0.0;

    final paint = Paint()..color = color;
    for (final element in symbology.barcode.make(
      v,
      width: w,
      height: h,
      drawText: drawText,
      fontHeight: fontHeight,
    )) {
      if (element is BarcodeBar) {
        if (!element.black) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            margin + element.left,
            margin + element.top,
            element.width,
            element.height,
          ),
          paint,
        );
      } else if (element is BarcodeText) {
        final tp = TextPainter(
          text: TextSpan(
            text: element.text,
            style: TextStyle(color: color, fontSize: element.height),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: element.width);
        tp.paint(
          canvas,
          Offset(
            margin + element.left + (element.width - tp.width) / 2,
            margin + element.top,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(BarcodePainter old) =>
      old.value != value ||
      old.symbology != symbology ||
      old.color != color ||
      old.drawText != drawText;
}

/// Renders a barcode to PNG bytes off-screen, on an opaque white background.
///
/// White background for the same reason the QR export has one: a transparent
/// PNG shows as black in gallery and print apps, and a dark code on black does
/// not scan.
Future<Uint8List?> renderBarcodePng(
  BarcodeSymbology symbology,
  String value, {
  required Color color,
  double width = 1024,
}) async {
  if (!symbology.accepts(value)) return null;
  final height = width / kBarcodeAspect;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  BarcodePainter(
    symbology: symbology,
    value: value,
    color: color,
  ).paint(canvas, Size(width, height));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.round(), height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data?.buffer.asUint8List();
}

/// Renders a barcode as an SVG document. Vector output is what a print shop
/// wants, and it is the reason this sits next to the PNG.
String? renderBarcodeSvg(
  BarcodeSymbology symbology,
  String value, {
  required Color color,
  double width = 1024,
}) {
  if (!symbology.accepts(value)) return null;
  final height = width / kBarcodeAspect;
  final rgb = color.toARGB32() & 0xFFFFFF;
  try {
    final svg = symbology.barcode.toSvg(
      normalizeDigits(value).trim(),
      width: width,
      height: height,
      color: rgb,
    );
    // The library draws no background; add one so the file matches the PNG.
    final bg = '<rect width="$width" height="$height" fill="#FFFFFF"/>';
    final at = svg.indexOf('>', svg.indexOf('<svg')) + 1;
    return svg.substring(0, at) + bg + svg.substring(at);
  } catch (_) {
    return null;
  }
}

/// One-page A4 PDF with the barcode centred and [label] underneath, built from
/// the same PNG the image export uses.
Future<Uint8List?> renderBarcodePdf(
  BarcodeSymbology symbology,
  String value, {
  required Color color,
  String? label,
}) async {
  final png = await renderBarcodePng(symbology, value, color: color);
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
              width: 420,
              height: 420 / kBarcodeAspect,
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

/// The barcode equivalent of `QrView`: the code on white, or blank while the
/// value is empty or not yet valid.
class BarcodeView extends StatelessWidget {
  const BarcodeView({
    super.key,
    required this.symbology,
    required this.value,
    this.color = const Color(0xFF0F3B3F),
    this.width = 220,
  });

  final BarcodeSymbology symbology;
  final String value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / kBarcodeAspect,
      child: CustomPaint(
        painter: BarcodePainter(
          symbology: symbology,
          value: value,
          color: color,
        ),
      ),
    );
  }
}
