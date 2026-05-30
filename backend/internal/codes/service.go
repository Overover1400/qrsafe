package codes

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/Overover1400/qrsafe/internal/safety"
	"github.com/google/uuid"
)

// Pagination and retry bounds.
const (
	DefaultListLimit = 20
	MaxListLimit     = 100
	maxSlugAttempts  = 5
)

// Service-level sentinel errors, mapped to HTTP status codes by the handler.
var (
	ErrDynamicUnsupported   = errors.New("dynamic codes are only supported for url type")
	ErrDynamicURLRequired   = errors.New("dynamic url code requires payload.url")
	ErrNotDynamic           = errors.New("code is not dynamic")
	ErrSlugGenerationFailed = errors.New("could not generate a unique slug")
	ErrInvalidCursor        = errors.New("invalid pagination cursor")
	ErrUnsafeDestination    = errors.New("destination failed the safety check")
)

// repository is the persistence surface the service depends on. *Repository
// satisfies it; tests can substitute a fake.
type repository interface {
	Create(ctx context.Context, c *Code) error
	CreateDynamic(ctx context.Context, c *Code, slug, destination string) error
	GetByID(ctx context.Context, userID, id uuid.UUID) (*Code, error)
	List(ctx context.Context, userID uuid.UUID, cur *Cursor, limit int) ([]*Code, error)
	UpdateLabel(ctx context.Context, userID, id uuid.UUID, label *string) error
	UpdateDestination(ctx context.Context, codeID uuid.UUID, destination string) error
	Delete(ctx context.Context, userID, id uuid.UUID) error
}

// DestinationChecker validates a dynamic code's destination URL. A nil checker
// disables gating (the safety check is then only available via /scan/check).
type DestinationChecker interface {
	Check(ctx context.Context, rawURL string) (*safety.Result, error)
}

// Service holds the codes business logic.
type Service struct {
	repo    repository
	cache   Cache
	log     *slog.Logger
	checker DestinationChecker
	newSlug func() (string, error) // injectable for tests; defaults to GenerateSlug
}

// NewService constructs a Service. checker may be nil to disable destination
// gating.
func NewService(repo repository, cache Cache, log *slog.Logger, checker DestinationChecker) *Service {
	return &Service{repo: repo, cache: cache, log: log, checker: checker, newSlug: GenerateSlug}
}

// guardDestination rejects a destination only when it is classified malicious.
// Suspicious destinations are allowed (the client can surface the warning via
// /scan/check); a checker error fails open so the safety check never takes the
// product down.
func (s *Service) guardDestination(ctx context.Context, rawURL string) error {
	if s.checker == nil {
		return nil
	}
	res, err := s.checker.Check(ctx, rawURL)
	if err != nil {
		s.log.Warn("destination safety check failed; allowing",
			slog.String("error", err.Error()))
		return nil
	}
	if res.Verdict == safety.VerdictMalicious {
		s.log.Info("blocked unsafe destination", slog.String("verdict", string(res.Verdict)))
		return ErrUnsafeDestination
	}
	return nil
}

// CreateInput is the validated input for creating a code.
type CreateInput struct {
	UserID    uuid.UUID
	Type      string
	Payload   json.RawMessage
	Label     *string
	IsDynamic bool
}

// Create persists a new code. For dynamic codes it generates a slug (retrying
// on collision), uses payload.url as the initial destination, and writes the
// codes + dynamic_codes rows in one transaction.
func (s *Service) Create(ctx context.Context, in CreateInput) (*Code, error) {
	if in.IsDynamic && in.Type != string(TypeURL) {
		return nil, ErrDynamicUnsupported
	}

	c := &Code{
		UserID:    in.UserID,
		Type:      in.Type,
		Payload:   in.Payload,
		IsDynamic: in.IsDynamic,
		Label:     in.Label,
	}

	if !in.IsDynamic {
		if err := s.repo.Create(ctx, c); err != nil {
			return nil, fmt.Errorf("creating static code: %w", err)
		}
		return c, nil
	}

	dest, ok := extractURL(in.Payload)
	if !ok {
		return nil, ErrDynamicURLRequired
	}
	if err := s.guardDestination(ctx, dest); err != nil {
		return nil, err
	}

	for attempt := 1; attempt <= maxSlugAttempts; attempt++ {
		slug, err := s.newSlug()
		if err != nil {
			return nil, fmt.Errorf("generating slug: %w", err)
		}
		err = s.repo.CreateDynamic(ctx, c, slug, dest)
		switch {
		case err == nil:
			s.log.Info("created dynamic code",
				slog.String("code_id", c.ID.String()),
				slog.String("slug", slug),
				slog.Int("attempt", attempt))
			return c, nil
		case errors.Is(err, ErrSlugTaken):
			s.log.Warn("slug collision, retrying",
				slog.String("slug", slug), slog.Int("attempt", attempt))
			continue
		default:
			return nil, fmt.Errorf("creating dynamic code: %w", err)
		}
	}
	return nil, ErrSlugGenerationFailed
}

