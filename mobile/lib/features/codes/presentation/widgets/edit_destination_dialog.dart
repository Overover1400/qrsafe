import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';

/// Bottom sheet for changing a dynamic code's destination URL. Returns the new
/// destination via the sheet result (null if cancelled).
class EditDestinationDialog extends StatefulWidget {
  const EditDestinationDialog({super.key, required this.current});

  final String current;

  /// Shows the sheet and resolves to the new destination, or null if dismissed.
  static Future<String?> show(BuildContext context, String current) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.qrColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => EditDestinationDialog(current: current),
    );
  }

  @override
  State<EditDestinationDialog> createState() => _EditDestinationDialogState();
}

class _EditDestinationDialogState extends State<EditDestinationDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Change destination',
            style: TextStyle(
              color: c.brownDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The QR stays the same — only where it points changes.',
            style: TextStyle(color: c.brownLight, fontSize: 13),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Destination URL',
            controller: _controller,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          PrimaryButton.solid(
            label: 'Save destination',
            color: c.brownDark,
            onPressed: () {
              final value = _controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
          ),
        ],
      ),
    );
  }
}
