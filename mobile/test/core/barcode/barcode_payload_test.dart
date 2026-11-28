import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/barcode/barcode_image.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';
import 'package:qrsafe_mobile/features/generator/data/multi_link.dart';
import 'package:qrsafe_mobile/features/generator/data/payload_encoder.dart';

void main() {
  group('symbology validation', () {
    test('EAN-13 computes a missing check digit and refuses a wrong one', () {
      const ean = BarcodeSymbology.ean13;
      expect(ean.accepts('4006381333931'), isTrue, reason: 'full 13 digits');
      // Measured behaviour of package:barcode: 12 digits are accepted and the
      // 13th is computed. The hint text says so, so it must stay true.
      expect(ean.accepts('400638133393'), isTrue, reason: '12 digits');
      // A wrong check digit would scan as a different product. Never accepted.
      expect(ean.accepts('4006381333930'), isFalse, reason: 'wrong check digit');
      expect(ean.accepts('40063813339'), isFalse, reason: '11 digits');
      expect(ean.errorFor('4006381333930'), contains('check digit'));
      expect(ean.errorFor(''), isNull, reason: 'empty is not an error yet');
    });

    test('Code 128 takes letters and digits', () {
      expect(BarcodeSymbology.code128.accepts('SEMICOLON-42'), isTrue);
      expect(BarcodeSymbology.code128.accepts(''), isFalse);
    });

    test('a stored symbology survives a round trip', () {
      for (final s in BarcodeSymbology.values) {
        expect(BarcodeSymbology.parse(s.wire), s);
      }
      // An unknown value must not crash an old code on a new build.
      expect(BarcodeSymbology.parse('something-else'), BarcodeSymbology.code128);
      expect(BarcodeSymbology.parse(null), BarcodeSymbology.code128);
    });
  });

  group('Persian and Arabic digits', () {
    // The bug this prevents: on a Persian keyboard every number comes out as
    // U+06F1 and friends, which no symbology can encode, so Save stayed grey
    // for every barcode type while the field looked perfectly correct.
    test('are read as the digits they are', () {
      expect(normalizeDigits('۱۲۳۴۵'), '12345');
      expect(normalizeDigits('١٢٣'), '123');
      expect(normalizeDigits('ABC-123'), 'ABC-123', reason: 'ASCII untouched');
      expect(normalizeDigits('۴۰۰۶۳۸۱۳۳۳۹۳۱'),
          '4006381333931');
    });

    test('make a valid barcode', () {
      expect(BarcodeSymbology.code128.accepts('۱۲۳۴۵'), isTrue);
      expect(
        BarcodeSymbology.ean13
            .accepts('۴۰۰۶۳۸۱۳۳۳۹۳۱'),
        isTrue,
      );
      // And what gets stored and drawn is the ASCII form, so the saved code
      // and the printed one cannot disagree.
      const p = BarcodePayload(
        symbology: BarcodeSymbology.code128,
        value: '۱۲۳۴۵',
      );
      expect(p.isValid, isTrue);
      expect(p.toJson()['value'], '12345');
    });
  });

  group('the near-miss suggestion', () {
    test('offers the typed digits minus the wrong check digit', () {
      // What a dead Save button looked like before: a full-length number
      // whose last digit is wrong is refused, and nothing says what to do.
      const ean = BarcodeSymbology.ean13;
      expect(ean.accepts('4006381333930'), isFalse);
      expect(ean.suggestionFor('4006381333930'), '400638133393');
      expect(ean.accepts(ean.suggestionFor('4006381333930')!), isTrue);
    });

    test('offers nothing when there is nothing to offer', () {
      expect(BarcodeSymbology.ean13.suggestionFor(''), isNull);
      expect(BarcodeSymbology.ean13.suggestionFor('4006381333931'), isNull,
          reason: 'already valid');
      expect(BarcodeSymbology.ean13.suggestionFor('12'), isNull,
          reason: 'far too short to be a near miss');
      // Code 128 has no check digit to drop, so trimming a character would
      // just silently change the content.
      expect(BarcodeSymbology.code128.suggestionFor(''), isNull);
    });
  });

  group('barcode payload', () {
    test('is valid only when the symbology can encode the value', () {
      const bad = BarcodePayload(
        symbology: BarcodeSymbology.ean13,
        value: '123',
      );
      const good = BarcodePayload(
        symbology: BarcodeSymbology.ean13,
        value: '4006381333931',
      );
      expect(bad.isValid, isFalse);
      expect(good.isValid, isTrue);
    });

    test('encodes its value literally', () {
      const p = BarcodePayload(
        symbology: BarcodeSymbology.code128,
        value: '  ABC-123  ',
      );
      expect(PayloadEncoder.encode(p), 'ABC-123');
    });

    test('round-trips through the stored JSON', () {
      const p = BarcodePayload(
        symbology: BarcodeSymbology.upcA,
        value: '036000291452',
      );
      final back = CodePayload.fromJson(CodeType.barcode, p.toJson());
      expect(back, isA<BarcodePayload>());
      expect((back as BarcodePayload).symbology, BarcodeSymbology.upcA);
      expect(back.value, '036000291452');
    });

    test('never becomes a row on a multi-link page', () {
      // A 1D barcode cannot carry a link to the page, so it must be saved on
      // its own rather than quietly folded into a multi-link QR.
      const p = BarcodePayload(
        symbology: BarcodeSymbology.code128,
        value: 'ABC-123',
      );
      expect(buildMultiLinkItems([p]), isEmpty);
      expect(
        buildMultiLinkItems([const UrlPayload(url: 'example.com'), p]).length,
        1,
      );
    });
  });

  group('rendering', () {
    test('SVG is produced for a valid code and refused for an invalid one', () {
      final svg = renderBarcodeSvg(
        BarcodeSymbology.code128,
        'ABC-123',
        color: const Color(0xFF0F3B3F),
      );
      expect(svg, isNotNull);
      expect(svg, contains('<svg'));
      // The white background is what keeps a dark code readable in gallery
      // and print apps, exactly as for the QR export.
      expect(svg, contains('#FFFFFF'));

      expect(
        renderBarcodeSvg(
          BarcodeSymbology.ean13,
          '123',
          color: const Color(0xFF0F3B3F),
        ),
        isNull,
      );
    });
  });
}
