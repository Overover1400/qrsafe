// Command api is the QRSafe backend HTTP service entrypoint. It is the only
// place that knows about concrete implementations; everything below is wired
// through constructors.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Overover1400/qrsafe/internal/auth"
	"github.com/Overover1400/qrsafe/internal/config"
	httpserver "github.com/Overover1400/qrsafe/internal/http"
	"github.com/Overover1400/qrsafe/internal/http/handlers"
	"github.com/Overover1400/qrsafe/internal/platform"
	"github.com/Overover1400/qrsafe/internal/users"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
)

// redisPinger adapts *redis.Client to the handlers.Pinger interface.
type redisPinger struct{ c *redis.Client }

func (p redisPinger) Ping(ctx context.Context) error { return p.c.Ping(ctx).Err() }

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	if err := run(logger); err != nil {
		logger.Error("fatal startup error", slog.String("error", err.Error()))
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	// Load .env if present; env vars set externally take precedence and a
	// missing file is not an error (production sets real env vars directly).
	_ = godotenv.Load()

	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("loading config: %w", err)
	}

	// Startup context: connection setup may use the process context.
	ctx := context.Background()

	pool, err := platform.NewPostgresPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connecting to postgres: %w", err)
	}
	defer pool.Close()
	logger.Info("connected to postgres")

	rdb, err := platform.NewRedisClient(ctx, cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB)
	if err != nil {
		return fmt.Errorf("connecting to redis: %w", err)
	}
	defer func() { _ = rdb.Close() }()
	logger.Info("connected to redis")

	tokens := auth.NewTokenManager(cfg.JWTSecret, cfg.JWTTTL)
	repo := users.NewRepository(pool)
	authSvc := auth.NewService(repo, tokens)

	healthHandler := handlers.NewHealthHandler(pool, redisPinger{c: rdb})
	authHandler := handlers.NewAuthHandler(authSvc)

	srv := httpserver.NewServer(net.JoinHostPort("", cfg.Port), logger, tokens, healthHandler, authHandler)

	// Run the server and wait for either a fatal serve error or a signal.
	serveErr := make(chan error, 1)
	go func() { serveErr <- srv.Start() }()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-serveErr:
		return err
	case sig := <-stop:
		logger.Info("shutdown signal received", slog.String("signal", sig.String()))
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown: %w", err)
	}
	logger.Info("server stopped cleanly")
	return nil
}
