// Package response centralizes how the API writes JSON. Every error shares one
// shape — {"error":{"code":"...","message":"..."}} — so the Flutter client has
// a single contract to parse.
package response

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

type errorBody struct {
	Error errorDetail `json:"error"`
}

type errorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// JSON writes v as a JSON response with the given status code. A nil v writes
// only the status (no body).
func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if v == nil {
		return
	}
	if err := json.NewEncoder(w).Encode(v); err != nil {
		// The status/headers are already committed; all we can do is log.
		slog.Error("encoding json response", slog.String("error", err.Error()))
	}
}

// Error writes a standard error envelope.
func Error(w http.ResponseWriter, status int, code, message string) {
	JSON(w, status, errorBody{Error: errorDetail{Code: code, Message: message}})
}
