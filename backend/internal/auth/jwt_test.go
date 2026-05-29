package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

func TestIssueAndVerify(t *testing.T) {
	tm := NewTokenManager([]byte("super-secret-signing-key-0123456789"), 7*24*time.Hour)
	id := uuid.New()
	now := time.Now()

	token, expiresAt, err := tm.Issue(id, true, now)
	require.NoError(t, err)
	require.NotEmpty(t, token)
	require.WithinDuration(t, now.Add(7*24*time.Hour), expiresAt, time.Second)

	claims, err := tm.Verify(token)
	require.NoError(t, err)
	require.Equal(t, id.String(), claims.Subject)
	require.True(t, claims.IsGuest)
}

func TestVerifyExpiredToken(t *testing.T) {
	tm := NewTokenManager([]byte("super-secret-signing-key-0123456789"), time.Hour)
	id := uuid.New()

	// Issued far enough in the past that it is already expired.
	token, _, err := tm.Issue(id, false, time.Now().Add(-2*time.Hour))
	require.NoError(t, err)

	_, err = tm.Verify(token)
	require.Error(t, err, "expired token must be rejected")
}

func TestVerifyWrongSecret(t *testing.T) {
	issuer := NewTokenManager([]byte("the-correct-signing-secret-0123456"), time.Hour)
	verifier := NewTokenManager([]byte("a-different-signing-secret-9876543"), time.Hour)

	token, _, err := issuer.Issue(uuid.New(), false, time.Now())
	require.NoError(t, err)

	_, err = verifier.Verify(token)
	require.Error(t, err, "token signed with another secret must be rejected")
}
