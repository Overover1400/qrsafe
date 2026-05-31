import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/qr_view.dart';
import '../../generator/presentation/download_sheet.dart';
import '../../generator/presentation/widgets/code_type_visuals.dart';
import '../application/code_detail_controller.dart';
import '../application/codes_providers.dart';
import '../data/code_models.dart';
import 'widgets/edit_destination_dialog.dart';

/// Detail view for one code: QR preview, metadata, dynamic destination editing,
/// download, and the all-time scan count. Label edit and delete live in the app
/// bar. The QR uses the default brown foreground (color is a generator-only,
/// non-persisted render choice).
class CodeDetailScreen extends ConsumerWidget {
  const CodeDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    final state = ref.watch(codeDetailControllerProvider(id));
    final code = state.valueOrNull;

    return Scaffold(
      backgroundColor: c.cream,
      appBar: AppBar(
        title: const Text('Code'),
        actions: [
          IconButton(
            tooltip: 'Edit label',
            icon: Icon(Icons.edit_rounded, color: c.brownMid),
            onPressed: code == null ? null : () => _editLabel(context, ref, code),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline_rounded, color: c.coral),
            onPressed: code == null ? null : () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoader(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              err is ApiException ? err.message : 'Could not load this code.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (code) => _Body(id: id, code: code),
      ),
    );
  }

  Future<void> _editLabel(BuildContext context, WidgetRef ref, Code code) async {
    final controller = TextEditingController(text: code.label ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.qrColors.cream,
        title: const Text('Edit label'),
        content: AppTextField(label: 'Label', controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(codeDetailControllerProvider(id).notifier).updateLabel(result);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.qrColors.cream,
        title: const Text('Delete code?'),
        content: const Text('This permanently removes the code and its link.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: context.qrColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(codeDetailControllerProvider(id).notifier).delete();
      if (!context.mounted) return;
      // Use Navigator (not context.pop) so this works under both go_router and
      // a plain Navigator (e.g. widget tests).
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.id, required this.code});
  final String id;
  final Code code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: c.peach.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: QrView(data: code.qrContent, color: c.brownDark, size: 220),
          ),
        ),
        const SizedBox(height: 24),
        _MetaRow(label: 'Label', value: code.displayLabel),
        _MetaRow(label: 'Type', value: codeTypeLabel(code.type)),
        _MetaRow(
          label: 'Content',
          value: code.qrContent,
          collapsed: true,
        ),
        _MetaRow(label: 'Created', value: _formatDate(code.createdAt)),
        if (code.isDynamic && code.dynamicInfo != null) ...[
          const SizedBox(height: 12),
          _DestinationRow(id: id, destination: code.dynamicInfo!.destination),
        ],
        const SizedBox(height: 24),
        PrimaryButton.solid(
          label: 'Download',
          color: c.brownDark,
          icon: Icons.download_rounded,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: c.cream,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            builder: (_) => DownloadSheet(
              data: code.qrContent,
              color: c.brownDark,
              fileName: 'qrsafe-${code.id}.png',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: _ScanCount(id: id)),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.collapsed = false,
  });
  final String label;
  final String value;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.brownLight, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: collapsed ? 2 : null,
            overflow: collapsed ? TextOverflow.ellipsis : null,
            style: TextStyle(color: c.brownDark, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DestinationRow extends ConsumerWidget {
  const _DestinationRow({required this.id, required this.destination});
  final String id;
  final String destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.safeBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination', style: TextStyle(color: c.brownLight, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.brownDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _change(context, ref),
            child: Text('Change', style: TextStyle(color: c.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final next = await EditDestinationDialog.show(context, destination);
    if (next == null) return;
    try {
      await ref
          .read(codeDetailControllerProvider(id).notifier)
          .updateDestination(next);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

/// Subtle scan-count line, sourced from the per-code analytics endpoint. Shows
/// nothing while loading or if analytics are unavailable.
class _ScanCount extends ConsumerWidget {
  const _ScanCount({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(codeAnalyticsProvider(id));
    final c = context.qrColors;
    return analytics.maybeWhen(
      data: (a) => Text(
        '${a.totalScans} scan${a.totalScans == 1 ? '' : 's'} · ${a.uniqueVisitors} unique',
        style: TextStyle(color: c.brownLight, fontSize: 13),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
