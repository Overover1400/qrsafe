import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/codes/data/code_models.dart';
import 'package:qrsafe_mobile/features/codes/presentation/widgets/code_list_tile.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';
import 'package:qrsafe_mobile/features/generator/presentation/widgets/code_type_visuals.dart';

Code _code(CodeType type, {bool isDynamic = false, String? label}) => Code(
  id: 'id-${type.wire}',
  type: type,
  payload: const {},
  label: label,
  isDynamic: isDynamic,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  dynamicInfo: isDynamic
      ? const DynamicInfo(
          slug: 's',
          destination: 'https://e.com',
          redirectUrl: 'https://api.qrsafe.flemby.com/r/s',
        )
      : null,
);

Future<void> _pump(WidgetTester tester, Code code) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: CodeListTile(code: code, onTap: () {})),
    ),
  );
}

void main() {
  for (final type in CodeType.values) {
    testWidgets('renders the ${type.wire} type icon + label', (tester) async {
      await _pump(tester, _code(type, label: 'My ${type.wire}'));
      expect(find.byIcon(codeTypeIcon(type)), findsOneWidget);
      expect(find.text('My ${type.wire}'), findsOneWidget);
      expect(find.text(codeTypeLabel(type)), findsOneWidget);
    });
  }

  testWidgets('shows the Dynamic badge only for dynamic codes', (tester) async {
    await _pump(tester, _code(CodeType.url, isDynamic: true));
    expect(find.text('Dynamic'), findsOneWidget);
  });

  testWidgets('no Dynamic badge for static codes', (tester) async {
    await _pump(tester, _code(CodeType.url));
    expect(find.text('Dynamic'), findsNothing);
  });

  testWidgets('falls back to the type name when unlabeled', (tester) async {
    await _pump(tester, _code(CodeType.wifi));
    // displayLabel falls back to the wire name 'wifi'.
    expect(find.text('wifi'), findsOneWidget);
  });
}
