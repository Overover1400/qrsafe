-- Drop in reverse dependency order: dynamic_codes references codes, scan_events
-- is independent, codes references users.
DROP TABLE IF EXISTS scan_events;
DROP TABLE IF EXISTS dynamic_codes;
DROP TABLE IF EXISTS codes;
