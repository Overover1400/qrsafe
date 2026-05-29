// DB strategy for handler tests: an in-memory fake repository (defined below)
// implements the auth.Repository interface. This keeps the HTTP/middleware/
// service path under test without requiring Postgres or Docker, so the handler
// tests run anywhere. The real SQL is covered separately by
// users/repository_test.go against a live Postgres.
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
	"github.com/Overover1400/qrsafe/internal/users"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

// fakeRepo is an in-memory users.Repository for tests.
type fakeRepo struct {
	mu      sync.Mutex
	byID    map[uuid.UUID]*users.User
	byEmail map[string]uuid.UUID
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		byID:    make(map[uuid.UUID]*users.User),
		byEmail: make(map[string]uuid.UUID),
	}
}

func (f *fakeRepo) Create(_ context.Context, u *users.User) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	u.ID = uuid.New()
	now := time.Now()
	u.CreatedAt = now
	u.UpdatedAt = now
	stored := *u
	f.byID[u.ID] = &stored
	return nil
}

func (f *fakeRepo) GetByID(_ context.Context, id uuid.UUID) (*users.User, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	u, ok := f.byID[id]
	if !ok {
		return nil, users.ErrNotFound
	}
	cp := *u
	return &cp, nil
}

func (f *fakeRepo) GetByEmail(_ context.Context, email string) (*users.User, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	id, ok := f.byEmail[strings.ToLower(email)]
	if !ok {
		return nil, users.ErrNotFound
	}
	u := f.byID[id]
	cp := *u
	return &cp, nil
}

func (f *fakeRepo) Update(_ context.Context, u *users.User) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.byID[u.ID]; !ok {
		return users.ErrNotFound
	}
	if u.Email != nil {
		key := strings.ToLower(*u.Email)
		if existing, ok := f.byEmail[key]; ok && existing != u.ID {
			return users.ErrEmailTaken
		}
		f.byEmail[key] = u.ID
	}
	u.UpdatedAt = time.Now()
	stored := *u
	f.byID[u.ID] = &stored
	return nil
}

// testEnv bundles the wired server and the token manager used to forge tokens.
type testEnv struct {
	handler http.Handler
	tokens  *auth.TokenManager
}

func newTestEnv(t *testing.T) *testEnv {
	t.Helper()
	tokens := auth.NewTokenManager([]byte("test-signing-secret-0123456789abc"), time.Hour)
	svc := auth.NewService(newFakeRepo(), tokens)

	health := handlers.NewHealthHandler(okPinger{}, okPinger{})
	authHandler := handlers.NewAuthHandler(svc)
	srv := httpserver.NewServer(":0", discardLogger(), tokens, health, authHandler)

	return &testEnv{handler: srv.Handler(), tokens: tokens}
}

func (e *testEnv) do(t *testing.T, method, path, token, body string) *httptest.ResponseRecorder {
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

type guestResp struct {
	User struct {
		ID      string  `json:"id"`
		Email   *string `json:"email"`
		IsGuest bool    `json:"is_guest"`
	} `json:"user"`
	Token     string `json:"token"`
	ExpiresAt string `json:"expires_at"`
}

func TestGuestCreatesUser(t *testing.T) {
	env := newTestEnv(t)

	w := env.do(t, http.MethodPost, "/api/v1/auth/guest", "", "")
	require.Equal(t, http.StatusCreated, w.Code)

	var resp guestResp
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	require.NotEmpty(t, resp.User.ID)
	require.True(t, resp.User.IsGuest)
	require.NotEmpty(t, resp.Token)

	claims, err := env.tokens.Verify(resp.Token)
	require.NoError(t, err)
	require.Equal(t, resp.User.ID, claims.Subject)
	require.True(t, claims.IsGuest)
}

func TestUpgradeWithBadJWTReturns401(t *testing.T) {
	env := newTestEnv(t)

	w := env.do(t, http.MethodPost, "/api/v1/auth/upgrade", "not-a-real-token",
		`{"email":"x@example.com","password":"password123"}`)
	require.Equal(t, http.StatusUnauthorized, w.Code)

	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
	require.Equal(t, "unauthorized", body.Error.Code)
}

func TestUpgradeWithGoodJWTPromotesUser(t *testing.T) {
	env := newTestEnv(t)

	// First become a guest.
	guestW := env.do(t, http.MethodPost, "/api/v1/auth/guest", "", "")
	require.Equal(t, http.StatusCreated, guestW.Code)
	var guest guestResp
	require.NoError(t, json.Unmarshal(guestW.Body.Bytes(), &guest))

	// Then upgrade with that guest token.
	upW := env.do(t, http.MethodPost, "/api/v1/auth/upgrade", guest.Token,
		`{"email":"new@example.com","password":"password123"}`)
	require.Equal(t, http.StatusOK, upW.Code)

	var up guestResp
	require.NoError(t, json.Unmarshal(upW.Body.Bytes(), &up))
	require.Equal(t, guest.User.ID, up.User.ID, "upgrade keeps the same user id")
	require.False(t, up.User.IsGuest)
	require.NotNil(t, up.User.Email)
	require.Equal(t, "new@example.com", *up.User.Email)

	claims, err := env.tokens.Verify(up.Token)
	require.NoError(t, err)
	require.False(t, claims.IsGuest, "new token should no longer be a guest token")
}

func TestUpgradeValidationError(t *testing.T) {
	env := newTestEnv(t)

	guestW := env.do(t, http.MethodPost, "/api/v1/auth/guest", "", "")
	var guest guestResp
	require.NoError(t, json.Unmarshal(guestW.Body.Bytes(), &guest))

	// Password too short.
	w := env.do(t, http.MethodPost, "/api/v1/auth/upgrade", guest.Token,
		`{"email":"new@example.com","password":"short"}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
}
