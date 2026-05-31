import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/scan/data/scan_models.dart';
import 'package:qrsafe_mobile/features/scan/presentation/widgets/scan_result_sheet.dart';

ScanResult _result(Verdict verdict, {List<SafetyReason> reasons = const []}) {
  return ScanResult(
    url: 'https://example.com/some/path',
    verdict: verdict,
    reasons: reasons,
    cached: false,
  );
}

Future<void> _pump(WidgetTester tester, ScanResult result) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: ScanResultView(result: result)),
      ),
    ),
  );
}

void main() {
  testWidgets('safe renders the safe pill and a plain Open link action',
      (tester) async {
    await _pump(tester, _result(Verdict.safe));

    expect(find.text('Verified safe'), findsOneWidget);
    expect(find.text('Open link'), findsOneWidget);
    expect(find.textContaining('example.com'), findsOneWidget);
  });

  testWidgets('caution renders the caution pill and Open anyway with warning',
      (tester) async {
    await _pump(tester, _result(Verdict.caution));

    expect(find.text('Use caution'), findsOneWidget);
    expect(find.text('Open anyway'), findsOneWidget);
    expect(find.text('We recommend not opening this'), findsOneWidget);
  });

  testWidgets('danger blocks with no easy path and a long-press override',
      (tester) async {
    await _pump(tester, _result(Verdict.danger));

    expect(find.text('Blocked — suspicious link'), findsOneWidget);
    expect(find.text("Don't open"), findsOneWidget);
    expect(
      find.text('Open anyway (not recommended) — long-press'),
      findsOneWidget,
    );
    // No friendly "Open link" affordance for danger.
    expect(find.text('Open link'), findsNothing);
  });

  testWidgets('unknown renders the unknown pill and a cautious Open link',
      (tester) async {
    await _pump(tester, _result(Verdict.unknown));

    expect(find.text("Couldn't verify"), findsOneWidget);
    expect(find.text('Open link'), findsOneWidget);
    expect(
      find.text("Couldn't verify — proceed with caution"),
      findsOneWidget,
    );
  });

  testWidgets('reasons are listed as safety checks', (tester) async {
    await _pump(
      tester,
      _result(
        Verdict.caution,
        reasons: const [
          SafetyReason(code: 'url_shortener', message: 'host is a URL shortener'),
        ],
      ),
    );

    expect(find.text('Safety checks'), findsOneWidget);
    expect(find.text('host is a URL shortener'), findsOneWidget);
  });
}
