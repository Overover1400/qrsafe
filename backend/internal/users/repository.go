package users

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Sentinel errors callers can branch on with errors.Is.
var (
	ErrNotFound   = errors.New("user not found")
	ErrEmailTaken = errors.New("email already taken")
)

// DB is the subset of pgxpool.Pool the repository depends on. Defining it as an
// interface keeps the repository testable and free of a hard dependency on a
// concrete pool type.
type DB interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

// Repository provides CRUD access to the users table.
type Repository struct {
	db DB
}

// NewRepository constructs a Repository backed by the given DB.
func NewRepository(db DB) *Repository {
	return &Repository{db: db}
}

// Create inserts u, letting Postgres assign the id and timestamps, then
// populates those generated fields back onto u.
func (r *Repository) Create(ctx context.Context, u *User) error {
	const q = `
		INSERT INTO users (email, password_hash, is_guest)
		VALUES ($1, $2, $3)
		RETURNING id, created_at, updated_at`
	err := r.db.QueryRow(ctx, q, u.Email, u.PasswordHash, u.IsGuest).
		Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrEmailTaken
		}
		return fmt.Errorf("inserting user: %w", err)
	}
	return nil
}

// GetByID returns the user with the given id, or ErrNotFound.
func (r *Repository) GetByID(ctx context.Context, id uuid.UUID) (*User, error) {
	const q = `
		SELECT id, email, password_hash, is_guest, created_at, updated_at
		FROM users
		WHERE id = $1`
	u := &User{}
	err := r.db.QueryRow(ctx, q, id).
		Scan(&u.ID, &u.Email, &u.PasswordHash, &u.IsGuest, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("selecting user by id: %w", err)
	}
	return u, nil
}

// GetByEmail returns the user with the given email, or ErrNotFound.
func (r *Repository) GetByEmail(ctx context.Context, email string) (*User, error) {
	const q = `
		SELECT id, email, password_hash, is_guest, created_at, updated_at
		FROM users
		WHERE email = $1`
	u := &User{}
	err := r.db.QueryRow(ctx, q, email).
		Scan(&u.ID, &u.Email, &u.PasswordHash, &u.IsGuest, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("selecting user by email: %w", err)
	}
	return u, nil
}

// Update persists email, password_hash and is_guest for an existing user and
// refreshes updated_at. Returns ErrNotFound if no row matches, or ErrEmailTaken
// if the email collides with another account.
func (r *Repository) Update(ctx context.Context, u *User) error {
	const q = `
		UPDATE users
		SET email = $2, password_hash = $3, is_guest = $4, updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at`
	err := r.db.QueryRow(ctx, q, u.ID, u.Email, u.PasswordHash, u.IsGuest).
		Scan(&u.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if isUniqueViolation(err) {
			return ErrEmailTaken
		}
		return fmt.Errorf("updating user: %w", err)
	}
	return nil
}

// isUniqueViolation reports whether err is a Postgres unique-constraint error.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return false
}
