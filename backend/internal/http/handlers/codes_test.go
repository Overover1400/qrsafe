// These handler tests exercise the full request/response cycle for the codes
// endpoints against a live Postgres and Redis (same skip strategy as the codes
// repository tests). Tokens are forged for real Postgres users so the codes FK
// to users is satisfied — the in-memory auth fake used elsewhere wouldn't put a
// user in the database.
package handlers_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	"github.com/Overover1400/qrsafe/internal/codes"
	httpserver "github.com/Overover1400/qrsafe/internal/http"
	"github.com/Overover1400/qrsafe/internal/http/handlers"
	"github.com/Overover1400/qrsafe/internal/safety"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/require"
)

const codesSchemaSQL = `
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email CITEXT UNIQUE, password_hash TEXT,
  is_guest BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('url','wifi','vcard','email','text','sms')),
  payload JSONB NOT NULL, is_dynamic BOOLEAN NOT NULL DEFAULT FALSE, label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS codes_user_id_created_at_idx ON codes (user_id, created_at DESC);
CREATE TABLE IF NOT EXISTS dynamic_codes (
  code_id UUID PRIMARY KEY REFERENCES codes(id) ON DELETE CASCADE,
  slug TEXT NOT NULL UNIQUE, destination TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS dynamic_codes_slug_idx ON dynamic_codes (slug);
CREATE TABLE IF NOT EXISTS scan_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL, ip_hash TEXT, user_agent TEXT,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS scan_events_slug_scanned_at_idx ON scan_events (slug, scanned_at DESC);
`

type codesEnv struct {
	handler http.Handler
	tokens  *auth.TokenManager
	pool    *pgxpool.Pool
	rdb     *redis.Client
	repo    *codes.Repository
}

func dbURL() string {
	if u := os.Getenv("TEST_DATABASE_URL"); u != "" {
		return u
	}
	return os.Getenv("DATABASE_URL")
}

func newCodesEnv(t *testing.T) *codesEnv {
	t.Helper()
	url := dbURL()
	if url == "" {
		t.Skip("neither TEST_DATABASE_URL nor DATABASE_URL set; skipping live codes handler tests")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	require.NoError(t, err)
	require.NoError(t, pool.Ping(ctx), "could not reach test database")
	_, err = pool.Exec(ctx, codesSchemaSQL)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, `TRUNCATE scan_events, dynamic_codes, codes, users CASCADE`)
	require.NoError(t, err)
	t.Cleanup(pool.Close)

	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	db, _ := strconv.Atoi(os.Getenv("REDIS_DB"))
	rdb := redis.NewClient(&redis.Options{Addr: addr, Password: os.Getenv("REDIS_PASSWORD"), DB: db})
	if err := rdb.Ping(ctx).Err(); err != nil {
		_ = rdb.Close()
		t.Skip("redis not reachable; skipping: " + err.Error())
	}
	t.Cleanup(func() { _ = rdb.Close() })

	tokens := auth.NewTokenManager([]byte("test-signing-secret-0123456789abc"), time.Hour)
	repo := codes.NewRepository(pool)
	cache := codes.NewRedisCache(rdb)
	safetySvc := safety.NewService(safety.NewHeuristicChecker(), safety.NewRedisCache(rdb), discardLogger())
	codesSvc := codes.NewService(repo, cache, discardLogger(), safetySvc)
	redirectSvc := codes.NewRedirectService(repo, cache, discardLogger())

	health := handlers.NewHealthHandler(okPinger{}, okPinger{})
	codesH := handlers.NewCodesHandler(codesSvc, "http://test.local")
	redirectH := handlers.NewRedirectHandler(redirectSvc, discardLogger())
	safetyH := handlers.NewSafetyHandler(safetySvc)
	qrH := handlers.NewQRHandler()
	srv := httpserver.NewServer(":0", discardLogger(), tokens, httpserver.Handlers{
		Health:   health,
		Codes:    codesH,
		Redirect: redirectH,
		Safety:   safetyH,
		QR:       qrH,
	}, nil)

	return &codesEnv{handler: srv.Handler(), tokens: tokens, pool: pool, rdb: rdb, repo: repo}
}

// newUser inserts a guest user and returns its id plus a forged bearer token.
func (e *codesEnv) newUser(t *testing.T) (uuid.UUID, string) {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`INSERT INTO users (is_guest) VALUES (true) RETURNING id`).Scan(&id))
	tok, _, err := e.tokens.Issue(id, true, time.Now())
	require.NoError(t, err)
	return id, tok
}

func (e *codesEnv) do(t *testing.T, method, path, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	var r *http.Request
	if body != "" {
		r = httptest.NewRequest(method, path, strings.NewReader(body))
		r.Header.Set("Content-Type", "application/json")
	} else {
		r = httptest.NewRequest(method, path, nil)
	}
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	e.handler.ServeHTTP(w, r)
	return w
}

