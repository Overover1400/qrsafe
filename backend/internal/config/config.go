// Package config loads and validates service configuration from environment
// variables. main.go is responsible for populating the environment (e.g. via
// godotenv) before calling Load.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// defaultCORSAllowedOrigins is used when CORS_ALLOWED_ORIGINS is unset/empty:
// the production web app plus common local dev origins.
const defaultCORSAllowedOrigins = "https://app.qrsafe.flemby.com,http://localhost:3000,http://localhost:8000"

// Config holds all runtime configuration. Fields are validated in Load; an
// invalid configuration is a fatal startup error, never a runtime surprise.
type Config struct {
	Port string
	Env  string

	PublicBaseURL string

	DatabaseURL string

	RedisAddr     string
	RedisPassword string
	RedisDB       int

	JWTSecret []byte
	JWTTTL    time.Duration

	// RateLimitRPM is the per-IP request budget per minute for /api/v1. A value
	// <= 0 disables rate limiting.
	RateLimitRPM int

	// CORSAllowedOrigins is the list of origins permitted to call the API from a
	// browser. Parsed from CORS_ALLOWED_ORIGINS (comma-separated).
	CORSAllowedOrigins []string
}

// Load reads configuration from the process environment and validates it.
func Load() (*Config, error) {
	cfg := &Config{
		Port:          getEnv("PORT", "8080"),
		Env:           getEnv("ENV", "development"),
		PublicBaseURL: getEnv("PUBLIC_BASE_URL", "http://localhost:8080"),
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		RedisAddr:     getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword: os.Getenv("REDIS_PASSWORD"),
	}

	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}
	if len(secret) < 16 {
		return nil, fmt.Errorf("JWT_SECRET must be at least 16 characters")
	}
	cfg.JWTSecret = []byte(secret)

	redisDB, err := strconv.Atoi(getEnv("REDIS_DB", "0"))
	if err != nil {
		return nil, fmt.Errorf("parsing REDIS_DB: %w", err)
	}
	cfg.RedisDB = redisDB

	ttlHours, err := strconv.Atoi(getEnv("JWT_TTL_HOURS", "168"))
	if err != nil {
		return nil, fmt.Errorf("parsing JWT_TTL_HOURS: %w", err)
	}
	if ttlHours <= 0 {
		return nil, fmt.Errorf("JWT_TTL_HOURS must be positive")
	}
	cfg.JWTTTL = time.Duration(ttlHours) * time.Hour

	rpm, err := strconv.Atoi(getEnv("RATE_LIMIT_RPM", "60"))
	if err != nil {
		return nil, fmt.Errorf("parsing RATE_LIMIT_RPM: %w", err)
	}
	cfg.RateLimitRPM = rpm

	cfg.CORSAllowedOrigins = parseCSV(getEnv("CORS_ALLOWED_ORIGINS", defaultCORSAllowedOrigins))

	return cfg, nil
}

// parseCSV splits a comma-separated list, trimming whitespace per item and
// dropping empties.
func parseCSV(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if t := strings.TrimSpace(p); t != "" {
			out = append(out, t)
		}
	}
	return out
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
