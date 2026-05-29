// Package users owns the user domain model and its persistence.
package users

import (
	"time"

	"github.com/google/uuid"
)

// User is the canonical representation of a user row. Email and PasswordHash
// are nil for guest users (they only get set on upgrade), which is why they
// are pointers rather than plain strings.
type User struct {
	ID           uuid.UUID
	Email        *string
	PasswordHash *string
	IsGuest      bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
