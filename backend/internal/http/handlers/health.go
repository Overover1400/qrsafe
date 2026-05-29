// Package handlers contains the HTTP handlers for the API. Handlers depend on
// interfaces, never concrete infrastructure types, so they stay testable.
package handlers

import (
	"context"
	"net/http"

	"github.com/Overover1400/qrsafe/internal/http/response"
)

// Version is reported by the health endpoint.
const Version = "0.1.0"

// Pinger is anything whose liveness can be checked with a context-bound ping.
// Both the pgx pool and a thin redis adapter satisfy it.
type Pinger interface {
	Ping(ctx context.Context) error
}

// HealthHandler reports liveness of the service and its dependencies.
type HealthHandler struct {
	db    Pinger
	redis Pinger
}

// NewHealthHandler constructs a HealthHandler.
func NewHealthHandler(db, redis Pinger) *HealthHandler {
	return &HealthHandler{db: db, redis: redis}
}

type healthResponse struct {
	Status  string `json:"status"`
	DB      string `json:"db"`
	Redis   string `json:"redis"`
	Version string `json:"version"`
}

// Health is the liveness probe. It returns 200 when all dependencies are
// reachable, or 503 with status "degraded" when any are not.
func (h *HealthHandler) Health(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	body := healthResponse{Status: "ok", DB: "ok", Redis: "ok", Version: Version}
	status := http.StatusOK

	if err := h.db.Ping(ctx); err != nil {
		body.DB = "error"
		body.Status = "degraded"
		status = http.StatusServiceUnavailable
	}
	if err := h.redis.Ping(ctx); err != nil {
		body.Redis = "error"
		body.Status = "degraded"
		status = http.StatusServiceUnavailable
	}

	response.JSON(w, status, body)
}
