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
	path := p.CredentialsPath
	if path == "" {
		home := os.Getenv("HOME")
		if home == "" {
			return "", time.Time{}, fmt.Errorf("HOME not set")
		}
		path = home + "/.claude/.credentials.json"
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("read credentials %s: %w", path, err)
	}
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
