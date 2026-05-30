package qr_test

import (
	"bytes"
	"encoding/json"
	"image/png"
	"testing"

	"github.com/Overover1400/qrsafe/internal/qr"
	"github.com/stretchr/testify/require"
)

func TestContent(t *testing.T) {
	got, err := qr.Content("url", json.RawMessage(`{"url":"https://example.com"}`))
	require.NoError(t, err)
	require.Equal(t, "https://example.com", got)

	_, err = qr.Content("url", json.RawMessage(`{"url":""}`))
	require.ErrorIs(t, err, qr.ErrMissingURL)

	_, err = qr.Content("wifi", json.RawMessage(`{"ssid":"x"}`))
	require.ErrorIs(t, err, qr.ErrUnsupportedType)
}

func TestPNGIsValidImage(t *testing.T) {
	data, err := qr.PNG("https://example.com", 256, qr.ECCMedium)
	require.NoError(t, err)
	require.NotEmpty(t, data)

	// PNG magic header.
	require.True(t, bytes.HasPrefix(data, []byte{0x89, 'P', 'N', 'G'}), "output is not a PNG")

	img, err := png.Decode(bytes.NewReader(data))
	require.NoError(t, err)
	b := img.Bounds()
	require.Equal(t, b.Dx(), b.Dy(), "QR image should be square")
	require.GreaterOrEqual(t, b.Dx(), 200, "256px request should yield a ~256px image")
}

func TestPNGSizeScales(t *testing.T) {
	small, err := qr.PNG("https://example.com", 128, qr.ECCMedium)
	require.NoError(t, err)
	large, err := qr.PNG("https://example.com", 512, qr.ECCMedium)
	require.NoError(t, err)

	smallImg, err := png.Decode(bytes.NewReader(small))
	require.NoError(t, err)
	largeImg, err := png.Decode(bytes.NewReader(large))
	require.NoError(t, err)
	require.Greater(t, largeImg.Bounds().Dx(), smallImg.Bounds().Dx(),
		"a larger size request should yield a larger image")
}

func TestClampSize(t *testing.T) {
	require.Equal(t, qr.MinSize, qr.ClampSize(1))
	require.Equal(t, qr.MaxSize, qr.ClampSize(99999))
	require.Equal(t, 300, qr.ClampSize(300))
}

func TestValidECC(t *testing.T) {
	require.True(t, qr.ValidECC(qr.ECCLow))
	require.True(t, qr.ValidECC(qr.ECCHighest))
	require.False(t, qr.ValidECC(qr.ECC("nonsense")))
}
