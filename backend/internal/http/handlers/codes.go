package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/Overover1400/qrsafe/internal/http/response"
	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
)

// CodesService is the business-logic surface the codes handler depends on.
type CodesService interface {
	Create(ctx context.Context, in codes.CreateInput) (*codes.Code, error)
	Get(ctx context.Context, userID, id uuid.UUID) (*codes.Code, error)
	List(ctx context.Context, userID uuid.UUID, cursor string, limit int) (*codes.ListResult, error)
	Update(ctx context.Context, userID, id uuid.UUID, in codes.UpdateInput) (*codes.Code, error)
	Delete(ctx context.Context, userID, id uuid.UUID) error
	Analytics(ctx context.Context, userID, id uuid.UUID) (*codes.Analytics, error)
}

// CodesHandler serves the protected /api/v1/codes endpoints.
type CodesHandler struct {
	svc      CodesService
	validate *validator.Validate
	baseURL  string
}

// NewCodesHandler constructs a CodesHandler. baseURL is the public origin used
// to build redirect links for dynamic codes.
func NewCodesHandler(svc CodesService, baseURL string) *CodesHandler {
	return &CodesHandler{
		svc:      svc,
		validate: validator.New(validator.WithRequiredStructEnabled()),
		baseURL:  strings.TrimRight(baseURL, "/"),
	}
}

type createCodeRequest struct {
	Type      string          `json:"type" validate:"required,oneof=url wifi vcard email text sms"`
	Payload   json.RawMessage `json:"payload" validate:"required"`
	Label     *string         `json:"label" validate:"omitempty,max=100"`
	IsDynamic bool            `json:"is_dynamic"`
}

type updateCodeRequest struct {
	Label       *string `json:"label" validate:"omitempty,max=100"`
	Destination *string `json:"destination" validate:"omitempty,min=1"`
}

type codeResponse struct {
	ID        string          `json:"id"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	Label     *string         `json:"label"`
	IsDynamic bool            `json:"is_dynamic"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

type dynamicResponse struct {
	Slug        string `json:"slug"`
	Destination string `json:"destination"`
	RedirectURL string `json:"redirect_url"`
}

// codeEnvelope is the response shape for a single code, shared by POST, GET and
// PATCH and by each element of the list response.
type codeEnvelope struct {
	Code    codeResponse     `json:"code"`
	Dynamic *dynamicResponse `json:"dynamic,omitempty"`
}

type listResponse struct {
	Codes      []codeEnvelope `json:"codes"`
	NextCursor *string        `json:"next_cursor"`
}

type dayCountResponse struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

type userAgentCountResponse struct {
	UserAgent string `json:"user_agent"`
	Count     int    `json:"count"`
}

type analyticsResponse struct {
	CodeID         string                   `json:"code_id"`
	TotalScans     int                      `json:"total_scans"`
	UniqueVisitors int                      `json:"unique_visitors"`
	Daily          []dayCountResponse       `json:"daily"`
	TopUserAgents  []userAgentCountResponse `json:"top_user_agents"`
}

type analyticsEnvelope struct {
	Analytics analyticsResponse `json:"analytics"`
}

// Create handles POST /api/v1/codes.
func (h *CodesHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}

	var req createCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error",
			"type must be one of url/wifi/vcard/email/text/sms, payload is required, label at most 100 chars")
		return
	}
	if !codes.IsJSONObject(req.Payload) {
		response.Error(w, http.StatusBadRequest, "validation_error", "payload must be a JSON object")
		return
	}

	c, err := h.svc.Create(r.Context(), codes.CreateInput{
		UserID:    userID,
		Type:      req.Type,
		Payload:   req.Payload,
		Label:     req.Label,
		IsDynamic: req.IsDynamic,
	})
	if err != nil {
		h.writeServiceError(w, err)
		return
	}
	response.JSON(w, http.StatusCreated, h.toEnvelope(c))
}

// List handles GET /api/v1/codes.
func (h *CodesHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}

	limit := 0
	if q := r.URL.Query().Get("limit"); q != "" {
		n, err := strconv.Atoi(q)
		if err != nil || n < 1 {
			response.Error(w, http.StatusBadRequest, "validation_error", "limit must be a positive integer")
			return
		}
		limit = n
	}
	cursor := r.URL.Query().Get("cursor")

	res, err := h.svc.List(r.Context(), userID, cursor, limit)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}

	items := make([]codeEnvelope, len(res.Codes))
	for i, c := range res.Codes {
		items[i] = h.toEnvelope(c)
	}
	var next *string
	if res.NextCursor != "" {
		next = &res.NextCursor
	}
	response.JSON(w, http.StatusOK, listResponse{Codes: items, NextCursor: next})
}