type codeEnvelopeResp struct {
	Code struct {
		ID        string          `json:"id"`
		Type      string          `json:"type"`
		Payload   json.RawMessage `json:"payload"`
		Label     *string         `json:"label"`
		IsDynamic bool            `json:"is_dynamic"`
	} `json:"code"`
	Dynamic *struct {
		Slug        string `json:"slug"`
		Destination string `json:"destination"`
		RedirectURL string `json:"redirect_url"`
	} `json:"dynamic"`
}

type listResp struct {
	Codes      []codeEnvelopeResp `json:"codes"`
	NextCursor *string            `json:"next_cursor"`
}

func TestCodesCreateStaticAndDynamic(t *testing.T) {
	env := newCodesEnv(t)
	_, token := env.newUser(t)

	// Static URL code.
	w := env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"url","payload":{"url":"https://example.com"},"label":"test","is_dynamic":false}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var static codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &static))
	require.NotEmpty(t, static.Code.ID)
	require.False(t, static.Code.IsDynamic)
	require.Nil(t, static.Dynamic)

	// Dynamic URL code.
	w = env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"url","payload":{"url":"https://example.com"},"is_dynamic":true}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var dyn codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &dyn))
	require.True(t, dyn.Code.IsDynamic)
	require.NotNil(t, dyn.Dynamic)
	require.Len(t, dyn.Dynamic.Slug, codes.SlugLength)
	require.Equal(t, "https://example.com", dyn.Dynamic.Destination)
	require.Equal(t, "http://test.local/r/"+dyn.Dynamic.Slug, dyn.Dynamic.RedirectURL)
}

func TestCodesCreateDynamicNonURLRejected(t *testing.T) {
	env := newCodesEnv(t)
	_, token := env.newUser(t)
	w := env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"text","payload":{"text":"hi"},"is_dynamic":true}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "dynamic_unsupported", errorCode(t, w.Body.Bytes()))
}

func TestCodesRequiresAuth(t *testing.T) {
	env := newCodesEnv(t)
	w := env.do(t, http.MethodGet, "/api/v1/codes", "", "")
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestCodesListGetPatchDelete(t *testing.T) {
	env := newCodesEnv(t)
	_, token := env.newUser(t)

	// Create one dynamic code.
	w := env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"url","payload":{"url":"https://one.example"},"label":"one","is_dynamic":true}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var created codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &created))
	id := created.Code.ID

	// List shows it.
	w = env.do(t, http.MethodGet, "/api/v1/codes", token, "")
	require.Equal(t, http.StatusOK, w.Code)
	var list listResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &list))
	require.Len(t, list.Codes, 1)
	require.Equal(t, id, list.Codes[0].Code.ID)
	require.NotNil(t, list.Codes[0].Dynamic)

	// Get one.
	w = env.do(t, http.MethodGet, "/api/v1/codes/"+id, token, "")
	require.Equal(t, http.StatusOK, w.Code)

	// Patch label + destination.
	w = env.do(t, http.MethodPatch, "/api/v1/codes/"+id, token,
		`{"label":"renamed","destination":"https://two.example"}`)
	require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	var patched codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &patched))
	require.Equal(t, "renamed", *patched.Code.Label)
	require.Equal(t, "https://two.example", patched.Dynamic.Destination)

	// Delete → 204, then gone.
	w = env.do(t, http.MethodDelete, "/api/v1/codes/"+id, token, "")
	require.Equal(t, http.StatusNoContent, w.Code)
	require.Empty(t, w.Body.String())

	w = env.do(t, http.MethodGet, "/api/v1/codes/"+id, token, "")
	require.Equal(t, http.StatusNotFound, w.Code)
}

func TestCodesOwnershipIsolation(t *testing.T) {
	env := newCodesEnv(t)
	_, ownerToken := env.newUser(t)
	_, otherToken := env.newUser(t)

	w := env.do(t, http.MethodPost, "/api/v1/codes", ownerToken,
		`{"type":"text","payload":{"text":"secret"}}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var created codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &created))
	id := created.Code.ID

	// The other user gets 404 for get/patch/delete — never 403, to avoid
	// leaking existence.
	require.Equal(t, http.StatusNotFound, env.do(t, http.MethodGet, "/api/v1/codes/"+id, otherToken, "").Code)
	require.Equal(t, http.StatusNotFound, env.do(t, http.MethodPatch, "/api/v1/codes/"+id, otherToken, `{"label":"x"}`).Code)
	require.Equal(t, http.StatusNotFound, env.do(t, http.MethodDelete, "/api/v1/codes/"+id, otherToken, "").Code)

	// The other user's list is empty.
	w = env.do(t, http.MethodGet, "/api/v1/codes", otherToken, "")
	require.Equal(t, http.StatusOK, w.Code)
	var list listResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &list))
	require.Empty(t, list.Codes)
}

func TestCodesPatchDestinationOnStaticRejected(t *testing.T) {
	env := newCodesEnv(t)
	_, token := env.newUser(t)
	w := env.do(t, http.MethodPost, "/api/v1/codes", token, `{"type":"text","payload":{"text":"hi"}}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var created codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &created))

	w = env.do(t, http.MethodPatch, "/api/v1/codes/"+created.Code.ID, token, `{"destination":"https://x.example"}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "not_dynamic", errorCode(t, w.Body.Bytes()))
}

func TestCodesCreateDynamicUnsafeDestinationRejected(t *testing.T) {
	env := newCodesEnv(t)
	_, token := env.newUser(t)
	// A javascript: destination is classified malicious → creation blocked.
	w := env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"url","payload":{"url":"javascript:alert(1)"},"is_dynamic":true}`)
	require.Equal(t, http.StatusBadRequest, w.Code, w.Body.String())
	require.Equal(t, "unsafe_destination", errorCode(t, w.Body.Bytes()))
}

