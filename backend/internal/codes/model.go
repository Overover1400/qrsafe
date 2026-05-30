// Package codes owns the QR-code domain: static and dynamic codes, their
// persistence, slug generation for dynamic redirects, and the public redirect
// path with its Redis cache.
package codes

import (
	"bytes"
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// CodeType enumerates the kinds of payload a code can carry. Only "url" codes
// may be dynamic.
type CodeType string

const (
	TypeURL   CodeType = "url"
	TypeWifi  CodeType = "wifi"
	TypeVCard CodeType = "vcard"
	TypeEmail CodeType = "email"
	TypeText  CodeType = "text"
	TypeSMS   CodeType = "sms"
)

// Code is a row in the codes table. Payload is stored as JSONB; its inner shape
// depends on Type and is not validated beyond "is a JSON object" for now.
// Dynamic is populated (via a LEFT JOIN) only for dynamic codes.
type Code struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Type      string
	Payload   json.RawMessage
	IsDynamic bool
	Label     *string
	CreatedAt time.Time
	UpdatedAt time.Time

	Dynamic *DynamicCode
}

// DynamicCode is the dynamic_codes row backing a dynamic code: a short slug that
// the public /r/{slug} endpoint resolves to the current destination.
type DynamicCode struct {
	CodeID      uuid.UUID
	Slug        string
	Destination string
	UpdatedAt   time.Time
}

// ScanEvent is an append-only record of a redirect being followed.
type ScanEvent struct {
	ID        uuid.UUID
	Slug      string
	IPHash    *string
	UserAgent *string
	ScannedAt time.Time
}

// Analytics summarizes the scan activity for a single code (all-time).
type Analytics struct {
	CodeID         uuid.UUID
	TotalScans     int
	UniqueVisitors int // distinct non-null ip_hash values
	Daily          []DayCount
	TopUserAgents  []UserAgentCount
}

// DayCount is a single day's scan total. Date is "YYYY-MM-DD" in UTC.
type DayCount struct {
	Date  string
	Count int
}

// UserAgentCount is a scan total for one user-agent string.
type UserAgentCount struct {
	UserAgent string
	Count     int
}

// IsJSONObject reports whether b is a syntactically valid JSON object ({...}).
// Arrays, scalars and null are rejected.
func IsJSONObject(b []byte) bool {
	t := bytes.TrimSpace(b)
	if len(t) == 0 || t[0] != '{' {
		return false
	}
	var m map[string]json.RawMessage
	return json.Unmarshal(t, &m) == nil
}
