CREATE TABLE codes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN ('url', 'wifi', 'vcard', 'email', 'text', 'sms')),
  payload         JSONB NOT NULL,
  is_dynamic      BOOLEAN NOT NULL DEFAULT FALSE,
  label           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX codes_user_id_created_at_idx ON codes (user_id, created_at DESC);

CREATE TABLE dynamic_codes (
  code_id         UUID PRIMARY KEY REFERENCES codes(id) ON DELETE CASCADE,
  slug            TEXT NOT NULL UNIQUE,
  destination     TEXT NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX dynamic_codes_slug_idx ON dynamic_codes (slug);

CREATE TABLE scan_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            TEXT NOT NULL,
  ip_hash         TEXT,
  user_agent      TEXT,
  scanned_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX scan_events_slug_scanned_at_idx ON scan_events (slug, scanned_at DESC);
