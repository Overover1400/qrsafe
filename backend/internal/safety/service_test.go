package safety_test

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"log/slog"
	"os"
	"strconv"
	"testing"

	"github.com/Overover1400/qrsafe/internal/safety"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/require"
)

// sha256hex mirrors the key derivation in the package's RedisCache so tests can
// flush the exact key they use.
func sha256hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

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

func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func TestServiceCachesVerdict(t *testing.T) {
	rdb := newTestRedis(t)
	svc := safety.NewService(safety.NewHeuristicChecker(), safety.NewRedisCache(rdb), discardLogger())
	ctx := context.Background()

	const url = "https://service-cache-test.example/page"
	require.NoError(t, rdb.Del(ctx, "safety:"+sha256hex(url)).Err())

	// First call is a fresh check.
	first, err := svc.Check(ctx, url)
	require.NoError(t, err)
	require.Equal(t, safety.VerdictSafe, first.Verdict)
	require.False(t, first.Cached, "first lookup should not be cached")

	// Second call is served from cache.
	second, err := svc.Check(ctx, url)
	require.NoError(t, err)
	require.Equal(t, safety.VerdictSafe, second.Verdict)
	require.True(t, second.Cached, "second lookup should be cached")

	t.Cleanup(func() { _ = rdb.Del(ctx, "safety:"+sha256hex(url)).Err() })
}

func TestServiceCachesMaliciousVerdict(t *testing.T) {
	rdb := newTestRedis(t)
	svc := safety.NewService(safety.NewHeuristicChecker(), safety.NewRedisCache(rdb), discardLogger())
	ctx := context.Background()

	const url = "https://evil.example/x"
	require.NoError(t, rdb.Del(ctx, "safety:"+sha256hex(url)).Err())
	t.Cleanup(func() { _ = rdb.Del(ctx, "safety:"+sha256hex(url)).Err() })

	first, err := svc.Check(ctx, url)
	require.NoError(t, err)
	require.Equal(t, safety.VerdictMalicious, first.Verdict)

	second, err := svc.Check(ctx, url)
	require.NoError(t, err)
	require.Equal(t, safety.VerdictMalicious, second.Verdict)
	require.True(t, second.Cached)
	require.NotEmpty(t, second.Reasons, "cached result should retain its reasons")
}
