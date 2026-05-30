package codes_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/stretchr/testify/require"
)

func TestRepositoryCRUD(t *testing.T) {
	pool := newTestPool(t)
	repo := codes.NewRepository(pool)
	ctx := context.Background()
	userID := insertUser(t, pool)

	// Create a static code.
	static := &codes.Code{
		UserID:  userID,
		Type:    string(codes.TypeText),
		Payload: json.RawMessage(`{"text":"hello"}`),
		Label:   ptr("a note"),
	}
	require.NoError(t, repo.Create(ctx, static))
	require.NotEqual(t, "00000000-0000-0000-0000-000000000000", static.ID.String())
	require.False(t, static.CreatedAt.IsZero())

	// Fetch it back.
	got, err := repo.GetByID(ctx, userID, static.ID)
	require.NoError(t, err)
	require.Equal(t, static.ID, got.ID)
	require.Equal(t, string(codes.TypeText), got.Type)
	require.Nil(t, got.Dynamic)
	var payload map[string]string
	require.NoError(t, json.Unmarshal(got.Payload, &payload))
	require.Equal(t, "hello", payload["text"])

	// Create a dynamic code.
	dyn := &codes.Code{
		UserID:  userID,
		Type:    string(codes.TypeURL),
		Payload: json.RawMessage(`{"url":"https://a.example"}`),
	}
	require.NoError(t, repo.CreateDynamic(ctx, dyn, "slugAAA1", "https://a.example"))
	require.True(t, dyn.IsDynamic)
	require.NotNil(t, dyn.Dynamic)

	gotDyn, err := repo.GetByID(ctx, userID, dyn.ID)
	require.NoError(t, err)
	require.NotNil(t, gotDyn.Dynamic)
	require.Equal(t, "slugAAA1", gotDyn.Dynamic.Slug)
	require.Equal(t, "https://a.example", gotDyn.Dynamic.Destination)

	// List returns newest first: the dynamic code was created last.
	list, err := repo.List(ctx, userID, nil, 10)
	require.NoError(t, err)
	require.Len(t, list, 2)
	require.Equal(t, dyn.ID, list[0].ID)
	require.Equal(t, static.ID, list[1].ID)

	// Update label on the static code.
	require.NoError(t, repo.UpdateLabel(ctx, userID, static.ID, ptr("updated label")))
	got, err = repo.GetByID(ctx, userID, static.ID)
	require.NoError(t, err)
	require.NotNil(t, got.Label)
	require.Equal(t, "updated label", *got.Label)

	// Update destination on the dynamic code.
	require.NoError(t, repo.UpdateDestination(ctx, dyn.ID, "https://b.example"))
	gotDyn, err = repo.GetByID(ctx, userID, dyn.ID)
	require.NoError(t, err)
	require.Equal(t, "https://b.example", gotDyn.Dynamic.Destination)

	// ResolveSlug reflects the updated destination.
	dest, codeID, err := repo.ResolveSlug(ctx, "slugAAA1")
	require.NoError(t, err)
	require.Equal(t, "https://b.example", dest)
	require.Equal(t, dyn.ID, codeID)

	// Delete the static code.
	require.NoError(t, repo.Delete(ctx, userID, static.ID))
	_, err = repo.GetByID(ctx, userID, static.ID)
	require.ErrorIs(t, err, codes.ErrNotFound)

	// Deleting the dynamic code cascades to dynamic_codes.
	require.NoError(t, repo.Delete(ctx, userID, dyn.ID))
	_, _, err = repo.ResolveSlug(ctx, "slugAAA1")
	require.ErrorIs(t, err, codes.ErrNotFound)
}

func TestRepositorySlugCollision(t *testing.T) {
	pool := newTestPool(t)
	repo := codes.NewRepository(pool)
	ctx := context.Background()
	userID := insertUser(t, pool)

	first := &codes.Code{UserID: userID, Type: string(codes.TypeURL), Payload: json.RawMessage(`{"url":"https://x"}`)}
	require.NoError(t, repo.CreateDynamic(ctx, first, "dupSLUG1", "https://x"))

	second := &codes.Code{UserID: userID, Type: string(codes.TypeURL), Payload: json.RawMessage(`{"url":"https://y"}`)}
	err := repo.CreateDynamic(ctx, second, "dupSLUG1", "https://y")
	require.ErrorIs(t, err, codes.ErrSlugTaken)

	// The rolled-back transaction must not have left a code row behind.
	list, err := repo.List(ctx, userID, nil, 10)
	require.NoError(t, err)
	require.Len(t, list, 1)
}

