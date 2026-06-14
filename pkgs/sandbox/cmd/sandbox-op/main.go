// Command sandbox-op is the in-VM shim installed as /usr/local/bin/op.
//
// It only understands `op read op://<vault>/<item>/<field>` and forwards the
// read to the macOS host via the sandbox bridge. Everything else exits 2 so
// scripts fail loudly instead of silently doing the wrong thing.
package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/cullenmcdermott/system-config/sandbox/internal/bridgeclient"
)

const (
	socketPath = "/run/sandbox/bridge.sock"
	tokenPath  = "/etc/sandbox/bridge-token"

	// bridgeHint is shown when the socket or token isn't there, which usually
	// means the user ran us outside a sandbox-managed session.
	bridgeHint = "sandbox bridge is only available in sessions started via `sandbox claude` / `sandbox shell`"
)

func main() {
	ref, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(2)
	}

	token, err := readToken(tokenPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "sandbox op shim: read bridge token: %v\nhint: %s\n", err, bridgeHint)
		os.Exit(1)
	}

	if _, err := os.Stat(socketPath); err != nil {
		fmt.Fprintf(os.Stderr, "sandbox op shim: bridge socket %s unavailable: %v\nhint: %s\n", socketPath, err, bridgeHint)
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	c := bridgeclient.New(socketPath, token)
	val, err := c.Secret(ctx, ref)
	if err != nil {
		fmt.Fprintf(os.Stderr, "sandbox op shim: %v\n", err)
		os.Exit(1)
	}

	// Match real `op read`: print the value followed by a single newline.
	if _, err := fmt.Fprint(os.Stdout, val+"\n"); err != nil {
		os.Exit(1)
	}
}

func readToken(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	tok := strings.TrimSpace(string(b))
	if tok == "" {
		return "", fmt.Errorf("token file %s is empty", path)
	}
	return tok, nil
}
