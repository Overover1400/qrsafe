import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/qr/qr_image.dart';
import '../data/qr_export_service.dart';

/// Bottom sheet offering download/share of the rendered QR. PNG works in v1;
/// SVG and PDF are shown disabled ("Coming soon"). Renders the PNG bytes on
/// demand from [data]/[color] via [renderQrPng].
class DownloadSheet extends StatelessWidget {
  const DownloadSheet({
    super.key,
    required this.data,
    required this.color,
    required this.fileName,
    this.exporter = const QrExportService(),
  });

  final String data;
  final Color color;
  final String fileName;
  final QrExportService exporter;

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final bytes = await renderQrPng(data, color: color);
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Nothing to export yet.")),
      );
      return;
    }
    try {
      // Save a copy to app storage, then open the share sheet so the user can
      // route the PNG to Files / Photos / another app. App-private storage
      // isn't visible on its own, so sharing is how the image leaves the app.
      await exporter.saveToDownloads(bytes, fileName);
      if (navigator.canPop()) navigator.pop(); // dismiss the sheet first
      await exporter.share(bytes, fileName);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the image.")),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await renderQrPng(data, color: color);
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Nothing to export yet.")),
      );
      return;
    }
    await exporter.share(bytes, fileName);
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
              onTap: () => _download(context),
            ),
            _Option(
              icon: Icons.share_rounded,
              title: 'Share',
              subtitle: 'Send to another app',
              onTap: () => _share(context),
            ),
            const _Option(
              icon: Icons.code_rounded,
              title: 'SVG vector',
              subtitle: 'Coming soon',
              onTap: null,
            ),
            const _Option(
              icon: Icons.picture_as_pdf_rounded,
              title: 'PDF document',
              subtitle: 'Coming soon',
              onTap: null,
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
        title: Text(title, style: TextStyle(color: c.brownDark, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: c.brownLight)),
        onTap: onTap,
      ),
    );
  }
}
