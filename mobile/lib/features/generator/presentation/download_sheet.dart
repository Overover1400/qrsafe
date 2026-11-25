import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/qr/qr_export_formats.dart';
import '../../../core/qr/qr_image.dart';
import '../../../core/theme/app_theme.dart';
import '../data/qr_export_service.dart';

/// The file formats the download sheet can produce.
enum QrExportFormat { png, svg, pdf }

/// Bottom sheet offering download/share of the rendered QR in PNG, SVG or PDF.
///
/// Every option follows the same path: build the bytes, close the sheet, write
/// the file, then open the share sheet. The sheet is closed *before* any
/// message is shown, because a SnackBar raised while the sheet is open is drawn
/// behind it and the tap looks like it did nothing.
class DownloadSheet extends StatelessWidget {
  const DownloadSheet({
    super.key,
    required this.data,
    required this.color,
    required this.fileName,
    this.label,
    this.exporter = const QrExportService(),
  });

  final String data;
  final Color color;
  final String fileName;

  /// Printed under the QR in the PDF export. Optional.
  final String? label;

  final QrExportService exporter;

  /// Base name without an extension, so each format can add its own.
  String get _baseName =>
      fileName.replaceAll(RegExp(r'\.(png|svg|pdf)$', caseSensitive: false), '');

  Future<(Uint8List?, String, String)> _build(QrExportFormat format) async {
    switch (format) {
      case QrExportFormat.png:
        return (
          await renderQrPng(data, color: color),
          '$_baseName.png',
          'image/png',
        );
      case QrExportFormat.svg:
        final svg = renderQrSvg(data, color: color);
        return (
          svg == null ? null : Uint8List.fromList(utf8.encode(svg)),
          '$_baseName.svg',
          'image/svg+xml',
        );
      case QrExportFormat.pdf:
        return (
          await renderQrPdf(data, color: color, label: label),
          '$_baseName.pdf',
          'application/pdf',
        );
    }
  }

  Future<void> _export(BuildContext context, QrExportFormat format) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final (bytes, name, mimeType) = await _build(format);
    if (navigator.canPop()) navigator.pop();

    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("This code can't be exported.")),
      );
      return;
    }
    try {
      await exporter.saveAndShare(bytes, name, mimeType: mimeType);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the file.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Download',
              style: TextStyle(
                color: c.brownDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _Option(
              icon: Icons.image_rounded,
              title: 'PNG image',
              subtitle: 'High-resolution, ready to print',
              onTap: () => _export(context, QrExportFormat.png),
            ),
            _Option(
              icon: Icons.code_rounded,
              title: 'SVG vector',
              subtitle: 'Stays sharp at any size',
              onTap: () => _export(context, QrExportFormat.svg),
            ),
            _Option(
              icon: Icons.picture_as_pdf_rounded,
              title: 'PDF document',
              subtitle: 'One A4 page, ready to print',
              onTap: () => _export(context, QrExportFormat.pdf),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: c.coral),
        title: Text(
          title,
          style: TextStyle(color: c.brownDark, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: c.brownLight)),
        onTap: onTap,
      ),
    );
  }
}
