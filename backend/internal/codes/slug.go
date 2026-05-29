package codes

import (
	"crypto/rand"
	"fmt"
)

// slugAlphabet is base62: digits, uppercase, lowercase. 62 symbols.
const slugAlphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

// SlugLength is the number of characters in a generated slug. 62^8 ≈ 2.18e14
// combinations, so collisions are astronomically unlikely; we still retry on the
// off chance (and to be correct under the UNIQUE constraint).
const SlugLength = 8

// GenerateSlug returns a cryptographically-random base62 slug of SlugLength
// characters. It uses crypto/rand so slugs are unguessable, not just unique.
func GenerateSlug() (string, error) {
	buf := make([]byte, SlugLength)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("reading random bytes: %w", err)
	}
	// Map each random byte into the alphabet. The modulo introduces a tiny bias
	// (256 is not a multiple of 62) that is irrelevant for slug uniqueness.
	for i, b := range buf {
		buf[i] = slugAlphabet[int(b)%len(slugAlphabet)]
	}
	return string(buf), nil
}
