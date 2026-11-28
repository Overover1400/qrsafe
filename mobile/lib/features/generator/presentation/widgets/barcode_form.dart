import 'package:flutter/material.dart';

import '../../../../core/barcode/barcode_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/code_payload.dart';

/// The barcode tab: pick a symbology, type the value.
///
/// The symbology rules are strict (EAN-13 is exactly 13 digits with a check
/// digit), so the rule is shown under the picker before anything is typed and
/// the error names the rule rather than just refusing.
class BarcodeForm extends StatefulWidget {
  const BarcodeForm({
    super.key,
    required this.payload,
    required this.onChanged,
  });

  final BarcodePayload payload;
  final ValueChanged<CodePayload> onChanged;

  @override
  State<BarcodeForm> createState() => _BarcodeFormState();
}

class _BarcodeFormState extends State<BarcodeForm> {
  late final TextEditingController _value = TextEditingController(
    text: widget.payload.value,
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _emit({BarcodeSymbology? symbology, String? value}) {
    widget.onChanged(
      BarcodePayload(
        symbology: symbology ?? widget.payload.symbology,
        value: value ?? _value.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    final sym = widget.payload.symbology;
    final error = sym.errorFor(_value.text);
    final suggestion = sym.suggestionFor(_value.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barcode type',
          style: TextStyle(
            color: c.inkMid,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: BarcodeSymbology.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = BarcodeSymbology.values[i];
              final active = s == sym;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  // Switching to a digit-only format keeps whatever is typed:
                  // the error line explains it rather than silently wiping it.
                  _emit(symbology: s);
                },
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: active ? c.tealGradient : null,
                    color: active ? null : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? Colors.transparent
                          : c.tealLight.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: active ? Colors.white : c.inkMid,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sym.hint,
          style: TextStyle(color: c.inkLight, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (suggestion != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _value.text = suggestion;
                _value.selection = TextSelection.collapsed(
                  offset: suggestion.length,
                );
                _emit(value: suggestion);
                setState(() {});
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text('Use $suggestion and let us add the check digit'),
            ),
          ),
        ],
        TextFormField(
          controller: _value,
          keyboardType: sym.digitsOnly
              ? TextInputType.number
              : TextInputType.text,
          // No digitsOnly formatter: it drops Persian digits before they can
          // be rewritten as ASCII, so the field would silently eat what was
          // typed. onChanged converts them instead.
          inputFormatters: null,
          textCapitalization: sym == BarcodeSymbology.code39
              ? TextCapitalization.characters
              : TextCapitalization.none,
          decoration: InputDecoration(
            labelText: 'Value',
            errorText: error,
            errorMaxLines: 3,
          ),
          onChanged: (v) {
            // A Persian keyboard types ۱۲۳. Rewrite them in place rather
            // than refusing the value, so the field shows what will actually
            // be encoded instead of silently disagreeing with it.
            final ascii = normalizeDigits(v);
            if (ascii != v) {
              final offset = _value.selection.baseOffset;
              _value.value = TextEditingValue(
                text: ascii,
                selection: TextSelection.collapsed(
                  offset: offset < 0 ? ascii.length : offset,
                ),
              );
            }
            _emit(value: ascii);
            setState(() {});
          },
        ),
      ],
    );
  }
}
