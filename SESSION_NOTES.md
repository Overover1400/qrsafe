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

## 2026-05-30 — Codes domain: CRUD + public dynamic redirect

### What we shipped
- **Codes feature** (`internal/codes/`): create/list/get/update/delete static and
  dynamic QR codes, plus the public `GET /r/{slug}` redirect for dynamic codes.
  - Protected endpoints (guest or full account): `POST /api/v1/codes`,
    `GET /api/v1/codes` (cursor-paginated), `GET|PATCH|DELETE /api/v1/codes/{id}`.
  - Public, unauthenticated: `GET /r/{slug}` → 302 to the current destination.
  - Types: `url|wifi|vcard|email|text|sms`; payload stored as JSONB (validated
    only as "is a JSON object"). Only `url` codes may be dynamic.
- **Migration 0002**: `codes`, `dynamic_codes`, `scan_events` (+ indexes), with a
  matching down migration.
- **Slugs**: 8-char base62 via `crypto/rand`, 5× collision-retry inside a
  transaction; unguessable, not just unique.
- **Redis redirect cache**: `redirect:{slug}` → `{destination, code_id}`, 1h TTL,
  invalidated on destination PATCH and on DELETE. Cache-miss falls back to
  Postgres and repopulates.
- **Scan recording**: fire-and-forget goroutine after the redirect (500ms ctx),
  client IP stored as SHA-256 hash.
- **Config**: `PUBLIC_BASE_URL` (used to build `redirect_url` in responses).
- Ownership is enforced by scoping every query to `user_id`; cross-user access
  returns `404` (never `403`) so existence isn't leaked.

### What's working (verified locally)
- `make migrate-up` applies 0002; `codes`/`dynamic_codes`/`scan_events` exist.
- `make test` green (codes 67.8%, handlers 60% coverage).
- Full curl flow: guest → static create 201 → dynamic create 201 (slug +
  redirect_url) → `/r/slug` 302 → PATCH destination 200 → `/r/slug` 302 to new
  target (cache invalidated) → list returns both → DELETE 204 → `/r/slug` 404.
  Scan events confirmed (rows with 64-char SHA-256 `ip_hash`).

### What's tested in CI (green on `main`)
- Backend CI now also covers the codes repository, service, and handler/redirect
  request cycles against the live Postgres + Redis service containers (same
  `TEST_DATABASE_URL || DATABASE_URL` skip strategy; Redis tests use prefixed
  keys).
- Tests run serially with `-p 1` (Makefile + CI): packages share the one test
  database and truncate between tests, so serializing avoids cross-package races.
- The users repo test now truncates with `CASCADE` (codes now FKs users).

### What's NOT built yet
- No URL safety check (`/scan/check`) — next brief.
- No server-side QR image generation (the Flutter client renders locally).
- No rate limiting; no metrics/observability beyond slog.
- Payload inner shapes are not validated per type (only "is an object").
- Redis SETs are best-effort: a cache error degrades to a Postgres read, not a
  request failure.

### Today's commits
- `45d94ef` feat(codes): add CRUD endpoints + public dynamic redirect

## 2026-05-30 — URL safety check + destination gating

### What we shipped
- **Safety feature** (`internal/safety/`): a local-only URL classifier and the
  `POST /api/v1/scan/check` endpoint (JWT-protected) returning a verdict
  (`safe|suspicious|malicious`) with reason codes.
  - `HeuristicChecker` (no external API/secrets, deterministic), behind a
    `Checker` interface so an external provider can be added later.
  - Verdict rules: dangerous schemes (`javascript:`/`data:`/`file:`/`vbscript:`/
    `blob:`) and blocklisted hosts → `malicious`; IP-literal host, punycode,
    embedded credentials, URL shorteners, overlong host → `suspicious`; else
    `safe`. Worst signal wins.
  - `Service` fronts the checker with a Redis verdict cache
    (`safety:{sha256(url)}`, 6h TTL); cache errors fail open.
  - Handler returns 200 with the verdict (even `malicious` is a result, not an
    error); 400 only on a missing/oversized url.
