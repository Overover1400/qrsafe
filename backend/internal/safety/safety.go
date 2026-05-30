// Package safety implements a URL safety check used by the /scan/check endpoint
// and to gate dynamic-code destinations. The current checker is local-only
// (heuristics, no external reputation API), so it is deterministic and needs no
// secrets or network egress. A Checker interface keeps the door open for adding
// an external provider later without changing callers.
package safety

// Verdict is the overall classification of a URL.
type Verdict string

const (
	VerdictSafe       Verdict = "safe"
	VerdictSuspicious Verdict = "suspicious"
	VerdictMalicious  Verdict = "malicious"
)

// Reason codes explain why a verdict was reached. They are stable identifiers
// the client can branch on; Message is human-readable detail.
const (
	ReasonDisallowedScheme    = "disallowed_scheme"
	ReasonUncommonScheme      = "uncommon_scheme"
	ReasonMissingHost         = "missing_host"
	ReasonEmbeddedCredentials = "embedded_credentials"
	ReasonIPLiteralHost       = "ip_literal_host"
	ReasonPunycodeHost        = "punycode_host"
	ReasonLongHost            = "long_host"
	ReasonBlocklistedHost     = "blocklisted_host"
	ReasonURLShortener        = "url_shortener"
	ReasonUnparseableURL      = "unparseable_url"
)

// Reason is a single signal contributing to a verdict.
type Reason struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Result is the outcome of checking one URL.
type Result struct {
	URL     string   `json:"url"`
	Verdict Verdict  `json:"verdict"`
	Reasons []Reason `json:"reasons"`
	Cached  bool     `json:"cached"`
}

// severity ranks verdicts so the worst signal wins.
const (
	sevSafe = iota
	sevSuspicious
	sevMalicious
)

func verdictForSeverity(sev int) Verdict {
	switch {
	case sev >= sevMalicious:
		return VerdictMalicious
	case sev >= sevSuspicious:
		return VerdictSuspicious
	default:
		return VerdictSafe
	}
}
