package bridge

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

// testHandlers implements Handlers for unit-testing handleRequest.
type testHandlers struct {
	secret func(ctx context.Context, ref string) (string, error)
	open   func(ctx context.Context, url string) error
	auth   func(ctx context.Context) (string, time.Time, error)
}

func (h *testHandlers) Secret(ctx context.Context, ref string) (string, error) {
	if h.secret != nil {
		return h.secret(ctx, ref)
	}
	return "", nil
}
func (h *testHandlers) Open(ctx context.Context, url string) error {
	if h.open != nil {
		return h.open(ctx, url)
	}
	return nil
}
func (h *testHandlers) Auth(ctx context.Context) (string, time.Time, error) {
	if h.auth != nil {
		return h.auth(ctx)
	}
	return "", time.Time{}, nil
}

// roundTripRequest calls handleRequest on a server and returns the reply bytes.
func roundTripRequest(srv *Server, req Request) string {
	var buf bytes.Buffer
	srv.handleRequest(context.Background(), &buf, req)
	return buf.String()
}

func parseReply(t *testing.T, body string) (ok bool, errMsg string) {
	t.Helper()
	var r Reply
	if err := json.Unmarshal([]byte(body), &r); err != nil {
		t.Fatalf("not JSON: %s: %v", body, err)
	}
	return r.OK, r.Error
}

func parseOKReply(t *testing.T, body string) (ok bool, value string) {
	t.Helper()
	var r OKReply
	if err := json.Unmarshal([]byte(body), &r); err != nil {
		t.Fatalf("not OKReply JSON: %s: %v", body, err)
	}
	return r.OK, r.Value
}

func parseAuthReply(t *testing.T, body string) (ok bool, token string, exp time.Time) {
	t.Helper()
	var r AuthReply
	if err := json.Unmarshal([]byte(body), &r); err != nil {
		t.Fatalf("not AuthReply JSON: %s: %v", body, err)
	}
	return r.OK, r.Token, r.ExpiresAt
}

func TestHandleRequest_RejectsBadToken(t *testing.T) {
	srv := NewServer("/unused", "right-token", &testHandlers{}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "secret.read", Token: "wrong", Ref: "op://X"})
	ok, errMsg := parseReply(t, out)
	if ok || !strings.Contains(errMsg, "invalid token") {
		t.Errorf("expected invalid-token error, got ok=%v msg=%q output=%s", ok, errMsg, out)
	}
}

func TestHandleRequest_SecretRead_CallsHandler(t *testing.T) {
	called := ""
	srv := NewServer("/unused", "tok", &testHandlers{
		secret: func(_ context.Context, ref string) (string, error) {
			called = ref
			return "s3cret", nil
		},
	}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "secret.read", Token: "tok", Ref: "op://Vault/Item/password"})
	if called != "op://Vault/Item/password" {
		t.Errorf("handler called with %q, want %q", called, "op://Vault/Item/password")
	}
	ok, val := parseOKReply(t, out)
	if !ok {
		t.Fatalf("expected ok=true, got: %s", out)
	}
	if val != "s3cret" {
		t.Errorf("value=%q, want %q", val, "s3cret")
	}
}

func TestHandleRequest_SecretRead_RejectsNonOpRef(t *testing.T) {
	srv := NewServer("/unused", "tok", &testHandlers{}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "secret.read", Token: "tok", Ref: "https://evil.com"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected rejection, got ok=true: %s", out)
	}
	if !strings.Contains(errMsg, "op://") {
		t.Errorf("expected op:// error, got: %s", errMsg)
	}
}

func TestHandleRequest_SecretRead_HandlerError(t *testing.T) {
	srv := NewServer("/unused", "tok", &testHandlers{
		secret: func(_ context.Context, ref string) (string, error) {
			return "", context.DeadlineExceeded
		},
	}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "secret.read", Token: "tok", Ref: "op://X"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected error, got ok=true: %s", out)
	}
	if !strings.Contains(errMsg, "context deadline exceeded") {
		t.Errorf("expected deadline error, got: %s", errMsg)
	}
}

func TestHandleRequest_URLOpen_CallsHandler(t *testing.T) {
	called := ""
	srv := NewServer("/unused", "tok", &testHandlers{
		open: func(_ context.Context, url string) error {
			called = url
			return nil
		},
	}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "url.open", Token: "tok", URL: "https://example.com"})
	if called != "https://example.com" {
		t.Errorf("open called with %q", called)
	}
	ok, _ := parseReply(t, out)
	if !ok {
		t.Errorf("expected ok=true: %s", out)
	}
}

func TestHandleRequest_URLOpen_RejectsFileScheme(t *testing.T) {
	srv := NewServer("/unused", "tok", &testHandlers{}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "url.open", Token: "tok", URL: "file:///etc/passwd"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected rejection: %s", out)
	}
	if !strings.Contains(errMsg, "http") {
		t.Errorf("expected http error, got: %s", errMsg)
	}
}

func TestHandleRequest_URLOpen_RejectsSSHScheme(t *testing.T) {
	srv := NewServer("/unused", "tok", &testHandlers{}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "url.open", Token: "tok", URL: "ssh://host"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected rejection: %s", out)
	}
	if !strings.Contains(errMsg, "http") {
		t.Errorf("expected http error, got: %s", errMsg)
	}
}

func TestHandleRequest_Auth_ReturnsTokenAndExpiry(t *testing.T) {
	exp := time.Date(2030, 6, 15, 0, 0, 0, 0, time.UTC)
	srv := NewServer("/unused", "tok", &testHandlers{
		auth: func(_ context.Context) (string, time.Time, error) {
			return "jwt-token", exp, nil
		},
	}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "claude.auth", Token: "tok"})
	ok, tok, gotExp := parseAuthReply(t, out)
	if !ok {
		t.Fatalf("expected ok=true: %s", out)
	}
	if tok != "jwt-token" {
		t.Errorf("token=%q, want %q", tok, "jwt-token")
	}
	if !gotExp.Equal(exp) {
		t.Errorf("expires_at=%v, want %v", gotExp, exp)
	}
}

func TestHandleRequest_Auth_HandlerError(t *testing.T) {
	srv := NewServer("/unused", "tok", &testHandlers{
		auth: func(_ context.Context) (string, time.Time, error) {
			return "", time.Time{}, context.DeadlineExceeded
		},
	}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "claude.auth", Token: "tok"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected error: %s", out)
	}
	if !strings.Contains(errMsg, "context deadline exceeded") {
		t.Errorf("expected deadline error: %s", errMsg)
	}
}

func TestHandleRequest_UnknownType(t *testing.T) {
	srv := NewServer("/unused", "tok", &testHandlers{}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "bad.type", Token: "tok"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected error: %s", out)
	}
	if !strings.Contains(errMsg, "unknown type") {
		t.Errorf("expected unknown type error, got: %s", errMsg)
	}
}

func TestHandleRequest_SecretRead_RefWithHTTPsPrefix(t *testing.T) {
	// https:// is NOT an op:// prefix.
	srv := NewServer("/unused", "tok", &testHandlers{}, 15*time.Second)
	out := roundTripRequest(srv, Request{Type: "secret.read", Token: "tok", Ref: "https://example.com/secret"})
	ok, errMsg := parseReply(t, out)
	if ok {
		t.Errorf("expected rejection of https:// ref: %s", out)
	}
	if !strings.Contains(errMsg, "op://") {
		t.Errorf("expected op:// error, got: %s", errMsg)
	}
}
