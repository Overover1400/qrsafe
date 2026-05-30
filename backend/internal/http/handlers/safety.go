package handlers

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/Overover1400/qrsafe/internal/http/response"
	"github.com/Overover1400/qrsafe/internal/safety"
	"github.com/go-playground/validator/v10"
)

// SafetyService is the surface the safety handler depends on.
type SafetyService interface {
	Check(ctx context.Context, rawURL string) (*safety.Result, error)
}

// SafetyHandler serves the protected POST /api/v1/scan/check endpoint.
type SafetyHandler struct {
	svc      SafetyService
	validate *validator.Validate
}

// NewSafetyHandler constructs a SafetyHandler.
func NewSafetyHandler(svc SafetyService) *SafetyHandler {
	return &SafetyHandler{
		svc:      svc,
		validate: validator.New(validator.WithRequiredStructEnabled()),
	}
}

type checkRequest struct {
	// URL is checked as an opaque string (max length guarded). We deliberately
	// don't apply a strict url validator: dangerous inputs like "javascript:..."
	// should produce a verdict, not a 400.
	URL string `json:"url" validate:"required,max=2048"`
}

// Check handles POST /api/v1/scan/check: it returns a safety verdict for a URL.
// The verdict (including "malicious") is a 200 result, not an error.
func (h *SafetyHandler) Check(w http.ResponseWriter, r *http.Request) {
	var req checkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "url is required and must be at most 2048 characters")
		return
	}

	result, err := h.svc.Check(r.Context(), req.URL)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal_error", "could not check url")
		return
	}
	response.JSON(w, http.StatusOK, result)
}
