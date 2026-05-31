import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';
import 'package:qrsafe_mobile/features/generator/data/payload_encoder.dart';

void main() {
  group('URL', () {
    test('encodes as-is when a scheme is present', () {
      expect(
        PayloadEncoder.encode(const UrlPayload(url: 'https://example.com')),
        'https://example.com',
      );
    });

    test('prepends https:// when no scheme', () {
      expect(
        PayloadEncoder.encode(const UrlPayload(url: 'example.com')),
        'https://example.com',
      );
    });

    test('keeps a non-https scheme (e.g. http)', () {
      expect(
        PayloadEncoder.encode(const UrlPayload(url: 'http://example.com')),
        'http://example.com',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        PayloadEncoder.encode(const UrlPayload(url: '  example.com ')),
        'https://example.com',
      );
    });
  });

  group('WiFi', () {
    test('encodes the standard format', () {
      expect(
        PayloadEncoder.encode(
          const WifiPayload(ssid: 'MyNet', password: 'secret'),
        ),
        'WIFI:T:WPA;S:MyNet;P:secret;H:false;;',
      );
    });

    test('nopass omits the password', () {
      expect(
        PayloadEncoder.encode(
          const WifiPayload(ssid: 'Guest', password: 'ignored', auth: WifiAuth.nopass),
        ),
        'WIFI:T:nopass;S:Guest;P:;H:false;;',
      );
    });

    test('hidden network flag', () {
      expect(
        PayloadEncoder.encode(
          const WifiPayload(ssid: 'Net', password: 'p', hidden: true),
        ),
        'WIFI:T:WPA;S:Net;P:p;H:true;;',
      );
    });

    test('escapes special characters in ssid and password', () {
      // Password with a semicolon and the SSID with a comma/colon.
      final out = PayloadEncoder.encode(
        const WifiPayload(ssid: 'Cafe:Wi,Fi', password: r'p;a$$\w"d'),
      );
      expect(out, r'WIFI:T:WPA;S:Cafe\:Wi\,Fi;P:p\;a$$\\w\"d;H:false;;');
    });
  });

  group('vCard', () {
    test('emits only non-empty optional fields, name always present', () {
      final out = PayloadEncoder.encode(const VCardPayload(name: 'Ada Lovelace'));
      expect(out, 'BEGIN:VCARD\nVERSION:3.0\nFN:Ada Lovelace\nEND:VCARD');
    });

    test('includes all provided fields in order', () {
      final out = PayloadEncoder.encode(
        const VCardPayload(
          name: 'Ada',
          org: 'Analytical Engine',
          phone: '+1234567890',
          email: 'ada@example.com',
          url: 'https://example.com',
        ),
      );
      expect(out, contains('ORG:Analytical Engine'));
      expect(out, contains('TEL:+1234567890'));
      expect(out, contains('EMAIL:ada@example.com'));
      expect(out, contains('URL:https://example.com'));
      expect(out.startsWith('BEGIN:VCARD'), isTrue);
      expect(out.endsWith('END:VCARD'), isTrue);
    });

    test('escapes commas, semicolons and backslashes', () {
      final out = PayloadEncoder.encode(
        const VCardPayload(name: 'Doe, John; Jr\\'),
      );
      expect(out, contains(r'FN:Doe\, John\; Jr\\'));
    });
  });

  group('Email', () {
    test('to only, no query', () {
      expect(
        PayloadEncoder.encode(const EmailPayload(to: 'a@b.com')),
        'mailto:a@b.com',
      );
    });

    test('url-encodes subject and body', () {
      final out = PayloadEncoder.encode(
        const EmailPayload(to: 'a@b.com', subject: 'Hi there', body: 'A & B'),
      );
      expect(out, 'mailto:a@b.com?subject=Hi%20there&body=A%20%26%20B');
    });

    test('body only', () {
      expect(
        PayloadEncoder.encode(const EmailPayload(to: 'a@b.com', body: 'hello')),
        'mailto:a@b.com?body=hello',
      );
    });
  });

  group('Text', () {
    test('encodes the literal text', () {
      expect(
        PayloadEncoder.encode(const TextPayload(text: 'just some text')),
        'just some text',
      );
    });

    test('preserves multi-line content', () {
      expect(
        PayloadEncoder.encode(const TextPayload(text: 'line1\nline2')),
        'line1\nline2',
      );
    });
  });

  group('validity gates', () {
    test('empty required fields are invalid', () {
      expect(const UrlPayload(url: '').isValid, isFalse);
      expect(const WifiPayload(ssid: '').isValid, isFalse);
      expect(const VCardPayload(name: '   ').isValid, isFalse);
      expect(const EmailPayload(to: '').isValid, isFalse);
      expect(const TextPayload(text: '').isValid, isFalse);
    });

    test('over-long text is invalid', () {
      final long = 'a' * (TextPayload.maxLength + 1);
      expect(TextPayload(text: long).isValid, isFalse);
    });

    test('toJson normalizes url with https prefix', () {
      expect(const UrlPayload(url: 'example.com').toJson(), {'url': 'https://example.com'});
    });
  });
}
