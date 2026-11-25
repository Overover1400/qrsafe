import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/generator/presentation/download_sheet.dart';

void main() {
  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DownloadSheet(
            data: 'https://qrsafe.flemby.com',
            color: const Color(0xFF3D2E1F),
            fileName: 'qrsafe-test.png',
            label: 'My code',
          ),
        ),
      ),
    );
  }

  testWidgets('offers PNG, SVG and PDF', (tester) async {
    await pump(tester);
    expect(find.text('PNG image'), findsOneWidget);
    expect(find.text('SVG vector'), findsOneWidget);
    expect(find.text('PDF document'), findsOneWidget);
  });

  testWidgets('no format is disabled any more', (tester) async {
    await pump(tester);
    expect(find.text('Coming soon'), findsNothing);
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
      expect(tile.onTap, isNotNull);
    }
  });
}
