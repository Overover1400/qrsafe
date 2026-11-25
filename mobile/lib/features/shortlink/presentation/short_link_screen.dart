import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/qr_view.dart';
import '../../codes/application/codes_list_controller.dart';
import '../../codes/application/codes_providers.dart';
import '../../codes/data/code_models.dart';
import '../../generator/data/code_payload.dart';
import '../../generator/presentation/download_sheet.dart';

/// Turns a long URL into a short qrsafe link.
///
/// There is no new backend concept here: a short link *is* a dynamic URL code,
/// so it gets the same `/r/{slug}` address, the same scan counts, and the
/// destination can still be changed later from the code's detail screen.
class ShortLinkScreen extends ConsumerStatefulWidget {
  const ShortLinkScreen({super.key});

  @override
  ConsumerState<ShortLinkScreen> createState() => _ShortLinkScreenState();
}

class _ShortLinkScreenState extends ConsumerState<ShortLinkScreen> {
  String _input = '';
  bool _working = false;
  Code? _created;

  bool get _canSubmit => _input.trim().isNotEmpty && !_working;

  Future<void> _shorten() async {
    final payload = UrlPayload(url: _input);
    setState(() => _working = true);
    try {
      final code = await ref.read(codesApiProvider).create(
        type: CodeType.url,
        payload: payload.toJson(),
        isDynamic: true,
      );
      ref.read(codesListControllerProvider.notifier).optimisticallyAddCode(code);
      if (!mounted) return;
      setState(() => _created = code);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Short link copied.')));
  }

  void _startOver() => setState(() {
    _created = null;
    _input = '';
  });

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    final created = _created;

    return Scaffold(
      backgroundColor: c.cream,
      appBar: AppBar(title: const Text('Short link')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: created == null
            ? _form(context)
            : _result(context, created),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.qrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste a long link and get a short one you can share or print.',
          style: TextStyle(color: c.brownMid, fontSize: 14),
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Long link',
          initialValue: _input,
          keyboardType: TextInputType.url,
          onChanged: (v) => setState(() => _input = v),
        ),
        const SizedBox(height: 24),
        PrimaryButton.solid(
          label: _working ? 'Working…' : 'Make short link',
          color: c.brownDark,
          icon: Icons.link_rounded,
          onPressed: _canSubmit ? _shorten : null,
        ),
      ],
    );
  }

  Widget _result(BuildContext context, Code code) {
    final c = context.qrColors;
    final shortUrl = code.dynamicInfo?.redirectUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: QrView(data: code.qrContent, color: c.brownDark)),
        const SizedBox(height: 24),
        Text(
          'Your short link',
          style: TextStyle(color: c.brownMid, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.peachLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  shortUrl,
                  style: TextStyle(
                    color: c.brownDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: Icon(Icons.copy_rounded, color: c.coral),
                onPressed: shortUrl.isEmpty ? null : () => _copy(shortUrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton.solid(
          label: 'Download the QR',
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
              label: code.label,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _startOver,
          icon: Icon(Icons.refresh_rounded, color: c.brownMid),
          label: Text(
            'Shorten another link',
            style: TextStyle(color: c.brownMid, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
