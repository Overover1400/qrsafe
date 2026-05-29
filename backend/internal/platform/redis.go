package platform

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
)

// NewRedisClient creates a go-redis client and verifies it with a ping.
func NewRedisClient(ctx context.Context, addr, password string, db int) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("pinging redis: %w", err)
	}
	return client, nil
}
