package auth

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestHashAndVerifyPassword(t *testing.T) {
	const password = "correct horse battery staple"

	hash, err := HashPassword(password)
	require.NoError(t, err)
	require.True(t, strings.HasPrefix(hash, "$argon2id$"), "hash should be a PHC argon2id string")

	ok, err := VerifyPassword(password, hash)
	require.NoError(t, err)
	require.True(t, ok, "correct password should verify")
}

func TestVerifyPasswordWrong(t *testing.T) {
	hash, err := HashPassword("the right one")
	require.NoError(t, err)

	ok, err := VerifyPassword("the wrong one", hash)
	require.NoError(t, err)
	require.False(t, ok, "wrong password must not verify")
}

func TestHashPasswordIsSalted(t *testing.T) {
	h1, err := HashPassword("same-password")
	require.NoError(t, err)
	h2, err := HashPassword("same-password")
	require.NoError(t, err)
	require.NotEqual(t, h1, h2, "each hash should use a fresh random salt")
}

func TestVerifyPasswordMalformedHash(t *testing.T) {
	_, err := VerifyPassword("whatever", "not-a-valid-hash")
	require.ErrorIs(t, err, ErrInvalidHash)
}
