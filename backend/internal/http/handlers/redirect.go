package handlers

import (
	"context"
	"errors"
	"html/template"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/Overover1400/qrsafe/internal/codes"
	"github.com/go-chi/chi/v5"
)

// RedirectService is the surface the public redirect handler depends on.
type RedirectService interface {
	ResolveTarget(ctx context.Context, slug string) (*codes.Target, error)
	RecordScan(ctx context.Context, slug, ipHash, userAgent string)
}

// RedirectHandler serves the public GET /r/{slug} endpoint.
type RedirectHandler struct {
	svc RedirectService
	log *slog.Logger
}

// NewRedirectHandler constructs a RedirectHandler.
func NewRedirectHandler(svc RedirectService, log *slog.Logger) *RedirectHandler {
	return &RedirectHandler{svc: svc, log: log}
}

// scanRecordTimeout bounds the fire-and-forget scan insert that runs after the
// response is sent.
const scanRecordTimeout = 500 * time.Millisecond

const notActiveHTML = `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Code not active</title></head>
<body><h1>This code is no longer active</h1></body>
</html>
`

// multiPageTemplate renders a multi-link code: every link the owner put behind
// the one QR, as buttons, plus any plain notes. html/template escapes the
// payload, and it also blanks out a javascript: href, so an owner cannot turn
// their own page into a script delivery vector.
var multiPageTemplate = template.Must(template.New("multi").Parse(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{{if .Title}}{{.Title}}{{else}}Links{{end}}</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 32px 20px 56px;
    background: #FDF6F0; color: #3D2E1F;
    font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    display: flex; justify-content: center;
  }
  main { width: 100%; max-width: 460px; }
  h1 { font-size: 24px; font-weight: 800; margin: 0 0 24px; text-align: center; }
  a.link {
    display: block; margin: 0 0 12px; padding: 16px 20px;
    background: linear-gradient(135deg, #FFB088, #FF8A65);
    color: #fff; font-weight: 700; text-decoration: none;
    border-radius: 18px; text-align: center;
    box-shadow: 0 8px 20px rgba(255, 138, 101, .3);
    word-break: break-word;
  }
  a.link:active { transform: translateY(1px); }
  .note {
    margin: 0 0 12px; padding: 16px 20px;
    background: #fff; border: 1px solid #FFD9C7;
    border-radius: 18px; word-break: break-word;
  }
  .note strong { display: block; font-size: 13px; color: #8A7260; margin-bottom: 4px; font-weight: 700; }
  footer { margin-top: 32px; text-align: center; font-size: 12px; color: #A89384; }
</style>
</head>
<body>
<main>
  <h1>{{if .Title}}{{.Title}}{{else}}Links{{end}}</h1>
  {{range .Items}}
    {{if .URL}}
      <a class="link" href="{{.URL}}" rel="noopener noreferrer nofollow">{{if .Label}}{{.Label}}{{else}}{{.URL}}{{end}}</a>
    {{else}}
      <div class="note">{{if .Label}}<strong>{{.Label}}</strong>{{end}}{{.Text}}</div>
    {{end}}
  {{end}}
  <footer>Made with QRSafe</footer>
</main>
</body>
</html>
`))

// Redirect resolves the slug and either renders its multi-link page or issues a
// 302 to the current destination. An unknown slug returns a minimal 404 HTML
// page. After responding it records the scan asynchronously (hashed IP, user
// agent) without blocking.
func (h *RedirectHandler) Redirect(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	target, err := h.svc.ResolveTarget(r.Context(), slug)
	if err != nil {
		if errors.Is(err, codes.ErrNotFound) {
			h.log.Info("redirect slug not found", slog.String("slug", slug))
		} else {
			h.log.Error("resolving redirect failed",
				slog.String("slug", slug), slog.String("error", err.Error()))
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(notActiveHTML))
		return
	}

	// Record the scan after responding, decoupled from the request lifecycle:
	// a fresh, short-lived context so it survives the response but can't hang.
	ipHash := codes.HashIP(clientIP(r))
	userAgent := r.UserAgent()
	defer func() {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), scanRecordTimeout)
			defer cancel()
			h.svc.RecordScan(ctx, slug, ipHash, userAgent)
		}()
	}()

	if target.Type == string(codes.TypeMulti) {
		h.renderMulti(w, slug, target)
		return
	}

	http.Redirect(w, r, target.Destination, http.StatusFound)
}

// renderMulti writes the multi-link page. A payload that no longer parses falls
// back to the stored destination so an old code keeps working.
func (h *RedirectHandler) renderMulti(w http.ResponseWriter, slug string, target *codes.Target) {
	page, ok := codes.ParseMulti(target.Payload)
	if !ok {
		h.log.Error("multi payload did not parse", slog.String("slug", slug))
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(notActiveHTML))
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if err := multiPageTemplate.Execute(w, page); err != nil {
		// The status is already sent by now; log and stop.
		h.log.Error("rendering multi page failed",
			slog.String("slug", slug), slog.String("error", err.Error()))
	}
}

// clientIP extracts the client IP, honoring a single X-Forwarded-For hop and
// falling back to the connection's remote address.
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if i := strings.IndexByte(xff, ','); i >= 0 {
			return strings.TrimSpace(xff[:i])
		}
		return strings.TrimSpace(xff)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
