// DB strategy for repository tests: a live Postgres, addressed via the
// TEST_DATABASE_URL environment variable. Docker is not available on this dev
// box, so testcontainers is out; and because these tests exist precisely to
// exercise real SQL (the citext UNIQUE constraint, RETURNING clauses, NULL
// handling for guests), a mock would test the wrong thing. When TEST_DATABASE_URL
// is unset the tests skip, so `go test ./...` stays green without a database.
//
// Point TEST_DATABASE_URL at a throwaway database — the tests TRUNCATE the
// users table. e.g.
//   TEST_DATABASE_URL=postgres://qrsafe:pw@localhost:5432/qrsafe_dev?sslmode=disable go test ./internal/users/...
package users_test

import (
	"context"
	"os"
	"testing"

	"github.com/Overover1400/qrsafe/internal/users"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"
)

const schemaSQL = `
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           CITEXT UNIQUE,
  password_hash   TEXT,
  is_guest        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);`

// newTestPool connects to TEST_DATABASE_URL, ensures the schema exists, and
// truncates the users table so each test starts clean. It skips the test if no
// database is configured.
func newTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping live Postgres repository tests")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	require.NoError(t, err)
	require.NoError(t, pool.Ping(ctx), "could not reach TEST_DATABASE_URL")

	_, err = pool.Exec(ctx, schemaSQL)
	require.NoError(t, err, "ensuring schema")
	_, err = pool.Exec(ctx, "TRUNCATE users")
	require.NoError(t, err, "truncating users")

	t.Cleanup(pool.Close)
	return pool
}

func strptr(s string) *string { return &s }

func TestCreateAndGetByID(t *testing.T) {
	pool := newTestPool(t)
	repo := users.NewRepository(pool)
	ctx := context.Background()

	u := &users.User{IsGuest: true}
	require.NoError(t, repo.Create(ctx, u))
	require.NotEqual(t, uuid.Nil, u.ID, "Create should populate the id")
	require.False(t, u.CreatedAt.IsZero(), "Create should populate created_at")

	got, err := repo.GetByID(ctx, u.ID)
	require.NoError(t, err)
	require.Equal(t, u.ID, got.ID)
	require.True(t, got.IsGuest)
	require.Nil(t, got.Email)
	require.Nil(t, got.PasswordHash)
}

func TestGetByIDNotFound(t *testing.T) {
	pool := newTestPool(t)
	repo := users.NewRepository(pool)

	_, err := repo.GetByID(context.Background(), uuid.New())
	require.ErrorIs(t, err, users.ErrNotFound)
}

func TestUpdateUpgradesUser(t *testing.T) {
	pool := newTestPool(t)
	repo := users.NewRepository(pool)
	ctx := context.Background()

	u := &users.User{IsGuest: true}
	require.NoError(t, repo.Create(ctx, u))

	u.Email = strptr("person@example.com")
	u.PasswordHash = strptr("$argon2id$dummy")
	u.IsGuest = false
	require.NoError(t, repo.Update(ctx, u))

	got, err := repo.GetByEmail(ctx, "person@example.com")
	require.NoError(t, err)
	require.Equal(t, u.ID, got.ID)
	require.False(t, got.IsGuest)
	require.NotNil(t, got.Email)
	require.Equal(t, "person@example.com", *got.Email)

	// citext is case-insensitive, so a differently-cased lookup matches too.
	gotUpper, err := repo.GetByEmail(ctx, "PERSON@EXAMPLE.COM")
	require.NoError(t, err)
	require.Equal(t, u.ID, gotUpper.ID)
}

func TestUniqueEmailConstraint(t *testing.T) {
	pool := newTestPool(t)
	repo := users.NewRepository(pool)
	ctx := context.Background()

	first := &users.User{IsGuest: true}
	require.NoError(t, repo.Create(ctx, first))
	first.Email = strptr("dup@example.com")
	first.PasswordHash = strptr("$argon2id$dummy")
	first.IsGuest = false
	require.NoError(t, repo.Update(ctx, first))

	second := &users.User{IsGuest: true}
	require.NoError(t, repo.Create(ctx, second))
	second.Email = strptr("dup@example.com")
	second.PasswordHash = strptr("$argon2id$dummy")
	second.IsGuest = false

	err := repo.Update(ctx, second)
	require.ErrorIs(t, err, users.ErrEmailTaken, "duplicate email should violate the unique constraint")
}
