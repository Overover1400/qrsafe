-- Multi codes must go before the narrower constraint can be restored.
DELETE FROM codes WHERE type = 'multi';
ALTER TABLE codes DROP CONSTRAINT IF EXISTS codes_type_check;
ALTER TABLE codes ADD CONSTRAINT codes_type_check
  CHECK (type IN ('url', 'wifi', 'vcard', 'email', 'text', 'sms'));
