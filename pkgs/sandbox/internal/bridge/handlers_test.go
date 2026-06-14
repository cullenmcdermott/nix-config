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

func TestProdSecret_EmptyAllowlistDenies(t *testing.T) {
	h := &ProdHandlers{}
	_, err := h.Secret(context.Background(), "op://Private/GitHub/token")
	if err == nil {
		t.Fatal("expected denial with empty allowlist")
	}
	if !strings.Contains(err.Error(), "op_allow") {
		t.Errorf("expected hint about op_allow, got: %v", err)
	}
}

func TestProdSecret_NonMatchingRefDenied(t *testing.T) {
	h := &ProdHandlers{OpAllow: []string{"op://Private/*"}}
	_, err := h.Secret(context.Background(), "op://Shared/GitHub/token")
	if err == nil {
		t.Fatal("expected denial for non-matching ref")
	}
	if !strings.Contains(err.Error(), "does not match") {
		t.Errorf("expected non-match error, got: %v", err)
	}
}

func TestAllowRef_EmptyDeniesAll(t *testing.T) {
	if allowRef("op://Private/X/y", nil) {
		t.Error("nil allowlist must deny")
	}
	if allowRef("op://Private/X/y", []string{}) {
		t.Error("empty allowlist must deny")
	}
}

func TestAllowRef_ExactMatch(t *testing.T) {
	pats := []string{"op://Private/GitHub/token"}
	if !allowRef("op://Private/GitHub/token", pats) {
		t.Error("exact match must allow")
	}
	if allowRef("op://Private/GitHub/tokenx", pats) {
		t.Error("longer ref must NOT match an exact pattern")
	}
	if allowRef("op://Private/GitHub", pats) {
		t.Error("prefix of ref must not match exact pattern")
	}
}

func TestAllowRef_PrefixMatch(t *testing.T) {
	pats := []string{"op://Private/*"}
	if !allowRef("op://Private/GitHub/token", pats) {
		t.Error("prefix should match")
	}
	if !allowRef("op://Private/", pats) {
		t.Error("just-the-prefix should match")
	}
	if allowRef("op://Shared/X/y", pats) {
		t.Error("different vault must not match")
	}
}

func TestAllowRef_StarMatchesAll(t *testing.T) {
	if !allowRef("op://anything/at/all", []string{"*"}) {
		t.Error("'*' must allow everything")
	}
	if !allowRef("", []string{"*"}) {
		t.Error("'*' must allow even empty")
	}
}

func TestAllowRef_MultiplePatternsAnyMatchAllows(t *testing.T) {
	pats := []string{"op://Private/GitHub/token", "op://Work/*"}
	if !allowRef("op://Private/GitHub/token", pats) {
		t.Error("first pattern should match")
	}
	if !allowRef("op://Work/AWS/key", pats) {
		t.Error("second pattern should match")
	}
	if allowRef("op://Shared/X/y", pats) {
		t.Error("no pattern should match")
	}
}

func TestProdOpen_RejectsNonHTTPScheme(t *testing.T) {
	h := &ProdHandlers{}
	for _, bad := range []string{
		"file:///etc/passwd",
		"ssh://host/cmd",
		"javascript:alert(1)",
		"ftp://example.com",
	} {
		err := h.Open(context.Background(), bad)
		if err == nil {
			t.Errorf("expected rejection of %q", bad)
			continue
		}
		if !strings.Contains(err.Error(), "http") {
			t.Errorf("error for %q missing http hint: %v", bad, err)
		}
	}
}

func TestProdOpen_RejectsEmptyHost(t *testing.T) {
	h := &ProdHandlers{}
	err := h.Open(context.Background(), "https:///path")
	if err == nil {
		t.Fatal("expected rejection for empty host")
	}
	if !strings.Contains(err.Error(), "host") {
		t.Errorf("expected empty-host error, got %v", err)
	}
}

func TestProdOpen_RejectsMalformedURL(t *testing.T) {
	h := &ProdHandlers{}
	err := h.Open(context.Background(), "http://exa mple.com")
	if err == nil {
		t.Fatal("expected error on malformed URL")
	}
}
