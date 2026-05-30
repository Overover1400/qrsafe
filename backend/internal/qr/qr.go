// Package qr renders QR-code images. v1 is stateless and PNG-only, and encodes
// "url" payloads (the caller passes the exact URL to encode — for a dynamic code
// that is its /r/{slug} link). Other code types are not yet supported; their
// canonical encoders (WIFI:, mailto:, SMSTO:, vCard, …) are intentionally
// deferred to avoid diverging from the client's encoding.
package qr

import (
	"encoding/json"
	"errors"
	"fmt"

	qrcode "github.com/skip2/go-qrcode"
)

// Sentinel errors callers branch on with errors.Is.
var (
	ErrUnsupportedType = errors.New("unsupported code type for qr generation")
	ErrMissingURL      = errors.New("url payload requires a non-empty url")
)

// ECC is the QR error-correction level.
type ECC string

const (
	ECCLow     ECC = "low"
	ECCMedium  ECC = "medium"
	ECCHigh    ECC = "high"
	ECCHighest ECC = "highest"
)

// Image size bounds (pixels along an edge) and defaults.
const (
	DefaultSize = 256
	MinSize     = 64
	MaxSize     = 2048
	DefaultECC  = ECCMedium
)

// ValidECC reports whether e is a recognized error-correction level.
func ValidECC(e ECC) bool {
	switch e {
	case ECCLow, ECCMedium, ECCHigh, ECCHighest:
		return true
	default:
		return false
	}
}

// Content returns the string to encode for a code type + payload. v1 supports
// only "url"; everything else returns ErrUnsupportedType.
func Content(codeType string, payload []byte) (string, error) {
	switch codeType {
	case "url":
		var p struct {
			URL string `json:"url"`
		}
		if err := json.Unmarshal(payload, &p); err != nil {
			return "", fmt.Errorf("decoding url payload: %w", err)
		}
		if p.URL == "" {
			return "", ErrMissingURL
		}
		return p.URL, nil
	default:
		return "", ErrUnsupportedType
	}
}

// PNG renders content as a PNG QR code, size pixels along each edge, at the
// given error-correction level.
func PNG(content string, size int, ecc ECC) ([]byte, error) {
	if content == "" {
		return nil, errors.New("empty qr content")
	}
	png, err := qrcode.Encode(content, recoveryLevel(ecc), size)
	if err != nil {
		return nil, fmt.Errorf("encoding qr png: %w", err)
	}
	return png, nil
}

// ClampSize bounds a requested size to [MinSize, MaxSize].
func ClampSize(size int) int {
	if size < MinSize {
		return MinSize
	}
	if size > MaxSize {
		return MaxSize
	}
	return size
}

func recoveryLevel(e ECC) qrcode.RecoveryLevel {
	switch e {
	case ECCLow:
		return qrcode.Low
	case ECCHigh:
		return qrcode.High
	case ECCHighest:
		return qrcode.Highest
	default:
		return qrcode.Medium
	}
}