func TestCodesPatchUnsafeDestinationRejected(t *testing.T) {
	env := newCodesEnv(t)
	_, token := env.newUser(t)
	// Create a safe dynamic code first.
	w := env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"url","payload":{"url":"https://example.com"},"is_dynamic":true}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var created codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &created))

	// Patching to a blocklisted destination is rejected.
	w = env.do(t, http.MethodPatch, "/api/v1/codes/"+created.Code.ID, token,
		`{"destination":"https://evil.example/login"}`)
	require.Equal(t, http.StatusBadRequest, w.Code, w.Body.String())
	require.Equal(t, "unsafe_destination", errorCode(t, w.Body.Bytes()))
}

type analyticsResp struct {
	Analytics struct {
		CodeID         string `json:"code_id"`
		TotalScans     int    `json:"total_scans"`
		UniqueVisitors int    `json:"unique_visitors"`
		Daily          []struct {
			Date  string `json:"date"`
			Count int    `json:"count"`
		} `json:"daily"`
		TopUserAgents []struct {
			UserAgent string `json:"user_agent"`
			Count     int    `json:"count"`
		} `json:"top_user_agents"`
	} `json:"analytics"`
}

func TestCodesAnalytics(t *testing.T) {
	env := newCodesEnv(t)
	ctx := context.Background()
	_, token := env.newUser(t)

	// Create a dynamic code and record a few scans for its slug.
	w := env.do(t, http.MethodPost, "/api/v1/codes", token,
		`{"type":"url","payload":{"url":"https://example.com"},"is_dynamic":true}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var created codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &created))
	slug := created.Dynamic.Slug
	for _, ip := range []string{"ip-1", "ip-1", "ip-2"} {
		ipc := ip
		require.NoError(t, env.repo.InsertScanEvent(ctx, &codes.ScanEvent{Slug: slug, IPHash: &ipc, UserAgent: ptrString("curl/8")}))
	}

	w = env.do(t, http.MethodGet, "/api/v1/codes/"+created.Code.ID+"/analytics", token, "")
	require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	var resp analyticsResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	require.Equal(t, created.Code.ID, resp.Analytics.CodeID)
	require.Equal(t, 3, resp.Analytics.TotalScans)
	require.Equal(t, 2, resp.Analytics.UniqueVisitors)
	require.Len(t, resp.Analytics.Daily, 1)
	require.Len(t, resp.Analytics.TopUserAgents, 1)
}

func TestCodesAnalyticsOwnershipAndStatic(t *testing.T) {
	env := newCodesEnv(t)
	_, ownerToken := env.newUser(t)
	_, otherToken := env.newUser(t)

	// A static code → zeros, never null slices.
	w := env.do(t, http.MethodPost, "/api/v1/codes", ownerToken, `{"type":"text","payload":{"text":"hi"}}`)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var created codeEnvelopeResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &created))

	w = env.do(t, http.MethodGet, "/api/v1/codes/"+created.Code.ID+"/analytics", ownerToken, "")
	require.Equal(t, http.StatusOK, w.Code)
	var resp analyticsResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	require.Equal(t, 0, resp.Analytics.TotalScans)
	require.NotNil(t, resp.Analytics.Daily)
	require.NotNil(t, resp.Analytics.TopUserAgents)

	// Another user gets 404 (not 403) — no existence leak.
	w = env.do(t, http.MethodGet, "/api/v1/codes/"+created.Code.ID+"/analytics", otherToken, "")
	require.Equal(t, http.StatusNotFound, w.Code)
}

func ptrString(s string) *string { return &s }

// errorCode extracts error.code from an error envelope body.
func errorCode(t *testing.T, body []byte) string {
	t.Helper()
	var e struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	require.NoError(t, json.Unmarshal(body, &e))
	return e.Error.Code
}
