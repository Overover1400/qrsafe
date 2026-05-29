# QRSafe backend Makefile.
#
# Targets that need DATABASE_URL (migrate-*) read it from .env, which is loaded
# below. The Go binary itself loads .env via godotenv at startup, so `make run`
# does not need the variables exported — but we export them anyway so the
# migrate CLI and ad-hoc commands see them too.

ifneq (,$(wildcard ./.env))
include .env
export
endif

.PHONY: run build migrate-up migrate-down migrate-create test tidy lint

## run: start the API (loads .env via godotenv)
run:
	go run ./cmd/api

## build: compile the API binary to ./bin/api
build:
	mkdir -p bin
	go build -o bin/api ./cmd/api

## migrate-up: apply all pending migrations
migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

## migrate-down: roll back the most recent migration
migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

## migrate-create: scaffold a new migration pair, e.g. `make migrate-create name=add_codes`
migrate-create:
	@test -n "$(name)" || (echo "usage: make migrate-create name=<migration_name>" && exit 1)
	migrate create -ext sql -dir migrations -seq $(name)

## test: run all tests with the race detector and coverage
# -p 1 runs package test binaries one at a time. Multiple packages share the
# one test database and truncate tables between tests, so serializing them
# avoids cross-package truncation races.
test:
	go test -race -cover -p 1 ./...

## tidy: sync go.mod/go.sum
tidy:
	go mod tidy

## lint: static checks (golangci-lint to be added later)
lint:
	go vet ./...
