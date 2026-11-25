import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/qr/qr_export_formats.dart';
import 'package:qrsafe_mobile/core/qr/qr_image.dart';

/// Note: PNG and PDF rendering touch the real engine (`Picture.toImage`), so
/// those cases run inside `tester.runAsync` — under the test binding's fake
/// clock the future would never complete.
void main() {
  group('renderQrSvg', () {
    test('returns null for empty data', () {
      expect(renderQrSvg('', color: const Color(0xFF3D2E1F)), isNull);
    });

    test('emits an SVG with a white background and the chosen colour', () {
      final svg = renderQrSvg(
        'https://qrsafe.flemby.com',
        color: const Color(0xFF3D2E1F),
      );
      expect(svg, isNotNull);
      expect(svg, contains('<svg'));
      expect(svg, contains('fill="#FFFFFF"'));
      expect(svg, contains('fill="#3D2E1F"'));
      expect(svg, contains('</svg>'));
    });

    test('leaves a quiet zone on every side', () {
      const quietZone = 4;
      final code = buildQrCode('hello')!;
      final svg = renderQrSvg(
        'hello',
        color: const Color(0xFF000000),
        quietZone: quietZone,
      )!;
      final total = code.moduleCount + quietZone * 2;
      expect(svg, contains('viewBox="0 0 $total $total"'));
      // No module may be drawn inside the margin.
      expect(svg, isNot(contains('d="M0 ')));
    });
  });

  group('renderQrPng', () {
    testWidgets('produces real PNG bytes', (tester) async {
      final bytes = await tester.runAsync(
        () => renderQrPng(
          'https://qrsafe.flemby.com',
          color: const Color(0xFF3D2E1F),
          size: 256,
        ),
      );
      expect(bytes, isNotNull);
      // PNG magic number — proves we got an image back, not an empty buffer.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(bytes.length, greaterThan(100));
    });

    testWidgets('returns null for empty data', (tester) async {
      final bytes = await tester.runAsync(
        () => renderQrPng('', color: const Color(0xFF3D2E1F)),
      );
      expect(bytes, isNull);
    });
  });

  group('renderQrPdf', () {
    testWidgets('produces a PDF document', (tester) async {
      final bytes = await tester.runAsync(
        () => renderQrPdf(
          'https://qrsafe.flemby.com',
          color: const Color(0xFF3D2E1F),
          label: 'My code',
        ),
      );
      expect(bytes, isNotNull);
      // "%PDF" header.
      expect(bytes!.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });
  });
}
