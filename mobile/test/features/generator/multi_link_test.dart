import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';
import 'package:qrsafe_mobile/features/generator/data/multi_link.dart';

void main() {
  group('buildMultiLinkItems', () {
    test('skips tabs that were never filled in', () {
      final items = buildMultiLinkItems([
        const UrlPayload(url: ''),
        const TextPayload(text: ''),
      ]);
      expect(items, isEmpty);
    });

    test('a url becomes a button with a normalised address', () {
      final items = buildMultiLinkItems([
        const UrlPayload(url: 'qrsafe.flemby.com'),
      ]);
      expect(items, hasLength(1));
      expect(items.single.url, 'https://qrsafe.flemby.com');
      expect(items.single.kind, 'url');
    });

    test('an email becomes a mailto button', () {
      final items = buildMultiLinkItems([
        const EmailPayload(to: 'hi@example.com', subject: 'Hello'),
      ]);
      expect(items.single.url, startsWith('mailto:hi@example.com'));
    });

    test('wifi becomes a note holding the network and password', () {
      final items = buildMultiLinkItems([
        const WifiPayload(ssid: 'Cafe', password: 'secret123'),
      ]);
      expect(items.single.url, isEmpty);
      expect(items.single.text, contains('Cafe'));
      expect(items.single.text, contains('secret123'));
    });

    test('an open network does not print a password line', () {
      final items = buildMultiLinkItems([
        const WifiPayload(ssid: 'Open', password: '', auth: WifiAuth.nopass),
      ]);
      expect(items.single.text, 'Network: Open');
    });

    test('a contact with a phone gets both a call button and its details', () {
      final items = buildMultiLinkItems([
        const VCardPayload(
          name: 'Sara',
          org: 'Semicolon',
          phone: '+1 604 555 0101',
        ),
      ]);
      expect(items, hasLength(2));
      expect(items.first.url, 'tel:+1 604 555 0101');
      expect(items.last.label, 'Sara');
      expect(items.last.text, contains('Semicolon'));
    });

    test('a contact with only a name still carries text', () {
      final items = buildMultiLinkItems([const VCardPayload(name: 'Sara')]);
      expect(items.single.text, 'Sara');
    });

    test('several filled tabs all come through, in order', () {
      final items = buildMultiLinkItems([
        const UrlPayload(url: 'https://example.com'),
        const EmailPayload(to: 'hi@example.com'),
        const TextPayload(text: 'Open 9 to 5'),
      ]);
      expect(items.map((i) => i.kind), ['url', 'email', 'text']);
    });

    test('toJson leaves out the half of the row that is unused', () {
      final link = buildMultiLinkItems([
        const UrlPayload(url: 'https://example.com'),
      ]).single.toJson();
      expect(link.containsKey('url'), isTrue);
      expect(link.containsKey('text'), isFalse);
    });
  });
}
