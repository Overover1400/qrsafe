package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"html/template"
	"log/slog"
	"net/http"
	"net/url"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	"github.com/Overover1400/qrsafe/internal/http/response"
	"github.com/Overover1400/qrsafe/internal/users"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
)

// AuthService is the business-logic surface the auth handler depends on.
type AuthService interface {
	CreateGuest(ctx context.Context) (*auth.Result, error)
	UpgradeToAccount(ctx context.Context, userID uuid.UUID, email, password string) (*auth.Result, error)
	SignInWithGoogle(ctx context.Context, guestID uuid.UUID, email string) (*auth.Result, error)
}

// AuthHandler serves the auth endpoints.
type AuthHandler struct {
	svc         AuthService
	validate    *validator.Validate
	google      auth.GoogleConfig
	state       *auth.StateSigner
	appRedirect string
	client      *http.Client
	log         *slog.Logger
}

// NewAuthHandler constructs an AuthHandler with its own request validator.
//
// google may be zero-valued: sign-in with Google then reports itself as
// unavailable instead of the service refusing to start.
func NewAuthHandler(
	svc AuthService,
	google auth.GoogleConfig,
	state *auth.StateSigner,
	appRedirect string,
	log *slog.Logger,
) *AuthHandler {
	return &AuthHandler{
		svc:         svc,
		validate:    validator.New(validator.WithRequiredStructEnabled()),
		google:      google,
		state:       state,
		appRedirect: appRedirect,
		client:      &http.Client{Timeout: 15 * time.Second},
		log:         log,
	}
}

type userResponse struct {
	ID        string    `json:"id"`
	Email     *string   `json:"email,omitempty"`
	IsGuest   bool      `json:"is_guest"`
	CreatedAt time.Time `json:"created_at"`
}

type authResponse struct {
	User      userResponse `json:"user"`
	Token     string       `json:"token"`
	ExpiresAt time.Time    `json:"expires_at"`
}

type upgradeRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

// Guest handles POST /api/v1/auth/guest: creates an anonymous user and returns
// a guest token.
func (h *AuthHandler) Guest(w http.ResponseWriter, r *http.Request) {
	result, err := h.svc.CreateGuest(r.Context())
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal_error", "could not create guest user")
		return
	}
	response.JSON(w, http.StatusCreated, toAuthResponse(result))
}

// Upgrade handles POST /api/v1/auth/upgrade: promotes the authenticated guest
// to an email+password account. Requires a valid guest token (enforced by the
// auth middleware, which populates the user id in the context).
func (h *AuthHandler) Upgrade(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}

	var req upgradeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "email must be valid and password at least 8 characters")
		return
	}

	result, err := h.svc.UpgradeToAccount(r.Context(), userID, req.Email, req.Password)
	if err != nil {
		switch {
		case errors.Is(err, auth.ErrAlreadyUpgraded):
			response.Error(w, http.StatusForbidden, "already_upgraded", "this account has already been upgraded")
		case errors.Is(err, users.ErrEmailTaken):
			response.Error(w, http.StatusConflict, "email_taken", "that email is already in use")
		default:
			response.Error(w, http.StatusInternalServerError, "internal_error", "could not upgrade account")
		}
		return
	}
	response.JSON(w, http.StatusOK, toAuthResponse(result))
}

type googleStartResponse struct {
	AuthURL string `json:"auth_url"`
}

// GoogleStart handles POST /api/v1/auth/google/start. It hands the app the URL
// to open in a browser, with a signed state carrying the current guest id.
//
// The URL is returned rather than redirected to, and the caller's token stays
// in the Authorization header: a token in a URL would end up in browser
// history and in every log along the way.
func (h *AuthHandler) GoogleStart(w http.ResponseWriter, r *http.Request) {
	if !h.google.Enabled() {
		response.Error(w, http.StatusServiceUnavailable, "google_disabled",
			"sign-in with Google is not configured")
		return
	}
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}

	state, err := h.state.Sign(userID, time.Now())
	if err != nil {
		h.log.Error("signing google state failed", slog.String("error", err.Error()))
		response.Error(w, http.StatusInternalServerError, "internal_error", "could not start sign-in")
		return
	}
	response.JSON(w, http.StatusOK, googleStartResponse{AuthURL: h.google.AuthURL(state)})
}

