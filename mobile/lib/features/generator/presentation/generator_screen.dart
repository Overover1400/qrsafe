import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/generator_controller.dart';
import '../data/code_payload.dart';
import 'download_sheet.dart';
import 'widgets/color_picker_row.dart';
import 'widgets/dynamic_toggle.dart';
import 'widgets/live_qr_preview.dart';
import 'widgets/payload_form.dart';
import 'widgets/type_chip_row.dart';

/// The create flow: pick a type, fill the form, watch the QR update live, then
/// "Save & Download". The preview is debounced (200ms) so we don't re-render the
/// QR on every keystroke.
class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  Timer? _debounce;
  String _previewData = '';
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Recomputes the preview 200ms after the last change.
  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _previewData = ref.read(generatorControllerProvider).encodedContent);
    });
  }

  Future<void> _save() async {
    final controller = ref.read(generatorControllerProvider.notifier);
    setState(() => _saving = true);
    try {
      final code = await controller.save();
      if (!mounted) return;
      final state = ref.read(generatorControllerProvider);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: context.qrColors.cream,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => DownloadSheet(
          data: code.qrContent,
          color: Color(state.color),
          fileName: 'qrsafe-${code.id}.png',
        ),
      );
      if (!mounted) return;
      controller.reset();
      context.go('/codes/${code.id}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    final state = ref.watch(generatorControllerProvider);
    final controller = ref.read(generatorControllerProvider.notifier);
    final canSave = state.isValid && !_saving;

    return Scaffold(
      backgroundColor: c.cream,
      appBar: AppBar(
        title: const Text('New code'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: canSave ? c.coral : c.brownTint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeChipRow(
              selected: state.type,
              onSelected: (t) {
                controller.setType(t);
                _schedulePreview();
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: LiveQrPreview(data: _previewData, color: Color(state.color)),
            ),
            const SizedBox(height: 24),
            PayloadForm(
              payload: state.payload,
              onChanged: (p) {
                controller.updatePayload(p);
                _schedulePreview();
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Label (optional)',
              initialValue: state.label,
              onChanged: controller.setLabel,
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: 'Color'),
            const SizedBox(height: 10),
            ColorPickerRow(
              selected: state.color,
              onSelected: (v) {
                controller.setColor(v);
                _schedulePreview();
              },
            ),
            const SizedBox(height: 20),
            DynamicToggle(
              value: state.isDynamic,
              enabled: state.type.supportsDynamic,
              onChanged: controller.setDynamic,
            ),
            const SizedBox(height: 24),
            PrimaryButton.solid(
              label: _saving ? 'Saving…' : 'Save & Download',
              color: c.brownDark,
              icon: Icons.download_rounded,
              onPressed: canSave ? _save : null,
            ),
            if (!state.isValid) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _reason(state.payload),
                  style: TextStyle(color: c.brownLight, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _reason(CodePayload payload) => switch (payload) {
    UrlPayload _ => 'Enter a URL to continue',
    WifiPayload _ => 'Enter the network name to continue',
    VCardPayload _ => 'Enter a name to continue',
    EmailPayload _ => 'Enter a recipient to continue',
    TextPayload _ => 'Enter some text to continue',
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.qrColors.brownMid,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
