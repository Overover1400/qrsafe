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
	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/Overover1400/qrsafe/internal/config"
	httpserver "github.com/Overover1400/qrsafe/internal/http"
	"github.com/Overover1400/qrsafe/internal/http/handlers"
	mw "github.com/Overover1400/qrsafe/internal/http/middleware"
	"github.com/Overover1400/qrsafe/internal/platform"
	"github.com/Overover1400/qrsafe/internal/ratelimit"
	"github.com/Overover1400/qrsafe/internal/safety"
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

	safetySvc := safety.NewService(safety.NewHeuristicChecker(), safety.NewRedisCache(rdb), logger)

	codesRepo := codes.NewRepository(pool)
	redirectCache := codes.NewRedisCache(rdb)
	codesSvc := codes.NewService(codesRepo, redirectCache, logger, safetySvc)
	redirectSvc := codes.NewRedirectService(codesRepo, redirectCache, logger)

	healthHandler := handlers.NewHealthHandler(pool, redisPinger{c: rdb})
	authHandler := handlers.NewAuthHandler(authSvc)
	codesHandler := handlers.NewCodesHandler(codesSvc, cfg.PublicBaseURL)
	redirectHandler := handlers.NewRedirectHandler(redirectSvc, logger)
	safetyHandler := handlers.NewSafetyHandler(safetySvc)
	qrHandler := handlers.NewQRHandler()

	// A nil interface (not a typed-nil pointer) when disabled, so the server's
	// nil check works correctly.
	var rateLimiter mw.Limiter
	if cfg.RateLimitRPM > 0 {
		rateLimiter = ratelimit.NewRedisLimiter(rdb, cfg.RateLimitRPM, time.Minute)
		logger.Info("rate limiting enabled", slog.Int("rpm", cfg.RateLimitRPM))
	} else {
		logger.Info("rate limiting disabled")
	}

	srv := httpserver.NewServer(net.JoinHostPort("", cfg.Port), logger, tokens, httpserver.Handlers{
		Health:   healthHandler,
		Auth:     authHandler,
		Codes:    codesHandler,
		Redirect: redirectHandler,
		Safety:   safetyHandler,
		QR:       qrHandler,
	}, rateLimiter)

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
