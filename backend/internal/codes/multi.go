package codes

import (
	"encoding/json"
	"strings"
)

// MultiItem is one row on a multi-link page. A row with a URL renders as a
// button; a row with only Text renders as a block the visitor can read or copy
// (a WiFi password, a note). Kind drives the icon and nothing else.
type MultiItem struct {
	Kind  string `json:"kind"`
	Label string `json:"label"`
	URL   string `json:"url,omitempty"`
	Text  string `json:"text,omitempty"`
}

// MultiPayload is the payload JSON of a code of TypeMulti.
type MultiPayload struct {
	Title string      `json:"title"`
	Items []MultiItem `json:"items"`
}

// ParseMulti decodes a multi-link payload. It reports false when the JSON does
// not fit or carries no usable row, which the handler turns into a 400.
func ParseMulti(payload []byte) (*MultiPayload, bool) {
	var p MultiPayload
	if err := json.Unmarshal(payload, &p); err != nil {
		return nil, false
	}
	kept := p.Items[:0]
	for _, item := range p.Items {
		item.Label = strings.TrimSpace(item.Label)
		item.URL = strings.TrimSpace(item.URL)
		item.Text = strings.TrimSpace(item.Text)
		if item.URL == "" && item.Text == "" {
			continue
		}
		kept = append(kept, item)
	}
	p.Items = kept
	if len(p.Items) == 0 {
		return nil, false
	}
	p.Title = strings.TrimSpace(p.Title)
	return &p, true
}

// FirstURL returns the first linked row's URL, used as the stored fallback
// destination so a multi code still has something sane in dynamic_codes.
func (p *MultiPayload) FirstURL() string {
	for _, item := range p.Items {
		if item.URL != "" {
			return item.URL
		}
	}
	return ""
}
