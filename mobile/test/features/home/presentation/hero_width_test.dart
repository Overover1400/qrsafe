import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/home/presentation/widgets/scan_hero_button.dart';

void main() {
  testWidgets('hero card fills the width it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ScanHeroButton(onTap: () {})],
            ),
          ),
        ),
      ),
    );

    final screen = tester.getSize(find.byType(Scaffold)).width;
    final card = tester.getSize(find.byType(ScanHeroButton)).width;
    // 20px padding each side; without width: double.infinity the card
    // shrink-wrapped its text and sat left of centre.
    expect(card, screen - 40);
  });
}
