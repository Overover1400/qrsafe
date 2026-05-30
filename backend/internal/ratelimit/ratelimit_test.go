package ratelimit_test

import (
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/Overover1400/qrsafe/internal/ratelimit"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/require"
)

func newTestRedis(t *testing.T) *redis.Client {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	db, _ := strconv.Atoi(os.Getenv("REDIS_DB"))
	client := redis.NewClient(&redis.Options{Addr: addr, Password: os.Getenv("REDIS_PASSWORD"), DB: db})
	if err := client.Ping(context.Background()).Err(); err != nil {
		_ = client.Close()
		t.Skip("redis not reachable; skipping: " + err.Error())
	}
	t.Cleanup(func() { _ = client.Close() })
	return client
}

func TestRedisLimiterAllowsUpToLimit(t *testing.T) {
	rdb := newTestRedis(t)
	// A long window so the test isn't affected by minute boundaries.
	lim := ratelimit.NewRedisLimiter(rdb, 3, time.Hour)
	// Unique key → a fresh bucket, independent of other runs.
	key := "test-" + uuid.NewString()
	ctx := context.Background()

	require.Equal(t, 3, lim.Limit())

	for i := 1; i <= 3; i++ {
		allowed, remaining, reset, err := lim.Allow(ctx, key)
		require.NoError(t, err)
		require.True(t, allowed, "request %d should be allowed", i)
		require.Equal(t, 3-i, remaining)
		require.Greater(t, reset, time.Duration(0))
	}

	// 4th request over the limit.
	allowed, remaining, _, err := lim.Allow(ctx, key)
	require.NoError(t, err)
	require.False(t, allowed, "4th request should be blocked")
	require.Equal(t, 0, remaining)
}

func TestRedisLimiterKeysAreIndependent(t *testing.T) {
	rdb := newTestRedis(t)
	lim := ratelimit.NewRedisLimiter(rdb, 1, time.Hour)
	ctx := context.Background()
	keyA := "a-" + uuid.NewString()
	keyB := "b-" + uuid.NewString()

	allowed, _, _, err := lim.Allow(ctx, keyA)
	require.NoError(t, err)
	require.True(t, allowed)

	// keyA is now exhausted, but keyB has its own budget.
	allowed, _, _, err = lim.Allow(ctx, keyA)
	require.NoError(t, err)
	require.False(t, allowed)

	allowed, _, _, err = lim.Allow(ctx, keyB)
	require.NoError(t, err)
	require.True(t, allowed, "a different key must not share keyA's budget")
}
