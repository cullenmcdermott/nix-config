package bridge

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// ProdHandlers wires the bridge to the host's 1Password CLI, macOS open, and
// the Claude credentials file.
type ProdHandlers struct {
	// CredentialsPath defaults to ~/.claude/.credentials.json.
	CredentialsPath string
}

// Secret reads a reference from 1Password. The ref is validated to start with
// "op://" before being passed to "op read". exec.Command passes each argument
// as a separate argv entry (not shell-expanded), so there is no shell injection
// risk. The op:// prefix also prevents flag injection since refs never start
// with "-".
func (p *ProdHandlers) Secret(ctx context.Context, ref string) (string, error) {
	if !strings.HasPrefix(ref, "op://") {
		return "", fmt.Errorf("ref must start with op://")
	}
	cmd := exec.CommandContext(ctx, "op", "read", ref)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("op read %s: %w", ref, err)
	}
	return strings.TrimRight(string(out), "\n"), nil
}

func (p *ProdHandlers) Open(ctx context.Context, url string) error {
	cmd := exec.CommandContext(ctx, "open", url)
	return cmd.Run()
}

func (p *ProdHandlers) Auth(ctx context.Context) (string, time.Time, error) {
	// 1. Explicit environment variable — highest priority, no expiry.
	if key := os.Getenv("ANTHROPIC_API_KEY"); key != "" {
		return key, time.Time{}, nil
	}

	// 2. Credentials file written by `claude setup-token` or `claude login`.
	path := p.CredentialsPath
	if path == "" {
		home := os.Getenv("HOME")
		if home == "" {
			return "", time.Time{}, fmt.Errorf("HOME not set")
		}
		path = home + "/.claude/.credentials.json"
	}
	b, err := os.ReadFile(path)
	if err == nil {
		tok, exp, parseErr := parseCredentialsFile(b)
		if parseErr == nil {
			return tok, exp, nil
		}
		return "", time.Time{}, parseErr
	}

	// 3. macOS Keychain — Claude Code stores OAuth tokens under
	//    service "Claude Code-credentials".
	tok, exp, keychainErr := readKeychainCredentials(ctx)
	if keychainErr == nil {
		return tok, exp, nil
	}

	return "", time.Time{}, fmt.Errorf("no credentials found:\n  file: %w\n  keychain: %v\nhint: run `claude setup-token` or set ANTHROPIC_API_KEY", err, keychainErr)
}

func parseCredentialsFile(b []byte) (string, time.Time, error) {
	var creds struct {
		AccessToken string    `json:"access_token"`
		Token       string    `json:"token"`
		ExpiresAt   time.Time `json:"expires_at"`
	}
	if err := json.Unmarshal(b, &creds); err != nil {
		return "", time.Time{}, fmt.Errorf("parse credentials: %w", err)
	}
	tok := creds.AccessToken
	if tok == "" {
		tok = creds.Token
	}
	if tok == "" {
		return "", time.Time{}, fmt.Errorf("no access_token in credentials file")
	}
	return tok, creds.ExpiresAt, nil
}

// readKeychainCredentials shells out to `security find-generic-password` to
// read the OAuth token that Claude Code stores in the macOS login keychain.
func readKeychainCredentials(ctx context.Context) (string, time.Time, error) {
	user := os.Getenv("USER")
	if user == "" {
		return "", time.Time{}, fmt.Errorf("USER not set")
	}
	cmd := exec.CommandContext(ctx, "security", "find-generic-password",
		"-s", "Claude Code-credentials", "-a", user, "-w")
	out, err := cmd.Output()
	if err != nil {
		return "", time.Time{}, fmt.Errorf("security find-generic-password: %w", err)
	}

	var wrapper struct {
		ClaudeAiOauth struct {
			AccessToken string `json:"accessToken"`
			ExpiresAt   int64  `json:"expiresAt"` // epoch millis
		} `json:"claudeAiOauth"`
	}
	if err := json.Unmarshal(out, &wrapper); err != nil {
		return "", time.Time{}, fmt.Errorf("parse keychain credentials: %w", err)
	}
	tok := wrapper.ClaudeAiOauth.AccessToken
	if tok == "" {
		return "", time.Time{}, fmt.Errorf("no accessToken in keychain credentials")
	}
	var exp time.Time
	if wrapper.ClaudeAiOauth.ExpiresAt > 0 {
		exp = time.UnixMilli(wrapper.ClaudeAiOauth.ExpiresAt)
	}
	return tok, exp, nil
}
