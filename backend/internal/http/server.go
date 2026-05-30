// Package http wires routes and middleware onto a chi router and manages the
// underlying http.Server lifecycle, including graceful shutdown.
package http

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	"github.com/Overover1400/qrsafe/internal/http/handlers"
	mw "github.com/Overover1400/qrsafe/internal/http/middleware"
	"github.com/go-chi/chi/v5"
)

// Server owns the configured http.Server and its router.
type Server struct {
	httpServer *http.Server
	logger     *slog.Logger
}

// Handlers bundles the route handlers NewServer mounts. Grouping them keeps the
// constructor signature stable as endpoints are added.
type Handlers struct {
	Health   *handlers.HealthHandler
	Auth     *handlers.AuthHandler
	Codes    *handlers.CodesHandler
	Redirect *handlers.RedirectHandler
	Safety   *handlers.SafetyHandler
	QR       *handlers.QRHandler
}

// NewServer builds the router, mounts middleware and routes, and returns a
// Server ready to Start.
func NewServer(addr string, logger *slog.Logger, tokens *auth.TokenManager, h Handlers) *Server {
	r := chi.NewRouter()
	r.Use(mw.Recover(logger))
	r.Use(mw.Logger(logger))

	r.Get("/health", h.Health.Health)

	// Public, unauthenticated redirect for dynamic QR codes. Mounted at the
	// root (outside /api/v1) so scanned codes resolve without a token.
	r.Get("/r/{slug}", h.Redirect.Redirect)

	r.Route("/api/v1", func(r chi.Router) {
		r.Route("/auth", func(r chi.Router) {
			r.Post("/guest", h.Auth.Guest)

			// Protected: requires a valid bearer token.
			r.Group(func(r chi.Router) {
				r.Use(mw.Auth(tokens))
				r.Post("/upgrade", h.Auth.Upgrade)
			})
		})

		// Codes CRUD — all protected; guest and full accounts may both manage
		// their own codes.
		r.Group(func(r chi.Router) {
			r.Use(mw.Auth(tokens))
			r.Post("/codes", h.Codes.Create)
			r.Get("/codes", h.Codes.List)
			r.Get("/codes/{id}", h.Codes.Get)
			r.Patch("/codes/{id}", h.Codes.Update)
			r.Delete("/codes/{id}", h.Codes.Delete)
			r.Get("/codes/{id}/analytics", h.Codes.Analytics)

			// URL safety check.
			r.Post("/scan/check", h.Safety.Check)

			// QR image generation (stateless).
			r.Post("/qr", h.QR.Generate)
		})
	})

	return &Server{
		httpServer: &http.Server{
			Addr:              addr,
			Handler:           r,
			ReadHeaderTimeout: 10 * time.Second,
		},
		logger: logger,
	}
}

// Handler exposes the router for testing with httptest.
func (s *Server) Handler() http.Handler {
	return s.httpServer.Handler
}

// Start blocks serving HTTP until the server is closed. A clean shutdown
// (http.ErrServerClosed) is not treated as an error.
func (s *Server) Start() error {
	s.logger.Info("http server listening", slog.String("addr", s.httpServer.Addr))
	if err := s.httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("http server: %w", err)
	}
	return nil
}

// Shutdown gracefully drains in-flight requests, bounded by ctx.
func (s *Server) Shutdown(ctx context.Context) error {
	if err := s.httpServer.Shutdown(ctx); err != nil {
		return fmt.Errorf("shutting down http server: %w", err)
	}
	return nil
}
