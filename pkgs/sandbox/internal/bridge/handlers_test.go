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

func TestProdAuth_EnvVarTakesPriority(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "sk-from-env")

	// Even with a valid credentials file, env var wins.
	dir := t.TempDir()
	credPath := filepath.Join(dir, "creds.json")
	body := map[string]any{"access_token": "from-file"}
	b, _ := json.Marshal(body)
	_ = os.WriteFile(credPath, b, 0o600)

	h := &ProdHandlers{CredentialsPath: credPath}
	tok, exp, err := h.Auth(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if tok != "sk-from-env" {
		t.Errorf("token = %q, want sk-from-env", tok)
	}
	if !exp.IsZero() {
		t.Errorf("expected zero expiry for env var token, got %v", exp)
	}
}
func TestProdAuth_ReadsCredentialsFile(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "") // clear so file path is exercised
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

func TestProdAuth_MissingFile_FallsToKeychain(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "")
	// With a missing file and (likely) no matching keychain entry in CI,
	// Auth should return an error mentioning "credentials".
	// On a dev machine with Claude Code OAuth this might succeed via keychain.
	h := &ProdHandlers{CredentialsPath: filepath.Join(t.TempDir(), "nope")}
	_, _, err := h.Auth(context.Background())
	// Either it succeeds via keychain or errors with "credentials"
	if err != nil && !strings.Contains(err.Error(), "credentials") {
		t.Errorf("expected credentials-related error, got %v", err)
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

func TestParseCredentialsFile_Valid(t *testing.T) {
	body := map[string]any{
		"access_token": "test-tok",
		"expires_at":   "2030-01-01T00:00:00Z",
	}
	b, _ := json.Marshal(body)
	tok, exp, err := parseCredentialsFile(b)
	if err != nil {
		t.Fatal(err)
	}
	if tok != "test-tok" {
		t.Errorf("token = %q", tok)
	}
	if exp.Year() != 2030 {
		t.Errorf("expected 2030, got %v", exp)
	}
}

func TestParseCredentialsFile_FallbackToken(t *testing.T) {
	body := map[string]any{"token": "fb-tok"}
	b, _ := json.Marshal(body)
	tok, _, err := parseCredentialsFile(b)
	if err != nil {
		t.Fatal(err)
	}
	if tok != "fb-tok" {
		t.Errorf("token = %q, want fb-tok", tok)
	}
}

func TestParseCredentialsFile_Empty(t *testing.T) {
	b, _ := json.Marshal(map[string]any{})
	_, _, err := parseCredentialsFile(b)
	if err == nil || !strings.Contains(err.Error(), "no access_token") {
		t.Errorf("expected error, got %v", err)
	}
}

func TestProdSecret_RefMustStartWithOp(t *testing.T) {
	h := &ProdHandlers{}
	_, err := h.Secret(context.Background(), "https://evil.com")
	if err == nil || !strings.Contains(err.Error(), "op://") {
		t.Errorf("expected op:// error, got %v", err)
	}
}
