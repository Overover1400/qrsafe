import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/barcode/barcode_image.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';
import 'package:qrsafe_mobile/features/generator/presentation/widgets/barcode_form.dart';

void main() {
  testWidgets('typing a value emits a payload that can be saved', (t) async {
    CodePayload? last;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BarcodeForm(
            payload: const BarcodePayload(
              symbology: BarcodeSymbology.code128,
              value: '',
            ),
            onChanged: (p) => last = p,
          ),
        ),
      ),
    );

    await t.enterText(find.byType(TextFormField), '12345');
    await t.pump();

    expect(last, isNotNull, reason: 'the form must report what was typed');
    expect(last!.isValid, isTrue);
  });
}