// Get returns one of the user's codes, or ErrNotFound.
func (s *Service) Get(ctx context.Context, userID, id uuid.UUID) (*Code, error) {
	return s.repo.GetByID(ctx, userID, id)
}

// ListResult is a page of codes plus the cursor for the next page (empty when
// there are no more).
type ListResult struct {
	Codes      []*Code
	NextCursor string
}

// List returns a page of the user's codes. limit is clamped to [1, MaxListLimit]
// with a default of DefaultListLimit.
func (s *Service) List(ctx context.Context, userID uuid.UUID, cursorToken string, limit int) (*ListResult, error) {
	if limit <= 0 {
		limit = DefaultListLimit
	}
	if limit > MaxListLimit {
		limit = MaxListLimit
	}

	var cur *Cursor
	if cursorToken != "" {
		c, err := decodeCursor(cursorToken)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidCursor, err)
		}
		cur = c
	}

	// Fetch one extra row to know whether a further page exists.
	items, err := s.repo.List(ctx, userID, cur, limit+1)
	if err != nil {
		return nil, fmt.Errorf("listing codes: %w", err)
	}

	res := &ListResult{Codes: items}
	if len(items) > limit {
		last := items[limit-1]
		res.Codes = items[:limit]
		res.NextCursor = encodeCursor(Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
	}
	return res, nil
}

// UpdateInput carries the optional fields of a PATCH. A nil field means "leave
// unchanged".
type UpdateInput struct {
	Label       *string
	Destination *string
}

// Update applies a partial update. Label applies to any code; Destination only
// to dynamic codes (and invalidates the redirect cache). It returns the
// refreshed code.
func (s *Service) Update(ctx context.Context, userID, id uuid.UUID, in UpdateInput) (*Code, error) {
	c, err := s.repo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, err
	}

	if in.Destination != nil {
		if !c.IsDynamic || c.Dynamic == nil {
			return nil, ErrNotDynamic
		}
		if err := s.guardDestination(ctx, *in.Destination); err != nil {
			return nil, err
		}
		if err := s.repo.UpdateDestination(ctx, c.ID, *in.Destination); err != nil {
			return nil, fmt.Errorf("updating destination: %w", err)
		}
		if err := s.cache.Invalidate(ctx, c.Dynamic.Slug); err != nil {
			s.log.Warn("invalidating redirect cache failed",
				slog.String("slug", c.Dynamic.Slug), slog.String("error", err.Error()))
		}
	}

	if in.Label != nil {
		if err := s.repo.UpdateLabel(ctx, userID, id, in.Label); err != nil {
			return nil, fmt.Errorf("updating label: %w", err)
		}
	}

	updated, err := s.repo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	return updated, nil
}

// Delete removes one of the user's codes and invalidates its redirect cache if
// it was dynamic.
func (s *Service) Delete(ctx context.Context, userID, id uuid.UUID) error {
	c, err := s.repo.GetByID(ctx, userID, id)
	if err != nil {
		return err
	}
	if err := s.repo.Delete(ctx, userID, id); err != nil {
		return err
	}
	if c.IsDynamic && c.Dynamic != nil {
		if err := s.cache.Invalidate(ctx, c.Dynamic.Slug); err != nil {
			s.log.Warn("invalidating redirect cache after delete failed",
				slog.String("slug", c.Dynamic.Slug), slog.String("error", err.Error()))
		}
	}
	return nil
}

// Cursor is the keyset position used for list pagination.
type Cursor struct {
	CreatedAt time.Time
	ID        uuid.UUID
}

// encodeCursor renders a cursor as an opaque base64 token.
func encodeCursor(c Cursor) string {
	raw := c.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + c.ID.String()
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// decodeCursor parses a token produced by encodeCursor.
func decodeCursor(token string) (*Cursor, error) {
	b, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return nil, err
	}
	parts := strings.SplitN(string(b), "|", 2)
	if len(parts) != 2 {
		return nil, errors.New("malformed cursor")
	}
	ts, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return nil, err
	}
	id, err := uuid.Parse(parts[1])
	if err != nil {
		return nil, err
	}
	return &Cursor{CreatedAt: ts, ID: id}, nil
}

// extractURL pulls payload.url out of a code payload, reporting whether a
// non-empty value was present.
func extractURL(payload []byte) (string, bool) {
	var p struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal(payload, &p); err != nil {
		return "", false
	}
	if p.URL == "" {
		return "", false
	}
	return p.URL, true
}
