import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/home/presentation/widgets/scan_hero_button.dart';

void main() {
  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ScanHeroButton(onTap: () {})),
      ),
    );
  }

  testWidgets('hero text is present', (tester) async {
    await pump(tester);
    expect(find.text('Tap to scan'), findsOneWidget);
    expect(find.text('Check a QR code before you open it'), findsOneWidget);
  });

  testWidgets('hero column centers its children horizontally', (tester) async {
    await pump(tester);
    // The hero's content Column must center children so the text is not
    // left-offset within the gradient card.
    final column = tester.widget<Column>(
      find.descendant(
        of: find.byType(ScanHeroButton),
        matching: find.byType(Column),
      ),
    );
    expect(column.crossAxisAlignment, CrossAxisAlignment.center);
  });

  testWidgets('hero title text is center-aligned', (tester) async {
    await pump(tester);
    final title = tester.widget<Text>(find.text('Tap to scan'));
    expect(title.textAlign, TextAlign.center);
  });
}
