// Package auth provides authentication primitives: password hashing, JWT
// issuance/verification, request-context helpers, and the auth service that
// ties them to the user repository.
package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

// argon2id parameters. These are encoded into every hash so verification stays
// correct even if we tune them later.
const (
	argonTime    = 1
	argonMemory  = 64 * 1024 // 64 MiB
	argonThreads = 4
	argonKeyLen  = 32
	argonSaltLen = 16
)

var (
	// ErrInvalidHash is returned when a stored hash is not in the expected
	// PHC ($argon2id$...) format.
	ErrInvalidHash = errors.New("invalid password hash format")
	// ErrIncompatibleVersion is returned when a hash was produced by a
	// different argon2 version than this binary supports.
	ErrIncompatibleVersion = errors.New("incompatible argon2 version")
)

// HashPassword hashes password with argon2id and returns a self-describing PHC
// string of the form $argon2id$v=19$m=65536,t=1,p=4$<salt>$<hash>.
func HashPassword(password string) (string, error) {
	salt := make([]byte, argonSaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("generating salt: %w", err)
	}

	hash := argon2.IDKey([]byte(password), salt, argonTime, argonMemory, argonThreads, argonKeyLen)

	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)

	return fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version, argonMemory, argonTime, argonThreads, b64Salt, b64Hash), nil
}

// VerifyPassword reports whether password matches encodedHash. A false result
// with a nil error means the password simply did not match; a non-nil error
// means the stored hash could not be parsed.
func VerifyPassword(password, encodedHash string) (bool, error) {
	parts := strings.Split(encodedHash, "$")
	if len(parts) != 6 || parts[0] != "" || parts[1] != "argon2id" {
		return false, ErrInvalidHash
	}

	var version int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil {
		return false, fmt.Errorf("parsing argon2 version: %w", err)
	}
	if version != argon2.Version {
		return false, ErrIncompatibleVersion
	}

	var memory, time uint32
	var threads uint8
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &time, &threads); err != nil {
		return false, fmt.Errorf("parsing argon2 params: %w", err)
	}

	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false, fmt.Errorf("decoding salt: %w", err)
	}
	expected, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil {
		return false, fmt.Errorf("decoding hash: %w", err)
	}

	computed := argon2.IDKey([]byte(password), salt, time, memory, threads, uint32(len(expected)))
	return subtle.ConstantTimeCompare(computed, expected) == 1, nil
}
