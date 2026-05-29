package middleware

import (
	"net/http"
	"strings"

	"github.com/Overover1400/qrsafe/internal/auth"
	"github.com/Overover1400/qrsafe/internal/http/response"
	"github.com/google/uuid"
)

// Auth validates the bearer token on each request and stashes the user id and
// is_guest claim into the request context for downstream handlers. Any failure
// short-circuits with a 401 in the standard error shape.
func Auth(tokens *auth.TokenManager) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if header == "" {
				response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authorization header")
				return
			}

			scheme, token, ok := strings.Cut(header, " ")
			if !ok || !strings.EqualFold(scheme, "Bearer") || token == "" {
				response.Error(w, http.StatusUnauthorized, "unauthorized", "malformed authorization header")
				return
			}

			claims, err := tokens.Verify(token)
			if err != nil {
				response.Error(w, http.StatusUnauthorized, "unauthorized", "invalid or expired token")
				return
			}

			userID, err := uuid.Parse(claims.Subject)
			if err != nil {
				response.Error(w, http.StatusUnauthorized, "unauthorized", "invalid subject claim")
				return
			}

			ctx := auth.WithUserID(r.Context(), userID)
			ctx = auth.WithIsGuest(ctx, claims.IsGuest)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
