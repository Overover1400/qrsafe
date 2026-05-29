package handlers_test

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/stretchr/testify/require"
)

// makeDynamic inserts a user and a dynamic code with the given slug/destination,
// returning the slug. It also clears any cached entry for a clean starting point.
func (e *codesEnv) makeDynamic(t *testing.T, slug, destination string) string {
	t.Helper()
	ctx := context.Background()
	userID, _ := e.newUser(t)
	c := &codes.Code{
		UserID:  userID,
		Type:    string(codes.TypeURL),
		Payload: json.RawMessage(`{"url":"` + destination + `"}`),
	}
	require.NoError(t, e.repo.CreateDynamic(ctx, c, slug, destination))
	require.NoError(t, e.rdb.Del(ctx, "redirect:"+slug).Err())
	return slug
}

func TestRedirectCacheMissThenSet(t *testing.T) {
	env := newCodesEnv(t)
	ctx := context.Background()
	slug := env.makeDynamic(t, "rdmiss01", "https://dest.example")

	// Cache is empty → handler resolves from Postgres and 302s.
	w := env.do(t, http.MethodGet, "/r/"+slug, "", "")
	require.Equal(t, http.StatusFound, w.Code)
	require.Equal(t, "https://dest.example", w.Header().Get("Location"))

	// The miss should have populated the cache.
	val, err := env.rdb.Get(ctx, "redirect:"+slug).Bytes()
	require.NoError(t, err, "cache should be set after a miss")
	var target codes.CachedTarget
	require.NoError(t, json.Unmarshal(val, &target))
	require.Equal(t, "https://dest.example", target.Destination)

	// A scan event is recorded asynchronously; poll briefly for it.
	requireScanEventuallyRecorded(t, env, slug)
}

func TestRedirectCacheHit(t *testing.T) {
	env := newCodesEnv(t)
	ctx := context.Background()

	// Seed the cache for a slug that has NO database row. A successful redirect
	// proves the handler served from cache without touching Postgres.
	slug := "rdhit001"
	payload, _ := json.Marshal(codes.CachedTarget{Destination: "https://cached.example", CodeID: "00000000-0000-0000-0000-000000000000"})
	require.NoError(t, env.rdb.Set(ctx, "redirect:"+slug, payload, time.Hour).Err())
	t.Cleanup(func() { _ = env.rdb.Del(ctx, "redirect:"+slug).Err() })

	w := env.do(t, http.MethodGet, "/r/"+slug, "", "")
	require.Equal(t, http.StatusFound, w.Code)
	require.Equal(t, "https://cached.example", w.Header().Get("Location"))
}

func TestRedirectSlugNotFound(t *testing.T) {
	env := newCodesEnv(t)
	w := env.do(t, http.MethodGet, "/r/doesnotexist", "", "")
	require.Equal(t, http.StatusNotFound, w.Code)
	require.Contains(t, w.Body.String(), "no longer active")
	require.Contains(t, w.Header().Get("Content-Type"), "text/html")
}

// requireScanEventuallyRecorded polls scan_events for up to 200ms for a row
// matching slug (the scan insert is fire-and-forget).
func requireScanEventuallyRecorded(t *testing.T, env *codesEnv, slug string) {
	t.Helper()
	ctx := context.Background()
	deadline := time.Now().Add(200 * time.Millisecond)
	for {
		var n int
		err := env.pool.QueryRow(ctx, `SELECT count(*) FROM scan_events WHERE slug = $1`, slug).Scan(&n)
		require.NoError(t, err)
		if n >= 1 {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("no scan_events row recorded for slug %q within 200ms", slug)
		}
		time.Sleep(10 * time.Millisecond)
	}
}
