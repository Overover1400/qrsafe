// Package config loads and validates service configuration from environment
// variables. main.go is responsible for populating the environment (e.g. via
// godotenv) before calling Load.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all runtime configuration. Fields are validated in Load; an
// invalid configuration is a fatal startup error, never a runtime surprise.
type Config struct {
	Port string
	Env  string

	DatabaseURL string

	RedisAddr     string
	RedisPassword string
	RedisDB       int

	JWTSecret []byte
	JWTTTL    time.Duration
}

// Load reads configuration from the process environment and validates it.
func Load() (*Config, error) {
	cfg := &Config{
		Port:          getEnv("PORT", "8080"),
		Env:           getEnv("ENV", "development"),
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

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
