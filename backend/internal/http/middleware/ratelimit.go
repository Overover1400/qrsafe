package middleware

import (
	"context"
	"log/slog"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/Overover1400/qrsafe/internal/http/response"
)

// Limiter is the rate-limit decision surface. The Redis-backed implementation
// lives in the ratelimit package; defining the interface here keeps this
// middleware free of any concrete dependency.
type Limiter interface {
	// Allow records a request for key and reports whether it is within the
	// limit, how many requests remain, and how long until the window resets.
	Allow(ctx context.Context, key string) (allowed bool, remaining int, reset time.Duration, err error)
	// Limit returns the configured per-window limit (for response headers).
	Limit() int
}

// RateLimit returns middleware that limits requests per client IP. A limiter
// error fails open (the request is allowed) so a limiter outage cannot take the
// API down. Blocked requests get a 429 with Retry-After and the standard error
// envelope.
func RateLimit(limiter Limiter, logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			allowed, remaining, reset, err := limiter.Allow(r.Context(), clientIP(r))
			if err != nil {
				logger.Warn("rate limiter error; allowing request", slog.String("error", err.Error()))
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("X-RateLimit-Limit", strconv.Itoa(limiter.Limit()))
			w.Header().Set("X-RateLimit-Remaining", strconv.Itoa(remaining))

			if !allowed {
				retry := int(math.Ceil(reset.Seconds()))
				if retry < 1 {
					retry = 1
				}
				w.Header().Set("Retry-After", strconv.Itoa(retry))
				response.Error(w, http.StatusTooManyRequests, "rate_limited", "too many requests; slow down")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// clientIP extracts the client IP, honoring a single X-Forwarded-For hop and
// falling back to the connection's remote address.
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if i := strings.IndexByte(xff, ','); i >= 0 {
			return strings.TrimSpace(xff[:i])
		}
		return strings.TrimSpace(xff)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
