package auth

import (
	"context"

	"github.com/google/uuid"
)

// contextKey is an unexported type so values stashed by this package cannot
// collide with keys set elsewhere.
type contextKey int

const (
	userIDKey contextKey = iota
	isGuestKey
)

// WithUserID returns a copy of ctx carrying the authenticated user id.
func WithUserID(ctx context.Context, id uuid.UUID) context.Context {
	return context.WithValue(ctx, userIDKey, id)
}

// UserIDFromContext retrieves the authenticated user id set by the auth
// middleware. The boolean reports whether a value was present.
func UserIDFromContext(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}

// WithIsGuest returns a copy of ctx carrying the token's is_guest claim.
func WithIsGuest(ctx context.Context, isGuest bool) context.Context {
	return context.WithValue(ctx, isGuestKey, isGuest)
}

// IsGuestFromContext retrieves the is_guest claim set by the auth middleware.
func IsGuestFromContext(ctx context.Context) (bool, bool) {
	g, ok := ctx.Value(isGuestKey).(bool)
	return g, ok
}
