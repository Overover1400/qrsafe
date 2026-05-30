package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/Overover1400/qrsafe/internal/http/response"
	"github.com/Overover1400/qrsafe/internal/qr"
	"github.com/go-playground/validator/v10"
)

// QRHandler serves POST /api/v1/qr. QR rendering is a pure, deterministic
// function with no infrastructure, so the handler calls the qr package directly
// rather than depending on an injected service.
type QRHandler struct {
	validate *validator.Validate
}

// NewQRHandler constructs a QRHandler.
func NewQRHandler() *QRHandler {
	return &QRHandler{validate: validator.New(validator.WithRequiredStructEnabled())}
}

type qrRequest struct {
	Type    string          `json:"type" validate:"required,oneof=url wifi vcard email text sms"`
	Payload json.RawMessage `json:"payload" validate:"required"`
}

// Generate handles POST /api/v1/qr: it renders a QR PNG for the given payload.
// Size and error-correction level are controlled by ?size= and ?ecc= query
// params. On success it writes image/png; failures use the JSON error envelope.
func (h *QRHandler) Generate(w http.ResponseWriter, r *http.Request) {
	var req qrRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error", "invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		response.Error(w, http.StatusBadRequest, "validation_error",
			"type must be one of url/wifi/vcard/email/text/sms and payload is required")
		return
	}
	if !codes.IsJSONObject(req.Payload) {
		response.Error(w, http.StatusBadRequest, "validation_error", "payload must be a JSON object")
		return
	}

	size := qr.DefaultSize
	if q := r.URL.Query().Get("size"); q != "" {
		n, err := strconv.Atoi(q)
		if err != nil {
			response.Error(w, http.StatusBadRequest, "validation_error", "size must be an integer")
			return
		}
		size = qr.ClampSize(n)
	}

	ecc := qr.DefaultECC
	if q := r.URL.Query().Get("ecc"); q != "" {
		ecc = qr.ECC(q)
		if !qr.ValidECC(ecc) {
			response.Error(w, http.StatusBadRequest, "validation_error", "ecc must be one of low/medium/high/highest")
			return
		}
	}

	content, err := qr.Content(req.Type, req.Payload)
	if err != nil {
		switch {
		case errors.Is(err, qr.ErrUnsupportedType):
			response.Error(w, http.StatusBadRequest, "unsupported_type", "qr generation currently supports only url codes")
		case errors.Is(err, qr.ErrMissingURL):
			response.Error(w, http.StatusBadRequest, "validation_error", "a url code requires a non-empty payload.url")
		default:
			response.Error(w, http.StatusBadRequest, "validation_error", "could not build qr content")
		}
		return
	}

	png, err := qr.PNG(content, size, ecc)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal_error", "could not render qr image")
		return
	}

	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("Content-Length", strconv.Itoa(len(png)))
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(png)
}
