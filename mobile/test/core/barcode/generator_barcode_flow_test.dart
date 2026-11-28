import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/generator/presentation/generator_screen.dart';

void main() {
  testWidgets('tap Barcode, type a value, Save turns on', (t) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GeneratorScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    // The chip row scrolls; Barcode is the last chip.
    final chip = find.text('Barcode');
    await t.scrollUntilVisible(chip, 100, scrollable: find.byType(Scrollable).first);
    await t.tap(chip);
    await t.pumpAndSettle();

    final field = find.byType(TextFormField);
    await t.enterText(field.first, '12345');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();

    expect(find.text('Save & Download'), findsOneWidget);
    final reason = find.textContaining('to continue');
    expect(reason.evaluate().isEmpty, isTrue,
        reason: 'Save must be live once the value can be encoded');
  });
}
