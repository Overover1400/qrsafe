package handlers_test

import (
	"bytes"
	"image/png"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	httpserver "github.com/Overover1400/qrsafe/internal/http"
	"github.com/Overover1400/qrsafe/internal/http/handlers"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

// newQREnv wires a server with only the QR handler. QR rendering needs no
// Postgres or Redis, so these tests run anywhere; the token is forged directly.
func newQREnv(t *testing.T) (http.Handler, string) {
	t.Helper()
	tokens := auth.NewTokenManager([]byte("test-signing-secret-0123456789abc"), time.Hour)
	health := handlers.NewHealthHandler(okPinger{}, okPinger{})
	qrH := handlers.NewQRHandler()
	srv := httpserver.NewServer(":0", discardLogger(), tokens, health, nil, nil, nil, nil, qrH)
	token, _, err := tokens.Issue(uuid.New(), true, time.Now())
	require.NoError(t, err)
	return srv.Handler(), token
}

func postQR(t *testing.T, h http.Handler, token, query, body string) *httptest.ResponseRecorder {
	t.Helper()
	r := httptest.NewRequest(http.MethodPost, "/api/v1/qr"+query, strings.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}

func TestQRRequiresAuth(t *testing.T) {
	h, _ := newQREnv(t)
	w := postQR(t, h, "", "", `{"type":"url","payload":{"url":"https://example.com"}}`)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestQRRendersPNG(t *testing.T) {
	h, token := newQREnv(t)
	w := postQR(t, h, token, "", `{"type":"url","payload":{"url":"https://example.com"}}`)
	require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	require.Equal(t, "image/png", w.Header().Get("Content-Type"))

	body := w.Body.Bytes()
	require.True(t, bytes.HasPrefix(body, []byte{0x89, 'P', 'N', 'G'}))
	img, err := png.Decode(bytes.NewReader(body))
	require.NoError(t, err)
	require.Equal(t, img.Bounds().Dx(), img.Bounds().Dy())
}

func TestQRSizeParam(t *testing.T) {
	h, token := newQREnv(t)
	w := postQR(t, h, token, "?size=512", `{"type":"url","payload":{"url":"https://example.com"}}`)
	require.Equal(t, http.StatusOK, w.Code)
	img, err := png.Decode(bytes.NewReader(w.Body.Bytes()))
	require.NoError(t, err)
	require.GreaterOrEqual(t, img.Bounds().Dx(), 500)
}

func TestQRInvalidSize(t *testing.T) {
	h, token := newQREnv(t)
	w := postQR(t, h, token, "?size=abc", `{"type":"url","payload":{"url":"https://example.com"}}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "validation_error", errorCode(t, w.Body.Bytes()))
}

func TestQRUnsupportedType(t *testing.T) {
	h, token := newQREnv(t)
	w := postQR(t, h, token, "", `{"type":"wifi","payload":{"ssid":"x"}}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "unsupported_type", errorCode(t, w.Body.Bytes()))
}

func TestQRMissingURL(t *testing.T) {
	h, token := newQREnv(t)
	w := postQR(t, h, token, "", `{"type":"url","payload":{"foo":"bar"}}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "validation_error", errorCode(t, w.Body.Bytes()))
}

func TestQRInvalidECC(t *testing.T) {
	h, token := newQREnv(t)
	w := postQR(t, h, token, "?ecc=bogus", `{"type":"url","payload":{"url":"https://example.com"}}`)
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Equal(t, "validation_error", errorCode(t, w.Body.Bytes()))
}
