# QRSafe Backend

[![Backend CI](https://github.com/Overover1400/qrsafe/actions/workflows/backend.yml/badge.svg)](https://github.com/Overover1400/qrsafe/actions/workflows/backend.yml)

HTTP API for QRSafe, written in Go. It provides guest-first authentication:
clients start as anonymous guests and can later upgrade to a full
email + password account, keeping the same user id.

## Stack

- **Go 1.23** with [chi](https://github.com/go-chi/chi) for routing
- **PostgreSQL** (via [pgx](https://github.com/jackc/pgx)) for persistence
- **Redis** (via [go-redis](https://github.com/redis/go-redis))
- **JWT** ([golang-jwt](https://github.com/golang-jwt/jwt)) for stateless auth
- [golang-migrate](https://github.com/golang-migrate/migrate) for schema migrations

## Layout

```
cmd/api            service entrypoint and dependency wiring
internal/auth      JWT token manager, password hashing, auth service
internal/config    environment-based configuration loader
internal/users     user model and Postgres repository
internal/http      router, middleware, handlers, response helpers
internal/platform  Postgres and Redis client constructors
migrations         SQL migrations (golang-migrate)
```

## Configuration

Configuration is read from the environment. For local development, copy the
example file and fill in the placeholders — `.env` is loaded automatically at
startup via `godotenv` and is git-ignored, so real secrets never get committed.

```sh
cp .env.example .env
# then edit .env and replace the CHANGEME values
```

| Variable        | Description                                              |
|-----------------|----------------------------------------------------------|
| `PORT`          | HTTP listen port (default `8080`)                        |
| `ENV`           | Environment name (`development`, etc.)                   |
| `DATABASE_URL`  | Postgres connection URL. Percent-encode special characters in the password (e.g. `^` → `%5E`). |
| `REDIS_ADDR`    | Redis `host:port` (default `localhost:6379`)             |
| `REDIS_PASSWORD`| Redis password (plain value, no URL-encoding)            |
| `REDIS_DB`      | Redis database index (default `0`)                       |
| `JWT_SECRET`    | Signing secret, at least 16 characters                   |
| `JWT_TTL_HOURS` | Token lifetime in hours (default `168`)                  |

## Getting started

Requires a running Postgres and Redis, plus the `migrate` CLI on your `PATH`.

```sh
make migrate-up    # apply all pending migrations
make run           # start the API (loads .env)
make test          # run all tests with the race detector and coverage
```

Other targets: `make build`, `make migrate-down`, `make migrate-create name=<name>`,
`make tidy`, `make lint`. Run `make` with no arguments listing in mind — see the
`Makefile` for the full set.

## API

| Method | Path                   | Auth         | Description                                  |
|--------|------------------------|--------------|----------------------------------------------|
| GET    | `/health`              | none         | Liveness/readiness; reports DB and Redis     |
| POST   | `/api/v1/auth/guest`   | none         | Create an anonymous guest, returns a JWT     |
| POST   | `/api/v1/auth/upgrade` | Bearer token | Promote the guest to an email+password account |

### Examples

```sh
# Health
curl -s http://localhost:8080/health

# Create a guest and capture the token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/guest | jq -r .token)

# Upgrade the guest to a full account
curl -s -X POST http://localhost:8080/api/v1/auth/upgrade \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"a-strong-password"}'
```

`upgrade` requires a valid bearer token; the request body needs a valid `email`
and a `password` of at least 8 characters.
