package handlers

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/go-chi/chi/v5"
)

// RedirectService is the surface the public redirect handler depends on.
type RedirectService interface {
	Resolve(ctx context.Context, slug string) (string, error)
	RecordScan(ctx context.Context, slug, ipHash, userAgent string)
}

// RedirectHandler serves the public GET /r/{slug} endpoint.
type RedirectHandler struct {
	svc RedirectService
	log *slog.Logger
}

// NewRedirectHandler constructs a RedirectHandler.
func NewRedirectHandler(svc RedirectService, log *slog.Logger) *RedirectHandler {
	return &RedirectHandler{svc: svc, log: log}
}

// scanRecordTimeout bounds the fire-and-forget scan insert that runs after the
// response is sent.
const scanRecordTimeout = 500 * time.Millisecond

const notActiveHTML = `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Code not active</title></head>
<body><h1>This code is no longer active</h1></body>
</html>
`

// Redirect resolves the slug to its current destination and issues a 302. An
// unknown slug returns a minimal 404 HTML page. After responding it records the
// scan asynchronously (hashed IP, user agent) without blocking the redirect.
func (h *RedirectHandler) Redirect(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	dest, err := h.svc.Resolve(r.Context(), slug)
	if err != nil {
		if errors.Is(err, codes.ErrNotFound) {
			h.log.Info("redirect slug not found", slog.String("slug", slug))
		} else {
			h.log.Error("resolving redirect failed",
				slog.String("slug", slug), slog.String("error", err.Error()))
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(notActiveHTML))
		return
	}

	// Record the scan after the redirect, decoupled from the request lifecycle:
	// a fresh, short-lived context so it survives the response but can't hang.
	ipHash := codes.HashIP(clientIP(r))
	userAgent := r.UserAgent()
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), scanRecordTimeout)
		defer cancel()
		h.svc.RecordScan(ctx, slug, ipHash, userAgent)
	}()

	http.Redirect(w, r, dest, http.StatusFound)
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