func TestRepositoryScanAnalytics(t *testing.T) {
	pool := newTestPool(t)
	repo := codes.NewRepository(pool)
	ctx := context.Background()
	userID := insertUser(t, pool)

	dyn := &codes.Code{UserID: userID, Type: string(codes.TypeURL), Payload: json.RawMessage(`{"url":"https://a.example"}`)}
	require.NoError(t, repo.CreateDynamic(ctx, dyn, "anlytcs1", "https://a.example"))
	slug := dyn.Dynamic.Slug

	// Two distinct IPs (one repeated) and two user agents.
	events := []codes.ScanEvent{
		{Slug: slug, IPHash: ptr("ip-a"), UserAgent: ptr("curl/8")},
		{Slug: slug, IPHash: ptr("ip-a"), UserAgent: ptr("curl/8")},
		{Slug: slug, IPHash: ptr("ip-b"), UserAgent: ptr("Mozilla/5.0")},
		{Slug: slug, IPHash: nil, UserAgent: nil}, // unknown ip + ua
	}
	for i := range events {
		e := events[i]
		require.NoError(t, repo.InsertScanEvent(ctx, &e))
	}

	total, unique, err := repo.ScanCounts(ctx, slug)
	require.NoError(t, err)
	require.Equal(t, 4, total)
	require.Equal(t, 2, unique, "distinct non-null ip_hash count")

	daily, err := repo.ScanDaily(ctx, slug)
	require.NoError(t, err)
	require.Len(t, daily, 1, "all scans recorded today → one bucket")
	require.Equal(t, 4, daily[0].Count)

	uas, err := repo.ScanTopUserAgents(ctx, slug, 10)
	require.NoError(t, err)
	require.Len(t, uas, 2)
	require.Equal(t, "curl/8", uas[0].UserAgent, "most frequent first")
	require.Equal(t, 2, uas[0].Count)

	// A slug with no scans yields zeros / empty.
	total, unique, err = repo.ScanCounts(ctx, "noscans1")
	require.NoError(t, err)
	require.Equal(t, 0, total)
	require.Equal(t, 0, unique)
}

func TestRepositoryUserIsolation(t *testing.T) {
	pool := newTestPool(t)
	repo := codes.NewRepository(pool)
	ctx := context.Background()
	owner := insertUser(t, pool)
	other := insertUser(t, pool)

	c := &codes.Code{UserID: owner, Type: string(codes.TypeText), Payload: json.RawMessage(`{"text":"secret"}`)}
	require.NoError(t, repo.Create(ctx, c))

	// The other user can't see, update, or delete the owner's code.
	_, err := repo.GetByID(ctx, other, c.ID)
	require.ErrorIs(t, err, codes.ErrNotFound)

	list, err := repo.List(ctx, other, nil, 10)
	require.NoError(t, err)
	require.Empty(t, list)

	require.ErrorIs(t, repo.UpdateLabel(ctx, other, c.ID, ptr("hax")), codes.ErrNotFound)
	require.ErrorIs(t, repo.Delete(ctx, other, c.ID), codes.ErrNotFound)

	// The owner still can.
	got, err := repo.GetByID(ctx, owner, c.ID)
	require.NoError(t, err)
	require.Equal(t, c.ID, got.ID)
}

func TestPaginationCursor(t *testing.T) {
	pool := newTestPool(t)
	repo := codes.NewRepository(pool)
	svc := codes.NewService(repo, codes.NewRedisCache(nil), discardLogger(), nil)
	ctx := context.Background()
	userID := insertUser(t, pool)

	// Create five codes.
	for i := 0; i < 5; i++ {
		c := &codes.Code{UserID: userID, Type: string(codes.TypeText), Payload: json.RawMessage(`{"text":"x"}`)}
		require.NoError(t, repo.Create(ctx, c))
	}

	// Page through 2 at a time and collect ids; expect all 5, no repeats.
	seen := map[string]struct{}{}
	cursor := ""
	pages := 0
	for {
		res, err := svc.List(ctx, userID, cursor, 2)
		require.NoError(t, err)
		for _, c := range res.Codes {
			_, dup := seen[c.ID.String()]
			require.False(t, dup, "id appeared on two pages")
			seen[c.ID.String()] = struct{}{}
		}
		pages++
		require.LessOrEqual(t, pages, 10, "pagination did not terminate")
		if res.NextCursor == "" {
			break
		}
		cursor = res.NextCursor
	}
	require.Len(t, seen, 5)
}
