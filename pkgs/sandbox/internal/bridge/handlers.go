package bridge

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
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

	// OpAllow is the allowlist of op:// reference patterns the VM is permitted
	// to read. A pattern ending in "*" is a prefix match; otherwise the match
	// is exact. An empty slice denies every read — this is the safer default
	// for a fresh install, where the user must opt in to specific refs.
	OpAllow []string
}

// allowRef returns true when ref matches at least one pattern in patterns.
// Pattern semantics:
//   - trailing "*" → prefix match (everything before the "*" must be a prefix
//     of ref); the pattern "*" alone therefore allows everything.
//   - no trailing "*" → exact string match.
//
// An empty pattern list denies everything.
func allowRef(ref string, patterns []string) bool {
	for _, p := range patterns {
		if strings.HasSuffix(p, "*") {
			if strings.HasPrefix(ref, strings.TrimSuffix(p, "*")) {
				return true
			}
		} else if ref == p {
			return true
		}
	}
	return false
}

// Secret reads a reference from 1Password. The ref is validated to start with
// "op://" before being passed to "op read". exec.Command passes each argument
// as a separate argv entry (not shell-expanded), so there is no shell injection
// risk. The op:// prefix also prevents flag injection since refs never start
// with "-".
//
// In addition, the ref must match the OpAllow allowlist. An empty allowlist
// denies all reads with a hint to configure bridge.op_allow.
func (p *ProdHandlers) Secret(ctx context.Context, ref string) (string, error) {
	if !strings.HasPrefix(ref, "op://") {
		return "", fmt.Errorf("ref must start with op://")
	}
	if len(p.OpAllow) == 0 {
		return "", fmt.Errorf(`op read denied: no bridge.op_allow patterns configured in ~/.config/sandbox/config.toml (add e.g. op_allow = ["op://Private/*"] under [bridge])`)
	}
	if !allowRef(ref, p.OpAllow) {
		return "", fmt.Errorf("op read denied: %s does not match any bridge.op_allow pattern", ref)
	}
	cmd := exec.CommandContext(ctx, "op", "read", ref)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("op read %s: %w", ref, err)
	}
	return strings.TrimRight(string(out), "\n"), nil
}

// Open opens a URL on the host via macOS `open`. The VM is untrusted, so the
// scheme is re-validated here even though the server layer also checks it —
// defense in depth, and protects any non-server caller in the future.
func (p *ProdHandlers) Open(ctx context.Context, raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("parse url: %w", err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return fmt.Errorf("url.open: only http(s) URLs allowed, got scheme %q", u.Scheme)
	}
	if u.Host == "" {
		return fmt.Errorf("url.open: empty host in %q", raw)
	}
	cmd := exec.CommandContext(ctx, "open", raw)
	return cmd.Run()
}

// Auth returns the host's Claude credential to the VM. Unlike Secret, there is
// NO allowlist here: any VM process holding the bridge token receives the
// token. This is an intentional credential-egress surface (the in-VM agent must
// authenticate to the Anthropic API on the user's behalf), but it means the
// host's Claude credential is exposed to whatever runs in the sandbox. Prefer
// the short-lived OAuth token (file/keychain) over a static ANTHROPIC_API_KEY:
// the env var is returned with no expiry and, if exfiltrated, does not rotate.
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
