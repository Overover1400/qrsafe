package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// ErrInvalidToken is returned when a token parses but fails validation.
var ErrInvalidToken = errors.New("invalid token")

// Claims is the JWT payload carried by access tokens.
type Claims struct {
	IsGuest bool `json:"is_guest"`
	jwt.RegisteredClaims
}

// TokenManager issues and verifies HS256 JWTs.
type TokenManager struct {
	secret []byte
	ttl    time.Duration
}

// NewTokenManager constructs a TokenManager with the given signing secret and
// token lifetime.
func NewTokenManager(secret []byte, ttl time.Duration) *TokenManager {
	return &TokenManager{secret: secret, ttl: ttl}
}

// Issue mints a signed token for userID. now is injected so callers (and tests)
// control the issued-at/expiry basis. It returns the token and its expiry.
func (m *TokenManager) Issue(userID uuid.UUID, isGuest bool, now time.Time) (string, time.Time, error) {
	expiresAt := now.Add(m.ttl)
	claims := Claims{
		IsGuest: isGuest,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(m.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("signing token: %w", err)
	}
	return signed, expiresAt, nil
}

// Verify parses and validates tokenString, returning its claims. It rejects any
// token not signed with HMAC and any expired or otherwise invalid token.
func (m *TokenManager) Verify(tokenString string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return m.secret, nil
	})
	if err != nil {
		return nil, fmt.Errorf("parsing token: %w", err)
	}
	if !token.Valid {
		return nil, ErrInvalidToken
	}
	return claims, nil
}
