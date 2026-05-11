package bridgeclient

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"
)

func startEchoServer(t *testing.T, reply string) string {
	t.Helper()
	// Use a short manual temp dir to avoid exceeding macOS's 104-char socket path limit.
	dir, err := os.MkdirTemp("", "bc")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(dir) })
	sock := filepath.Join(dir, "b.sock")
	lis, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = lis.Close() })
	go func() {
		for {
			c, err := lis.Accept()
			if err != nil {
				return
			}
			go func() {
				defer func() { _ = c.Close() }()
				_, _ = bufio.NewReader(c).ReadBytes('\n') // discard request
				_, _ = c.Write([]byte(reply + "\n"))
			}()
		}
	}()
	return sock
}

func TestClient_Auth(t *testing.T) {
	body := `{"ok":true,"token":"abc","expires_at":"2030-01-01T00:00:00Z"}`
	sock := startEchoServer(t, body)
	c := New(sock, "tok")
	got, err := c.Auth(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if got.Token != "abc" {
		t.Errorf("got %+v", got)
	}
}

func TestClient_Secret_RoundTrip(t *testing.T) {
	body := `{"ok":true,"value":"hello"}`
	sock := startEchoServer(t, body)
	c := New(sock, "tok")
	v, err := c.Secret(context.Background(), "op://X/Y/Z")
	if err != nil {
		t.Fatal(err)
	}
	if v != "hello" {
		t.Errorf("got %q", v)
	}
}

func TestClient_ErrorReply(t *testing.T) {
	body := `{"ok":false,"error":"boom"}`
	sock := startEchoServer(t, body)
	c := New(sock, "tok")
	if _, err := c.Secret(context.Background(), "op://X"); err == nil {
		t.Fatal("expected error")
	}
}

func TestClient_DecodesValue_AsLiteralValue(t *testing.T) {
	body := `{"ok":true,"value":"a\nb"}`
	sock := startEchoServer(t, body)
	c := New(sock, "tok")
	v, err := c.Secret(context.Background(), "op://X")
	if err != nil {
		t.Fatal(err)
	}
	if v != "a\nb" {
		t.Errorf("got %q", v)
	}
	// Confirm json.Unmarshal handled the escape:
	var raw map[string]any
	_ = json.Unmarshal([]byte(body), &raw)
	if raw["value"] != "a\nb" {
		t.Errorf("encoder sanity check failed")
	}
}
