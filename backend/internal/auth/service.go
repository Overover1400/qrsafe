package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/Overover1400/qrsafe/internal/users"
	"github.com/google/uuid"
)

var (
	// ErrAlreadyUpgraded is returned when an upgrade is attempted on a user
	// that is no longer a guest.
	ErrAlreadyUpgraded = errors.New("user is already upgraded")
	// ErrInvalidCredentials is returned by Login when email/password do not
	// match a stored account.
	ErrInvalidCredentials = errors.New("invalid credentials")
)

// Repository is the persistence surface the auth service needs. The concrete
// implementation lives in the users package.
type Repository interface {
	Create(ctx context.Context, u *users.User) error
	GetByID(ctx context.Context, id uuid.UUID) (*users.User, error)
	GetByEmail(ctx context.Context, email string) (*users.User, error)
	Update(ctx context.Context, u *users.User) error
}

// Result bundles a user with a freshly issued token and its expiry.
type Result struct {
	User      *users.User
	Token     string
	ExpiresAt time.Time
}

// Service holds the authentication business logic.
type Service struct {
	repo   Repository
	tokens *TokenManager
	now    func() time.Time
}

// NewService constructs a Service. The clock is fixed to time.Now; tests that
// need determinism can construct tokens directly via TokenManager.
func NewService(repo Repository, tokens *TokenManager) *Service {
	return &Service{repo: repo, tokens: tokens, now: time.Now}
}

// CreateGuest creates an anonymous user and issues a guest token.
func (s *Service) CreateGuest(ctx context.Context) (*Result, error) {
	u := &users.User{IsGuest: true}
	if err := s.repo.Create(ctx, u); err != nil {
		return nil, fmt.Errorf("creating guest user: %w", err)
	}
	return s.issue(u)
}

// UpgradeToAccount converts a guest into an email+password account and issues a
// fresh (non-guest) token. It is the caller's responsibility to have validated
// email/password format before calling.
func (s *Service) UpgradeToAccount(ctx context.Context, userID uuid.UUID, email, password string) (*Result, error) {
	u, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("fetching user for upgrade: %w", err)
	}
	if !u.IsGuest {
		return nil, ErrAlreadyUpgraded
	}

	hash, err := HashPassword(password)
	if err != nil {
		return nil, fmt.Errorf("hashing password: %w", err)
	}

	u.Email = &email
	u.PasswordHash = &hash
	u.IsGuest = false
	if err := s.repo.Update(ctx, u); err != nil {
		return nil, fmt.Errorf("updating user for upgrade: %w", err)
	}
	return s.issue(u)
}

// Login verifies email/password and issues a token. Provided for completeness;
// not yet wired to an endpoint.
func (s *Service) Login(ctx context.Context, email, password string) (*Result, error) {
	u, err := s.repo.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, users.ErrNotFound) {
			return nil, ErrInvalidCredentials
		}
		return nil, fmt.Errorf("fetching user for login: %w", err)
	}
	if u.PasswordHash == nil {
		return nil, ErrInvalidCredentials
	}

	ok, err := VerifyPassword(password, *u.PasswordHash)
	if err != nil {
		return nil, fmt.Errorf("verifying password: %w", err)
	}
	if !ok {
		return nil, ErrInvalidCredentials
	}
	return s.issue(u)
}

func (s *Service) issue(u *users.User) (*Result, error) {
	token, expiresAt, err := s.tokens.Issue(u.ID, u.IsGuest, s.now())
	if err != nil {
		return nil, fmt.Errorf("issuing token: %w", err)
	}
	return &Result{User: u, Token: token, ExpiresAt: expiresAt}, nil
}
