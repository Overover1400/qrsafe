// DB strategy for codes tests mirrors users/repository_test.go: a live Postgres
// addressed via TEST_DATABASE_URL (falling back to DATABASE_URL). When neither
// is set the DB-backed tests skip, so `go test ./...` stays green without
// infrastructure. Redis tests likewise skip when no reachable Redis is
// configured (REDIS_ADDR/REDIS_PASSWORD/REDIS_DB).
//
// `make test` exports these from .env, and CI sets them for the service
// containers, so both environments exercise the real code paths.
package codes_test

import (
	"context"
	"io"
	"log/slog"
	"os"
	"strconv"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/require"
)

// ensureSchemaSQL creates the tables the codes tests need if they do not already
// exist (in CI the migrations create them first; this keeps local runs working
// without a migrate step). It mirrors migration 0002 plus the users table.
const ensureSchemaSQL = `
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           CITEXT UNIQUE,
  password_hash   TEXT,
  is_guest        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS codes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN ('url', 'wifi', 'vcard', 'email', 'text', 'sms')),
  payload         JSONB NOT NULL,
  is_dynamic      BOOLEAN NOT NULL DEFAULT FALSE,
  label           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS codes_user_id_created_at_idx ON codes (user_id, created_at DESC);
CREATE TABLE IF NOT EXISTS dynamic_codes (
  code_id         UUID PRIMARY KEY REFERENCES codes(id) ON DELETE CASCADE,
  slug            TEXT NOT NULL UNIQUE,
  destination     TEXT NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS dynamic_codes_slug_idx ON dynamic_codes (slug);
CREATE TABLE IF NOT EXISTS scan_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            TEXT NOT NULL,
  ip_hash         TEXT,
  user_agent      TEXT,
  scanned_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS scan_events_slug_scanned_at_idx ON scan_events (slug, scanned_at DESC);
`

func testDatabaseURL() string {
	if u := os.Getenv("TEST_DATABASE_URL"); u != "" {
		return u
	}
	return os.Getenv("DATABASE_URL")
}

// newTestPool connects to the test database, ensures the schema, and truncates
// the codes-related tables so each test starts clean. Skips when no database is
// configured.
func newTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := testDatabaseURL()
	if url == "" {
		t.Skip("neither TEST_DATABASE_URL nor DATABASE_URL set; skipping live Postgres codes tests")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	require.NoError(t, err)
	require.NoError(t, pool.Ping(ctx), "could not reach test database")

	_, err = pool.Exec(ctx, ensureSchemaSQL)
	require.NoError(t, err, "ensuring schema")
	_, err = pool.Exec(ctx, `TRUNCATE scan_events, dynamic_codes, codes, users CASCADE`)
	require.NoError(t, err, "truncating tables")

	t.Cleanup(pool.Close)
	return pool
}

// newTestRedis connects to the configured Redis, skipping if unreachable.
func newTestRedis(t *testing.T) *redis.Client {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	db, _ := strconv.Atoi(os.Getenv("REDIS_DB"))
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: os.Getenv("REDIS_PASSWORD"),
		DB:       db,
	})
	ctx := context.Background()
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		t.Skip("redis not reachable; skipping: " + err.Error())
	}
	t.Cleanup(func() { _ = client.Close() })
	return client
}

// insertUser creates a guest user row and returns its id (codes FK to users).
func insertUser(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (is_guest) VALUES (true) RETURNING id`).Scan(&id)
	require.NoError(t, err)
	return id
}

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func ptr[T any](v T) *T { return &v }
