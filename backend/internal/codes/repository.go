package codes

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Sentinel errors callers branch on with errors.Is.
var (
	ErrNotFound  = errors.New("code not found")
	ErrSlugTaken = errors.New("slug already taken")
)

// DB is the subset of pgxpool.Pool the repository depends on. Begin and Query
// are needed in addition to the users-repo surface because dynamic codes are
// created in a transaction and listing returns many rows.
type DB interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Begin(ctx context.Context) (pgx.Tx, error)
}

// Repository provides CRUD access to the codes, dynamic_codes and scan_events
// tables.
type Repository struct {
	db DB
}

// NewRepository constructs a Repository backed by the given DB.
func NewRepository(db DB) *Repository {
	return &Repository{db: db}
}

// selectColumns is the column list shared by GetByID and List. dynamic_codes
// columns come last and are NULL for static codes (LEFT JOIN).
const selectColumns = `
	c.id, c.user_id, c.type, c.payload, c.is_dynamic, c.label,
	c.created_at, c.updated_at,
	d.slug, d.destination, d.updated_at`

// Create inserts a static code and populates the generated fields back onto c.
func (r *Repository) Create(ctx context.Context, c *Code) error {
	const q = `
		INSERT INTO codes (user_id, type, payload, is_dynamic, label)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at, updated_at`
	err := r.db.QueryRow(ctx, q, c.UserID, c.Type, c.Payload, c.IsDynamic, c.Label).
		Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return fmt.Errorf("inserting code: %w", err)
	}
	return nil
}

