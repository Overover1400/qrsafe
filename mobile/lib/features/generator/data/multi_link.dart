import 'code_payload.dart';
import 'payload_encoder.dart';

/// One row of a hosted multi-link page.
///
/// A row with a [url] renders as a button on the page; a row with only [text]
/// renders as a note the visitor can read (a WiFi password, an address). [kind]
/// mirrors the tab it came from and only drives presentation.
class MultiLinkItem {
  const MultiLinkItem({
    required this.kind,
    required this.label,
    this.url = '',
    this.text = '',
  });

  final String kind;
  final String label;
  final String url;
  final String text;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'label': label,
    if (url.isNotEmpty) 'url': url,
    if (text.isNotEmpty) 'text': text,
  };
}

/// Builds the rows of a multi-link page from the generator's filled tabs.
///
/// This is what makes "fill more than one tab" mean something: anything that
/// can be opened (a site, an email address, a phone number) becomes a button,
/// and everything else becomes a note, so one QR can carry all of it.
List<MultiLinkItem> buildMultiLinkItems(Iterable<CodePayload> payloads) {
  final items = <MultiLinkItem>[];

  for (final payload in payloads) {
    if (!payload.isValid) continue;
    switch (payload) {
      // A barcode is never a row here: it is saved on its own, and a 1D
      // symbology cannot carry a link to this page anyway. GeneratorState
      // already leaves it out of filledPayloads; this case is the backstop
      // that also keeps the switch exhaustive.
      case BarcodePayload _:
        break;

      case UrlPayload p:
        items.add(
          MultiLinkItem(kind: 'url', label: 'Website', url: p.normalizedUrl),
        );

      case EmailPayload p:
        items.add(
          MultiLinkItem(
            kind: 'email',
            label: 'Send an email',
            url: PayloadEncoder.encode(p),
          ),
        );

      case VCardPayload p:
        final name = p.name.trim();
        final phone = p.phone.trim();
        if (phone.isNotEmpty) {
          items.add(
            MultiLinkItem(
              kind: 'vcard',
              label: name.isEmpty ? 'Call' : 'Call $name',
              url: 'tel:$phone',
            ),
          );
        }
        final details = [
          if (p.org.trim().isNotEmpty) p.org.trim(),
          if (phone.isNotEmpty) phone,
          if (p.email.trim().isNotEmpty) p.email.trim(),
        ].join(' · ');
        items.add(
          MultiLinkItem(
            kind: 'vcard',
            label: name,
            // A contact with nothing but a name still has to say something, or
            // the backend drops the empty row.
            text: details.isEmpty ? name : details,
          ),
        );

      case WifiPayload p:
        final ssid = p.ssid.trim();
        final password = p.password.trim();
        final hasPassword = p.auth != WifiAuth.nopass && password.isNotEmpty;
        items.add(
          MultiLinkItem(
            kind: 'wifi',
            label: 'WiFi',
            text: hasPassword
                ? 'Network: $ssid\nPassword: $password'
                : 'Network: $ssid',
          ),
        );

      case TextPayload p:
        items.add(
          MultiLinkItem(kind: 'text', label: 'Note', text: p.text.trim()),
        );
    }
  }

  return items;
}
