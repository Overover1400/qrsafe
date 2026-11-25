package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	googleAuthEndpoint  = "https://accounts.google.com/o/oauth2/v2/auth"
	googleTokenEndpoint = "https://oauth2.googleapis.com/token"
)

var (
	// ErrGoogleDisabled means the service is running without Google credentials.
	ErrGoogleDisabled = errors.New("google sign-in is not configured")
	// ErrGoogleIdentity means Google answered, but not with an identity we can
	// trust enough to sign someone in with.
	ErrGoogleIdentity = errors.New("google did not return a usable identity")
	// ErrInvalidState means the callback did not come from a flow we started.
	ErrInvalidState = errors.New("invalid or expired sign-in state")
)

// GoogleConfig holds the OAuth client the API signs people in with. All three
// fields come from the environment; leaving any of them empty turns the feature
// off rather than breaking startup.
type GoogleConfig struct {
	ClientID     string
	ClientSecret string
	RedirectURL  string
}

// Enabled reports whether Google sign-in can be offered.
func (c GoogleConfig) Enabled() bool {
	return c.ClientID != "" && c.ClientSecret != "" && c.RedirectURL != ""
}

// AuthURL is where the app sends the browser to start the flow.
func (c GoogleConfig) AuthURL(state string) string {
	q := url.Values{
		"client_id":     {c.ClientID},
		"redirect_uri":  {c.RedirectURL},
		"response_type": {"code"},
		"scope":         {"openid email profile"},
		"state":         {state},
		// Always let her pick the account: phones are often signed into more
		// than one, and a silent pick of the wrong one is confusing.
		"prompt": {"select_account"},
	}
	return googleAuthEndpoint + "?" + q.Encode()
}

// GoogleIdentity is the part of the ID token we act on.
type GoogleIdentity struct {
	Subject string
	Email   string
	Name    string
}

// Exchange trades the authorization code for the signed-in identity.
func (c GoogleConfig) Exchange(ctx context.Context, client *http.Client, code string) (*GoogleIdentity, error) {
	if !c.Enabled() {
		return nil, ErrGoogleDisabled
	}
	if code == "" {
		return nil, fmt.Errorf("%w: no authorization code", ErrGoogleIdentity)
	}

	form := url.Values{
		"code":          {code},
		"client_id":     {c.ClientID},
		"client_secret": {c.ClientSecret},
		"redirect_uri":  {c.RedirectURL},
		"grant_type":    {"authorization_code"},
	}
	req, err := http.NewRequestWithContext(
		ctx, http.MethodPost, googleTokenEndpoint, strings.NewReader(form.Encode()),
	)
	if err != nil {
		return nil, fmt.Errorf("building token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	res, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("calling google token endpoint: %w", err)
	}
	defer func() { _ = res.Body.Close() }()

	if res.StatusCode != http.StatusOK {
		// The body carries Google's own error code; keep it out of the response
		// to the user but useful in the log.
		snippet, _ := io.ReadAll(io.LimitReader(res.Body, 512))
		return nil, fmt.Errorf("google token endpoint: status %d: %s", res.StatusCode, snippet)
	}

	var body struct {
		IDToken string `json:"id_token"`
	}
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		return nil, fmt.Errorf("decoding token response: %w", err)
	}
	return c.identityFromIDToken(body.IDToken)
}

// identityFromIDToken reads the claims of an ID token fetched straight from
// Google's token endpoint over TLS. Google documents that a token obtained that
// way needs no signature check, because the channel already authenticates it.
// Audience, issuer and expiry are still checked: those guard against a
// misconfigured client accepting a token minted for somebody else.
func (c GoogleConfig) identityFromIDToken(idToken string) (*GoogleIdentity, error) {
	parts := strings.Split(idToken, ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("%w: malformed id_token", ErrGoogleIdentity)
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("%w: undecodable id_token", ErrGoogleIdentity)
	}

	var claims struct {
		Iss           string `json:"iss"`
		Aud           string `json:"aud"`
		Sub           string `json:"sub"`
		Exp           int64  `json:"exp"`
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
		Name          string `json:"name"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil {
		return nil, fmt.Errorf("%w: unreadable claims", ErrGoogleIdentity)
	}

	if claims.Aud != c.ClientID {
		return nil, fmt.Errorf("%w: audience mismatch", ErrGoogleIdentity)
	}
	if claims.Iss != "accounts.google.com" && claims.Iss != "https://accounts.google.com" {
		return nil, fmt.Errorf("%w: unexpected issuer %q", ErrGoogleIdentity, claims.Iss)
	}
	if claims.Exp > 0 && time.Now().After(time.Unix(claims.Exp, 0)) {
		return nil, fmt.Errorf("%w: expired id_token", ErrGoogleIdentity)
	}
	if claims.Email == "" || !claims.EmailVerified {
		return nil, fmt.Errorf("%w: no verified email", ErrGoogleIdentity)
	}

	return &GoogleIdentity{
		Subject: claims.Sub,
		Email:   strings.ToLower(strings.TrimSpace(claims.Email)),
		Name:    claims.Name,
	}, nil
}

// stateTTL bounds how long a started sign-in may take to come back.
const stateTTL = 10 * time.Minute

// StateSigner signs the `state` that survives the round trip to Google. It
// proves the callback belongs to a flow this service started, and carries the
// guest's user id so the codes she made before signing in stay hers.
type StateSigner struct {
	secret []byte
}

// NewStateSigner builds a signer over the service's JWT secret.
func NewStateSigner(secret []byte) *StateSigner {
	return &StateSigner{secret: secret}
}

// Sign returns the state string for a flow started by guestID.
func (s *StateSigner) Sign(guestID uuid.UUID, now time.Time) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"gid": guestID.String(),
		"iat": now.Unix(),
		"exp": now.Add(stateTTL).Unix(),
	})
	signed, err := token.SignedString(s.secret)
	if err != nil {
		return "", fmt.Errorf("signing state: %w", err)
	}
	return signed, nil
}

// Parse validates a state string and returns the guest id it carries.
func (s *StateSigner) Parse(state string) (uuid.UUID, error) {
	parsed, err := jwt.Parse(state, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method %v", t.Header["alg"])
		}
		return s.secret, nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !parsed.Valid {
		return uuid.Nil, ErrInvalidState
	}

	claims, ok := parsed.Claims.(jwt.MapClaims)
	if !ok {
		return uuid.Nil, ErrInvalidState
	}
	raw, _ := claims["gid"].(string)
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, ErrInvalidState
	}
	return id, nil
}