// CreateDynamic inserts a code and its dynamic_codes row atomically. On a slug
// unique-constraint violation it returns ErrSlugTaken so the caller can retry
// with a fresh slug; the whole transaction is rolled back in that case.
func (r *Repository) CreateDynamic(ctx context.Context, c *Code, slug, destination string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("beginning transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const insCode = `
		INSERT INTO codes (user_id, type, payload, is_dynamic, label)
		VALUES ($1, $2, $3, TRUE, $4)
		RETURNING id, created_at, updated_at`
	if err := tx.QueryRow(ctx, insCode, c.UserID, c.Type, c.Payload, c.Label).
		Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return fmt.Errorf("inserting dynamic code: %w", err)
	}

	const insDyn = `
		INSERT INTO dynamic_codes (code_id, slug, destination)
		VALUES ($1, $2, $3)
		RETURNING updated_at`
	dyn := &DynamicCode{CodeID: c.ID, Slug: slug, Destination: destination}
	if err := tx.QueryRow(ctx, insDyn, c.ID, slug, destination).Scan(&dyn.UpdatedAt); err != nil {
		if isUniqueViolation(err) {
			return ErrSlugTaken
		}
		return fmt.Errorf("inserting dynamic_codes row: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("committing dynamic code: %w", err)
	}
	c.IsDynamic = true
	c.Dynamic = dyn
	return nil
}

// GetByID returns the code with the given id owned by userID, or ErrNotFound.
// Scoping by user_id is how ownership is enforced — a code belonging to another
// user is indistinguishable from one that does not exist.
func (r *Repository) GetByID(ctx context.Context, userID, id uuid.UUID) (*Code, error) {
	q := `
		SELECT ` + selectColumns + `
		FROM codes c
		LEFT JOIN dynamic_codes d ON d.code_id = c.id
		WHERE c.id = $1 AND c.user_id = $2`
	return scanCode(r.db.QueryRow(ctx, q, id, userID))
}

// List returns a page of the user's codes, newest first. When cur is non-nil it
// returns codes strictly older than the cursor (keyset pagination on
// (created_at, id)). Pass limit+1 to detect whether a further page exists.
func (r *Repository) List(ctx context.Context, userID uuid.UUID, cur *Cursor, limit int) ([]*Code, error) {
	var (
		rows pgx.Rows
		err  error
	)
	if cur == nil {
		q := `
			SELECT ` + selectColumns + `
			FROM codes c
			LEFT JOIN dynamic_codes d ON d.code_id = c.id
			WHERE c.user_id = $1
			ORDER BY c.created_at DESC, c.id DESC
			LIMIT $2`
		rows, err = r.db.Query(ctx, q, userID, limit)
	} else {
		q := `
			SELECT ` + selectColumns + `
			FROM codes c
			LEFT JOIN dynamic_codes d ON d.code_id = c.id
			WHERE c.user_id = $1 AND (c.created_at, c.id) < ($2, $3)
			ORDER BY c.created_at DESC, c.id DESC
			LIMIT $4`
		rows, err = r.db.Query(ctx, q, userID, cur.CreatedAt, cur.ID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("querying codes: %w", err)
	}
	defer rows.Close()

	var out []*Code
	for rows.Next() {
		c, err := scanCode(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating codes: %w", err)
	}
	return out, nil
}

// UpdateLabel sets the label on the user's code and bumps updated_at. Returns
// ErrNotFound if no such code belongs to the user.
func (r *Repository) UpdateLabel(ctx context.Context, userID, id uuid.UUID, label *string) error {
	const q = `
		UPDATE codes SET label = $3, updated_at = NOW()
		WHERE id = $1 AND user_id = $2`
	tag, err := r.db.Exec(ctx, q, id, userID, label)
	if err != nil {
		return fmt.Errorf("updating label: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateDestination changes a dynamic code's destination and bumps its
// dynamic_codes.updated_at. Returns ErrNotFound if no dynamic_codes row exists.
func (r *Repository) UpdateDestination(ctx context.Context, codeID uuid.UUID, destination string) error {
	const q = `
		UPDATE dynamic_codes SET destination = $2, updated_at = NOW()
		WHERE code_id = $1`
	tag, err := r.db.Exec(ctx, q, codeID, destination)
	if err != nil {
		return fmt.Errorf("updating destination: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete removes the user's code (cascading to dynamic_codes via FK). Returns
// ErrNotFound if no such code belongs to the user.
func (r *Repository) Delete(ctx context.Context, userID, id uuid.UUID) error {
	const q = `DELETE FROM codes WHERE id = $1 AND user_id = $2`
	tag, err := r.db.Exec(ctx, q, id, userID)
	if err != nil {
		return fmt.Errorf("deleting code: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ResolveSlug returns the current destination and owning code id for a slug, or
// ErrNotFound. This is the hot path behind /r/{slug} on a cache miss.
func (r *Repository) ResolveSlug(ctx context.Context, slug string) (destination string, codeID uuid.UUID, err error) {
	const q = `SELECT destination, code_id FROM dynamic_codes WHERE slug = $1`
	err = r.db.QueryRow(ctx, q, slug).Scan(&destination, &codeID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", uuid.Nil, ErrNotFound
		}
		return "", uuid.Nil, fmt.Errorf("resolving slug: %w", err)
	}
	return destination, codeID, nil
}

// InsertScanEvent appends a scan record and populates its generated fields.
func (r *Repository) InsertScanEvent(ctx context.Context, e *ScanEvent) error {
	const q = `
		INSERT INTO scan_events (slug, ip_hash, user_agent)
		VALUES ($1, $2, $3)
		RETURNING id, scanned_at`
	if err := r.db.QueryRow(ctx, q, e.Slug, e.IPHash, e.UserAgent).
		Scan(&e.ID, &e.ScannedAt); err != nil {
		return fmt.Errorf("inserting scan event: %w", err)
	}
	return nil
}

// scanCode scans a joined codes/dynamic_codes row. The dynamic columns are
// nullable (LEFT JOIN); when present they populate Code.Dynamic.
func scanCode(row pgx.Row) (*Code, error) {
	var (
		c          Code
		slug       *string
		dest       *string
		dynUpdated *time.Time
	)
	err := row.Scan(
		&c.ID, &c.UserID, &c.Type, &c.Payload, &c.IsDynamic, &c.Label,
		&c.CreatedAt, &c.UpdatedAt,
		&slug, &dest, &dynUpdated,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("scanning code: %w", err)
	}
	if slug != nil && dest != nil {
		c.Dynamic = &DynamicCode{CodeID: c.ID, Slug: *slug, Destination: *dest}
		if dynUpdated != nil {
			c.Dynamic.UpdatedAt = *dynUpdated
		}
	}
	return &c, nil
}

// isUniqueViolation reports whether err is a Postgres unique-constraint error.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return false
}
