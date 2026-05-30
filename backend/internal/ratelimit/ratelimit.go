// Package ratelimit implements a Redis-backed fixed-window rate limiter. The
// window is keyed by an epoch bucket embedded in the Redis key, so a counter
// naturally belongs to exactly one window and old counters expire on their own
// — no separate reset bookkeeping and no INCR/EXPIRE race.
package ratelimit

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisLimiter enforces a fixed number of requests per window per key.
type RedisLimiter struct {
	rdb    *redis.Client
	limit  int
	window time.Duration
	now    func() time.Time // injectable for tests
}

// NewRedisLimiter constructs a RedisLimiter allowing limit requests per window.
func NewRedisLimiter(rdb *redis.Client, limit int, window time.Duration) *RedisLimiter {
	return &RedisLimiter{rdb: rdb, limit: limit, window: window, now: time.Now}
}

// Limit returns the configured per-window request limit.
func (l *RedisLimiter) Limit() int { return l.limit }

// Allow records a request for key and reports whether it is within the limit,
// how many requests remain in the current window, and how long until the window
// resets.
func (l *RedisLimiter) Allow(ctx context.Context, key string) (allowed bool, remaining int, reset time.Duration, err error) {
	windowSecs := int64(l.window / time.Second)
	if windowSecs < 1 {
		windowSecs = 1
	}
	now := l.now().Unix()
	bucket := now / windowSecs
	redisKey := fmt.Sprintf("ratelimit:%s:%d", key, bucket)

	// INCR the bucket counter and (re)set its TTL in one round trip. Because the
	// key is bucket-specific, refreshing the TTL never extends the counting
	// window — it only governs cleanup — so calling EXPIRE every time is safe.
	pipe := l.rdb.Pipeline()
	incr := pipe.Incr(ctx, redisKey)
	pipe.Expire(ctx, redisKey, l.window)
	if _, execErr := pipe.Exec(ctx); execErr != nil {
		return false, 0, 0, fmt.Errorf("rate limit pipeline: %w", execErr)
	}
	count := incr.Val()

	reset = time.Duration((bucket+1)*windowSecs-now) * time.Second
	remaining = l.limit - int(count)
	if remaining < 0 {
		remaining = 0
	}
	return count <= int64(l.limit), remaining, reset, nil
}
