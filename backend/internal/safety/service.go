package safety

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	// safetyKeyPrefix namespaces verdict cache keys.
	safetyKeyPrefix = "safety:"
	// safetyTTL bounds how long a verdict is cached. Heuristics are
	// deterministic, but a TTL lets blocklist/heuristic changes take effect and
	// keeps the contract identical once an external provider is added.
	safetyTTL = 6 * time.Hour
)

// Cache stores URL verdicts. Backed by Redis in production; the service depends
// on this interface, not on go-redis, so tests can substitute a fake.
type Cache interface {
	Get(ctx context.Context, rawURL string) (*Result, bool, error)
	Set(ctx context.Context, rawURL string, r Result) error
}

// RedisCache implements Cache over a go-redis client, keying on a hash of the
// URL so arbitrary URLs make safe, bounded keys.
type RedisCache struct {
	rdb *redis.Client
}

// NewRedisCache wraps a go-redis client as a Cache.
func NewRedisCache(rdb *redis.Client) *RedisCache {
	return &RedisCache{rdb: rdb}
}

func safetyKey(rawURL string) string {
	sum := sha256.Sum256([]byte(rawURL))
	return safetyKeyPrefix + hex.EncodeToString(sum[:])
}

// Get returns the cached verdict for rawURL. The boolean reports a cache hit; a
// miss (redis.Nil) is not an error.
func (c *RedisCache) Get(ctx context.Context, rawURL string) (*Result, bool, error) {
	val, err := c.rdb.Get(ctx, safetyKey(rawURL)).Bytes()
	if errors.Is(err, redis.Nil) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("redis get: %w", err)
	}
	var r Result
	if err := json.Unmarshal(val, &r); err != nil {
		return nil, false, fmt.Errorf("decoding cached verdict: %w", err)
	}
	return &r, true, nil
}

// Set caches r for rawURL with the safety TTL.
func (c *RedisCache) Set(ctx context.Context, rawURL string, r Result) error {
	b, err := json.Marshal(r)
	if err != nil {
		return fmt.Errorf("encoding verdict: %w", err)
	}
	if err := c.rdb.Set(ctx, safetyKey(rawURL), b, safetyTTL).Err(); err != nil {
		return fmt.Errorf("redis set: %w", err)
	}
	return nil
}

// Service runs the checker, fronted by a verdict cache.
type Service struct {
	checker Checker
	cache   Cache
	log     *slog.Logger
}

// NewService constructs a Service.
func NewService(checker Checker, cache Cache, log *slog.Logger) *Service {
	return &Service{checker: checker, cache: cache, log: log}
}

// Check returns the verdict for rawURL. It consults the cache first; a cache
// error degrades to a fresh check (fail-open) rather than failing the request.
func (s *Service) Check(ctx context.Context, rawURL string) (*Result, error) {
	if r, hit, err := s.cache.Get(ctx, rawURL); err != nil {
		s.log.Warn("safety cache lookup failed", slog.String("error", err.Error()))
	} else if hit {
		r.Cached = true
		return r, nil
	}

	res := s.checker.Check(rawURL)
	if err := s.cache.Set(ctx, rawURL, res); err != nil {
		s.log.Warn("safety cache store failed", slog.String("error", err.Error()))
	}
	return &res, nil
}
