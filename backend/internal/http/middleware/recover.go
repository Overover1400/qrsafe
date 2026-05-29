package middleware

import (
	"log/slog"
	"net/http"

	"github.com/Overover1400/qrsafe/internal/http/response"
)

// Recover is a safety net: it converts a panic in any downstream handler into a
// logged 500 instead of crashing the server. Handlers should still return
// errors explicitly rather than relying on this.
func Recover(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					logger.LogAttrs(r.Context(), slog.LevelError, "panic recovered",
						slog.Any("panic", rec),
						slog.String("path", r.URL.Path),
					)
					response.Error(w, http.StatusInternalServerError, "internal_error", "internal server error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
