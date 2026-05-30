package codes_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

func TestServiceCreateDynamicGeneratesSlug(t *testing.T) {
	pool := newTestPool(t)
	rdb := newTestRedis(t)
	repo := codes.NewRepository(pool)
	svc := codes.NewService(repo, codes.NewRedisCache(rdb), discardLogger(), nil)
	ctx := context.Background()
	userID := insertUser(t, pool)

	c, err := svc.Create(ctx, codes.CreateInput{
		UserID:    userID,
		Type:      string(codes.TypeURL),
		Payload:   json.RawMessage(`{"url":"https://example.com"}`),
		IsDynamic: true,
	})
	require.NoError(t, err)
	require.True(t, c.IsDynamic)
	require.NotNil(t, c.Dynamic)
	require.Len(t, c.Dynamic.Slug, codes.SlugLength)
	require.Equal(t, "https://example.com", c.Dynamic.Destination)
}

func TestServiceCreateDynamicRejectsNonURL(t *testing.T) {
	// No DB needed: the type check happens before any persistence.
	svc := codes.NewService(nil, codes.NewRedisCache(nil), discardLogger(), nil)
	_, err := svc.Create(context.Background(), codes.CreateInput{
		UserID:    uuid.New(),
		Type:      string(codes.TypeText),
		Payload:   json.RawMessage(`{"text":"x"}`),
		IsDynamic: true,
	})
	require.ErrorIs(t, err, codes.ErrDynamicUnsupported)
}

func TestServiceUpdateDestinationInvalidatesCache(t *testing.T) {
	pool := newTestPool(t)
	rdb := newTestRedis(t)
	repo := codes.NewRepository(pool)
	cache := codes.NewRedisCache(rdb)
	svc := codes.NewService(repo, cache, discardLogger(), nil)
	redirectSvc := codes.NewRedirectService(repo, cache, discardLogger())
	ctx := context.Background()
	userID := insertUser(t, pool)

	c, err := svc.Create(ctx, codes.CreateInput{
		UserID:    userID,
		Type:      string(codes.TypeURL),
		Payload:   json.RawMessage(`{"url":"https://before.example"}`),
		IsDynamic: true,
	})
	require.NoError(t, err)
	slug := c.Dynamic.Slug
	t.Cleanup(func() { _ = rdb.Del(ctx, "redirect:"+slug).Err() })

	// Populate the cache by resolving once.
	dest, err := redirectSvc.Resolve(ctx, slug)
	require.NoError(t, err)
	require.Equal(t, "https://before.example", dest)
	n, err := rdb.Exists(ctx, "redirect:"+slug).Result()
	require.NoError(t, err)
	require.Equal(t, int64(1), n, "cache should be populated after a resolve")

	// Updating the destination must invalidate the cache.
	updated, err := svc.Update(ctx, userID, c.ID, codes.UpdateInput{Destination: ptr("https://after.example")})
	require.NoError(t, err)
	require.Equal(t, "https://after.example", updated.Dynamic.Destination)

	n, err = rdb.Exists(ctx, "redirect:"+slug).Result()
	require.NoError(t, err)
	require.Equal(t, int64(0), n, "cache should be invalidated after destination change")

	// A subsequent resolve returns the new destination.
	dest, err = redirectSvc.Resolve(ctx, slug)
	require.NoError(t, err)
	require.Equal(t, "https://after.example", dest)
}

func TestServiceUpdateDestinationOnStaticFails(t *testing.T) {
	pool := newTestPool(t)
	rdb := newTestRedis(t)
	repo := codes.NewRepository(pool)
	svc := codes.NewService(repo, codes.NewRedisCache(rdb), discardLogger(), nil)
	ctx := context.Background()
	userID := insertUser(t, pool)

	c, err := svc.Create(ctx, codes.CreateInput{
		UserID:  userID,
		Type:    string(codes.TypeText),
		Payload: json.RawMessage(`{"text":"hi"}`),
	})
	require.NoError(t, err)

	_, err = svc.Update(ctx, userID, c.ID, codes.UpdateInput{Destination: ptr("https://nope.example")})
	require.ErrorIs(t, err, codes.ErrNotDynamic)
}

func TestServiceAnalytics(t *testing.T) {
	pool := newTestPool(t)
	rdb := newTestRedis(t)
	repo := codes.NewRepository(pool)
	svc := codes.NewService(repo, codes.NewRedisCache(rdb), discardLogger(), nil)
	ctx := context.Background()
	userID := insertUser(t, pool)

	// Dynamic code with a couple of scans.
	c, err := svc.Create(ctx, codes.CreateInput{
		UserID:    userID,
		Type:      string(codes.TypeURL),
		Payload:   json.RawMessage(`{"url":"https://a.example"}`),
		IsDynamic: true,
	})
	require.NoError(t, err)
	for _, ip := range []string{"ip-1", "ip-1", "ip-2"} {
		ipc := ip
		require.NoError(t, repo.InsertScanEvent(ctx, &codes.ScanEvent{Slug: c.Dynamic.Slug, IPHash: &ipc, UserAgent: ptr("curl/8")}))
	}

	a, err := svc.Analytics(ctx, userID, c.ID)
	require.NoError(t, err)
	require.Equal(t, c.ID, a.CodeID)
	require.Equal(t, 3, a.TotalScans)
	require.Equal(t, 2, a.UniqueVisitors)
	require.Len(t, a.Daily, 1)
	require.Len(t, a.TopUserAgents, 1)

	// Static code → zeroed analytics (no slug, no scans), never nil slices.
	static, err := svc.Create(ctx, codes.CreateInput{
		UserID:  userID,
		Type:    string(codes.TypeText),
		Payload: json.RawMessage(`{"text":"hi"}`),
	})
	require.NoError(t, err)
	sa, err := svc.Analytics(ctx, userID, static.ID)
	require.NoError(t, err)
	require.Equal(t, 0, sa.TotalScans)
	require.NotNil(t, sa.Daily)
	require.NotNil(t, sa.TopUserAgents)

	// Another user can't see these analytics.
	other := insertUser(t, pool)
	_, err = svc.Analytics(ctx, other, c.ID)
	require.ErrorIs(t, err, codes.ErrNotFound)
}

func TestServiceDeleteCascadesDynamic(t *testing.T) {
	pool := newTestPool(t)
	rdb := newTestRedis(t)
	repo := codes.NewRepository(pool)
	svc := codes.NewService(repo, codes.NewRedisCache(rdb), discardLogger(), nil)
	ctx := context.Background()
	userID := insertUser(t, pool)

	c, err := svc.Create(ctx, codes.CreateInput{
		UserID:    userID,
		Type:      string(codes.TypeURL),
		Payload:   json.RawMessage(`{"url":"https://gone.example"}`),
		IsDynamic: true,
	})
	require.NoError(t, err)
	slug := c.Dynamic.Slug

	require.NoError(t, svc.Delete(ctx, userID, c.ID))

	// Both the code and its dynamic_codes row are gone.
	_, err = repo.GetByID(ctx, userID, c.ID)
	require.ErrorIs(t, err, codes.ErrNotFound)
	_, _, err = repo.ResolveSlug(ctx, slug)
	require.ErrorIs(t, err, codes.ErrNotFound)
}