// GoogleCallback handles GET /api/v1/auth/google/callback, the address Google
// returns the browser to. It is deliberately unauthenticated: the browser
// carries no bearer token, and the signed state is what proves the flow.
//
// It answers with a small HTML page that hands the token to the app over its
// deep link. A 302 to a custom scheme is not reliably followed by every mobile
// browser, so the page also offers a button.
func (h *AuthHandler) GoogleCallback(w http.ResponseWriter, r *http.Request) {
	if !h.google.Enabled() {
		h.finishHTML(w, "", "Sign-in with Google is not set up yet.")
		return
	}
	if reason := r.URL.Query().Get("error"); reason != "" {
		h.log.Info("google sign-in declined", slog.String("reason", reason))
		h.finishHTML(w, "", "Sign-in was cancelled.")
		return
	}

	guestID, err := h.state.Parse(r.URL.Query().Get("state"))
	if err != nil {
		h.log.Warn("google callback with bad state", slog.String("error", err.Error()))
		h.finishHTML(w, "", "This sign-in link has expired. Please try again.")
		return
	}

	identity, err := h.google.Exchange(r.Context(), h.client, r.URL.Query().Get("code"))
	if err != nil {
		h.log.Error("google code exchange failed", slog.String("error", err.Error()))
		h.finishHTML(w, "", "Google could not confirm that account.")
		return
	}

	result, err := h.svc.SignInWithGoogle(r.Context(), guestID, identity.Email)
	if err != nil {
		h.log.Error("google sign-in failed", slog.String("error", err.Error()))
		h.finishHTML(w, "", "Could not finish signing in.")
		return
	}

	target := h.appRedirect + "?token=" + url.QueryEscape(result.Token) +
		"&expires_at=" + url.QueryEscape(result.ExpiresAt.UTC().Format(time.RFC3339))
	h.finishHTML(w, target, "")
}

// finishHTML renders the end of the browser half of the flow: either a hand-off
// to the app's deep link, or a plain message when something went wrong.
func (h *AuthHandler) finishHTML(w http.ResponseWriter, deepLink, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if deepLink == "" {
		w.WriteHeader(http.StatusBadRequest)
		_ = signInPage.Execute(w, map[string]string{"Message": message})
		return
	}
	_ = signInPage.Execute(w, map[string]string{"DeepLink": deepLink})
}

var signInPage = template.Must(template.New("signin").Parse(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>QRSafe</title>
<style>
  body { margin:0; min-height:100vh; display:flex; align-items:center;
         justify-content:center; background:#F1FAF8; color:#0F3B3F;
         font:16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         text-align:center; padding:24px; }
  a.button { display:inline-block; margin-top:20px; padding:14px 28px;
             background:linear-gradient(135deg,#3FC9C0,#0E7C8A); color:#fff;
             border-radius:16px; text-decoration:none; font-weight:700; }
</style>
</head>
<body>
<main>
{{if .DeepLink}}
  <h1>Signed in</h1>
  <p>Taking you back to QRSafe&hellip;</p>
  <a class="button" href="{{.DeepLink}}">Open QRSafe</a>
  <script>location.replace({{.DeepLink}});</script>
{{else}}
  <h1>QRSafe</h1>
  <p>{{.Message}}</p>
{{end}}
</main>
</body>
</html>
`))

func toAuthResponse(r *auth.Result) authResponse {
	return authResponse{
		User: userResponse{
			ID:        r.User.ID.String(),
			Email:     r.User.Email,
			IsGuest:   r.User.IsGuest,
			CreatedAt: r.User.CreatedAt,
		},
		Token:     r.Token,
		ExpiresAt: r.ExpiresAt,
	}
}