// Get handles GET /api/v1/codes/{id}.
func (h *CodesHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		// A malformed id can't belong to the user; treat as not found rather
		// than leaking that the id was simply invalid.
		response.Error(w, http.StatusNotFound, "not_found", "code not found")
		return
	}

	c, err := h.svc.Get(r.Context(), userID, id)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}
	response.JSON(w, http.StatusOK, h.toEnvelope(c))
}

// Update handles PATCH /api/v1/codes/{id}.
func (h *CodesHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "not_found", "code not found")
		return
	}

	var req updateCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error",
			"label at most 100 chars, destination must be non-empty")
		return
	}

	c, err := h.svc.Update(r.Context(), userID, id, codes.UpdateInput{
		Label:       req.Label,
		Destination: req.Destination,
	})
	if err != nil {
		h.writeServiceError(w, err)
		return
	}
	response.JSON(w, http.StatusOK, h.toEnvelope(c))
}

// Delete handles DELETE /api/v1/codes/{id}.
func (h *CodesHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "not_found", "code not found")
		return
	}

	if err := h.svc.Delete(r.Context(), userID, id); err != nil {
		h.writeServiceError(w, err)
		return
	}
	response.JSON(w, http.StatusNoContent, nil)
}

// Analytics handles GET /api/v1/codes/{id}/analytics.
func (h *CodesHandler) Analytics(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		response.Error(w, http.StatusUnauthorized, "unauthorized", "missing authenticated user")
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "not_found", "code not found")
		return
	}

	a, err := h.svc.Analytics(r.Context(), userID, id)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}
	response.JSON(w, http.StatusOK, toAnalyticsEnvelope(a))
}

func toAnalyticsEnvelope(a *codes.Analytics) analyticsEnvelope {
	daily := make([]dayCountResponse, len(a.Daily))
	for i, d := range a.Daily {
		daily[i] = dayCountResponse{Date: d.Date, Count: d.Count}
	}
	uas := make([]userAgentCountResponse, len(a.TopUserAgents))
	for i, u := range a.TopUserAgents {
		uas[i] = userAgentCountResponse{UserAgent: u.UserAgent, Count: u.Count}
	}
	return analyticsEnvelope{Analytics: analyticsResponse{
		CodeID:         a.CodeID.String(),
		TotalScans:     a.TotalScans,
		UniqueVisitors: a.UniqueVisitors,
		Daily:          daily,
		TopUserAgents:  uas,
	}}
}

// toEnvelope maps a domain Code to the API response shape, attaching the dynamic
// block (with an absolute redirect URL) when present.
func (h *CodesHandler) toEnvelope(c *codes.Code) codeEnvelope {
	env := codeEnvelope{
		Code: codeResponse{
			ID:        c.ID.String(),
			Type:      c.Type,
			Payload:   c.Payload,
			Label:     c.Label,
			IsDynamic: c.IsDynamic,
			CreatedAt: c.CreatedAt,
			UpdatedAt: c.UpdatedAt,
		},
	}
	if c.Dynamic != nil {
		env.Dynamic = &dynamicResponse{
			Slug:        c.Dynamic.Slug,
			Destination: c.Dynamic.Destination,
			RedirectURL: h.baseURL + "/r/" + c.Dynamic.Slug,
		}
	}
	return env
}

// writeServiceError maps codes service errors to the standard error envelope.
func (h *CodesHandler) writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, codes.ErrNotFound):
		response.Error(w, http.StatusNotFound, "not_found", "code not found")
	case errors.Is(err, codes.ErrDynamicUnsupported):
		response.Error(w, http.StatusBadRequest, "dynamic_unsupported", "dynamic codes are only supported for url type")
	case errors.Is(err, codes.ErrDynamicURLRequired):
		response.Error(w, http.StatusBadRequest, "validation_error", "a dynamic url code requires payload.url")
	case errors.Is(err, codes.ErrNotDynamic):
		response.Error(w, http.StatusBadRequest, "not_dynamic", "destination can only be set on a dynamic code")
	case errors.Is(err, codes.ErrUnsafeDestination):
		response.Error(w, http.StatusBadRequest, "unsafe_destination", "destination was flagged as unsafe")
	case errors.Is(err, codes.ErrInvalidCursor):
		response.Error(w, http.StatusBadRequest, "validation_error", "invalid pagination cursor")
	case errors.Is(err, codes.ErrSlugGenerationFailed):
		response.Error(w, http.StatusInternalServerError, "slug_generation_failed", "could not generate a unique slug")
	default:
		response.Error(w, http.StatusInternalServerError, "internal_error", "something went wrong")
	}
}
