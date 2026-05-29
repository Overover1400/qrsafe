package handlers_test

import (
	"context"
	"io"
	"log/slog"
)

// okPinger is a Pinger that is always healthy.
type okPinger struct{}

func (okPinger) Ping(context.Context) error { return nil }

// discardLogger returns a slog.Logger that throws away output, keeping test
// runs quiet.
func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}
