# Session Notes

## 2026-05-29 — Backend scaffold + CI

### What we shipped
- **Go backend scaffold** (`backend/`): guest-first auth API on chi + pgx + Redis + JWT.
  - Endpoints: `GET /health`, `POST /api/v1/auth/guest`, `POST /api/v1/auth/upgrade`
    (upgrade is bearer-protected; promotes a guest to an email+password account,
    keeping the same user id).
  - Layout: `cmd/api` (entrypoint/wiring), `internal/{auth,users,config,platform,http}`.
  - Initial migration `0001_create_users` (uuid PK, citext unique email, guest flag).
  - `.env` is git-ignored; `.env.example` documents the variables. The Postgres
    password in `DATABASE_URL` must be percent-encoded (`^` → `%5E`).
- **Backend CI** (`.github/workflows/backend.yml`): Postgres 16 + Redis 7 service
  containers, migrations against the service DB, then vet/build/test.
- **Status badges** added to `backend/README.md` and `mobile/README.md`
  (Backend CI, Build Android APK, Build Web — all verified rendering "passing").
- **Doc-only skip**: all three workflows (`backend.yml`, `mobile.yml`, `web.yml`)
  ignore Markdown-only changes via a `!<dir>/**.md` negated path filter.

### What's working (verified locally)
- Migrations apply cleanly; `users` table exists with expected columns/indexes.
- Server boots, connects to Postgres and Redis, and serves all three endpoints
  (guest creation → upgrade flow checked end-to-end with curl).
- `go build ./...`, `go vet ./...`, and `go test ./... -race -cover` pass.

### What's tested in CI (green on `main`)
- **Backend CI**: container init, `migrate` install, `go mod tidy` cleanliness check,
  migrations on the service Postgres, vet, build, and `go test -race -cover`.
  - The live `users` repository tests run against the service Postgres (they read
    `TEST_DATABASE_URL`, falling back to `DATABASE_URL`), exercising real SQL
    (citext uniqueness, RETURNING, guest NULL handling).
  - Handler/service/auth tests run with in-memory fakes (no DB/Redis needed).
- **Build Android APK** and **Build Web** (Flutter): build + artifact upload.
  - Note: Flutter `analyze` and `test` steps are currently `continue-on-error: true`.

### What's NOT built yet
- No QR/code domain logic yet — only the user/auth slice exists.
- No Redis-backed feature yet (Redis is wired and health-checked, but no test or
  handler depends on it; the CI Redis service is future-proofing).
- No real Flutter app/tests beyond the default scaffold; mobile README is the
  default template.
- No production deploy/config, no rate limiting, no observability beyond slog.
- Actions are pinned to major versions (`@v4`/`@v5`); SHA-pinning deferred.
- `golangci-lint` not yet added (Makefile `lint` is `go vet` only).

### Today's commits
- `252c0da` Add Go backend scaffold with guest auth
- `5c23142` ci: add backend workflow with postgres + redis services
- `4d9e302` docs: add CI status badge to backend README
- `47717f5` ci: skip backend workflow for doc-only (Markdown) changes
- `6fcd013` docs: add CI status badges to mobile README
- `27b088c` ci: skip mobile and web workflows for doc-only (Markdown) changes
