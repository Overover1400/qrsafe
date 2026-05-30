package handlers_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
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

// memCache is an in-memory safety.Cache so these handler tests need no Redis.
type memCache struct {
	mu sync.Mutex
	m  map[string]safety.Result
}

func newMemCache() *memCache { return &memCache{m: map[string]safety.Result{}} }

func (c *memCache) Get(_ context.Context, url string) (*safety.Result, bool, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	r, ok := c.m[url]
	if !ok {
		return nil, false, nil
	}
	cp := r
	return &cp, true, nil
}

func (c *memCache) Set(_ context.Context, url string, r safety.Result) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.m[url] = r
	return nil
}

// newSafetyEnv wires a server with only the safety handler. The safety check
// touches neither Postgres nor Redis (in-memory cache), so these tests run
// everywhere; tokens are forged directly from the token manager.
func newSafetyEnv(t *testing.T) (http.Handler, string) {
	t.Helper()
	tokens := auth.NewTokenManager([]byte("test-signing-secret-0123456789abc"), time.Hour)
	svc := safety.NewService(safety.NewHeuristicChecker(), newMemCache(), discardLogger())
	health := handlers.NewHealthHandler(okPinger{}, okPinger{})
	safetyH := handlers.NewSafetyHandler(svc)
	srv := httpserver.NewServer(":0", discardLogger(), tokens, httpserver.Handlers{
		Health: health,
		Safety: safetyH,
	}, nil)

	token, _, err := tokens.Issue(uuid.New(), true, time.Now())
	require.NoError(t, err)
	return srv.Handler(), token
}

func postCheck(t *testing.T, h http.Handler, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	r := httptest.NewRequest(http.MethodPost, "/api/v1/scan/check", strings.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}

type checkResp struct {
	URL     string `json:"url"`
	Verdict string `json:"verdict"`
	Reasons []struct {
		Code string `json:"code"`
	} `json:"reasons"`
	Cached bool `json:"cached"`
}

func TestScanCheckRequiresAuth(t *testing.T) {
	h, _ := newSafetyEnv(t)
	w := postCheck(t, h, "", `{"url":"https://example.com"}`)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestScanCheckSafeURL(t *testing.T) {
	h, token := newSafetyEnv(t)
	w := postCheck(t, h, token, `{"url":"https://example.com"}`)
	require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	var resp checkResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	require.Equal(t, "safe", resp.Verdict)
	require.Empty(t, resp.Reasons)
}

func TestScanCheckMaliciousURL(t *testing.T) {
	h, token := newSafetyEnv(t)
	// Even a malicious verdict is a 200 — it's a check result, not an error.
	w := postCheck(t, h, token, `{"url":"javascript:alert(1)"}`)
	require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	var resp checkResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	require.Equal(t, "malicious", resp.Verdict)
	require.NotEmpty(t, resp.Reasons)
}

func TestScanCheckCachedFlag(t *testing.T) {
	h, token := newSafetyEnv(t)
	body := `{"url":"https://cached-flag.example"}`

	first := postCheck(t, h, token, body)
	require.Equal(t, http.StatusOK, first.Code)
	var r1 checkResp
	require.NoError(t, json.Unmarshal(first.Body.Bytes(), &r1))
	require.False(t, r1.Cached)

	second := postCheck(t, h, token, body)
	require.Equal(t, http.StatusOK, second.Code)
	var r2 checkResp
	require.NoError(t, json.Unmarshal(second.Body.Bytes(), &r2))
	require.True(t, r2.Cached)
}

func TestScanCheckValidation(t *testing.T) {
	h, token := newSafetyEnv(t)
	w := postCheck(t, h, token, `{}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "validation_error", errorCode(t, w.Body.Bytes()))
}
