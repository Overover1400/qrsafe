package codes_test

import (
	"strings"
	"testing"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/stretchr/testify/require"
)

const slugAlphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

func TestGenerateSlugLengthAndAlphabet(t *testing.T) {
	for i := 0; i < 1000; i++ {
		s, err := codes.GenerateSlug()
		require.NoError(t, err)
		require.Len(t, s, codes.SlugLength)
		for _, c := range s {
			require.True(t, strings.ContainsRune(slugAlphabet, c),
				"slug %q contains out-of-alphabet rune %q", s, c)
		}
	}
}

func TestGenerateSlugIsRandom(t *testing.T) {
	// Over 1000 calls, no two consecutive slugs should match and the set should
	// be essentially all-unique. Collisions in 62^8 space are astronomically
	// improbable, so any repeat almost certainly signals a broken generator.
	seen := make(map[string]struct{}, 1000)
	prev := ""
	for i := 0; i < 1000; i++ {
		s, err := codes.GenerateSlug()
		require.NoError(t, err)
		require.NotEqual(t, prev, s, "consecutive slugs must differ")
		seen[s] = struct{}{}
		prev = s
	}
	require.Equal(t, 1000, len(seen), "all 1000 generated slugs should be unique")
}
