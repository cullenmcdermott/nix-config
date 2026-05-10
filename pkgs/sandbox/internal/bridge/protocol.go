// Package bridge implements the sandbox host bridge protocol.
//
// Requests are NDJSON over a unix socket. One connection = one request + one
// reply. The token is checked first; per-type security is enforced by handlers.
package bridge

import "time"

// Request is a bridge request, sent as a single-line JSON object.
type Request struct {
	Type  string `json:"type"`
	Token string `json:"token"`
	// Ref is for secret.read (op://... URI).
	Ref string `json:"ref,omitempty"`
	// URL is for url.open (must be http:// or https://).
	URL string `json:"url,omitempty"`
}

// Reply is the base error reply.
type Reply struct {
	OK    bool   `json:"ok"`
	Error string `json:"error,omitempty"`
}

// OKReply is returned for secret.read and url.open on success.
type OKReply struct {
	OK    bool   `json:"ok"`
	Value string `json:"value,omitempty"`
}

// AuthReply is returned for claude.auth on success.
type AuthReply struct {
	OK        bool      `json:"ok"`
	Token     string    `json:"token,omitempty"`
	ExpiresAt time.Time `json:"expires_at,omitempty"`
	Error     string    `json:"error,omitempty"`
}
