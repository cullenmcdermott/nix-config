package bridge

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestProdAuth_ReadsCredentialsFile(t *testing.T) {
	dir := t.TempDir()
	credPath := filepath.Join(dir, "creds.json")
	exp := time.Now().Add(time.Hour).UTC().Truncate(time.Second)
	body := map[string]any{
		"access_token": "fake-jwt",
		"expires_at":   exp.Format(time.RFC3339),
	}
	b, _ := json.Marshal(body)
	_ = os.WriteFile(credPath, b, 0o600)

	h := &ProdHandlers{CredentialsPath: credPath}
	tok, gotExp, err := h.Auth(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if tok != "fake-jwt" {
		t.Errorf("token = %q", tok)
	}
	if !gotExp.Equal(exp) {
		t.Errorf("expires_at = %v, want %v", gotExp, exp)
	}
}

func TestProdAuth_FallsBackToTokenField(t *testing.T) {
	dir := t.TempDir()
	credPath := filepath.Join(dir, "creds.json")
	body := map[string]any{
		"token":      "fallback-jwt",
		"expires_at": time.Now().Add(time.Hour).Format(time.RFC3339),
	}
	b, _ := json.Marshal(body)
	_ = os.WriteFile(credPath, b, 0o600)

	h := &ProdHandlers{CredentialsPath: credPath}
	tok, _, err := h.Auth(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if tok != "fallback-jwt" {
		t.Errorf("expected fallback token, got %q", tok)
	}
}

func TestProdAuth_MissingFile(t *testing.T) {
	h := &ProdHandlers{CredentialsPath: filepath.Join(t.TempDir(), "nope")}
	_, _, err := h.Auth(context.Background())
	if err == nil || !strings.Contains(err.Error(), "credentials") {
		t.Errorf("expected credentials error, got %v", err)
	}
}

func TestProdAuth_NoAccessTokenField(t *testing.T) {
	dir := t.TempDir()
	credPath := filepath.Join(dir, "creds.json")
	body := map[string]any{
		"expires_at": time.Now().Add(time.Hour).Format(time.RFC3339),
	}
	b, _ := json.Marshal(body)
	_ = os.WriteFile(credPath, b, 0o600)

	h := &ProdHandlers{CredentialsPath: credPath}
	_, _, err := h.Auth(context.Background())
	if err == nil || !strings.Contains(err.Error(), "no access_token") {
		t.Errorf("expected 'no access_token' error, got %v", err)
	}
}

func TestProdAuth_InvalidJSON(t *testing.T) {
	dir := t.TempDir()
	credPath := filepath.Join(dir, "creds.json")
	_ = os.WriteFile(credPath, []byte("not json"), 0o600)

	h := &ProdHandlers{CredentialsPath: credPath}
	_, _, err := h.Auth(context.Background())
	if err == nil || !strings.Contains(err.Error(), "parse credentials") {
		t.Errorf("expected parse error, got %v", err)
	}
}

func TestProdSecret_RefMustStartWithOp(t *testing.T) {
	h := &ProdHandlers{}
	_, err := h.Secret(context.Background(), "https://evil.com")
	if err == nil || !strings.Contains(err.Error(), "op://") {
		t.Errorf("expected op:// error, got %v", err)
	}
}
