package codes

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	// redirectKeyPrefix namespaces the per-slug redirect cache keys.
	redirectKeyPrefix = "redirect:"
	// redirectTTL bounds how long a destination is cached before re-reading
	// from Postgres. PATCH/DELETE also invalidate eagerly.
	redirectTTL = time.Hour
)

// CachedTarget is the JSON value stored in Redis for a slug.
type CachedTarget struct {
	Destination string `json:"destination"`
	CodeID      string `json:"code_id"`
}

// Cache is the redirect cache surface. Backed by Redis in production; the
// service and redirect handler depend on this interface, not on go-redis.
type Cache interface {
	Lookup(ctx context.Context, slug string) (*CachedTarget, bool, error)
	Store(ctx context.Context, slug string, target CachedTarget) error
	Invalidate(ctx context.Context, slug string) error
}

// RedisCache implements Cache over a go-redis client.
type RedisCache struct {
	rdb *redis.Client
}

// NewRedisCache wraps a go-redis client as a Cache.
func NewRedisCache(rdb *redis.Client) *RedisCache {
	return &RedisCache{rdb: rdb}
}

func redirectKey(slug string) string { return redirectKeyPrefix + slug }

// Lookup returns the cached target for slug. The boolean reports a cache hit; a
// miss (redis.Nil) is not an error.
func (c *RedisCache) Lookup(ctx context.Context, slug string) (*CachedTarget, bool, error) {
	val, err := c.rdb.Get(ctx, redirectKey(slug)).Bytes()
	if errors.Is(err, redis.Nil) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("redis get: %w", err)
	}
	var t CachedTarget
	if err := json.Unmarshal(val, &t); err != nil {
		return nil, false, fmt.Errorf("decoding cached target: %w", err)
	}
	return &t, true, nil
}

// Store caches target for slug with the redirect TTL.
func (c *RedisCache) Store(ctx context.Context, slug string, target CachedTarget) error {
	b, err := json.Marshal(target)
	if err != nil {
		return fmt.Errorf("encoding cached target: %w", err)
	}
	if err := c.rdb.Set(ctx, redirectKey(slug), b, redirectTTL).Err(); err != nil {
		return fmt.Errorf("redis set: %w", err)
	}
	return nil
}

// Invalidate drops the cached entry for slug.
func (c *RedisCache) Invalidate(ctx context.Context, slug string) error {
	if err := c.rdb.Del(ctx, redirectKey(slug)).Err(); err != nil {
		return fmt.Errorf("redis del: %w", err)
	}
	return nil
}

// slugResolver is the persistence surface the redirect service needs.
type slugResolver interface {
	ResolveSlug(ctx context.Context, slug string) (string, uuid.UUID, error)
	InsertScanEvent(ctx context.Context, e *ScanEvent) error
}

// RedirectService resolves slugs to destinations (cache-first) and records
// scans.
type RedirectService struct {
	repo  slugResolver
	cache Cache
	log   *slog.Logger
}

// NewRedirectService constructs a RedirectService.
func NewRedirectService(repo slugResolver, cache Cache, log *slog.Logger) *RedirectService {
	return &RedirectService{repo: repo, cache: cache, log: log}
}

// Resolve returns the current destination for slug, consulting Redis first and
// falling back to Postgres (caching the result). It returns ErrNotFound for an
// unknown slug. A cache error is logged and treated as a miss, not a failure.
func (s *RedirectService) Resolve(ctx context.Context, slug string) (string, error) {
	if t, hit, err := s.cache.Lookup(ctx, slug); err != nil {
		s.log.Warn("redirect cache lookup failed",
			slog.String("slug", slug), slog.String("error", err.Error()))
	} else if hit {
		return t.Destination, nil
	}

	dest, codeID, err := s.repo.ResolveSlug(ctx, slug)
	if err != nil {
		return "", err
	}

	s.log.Info("redirect cache miss", slog.String("slug", slug))
	if err := s.cache.Store(ctx, slug, CachedTarget{Destination: dest, CodeID: codeID.String()}); err != nil {
		s.log.Warn("redirect cache store failed",
			slog.String("slug", slug), slog.String("error", err.Error()))
	}
	return dest, nil
}

// RecordScan appends a scan event. It is meant to be called from a fire-and-
// forget goroutine, so it logs rather than returns errors.
func (s *RedirectService) RecordScan(ctx context.Context, slug, ipHash, userAgent string) {
	e := &ScanEvent{Slug: slug}
	if ipHash != "" {
		e.IPHash = &ipHash
	}
	if userAgent != "" {
		e.UserAgent = &userAgent
	}
	if err := s.repo.InsertScanEvent(ctx, e); err != nil {
		s.log.Warn("recording scan event failed",
			slog.String("slug", slug), slog.String("error", err.Error()))
	}
}

// HashIP returns the hex-encoded SHA-256 of ip. An empty ip yields an empty
// string (so we store NULL rather than the hash of "").
func HashIP(ip string) string {
	if ip == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(ip))
	return hex.EncodeToString(sum[:])
}
