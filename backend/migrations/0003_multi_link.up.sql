-- A multi-link code is a hosted page that offers several destinations behind
-- one QR. It reuses the dynamic_codes slug, so only the type whitelist changes.
ALTER TABLE codes DROP CONSTRAINT IF EXISTS codes_type_check;
ALTER TABLE codes ADD CONSTRAINT codes_type_check
  CHECK (type IN ('url', 'wifi', 'vcard', 'email', 'text', 'sms', 'multi'));
