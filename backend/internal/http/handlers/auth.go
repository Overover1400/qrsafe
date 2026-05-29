package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
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
}

// AuthHandler serves the auth endpoints.
type AuthHandler struct {
	svc      AuthService
	validate *validator.Validate
}

// NewAuthHandler constructs an AuthHandler with its own request validator.
func NewAuthHandler(svc AuthService) *AuthHandler {
	return &AuthHandler{
		svc:      svc,
		validate: validator.New(validator.WithRequiredStructEnabled()),
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
