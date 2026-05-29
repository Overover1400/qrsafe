// Package platform wires up infrastructure clients (Postgres, Redis) that the
// rest of the service depends on. Constructors here verify connectivity before
// returning so startup fails fast on misconfiguration.
package platform

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPostgresPool creates a pgx connection pool and verifies it with a ping.
func NewPostgresPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("creating pgx pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("pinging postgres: %w", err)
	}
	return pool, nil
}