- **Destination gating**: the codes service runs the checker on dynamic-code
  create and destination PATCH, rejecting `malicious` with `400
  unsafe_destination`. `suspicious` is allowed through. `codes.NewService` now
  takes an optional `DestinationChecker` (nil disables gating).

### What's working (verified locally)
- `make test` green (safety 83.8% coverage).
- `/scan/check`: 401 unauth; `https://example.com` → safe; `javascript:alert(1)`
  → malicious (`disallowed_scheme`); `bit.ly/...` → suspicious (`url_shortener`);
  `cached` flips true on repeat.
- Gating via the API: dynamic create with `javascript:` → 400 `unsafe_destination`;
  safe → 201; PATCH to `evil.example` → 400; PATCH to safe host → 200.

### What's tested in CI (green on `main`)
- Backend CI covers the safety checker (pure table tests), the Redis verdict
  cache, the `/scan/check` handler cycle (in-memory cache, no infra needed), and
  codes destination gating via the API.

### What's NOT built yet / follow-ups
- Gating blocks `malicious` only; `suspicious` destinations are allowed (could be
  tightened to also block/flag suspicious).
- `unsafe_destination` errors return a generic message — they don't echo the
  specific reasons (those are available via `/scan/check`).
- No external reputation provider yet (Safe Browsing/VirusTotal); blocklist uses
  reserved `.test`/`.example` placeholder domains.
- Still outstanding from before: server-side QR rendering, rate limiting,
  metrics/observability, per-type payload validation.

### Today's commits
- `43c5a11` feat(safety): add URL safety check endpoint + gate dynamic destinations

## 2026-05-30 — Server-side QR image generation

### What we shipped
- **QR feature** (`internal/qr/`): a stateless `POST /api/v1/qr` (JWT-protected)
  that renders a PNG QR code for a payload without storing anything.
  - `Content` maps a code type + payload to the string to encode; **v1 supports
    only `type: "url"`** (other types → 400 `unsupported_type`). The caller
    passes the URL to encode — for a dynamic code that is its `/r/{slug}` link.
  - `PNG` renders via **`skip2/go-qrcode`** (new dependency; pure stdlib, no
    transitive deps). `?size=` (clamped 64–2048, default 256) and `?ecc=`
    (low/medium/high/highest, default medium) are configurable.
  - Handler returns `200 image/png` on success; JSON error envelope otherwise.
    Rendering is pure/deterministic, so the handler calls the `qr` package
    directly with no injected service.
- This **reverses** the earlier "client renders QR locally" decision for
  server-side generation.

### What's working (verified locally)
- `make test` green (qr 77.8% coverage); `go mod tidy` produces no diff.
- Live curl: no auth → 401; `?size=300` → 200 `image/png`, a valid 300×300 PNG
  (confirmed via `file`); `type:"wifi"` → 400 `unsupported_type`.

### What's tested in CI (green on `main`)
- Backend CI covers the qr package (content mapping, valid PNG, size scaling,
  clamping) and the handler cycle (auth, PNG output, size/ecc params, error
  cases) — no Postgres or Redis needed. The `go mod tidy` check passes with the
  new dependency.

### What's NOT built yet / follow-ups
- QR is `url`-only; canonical encoders for wifi/vcard/email/text/sms deferred.
- Stateless only — no by-id `/codes/{id}/qr` route that looks up and encodes the
  right value (e.g. a dynamic code's `/r/{slug}`) server-side.
- `httpserver.NewServer` now takes 9 positional handler args; worth refactoring
  to a `Handlers` struct.
- Still outstanding from before: rate limiting, metrics/observability, external
  reputation provider for safety, per-type payload validation.

### Today's commits
- `7c40712` feat(qr): add stateless QR image generation endpoint

## 2026-05-30 — Refactor: NewServer Handlers struct

- `httpserver.NewServer` now takes a single `Handlers` struct
  (Health/Auth/Codes/Redirect/Safety/QR) instead of six positional handler
  params. Call sites pass named fields (self-documenting; test envs omit
  handlers they don't exercise instead of positional `nil`s).
- Pure refactor, no behavior change; full `-race` suite + CI green. Resolves the
  "NewServer takes too many positional args" follow-up noted above.

### Today's commits
- `1152aa8` refactor(http): pass handlers to NewServer via a Handlers struct
