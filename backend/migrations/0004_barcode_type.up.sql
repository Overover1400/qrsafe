-- A barcode is a 1D code (Code 128, EAN-13, UPC-A and friends) rather than a
-- QR. It is stored like any other static code - payload {symbology, value} -
-- so only the type whitelist changes. It can never be dynamic: there is no
-- room in a 1D symbology for a redirect URL.
ALTER TABLE codes DROP CONSTRAINT IF EXISTS codes_type_check;
ALTER TABLE codes ADD CONSTRAINT codes_type_check
  CHECK (type IN ('url', 'wifi', 'vcard', 'email', 'text', 'sms', 'multi', 'barcode'));
