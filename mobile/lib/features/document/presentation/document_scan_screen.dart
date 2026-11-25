import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';

import '../../../core/files/document_pdf.dart';
import '../../../core/files/file_export.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';

/// Photograph a paper document and keep it as a PDF.
///
/// The native ML Kit scanner does the hard part — finding the page edges,
/// straightening the photo and letting the user drag the crop corners — so this
/// screen only collects the result, shows it, and shares the PDF. Pages come
/// back in a plugin-owned cache directory, so anything kept is copied out
/// before the cache is cleared.
class DocumentScanScreen extends StatefulWidget {
  const DocumentScanScreen({super.key});

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  static const _exporter = FileExportService();

  List<File> _pages = const [];
  String? _pdfPath;
  bool _busy = false;

  Future<void> _scan() async {
    setState(() => _busy = true);
    try {
      final result = await CunningDocumentScanner.scanDocuments(
        noOfPages: 10,
        output: ScanOutput.imagesAndPdf,
      );
      if (!mounted || result == null) return; // cancelled
      setState(() {
        _pages = result.images.map(File.new).toList();
        _pdfPath = result.pdf;
      });
    } on CunningDocumentScannerException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission_denied'
          ? 'QRSafe needs the camera to scan a document.'
          : "The scan didn't finish. Try again.";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final path = _pdfPath;
      // The plugin builds the PDF itself on both platforms; building it here is
      // the fallback for a result that came back as images only.
      final bytes = path != null && await File(path).exists()
          ? await File(path).readAsBytes()
          : await buildDocumentPdf(_pages);
      final name = 'qrsafe-document-'
          '${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}'
          '.pdf';
      await _exporter.saveAndShare(bytes, name, mimeType: 'application/pdf');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't build the PDF.")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Scan a document')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: _pages.isEmpty ? _empty(context) : _result(context),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.qrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.document_scanner_rounded, size: 72, color: c.teal),
        const SizedBox(height: 20),
        Text(
          'Point the camera at a page. The frame and the crop are found for '
          'you, and you can drag the corners before you keep it.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.inkMid, fontSize: 14),
        ),
        const SizedBox(height: 28),
        PrimaryButton.solid(
          label: _busy ? 'Opening…' : 'Scan a document',
          color: c.inkDark,
          icon: Icons.camera_alt_rounded,
          onPressed: _busy ? null : _scan,
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final c = context.qrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _pages.length == 1 ? '1 page' : '${_pages.length} pages',
          style: TextStyle(color: c.inkMid, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(_pages[i], height: 260, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton.solid(
          label: _busy ? 'Working…' : 'Save as PDF',
          color: c.inkDark,
          icon: Icons.picture_as_pdf_rounded,
          onPressed: _busy ? null : _savePdf,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _busy ? null : _scan,
          icon: Icon(Icons.refresh_rounded, color: c.inkMid),
          label: Text(
            'Scan again',
            style: TextStyle(color: c.inkMid, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
