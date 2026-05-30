package handlers_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	httpserver "github.com/Overover1400/qrsafe/internal/http"
	"github.com/Overover1400/qrsafe/internal/http/handlers"
	"github.com/Overover1400/qrsafe/internal/safety"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

// fakeLimiter counts per key in memory — enough to exercise the middleware and
// its wiring without Redis.
type fakeLimiter struct {
	mu    sync.Mutex
	limit int
	n     map[string]int
}

func (f *fakeLimiter) Limit() int { return f.limit }

func (f *fakeLimiter) Allow(_ context.Context, key string) (bool, int, time.Duration, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.n[key]++
	c := f.n[key]
	rem := f.limit - c
	if rem < 0 {
		rem = 0
	}
	return c <= f.limit, rem, 30 * time.Second, nil
}

func newLimitedEnv(t *testing.T, limit int) (http.Handler, string) {
	t.Helper()
	tokens := auth.NewTokenManager([]byte("test-signing-secret-0123456789abc"), time.Hour)
	health := handlers.NewHealthHandler(okPinger{}, okPinger{})
	safetySvc := safety.NewService(safety.NewHeuristicChecker(), newMemCache(), discardLogger())
	safetyH := handlers.NewSafetyHandler(safetySvc)
	srv := httpserver.NewServer(":0", discardLogger(), tokens, httpserver.Handlers{
		Health: health,
		Safety: safetyH,
	}, &fakeLimiter{limit: limit, n: map[string]int{}})
	token, _, err := tokens.Issue(uuid.New(), true, time.Now())
	require.NoError(t, err)
	return srv.Handler(), token
}

func TestRateLimitBlocksAfterLimitOnAPI(t *testing.T) {
	h, token := newLimitedEnv(t, 2)
	body := `{"url":"https://example.com"}`

	for i := 1; i <= 2; i++ {
		w := postCheck(t, h, token, body)
		require.Equal(t, http.StatusOK, w.Code, "request %d should pass", i)
		require.Equal(t, "2", w.Header().Get("X-RateLimit-Limit"))
	}

	// Third request over the limit.
	w := postCheck(t, h, token, body)
	require.Equal(t, http.StatusTooManyRequests, w.Code)
	require.Equal(t, "rate_limited", errorCode(t, w.Body.Bytes()))
	require.NotEmpty(t, w.Header().Get("Retry-After"))
}

func TestRateLimitExcludesHealth(t *testing.T) {
	h, _ := newLimitedEnv(t, 1)
	// /health is mounted at the root, outside /api/v1, so it is never limited.
	for i := 0; i < 3; i++ {
		r := httptest.NewRequest(http.MethodGet, "/health", nil)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		require.Equal(t, http.StatusOK, w.Code, "health check %d should not be rate limited", i)
	}
}
