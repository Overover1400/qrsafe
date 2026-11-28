import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/features/scan/application/scan_controller.dart';
import 'package:qrsafe_mobile/features/scan/data/scan_models.dart';

void main() {
  group('looksLikeWebLink', () {
    test('accepts real web links', () {
      expect(looksLikeWebLink('https://semicolon.live'), isTrue);
      expect(looksLikeWebLink('http://example.com/a?b=c'), isTrue);
      expect(looksLikeWebLink('example.com'), isTrue);
      expect(looksLikeWebLink('  app.qrsafe.flemby.com/r/abc  '), isTrue);
    });

    test('rejects a product barcode', () {
      // The reason this function exists: the backend calls a value with no
      // scheme malicious, which would show a red danger screen for every
      // EAN-13 and UPC on a shelf.
      expect(looksLikeWebLink('4006381333931'), isFalse);
      expect(looksLikeWebLink('036000291452'), isFalse);
    });

    test('rejects other non-link contents', () {
      expect(looksLikeWebLink('Table 14, back room'), isFalse);
      expect(looksLikeWebLink('+1 604 555 0199'), isFalse);
      expect(looksLikeWebLink('ABC-123'), isFalse);
      expect(looksLikeWebLink(''), isFalse);
      expect(looksLikeWebLink('mailto:a@b.com'), isFalse);
      expect(looksLikeWebLink('WIFI:S:home;T:WPA;P:x;;'), isFalse);
    });
  });

  test('a plain result is not a link and carries no verdict detail', () {
    final r = ScanResult.plain('4006381333931');
    expect(r.isLink, isFalse);
    expect(r.url, '4006381333931');
    expect(r.reasons, isEmpty);
    expect(r.verdict, Verdict.unknown);
  });

  test('a checked result is still a link by default', () {
    final r = ScanResult.fromJson({
      'url': 'https://example.com',
      'verdict': 'safe',
      'reasons': [],
      'cached': false,
    });
    expect(r.isLink, isTrue);
  });
}
