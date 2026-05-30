package safety

import (
	"net"
	"net/url"
	"strings"
)

// Checker classifies a raw URL. Implementations must be safe for concurrent use.
type Checker interface {
	Check(rawURL string) Result
}

// dangerousSchemes are schemes that should never appear in a scanned "URL" code
// — they execute code or read local resources rather than navigating the web.
var dangerousSchemes = map[string]struct{}{
	"javascript": {}, "data": {}, "vbscript": {}, "file": {}, "blob": {},
}

// defaultBlocklist is a small built-in set of hosts treated as malicious. The
// test/example TLDs are reserved (RFC 2606/6761) so they make safe fixtures and
// real placeholders until a real feed is wired in.
var defaultBlocklist = map[string]struct{}{
	"malware.test":     {},
	"phishing.test":    {},
	"evil.example":     {},
	"malware.example":  {},
	"phishing.example": {},
}

// defaultShorteners are link-shortener hosts: legitimate, but the final
// destination is hidden, so we flag them as suspicious.
var defaultShorteners = map[string]struct{}{
	"bit.ly": {}, "tinyurl.com": {}, "t.co": {}, "goo.gl": {},
	"ow.ly": {}, "is.gd": {}, "buff.ly": {}, "rebrand.ly": {},
}

// HeuristicChecker classifies URLs using local heuristics only.
type HeuristicChecker struct {
	blocklist  map[string]struct{}
	shorteners map[string]struct{}
}

// NewHeuristicChecker returns a checker with the built-in blocklist and
// shortener list.
func NewHeuristicChecker() *HeuristicChecker {
	return &HeuristicChecker{blocklist: defaultBlocklist, shorteners: defaultShorteners}
}

// Check evaluates rawURL and returns a verdict with the reasons behind it.
func (c *HeuristicChecker) Check(rawURL string) Result {
	res := Result{URL: rawURL, Reasons: []Reason{}}
	sev := sevSafe
	add := func(s int, code, msg string) {
		if s > sev {
			sev = s
		}
		res.Reasons = append(res.Reasons, Reason{Code: code, Message: msg})
	}

	u, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil {
		add(sevMalicious, ReasonUnparseableURL, "URL could not be parsed")
		res.Verdict = verdictForSeverity(sev)
		return res
	}

	scheme := strings.ToLower(u.Scheme)
	switch {
	case scheme == "http" || scheme == "https":
		// Web schemes: continue to host-based checks below.
	case scheme == "":
		add(sevMalicious, ReasonDisallowedScheme, "URL has no scheme")
	default:
		if _, bad := dangerousSchemes[scheme]; bad {
			add(sevMalicious, ReasonDisallowedScheme, "scheme is not allowed for web links: "+scheme)
		} else {
			add(sevSuspicious, ReasonUncommonScheme, "uncommon URL scheme: "+scheme)
		}
	}

	if scheme == "http" || scheme == "https" {
		host := strings.ToLower(u.Hostname())
		switch {
		case host == "":
			add(sevMalicious, ReasonMissingHost, "URL has no host")
		default:
			if u.User != nil {
				add(sevSuspicious, ReasonEmbeddedCredentials, "URL contains embedded credentials")
			}
			if net.ParseIP(host) != nil {
				add(sevSuspicious, ReasonIPLiteralHost, "host is a raw IP address")
			}
			if strings.Contains(host, "xn--") {
				add(sevSuspicious, ReasonPunycodeHost, "host uses punycode (possible homograph attack)")
			}
			if len(host) > 100 {
				add(sevSuspicious, ReasonLongHost, "host is unusually long")
			}
			if c.isBlocklisted(host) {
				add(sevMalicious, ReasonBlocklistedHost, "host is on the blocklist")
			}
			if _, short := c.shorteners[host]; short {
				add(sevSuspicious, ReasonURLShortener, "host is a URL shortener; final destination is hidden")
			}
		}
	}

	res.Verdict = verdictForSeverity(sev)
	return res
}

// isBlocklisted matches the host exactly or as a subdomain of a blocklisted
// domain (e.g. "login.evil.example" matches "evil.example").
func (c *HeuristicChecker) isBlocklisted(host string) bool {
	if _, ok := c.blocklist[host]; ok {
		return true
	}
	for bad := range c.blocklist {
		if strings.HasSuffix(host, "."+bad) {
			return true
		}
	}
	return false
}
