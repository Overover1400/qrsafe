package safety_test

import (
	"testing"

	"github.com/Overover1400/qrsafe/internal/safety"
	"github.com/stretchr/testify/require"
)

func TestHeuristicChecker(t *testing.T) {
	c := safety.NewHeuristicChecker()

	cases := []struct {
		name        string
		url         string
		want        safety.Verdict
		wantReason  string // a reason code that must be present ("" = none required)
	}{
		{"plain https", "https://example.com/path", safety.VerdictSafe, ""},
		{"plain http", "http://example.com", safety.VerdictSafe, ""},
		{"javascript scheme", "javascript:alert(1)", safety.VerdictMalicious, safety.ReasonDisallowedScheme},
		{"data scheme", "data:text/html,<script>", safety.VerdictMalicious, safety.ReasonDisallowedScheme},
		{"file scheme", "file:///etc/passwd", safety.VerdictMalicious, safety.ReasonDisallowedScheme},
		{"blocklisted host", "https://evil.example/login", safety.VerdictMalicious, safety.ReasonBlocklistedHost},
		{"blocklisted subdomain", "https://login.evil.example", safety.VerdictMalicious, safety.ReasonBlocklistedHost},
		{"ip literal host", "http://192.168.1.1/admin", safety.VerdictSuspicious, safety.ReasonIPLiteralHost},
		{"punycode host", "https://xn--80ak6aa92e.com", safety.VerdictSuspicious, safety.ReasonPunycodeHost},
		{"embedded credentials", "https://user:pass@example.com", safety.VerdictSuspicious, safety.ReasonEmbeddedCredentials},
		{"url shortener", "https://bit.ly/abc123", safety.VerdictSuspicious, safety.ReasonURLShortener},
		{"uncommon scheme", "ftp://files.example.com/x", safety.VerdictSuspicious, safety.ReasonUncommonScheme},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			res := c.Check(tc.url)
			require.Equal(t, tc.want, res.Verdict, "reasons: %+v", res.Reasons)
			require.Equal(t, tc.url, res.URL)
			if tc.wantReason != "" {
				require.True(t, hasReason(res, tc.wantReason),
					"expected reason %q in %+v", tc.wantReason, res.Reasons)
			}
			if tc.want == safety.VerdictSafe {
				require.Empty(t, res.Reasons)
			}
		})
	}
}

func TestHeuristicCheckerMaliciousWins(t *testing.T) {
	// A blocklisted host that is also an IP-literal-style suspicious signal must
	// still come out malicious (worst signal wins).
	res := safety.NewHeuristicChecker().Check("https://user:pass@evil.example")
	require.Equal(t, safety.VerdictMalicious, res.Verdict)
}

func hasReason(r safety.Result, code string) bool {
	for _, reason := range r.Reasons {
		if reason.Code == code {
			return true
		}
	}
	return false
}
